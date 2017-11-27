# encoding: UTF-8
#
# Cookbook Name:: openstack-dashboard
# Recipe:: horizon
#
# Copyright 2012, Rackspace US, Inc.
# Copyright 2012-2013, AT&T Services, Inc.
# Copyright 2013-2014, IBM, Corp.
# Copyright 2014, SUSE Linux, GmbH.
# Copyright 2014, x-ion, GmbH.
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

require 'uri'

class ::Chef::Recipe
  include ::Openstack
end
include_recipe 'openstack-identity'
platform_options = node['openstack']['dashboard']['platform']

identity_admin_endpoint = admin_endpoint 'identity'
auth_admin_uri = auth_uri_transform identity_admin_endpoint.to_s, node['openstack']['dashboard']['api']['auth']['version']
identity_endpoint = public_endpoint 'identity'
auth_uri = auth_uri_transform identity_endpoint.to_s, node['openstack']['dashboard']['api']['auth']['version']

http_bind = node['openstack']['bind_service']['dashboard_http']
http_bind_address = bind_address http_bind
https_bind = node['openstack']['bind_service']['dashboard_https']
https_bind_address = bind_address https_bind

horizon_host = if node['openstack']['dashboard']['use_ssl']
                 https_bind_address
               else
                 http_bind_address
               end

db_pass = get_password 'db', 'horizon'
db_info = db 'dashboard'

python_packages = node['openstack']['db']['python_packages'][db_info['service_type']]
# Add dashboard specific database packages
python_packages += Array(node['openstack']['dashboard']['db_python_packages'][db_info['service_type']])
(platform_options['horizon_packages'] + python_packages).each do |pkg|
  package pkg do
    action :upgrade
    options platform_options['package_overrides']
  end
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
  mode 0o0640
  sensitive true

  variables(
    db_pass: db_pass,
    db_info: db_info,
    auth_uri: auth_uri,
    auth_admin_uri: auth_admin_uri,
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
  mode 0o2770
  action :create
end

# ubuntu includes their own branding - we need to delete this until ubuntu makes this a
# configurable paramter
package 'openstack-dashboard-ubuntu-theme' do
  action :purge

  only_if { platform_family?('debian') }
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
  mode 0600
  subscribes :create, 'service[apache2]', :immediately
  only_if { ::File.exist?(secret_file) }
end

include_recipe 'openstack-dashboard::apache2-server'
