# encoding: UTF-8
#
# Cookbook Name:: openstack-dashboard
# Recipe:: server
#
# Copyright 2012, Rackspace US, Inc.
# Copyright 2012-2013, AT&T Services, Inc.
# Copyright 2013-2014, IBM, Corp.
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

#
# Workaround to install apache2 on a fedora machine with selinux set to enforcing
# TODO(breu): this should move to a subscription of the template from the apache2 recipe
#             and it should simply be a restorecon on the configuration file(s) and not
#             change the selinux mode
#
execute 'set-selinux-permissive' do
  command '/sbin/setenforce Permissive'
  action :run

  only_if "[ ! -e /etc/httpd/conf/httpd.conf ] && [ -e /etc/redhat-release ] && [ $(/sbin/sestatus | grep -c '^Current mode:.*enforcing') -eq 1 ]"
end

platform_options = node['openstack']['dashboard']['platform']

include_recipe 'apache2'
include_recipe 'apache2::mod_wsgi'
include_recipe 'apache2::mod_rewrite'
include_recipe 'apache2::mod_ssl'

#
# Workaround to re-enable selinux after installing apache on a fedora machine that has
# selinux enabled and is currently permissive and the configuration set to enforcing.
# TODO(breu): get the other one working and this won't be necessary
#
execute 'set-selinux-enforcing' do
  command '/sbin/setenforce Enforcing ; restorecon -R /etc/httpd'
  action :run

  only_if "[ -e /etc/httpd/conf/httpd.conf ] && [ -e /etc/redhat-release ] && [ $(/sbin/sestatus | grep -c '^Current mode:.*permissive') -eq 1 ] && [ $(/sbin/sestatus | grep -c '^Mode from config file:.*enforcing') -eq 1 ]"
end

identity_admin_endpoint = endpoint 'identity-admin'
auth_admin_uri = ::URI.decode identity_admin_endpoint.to_s
identity_endpoint = endpoint 'identity-api'
auth_uri = ::URI.decode identity_endpoint.to_s

case node['openstack']['dashboard']['identity_api_version']
when 2.0
  auth_version = 'v2.0'
when 3
  auth_version = 'v3.0'
end

auth_admin_uri = auth_uri_transform auth_admin_uri, auth_version
auth_uri = auth_uri_transform auth_uri, auth_version

db_pass = get_password 'db', 'horizon'
db_info = db 'dashboard'

python_packages = platform_options["#{db_info['service_type']}_python_packages"]
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

# delete the openstack-dashboard.conf before reload apache2 service on fedora, redhat and centos
# since this file is not valid on those platforms for the apache2 service.
file "#{node["apache"]["dir"]}/conf.d/openstack-dashboard.conf" do
  action :delete
  backup false

  only_if { platform_family?('fedora', 'rhel') } # :pragma-foodcritic: ~FC024 - won't fix this
end

template node['openstack']['dashboard']['local_settings_path'] do
  source 'local_settings.py.erb'
  owner  'root'
  group  'root'
  mode   00644

  variables(
    db_pass: db_pass,
    db_info: db_info,
    auth_uri: auth_uri,
    auth_admin_uri: auth_admin_uri,
    memcached_servers: memcached
  )

  notifies :restart, 'service[apache2]', :immediately
end

execute 'openstack-dashboard syncdb' do
  cwd node['openstack']['dashboard']['django_path']
  environment 'PYTHONPATH' => "/etc/openstack-dashboard:#{node['openstack']['dashboard']['django_path']}:$PYTHONPATH"
  command 'python manage.py syncdb --noinput'
  action :run
  only_if do
    node['openstack']['dashboard']['session_backend'] == 'sql' &&
    node['openstack']['db']['dashboard']['migrate'] ||
    db_info['service_type'] == 'sqlite'
  end
end

cert_file = "#{node['openstack']['dashboard']['ssl']['dir']}/certs/#{node['openstack']['dashboard']['ssl']['cert']}"
cert_mode = 00644
cert_owner = 'root'
cert_group = 'root'
if node['openstack']['dashboard']['ssl']['cert_url']
  remote_file cert_file do
    source node['openstack']['dashboard']['ssl']['cert_url']
    mode cert_mode
    owner  cert_owner
    group  cert_group

    notifies :run, 'execute[restore-selinux-context]', :immediately
  end
