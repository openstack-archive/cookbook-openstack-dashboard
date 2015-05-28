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

class ::Chef::Recipe # rubocop:disable Documentation
  include ::Openstack
end

platform_options = node['openstack']['dashboard']['platform']

identity_admin_endpoint = admin_endpoint 'identity-admin'
auth_admin_uri = auth_uri_transform identity_admin_endpoint.to_s, node['openstack']['dashboard']['api']['auth']['version']
identity_endpoint = public_endpoint 'identity-api'
auth_uri = auth_uri_transform identity_endpoint.to_s, node['openstack']['dashboard']['api']['auth']['version']

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

memcached = memcached_servers

template node['openstack']['dashboard']['local_settings_path'] do
  source 'local_settings.py.erb'
  owner 'root'
  group node['openstack']['dashboard']['horizon_group']
  mode 00640
  sensitive true

  variables(
    db_pass: db_pass,
    db_info: db_info,
    auth_uri: auth_uri,
    auth_admin_uri: auth_admin_uri,
    memcached_servers: memcached
  )

  notifies :restart, "service[#{node['openstack']['dashboard']['server_type']}]", :delayed
end

execute 'openstack-dashboard syncdb' do
  cwd node['openstack']['dashboard']['django_path']
  environment 'PYTHONPATH' => "/etc/openstack-dashboard:#{node['openstack']['dashboard']['django_path']}:$PYTHONPATH"
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
  mode 02770
  action :create
end

# ubuntu includes their own branding - we need to delete this until ubuntu makes this a
# configurable paramter
package 'openstack-dashboard-ubuntu-theme' do
  action :purge

  only_if { platform_family?('debian') }
end

# TODO(shep)
# Horizon has a forced dependency on there being a volume service endpoint in your keystone catalog
# https://answers.launchpad.net/horizon/+question/189551
