#
# Cookbook:: openstack-dashboard
# Recipe:: horizon
#
# Copyright:: 2012, Rackspace US, Inc.
# Copyright:: 2012-2013, AT&T Services, Inc.
# Copyright:: 2013-2014, IBM, Corp.
# Copyright:: 2014, SUSE Linux, GmbH.
# Copyright:: 2014, x-ion, GmbH.
# Copyright:: 2019-2020, Oregon State University
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class ::Chef::Recipe
  include ::Openstack
end

platform_options = node['openstack']['dashboard']['platform']

identity_endpoint = internal_endpoint 'identity'
auth_url = identity_endpoint.to_s

http_bind = node['openstack']['bind_service']['dashboard_http']
http_bind_address = bind_address http_bind
https_bind = node['openstack']['bind_service']['dashboard_https']
https_bind_address = bind_address https_bind

horizon_host =
  if node['openstack']['dashboard']['use_ssl']
    https_bind_address
  else
    http_bind_address
  end

db_pass = get_password 'db', 'horizon'
db_info = db 'dashboard'

python_packages = node['openstack']['db']['python_packages'][db_info['service_type']]
# Add dashboard specific database packages
python_packages += Array(node['openstack']['dashboard']['db_python_packages'][db_info['service_type']])
package platform_options['horizon_packages'] + python_packages do
  action :upgrade
  options platform_options['package_overrides']
end

if node['openstack']['dashboard']['session_backend'] == 'memcached'
  platform_options['memcache_python_packages'].each do |pkg|
    package pkg
  end
end

django_path = node['openstack']['dashboard']['django_path']
memcached = memcached_servers

template node['openstack']['dashboard']['local_settings_path'] do
  source 'local_settings.py.erb'
  owner 'root'
  group node['openstack']['dashboard']['horizon_group']
  mode '640'
  sensitive true

  variables(
    db_pass: db_pass,
    db_info: db_info,
    auth_url: auth_url,
    memcached_servers: memcached,
    host: horizon_host
  )

  notifies :restart, 'service[apache2]', :delayed
end

execute 'openstack-dashboard syncdb' do
  cwd django_path
  environment 'PYTHONPATH' => "/etc/openstack-dashboard:#{django_path}:$PYTHONPATH"
  command 'python manage.py syncdb --noinput'
  action :run
  only_if do
    (node['openstack']['dashboard']['session_backend'] == 'sql' &&
     node['openstack']['db']['dashboard']['migrate'] ||
     db_info['service_type'] == 'sqlite')
  end
end

directory "#{node['openstack']['dashboard']['dash_path']}/local" do
  owner 'root'
  group node['openstack']['dashboard']['horizon_group']
  mode '2770'
end

# resource can be triggered from other recipes (e.g. in
# recipes/neutron-lbaas-dashboard.rb)
execute 'openstack-dashboard collectstatic' do
  cwd django_path
  environment 'PYTHONPATH' => "/etc/openstack-dashboard:#{django_path}:$PYTHONPATH"
  command 'python manage.py collectstatic --noinput'
  action :nothing
end

# workaround for
# https://bugs.launchpad.net/openstack-chef/+bug/1496158
secret_file =
  ::File.join(node['openstack']['dashboard']['django_path'],
              'openstack_dashboard',
              'local',
              '.secret_key_store')

file secret_file do
  owner node['openstack']['dashboard']['horizon_user']
  group node['openstack']['dashboard']['horizon_user']
  mode '600'
  subscribes :create, 'service[apache2]', :immediately
  only_if { ::File.exist?(secret_file) }
end

include_recipe 'openstack-dashboard::apache2-server'
