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

class ::Chef::Recipe
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

http_bind = node['openstack']['bind_service']['dashboard_http']
http_bind_address = bind_address http_bind
https_bind = node['openstack']['bind_service']['dashboard_https']
https_bind_address = bind_address https_bind

# This allows the apache2/templates/default/ports.conf.erb to setup the correct listeners.
# Need to convert from Chef::Node::ImmutableArray in order to be able to modify
apache2_listen = Array(node['apache']['listen'])
# Remove the default apache2 cookbook port, as that is also the default for horizon, but with
# a different address syntax.  *:80   vs  0.0.0.0:80
apache2_listen -= ['*:80']

apache2_listen += ["#{http_bind['host']}:#{http_bind['port']}"]
if node['openstack']['dashboard']['use_ssl']
  apache2_listen += ["#{https_bind['host']}:#{https_bind['port']}"]
end

node.normal['apache']['listen'] = apache2_listen.uniq

include_recipe 'apache2'
include_recipe 'apache2::mod_headers'
include_recipe 'apache2::mod_wsgi'
include_recipe 'apache2::mod_rewrite'
include_recipe 'apache2::mod_ssl' if node['openstack']['dashboard']['use_ssl']

# delete the openstack-dashboard.conf before reload apache2 service on redhat and centos
# since this file is not valid on those platforms for the apache2 service.
file "#{node['apache']['dir']}/conf.d/openstack-dashboard.conf" do
  action :delete
  backup false
  only_if { platform_family?('rhel') } # :pragma-foodcritic: ~FC024 - won't fix this
end

if node['openstack']['dashboard']['ssl']['use_data_bag']
  ssl_cert = secret('certs', node['openstack']['dashboard']['ssl']['cert'])
  ssl_key = secret('certs', node['openstack']['dashboard']['ssl']['key'])
  if node['openstack']['dashboard']['ssl']['chain']
    ssl_chain = secret('certs', node['openstack']['dashboard']['ssl']['chain'])
  end
end
ssl_cert_file = File.join(node['openstack']['dashboard']['ssl']['cert_dir'], node['openstack']['dashboard']['ssl']['cert'])
ssl_key_file = File.join(node['openstack']['dashboard']['ssl']['key_dir'], node['openstack']['dashboard']['ssl']['key'])
ssl_chain_file = if node['openstack']['dashboard']['ssl']['chain']
                   File.join(node['openstack']['dashboard']['ssl']['cert_dir'], node['openstack']['dashboard']['ssl']['chain'])
                 end

if node['openstack']['dashboard']['use_ssl'] &&
   node['openstack']['dashboard']['ssl']['use_data_bag']
  unless ssl_cert_file == ssl_key_file
    cert_mode = 0o0644
    cert_owner = 'root'
    cert_group = 'root'

    file ssl_cert_file do
      content ssl_cert
      mode cert_mode
      owner cert_owner
      group cert_group
      notifies :run, 'execute[restore-selinux-context]', :immediately
    end
  end

  if ssl_chain_file
    cert_mode = 0o0644
    cert_owner = 'root'
    cert_group = 'root'

    file ssl_chain_file do
      content ssl_chain
      mode cert_mode
      owner cert_owner
      group cert_group
      notifies :run, 'execute[restore-selinux-context]', :immediately
    end
  end

  key_mode = 0o0640
  key_owner = 'root'
  key_group = node['openstack']['dashboard']['key_group']

  file ssl_key_file do
    content ssl_key
    mode key_mode
    owner key_owner
    group key_group
    notifies :run, 'execute[restore-selinux-context]', :immediately
  end
end

# make sure this file has correct permission
file node['openstack']['dashboard']['secret_key_path'] do
  owner node['openstack']['dashboard']['horizon_user']
  group node['openstack']['dashboard']['horizon_group']
  mode 0o0600
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
  mode 0o0644

  variables(
    ssl_cert_file: ssl_cert_file.to_s,
    ssl_key_file: ssl_key_file.to_s,
    ssl_chain_file: ssl_chain_file.to_s,
    http_bind_address: http_bind_address,
    http_bind_port: http_bind['port'].to_i,
    https_bind_address: https_bind_address,
    https_bind_port: https_bind['port'].to_i
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
  command 'restorecon -Rv /etc/httpd /etc/pki; chcon -R -t httpd_sys_content_t /usr/share/openstack-dashboard /var/www/html || :'
  action :nothing
  only_if { platform_family?('fedora') }
end