else
  cookbook_file cert_file do
    source 'horizon.pem'
    mode cert_mode
    owner  cert_owner
    group  cert_group

    notifies :run, 'execute[restore-selinux-context]', :immediately
  end
end

key_file = "#{node['openstack']['dashboard']['ssl']['dir']}/private/#{node['openstack']['dashboard']['ssl']['key']}"
key_mode = 00640
key_owner = 'root'
case node['platform_family']
when 'debian' # Don't know about fedora
  key_group = 'ssl-cert'
else
  key_group = 'root'
end

if node['openstack']['dashboard']['ssl']['key_url']
  remote_file key_file do
    source node['openstack']['dashboard']['ssl']['key_url']
    mode key_mode
    owner  key_owner
    group  key_group

    notifies :restart, 'service[apache2]', :immediately
    notifies :run, 'execute[restore-selinux-context]', :immediately
  end
else
  cookbook_file key_file do
    source 'horizon.key'
    mode   key_mode
    owner  key_owner
    group  key_group

    notifies :run, 'execute[restore-selinux-context]', :immediately
  end
end

directory "#{node['openstack']['dashboard']['dash_path']}/local" do
  owner 'root'
  group node['openstack']['dashboard']['horizon_group']
  mode 02770
  action :create
end

# make sure this file has correct permission
file node['openstack']['dashboard']['secret_key_path'] do
  owner node['openstack']['dashboard']['horizon_user']
  group node['openstack']['dashboard']['horizon_group']
  mode 00600
  # the only time the file should be created is if we have secret_key_content
  # set, otherwise let apache create it when someone first accesses the
  # dashboard
  if node['openstack']['dashboard']['secret_key_content'].nil?
    only_if { ::File.exists?(node['openstack']['dashboard']['secret_key_path']) }
  else
    content node['openstack']['dashboard']['secret_key_content']
    notifies :restart, 'service[apache2]'
  end
end

# stop apache bitching
directory "#{node["openstack"]["dashboard"]["dash_path"]}/.blackhole" do
  owner 'root'
  action :create
end

template node['openstack']['dashboard']['apache']['sites-path'] do
  source 'dash-site.erb'
  owner  'root'
  group  'root'
  mode   00644

  variables(
    ssl_cert_file: "#{node["openstack"]["dashboard"]["ssl"]["dir"]}/certs/#{node["openstack"]["dashboard"]["ssl"]["cert"]}",
    ssl_key_file: "#{node["openstack"]["dashboard"]["ssl"]["dir"]}/private/#{node["openstack"]["dashboard"]["ssl"]["key"]}"
  )

  notifies :run, 'execute[restore-selinux-context]', :immediately
  notifies :reload, 'service[apache2]', :immediately
end

# ubuntu includes their own branding - we need to delete this until ubuntu makes this a
# configurable paramter
package 'openstack-dashboard-ubuntu-theme' do
  action :purge

  only_if { platform_family?('debian') }
end

# The `apache_site` provided by the apache2 cookbook
# is not an LWRP. Guards do not apply to definitions.
# http://tickets.opscode.com/browse/CHEF-778
if platform_family?('debian')
  apache_site '000-default' do
    enable false
  end
elsif platform_family?('fedora', 'rhel') then
  apache_site 'default' do
    enable false

    notifies :run, 'execute[restore-selinux-context]', :immediately
  end
end

apache_site 'openstack-dashboard' do
  enable true

  notifies :run, 'execute[restore-selinux-context]', :immediately
  notifies :reload, 'service[apache2]', :immediately
end

execute 'restore-selinux-context' do
  command 'restorecon -Rv /etc/httpd /etc/pki; chcon -R -t httpd_sys_content_t /usr/share/openstack-dashboard || :'
  action :nothing

  only_if { platform_family?('fedora') }
end

# TODO(shep)
# Horizon has a forced dependency on there being a volume service endpoint in your keystone catalog
# https://answers.launchpad.net/horizon/+question/189551
