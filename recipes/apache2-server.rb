# encoding: UTF-8
#
# Cookbook Name:: openstack-dashboard
# Recipe:: apache2-server
#
# Copyright 2012, Rackspace US, Inc.
# Copyright 2012-2013, AT&T Services, Inc.
# Copyright 2013-2014, IBM, Corp.
# Copyright 2014, SUSE Linux, GmbH.
# Copyright 2014, x-ion GmbH.
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

http_bind = endpoint 'dashboard-http-bind'
https_bind = endpoint 'dashboard-https-bind'

# This allow the apache2/templates/default/ports.conf.erb to setup the correct listeners.
listen_addresses = node['apache']['listen_addresses'] - ['*'] + [http_bind.host]
listen_addresses += [https_bind.host] if node['openstack']['dashboard']['use_ssl']
listen_ports = node['apache']['listen_ports'] - ['80'] + [http_bind.port]
listen_ports += [https_bind.port] if node['openstack']['dashboard']['use_ssl']
node.set['apache']['listen_addresses'] = listen_addresses.uniq
node.set['apache']['listen_ports'] = listen_ports.uniq

include_recipe 'apache2'
include_recipe 'apache2::mod_headers'
include_recipe 'apache2::mod_wsgi'
include_recipe 'apache2::mod_rewrite'
include_recipe 'apache2::mod_ssl' if node['openstack']['dashboard']['use_ssl']

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

# delete the openstack-dashboard.conf before reload apache2 service on redhat and centos
# since this file is not valid on those platforms for the apache2 service.
file "#{node['apache']['dir']}/conf.d/openstack-dashboard.conf" do
  action :delete
  backup false

  only_if { platform_family?('rhel') } # :pragma-foodcritic: ~FC024 - won't fix this
end

if node['openstack']['dashboard']['use_ssl']
  cert_file = "#{node['openstack']['dashboard']['ssl']['dir']}/certs/#{node['openstack']['dashboard']['ssl']['cert']}"
  cert_mode = 00644
  cert_owner = 'root'
  cert_group = 'root'
  if node['openstack']['dashboard']['ssl']['cert_url']
    remote_file cert_file do
      sensitive true
      source node['openstack']['dashboard']['ssl']['cert_url']
      mode cert_mode
      owner cert_owner
      group cert_group

      notifies :run, 'execute[restore-selinux-context]', :immediately
    end
  else
    cookbook_file cert_file do
      sensitive true
      source 'horizon.pem'
      mode cert_mode
      owner cert_owner
      group cert_group

      notifies :run, 'execute[restore-selinux-context]', :immediately
    end
  end

  key_file = "#{node['openstack']['dashboard']['ssl']['dir']}/private/#{node['openstack']['dashboard']['ssl']['key']}"
  key_mode = 00640
  key_owner = 'root'
  case node['platform_family']
  when 'debian'
    key_group = 'ssl-cert'
  else
    key_group = 'root'
  end

  if node['openstack']['dashboard']['ssl']['key_url']
    remote_file key_file do
      sensitive true
      source node['openstack']['dashboard']['ssl']['key_url']
      mode key_mode
      owner key_owner
      group key_group

      notifies :restart, 'service[apache2]', :immediately
      notifies :run, 'execute[restore-selinux-context]', :immediately
    end
  else
    cookbook_file key_file do
      sensitive true
      source 'horizon.key'
      mode key_mode
      owner key_owner
      group key_group

      notifies :run, 'execute[restore-selinux-context]', :immediately
    end
  end
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
    only_if { ::File.exist?(node['openstack']['dashboard']['secret_key_path']) }
  else
    content node['openstack']['dashboard']['secret_key_content']
    notifies :restart, 'service[apache2]'
  end
end

# stop apache bitching
directory "#{node['openstack']['dashboard']['dash_path']}/.blackhole" do
  owner 'root'
  action :create
end

template node['openstack']['dashboard']['apache']['sites-path'] do
  source 'dash-site.erb'
  owner 'root'
  group 'root'
  mode 00644

  variables(
    ssl_cert_file: "#{node['openstack']['dashboard']['ssl']['dir']}/certs/#{node['openstack']['dashboard']['ssl']['cert']}",
    ssl_key_file: "#{node['openstack']['dashboard']['ssl']['dir']}/private/#{node['openstack']['dashboard']['ssl']['key']}",
    http_bind_address: http_bind.host,
    http_bind_port: http_bind.port.to_i,
    https_bind_address: https_bind.host,
    https_bind_port: https_bind.port.to_i
  )

  notifies :run, 'execute[restore-selinux-context]', :immediately
  notifies :reload, 'service[apache2]', :immediately
end

# The `apache_site` provided by the apache2 cookbook
# is not an LWRP. Guards do not apply to definitions.
# http://tickets.opscode.com/browse/CHEF-778
case node['platform_family']
when 'debian'
  apache_site '000-default' do
    enable false
  end
when 'rhel'
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
