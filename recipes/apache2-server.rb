#
# Cookbook:: openstack-dashboard
# Recipe:: apache2-server
#
# Copyright:: 2012, Rackspace US, Inc.
# Copyright:: 2012-2013, AT&T Services, Inc.
# Copyright:: 2013-2014, IBM, Corp.
# Copyright:: 2014, SUSE Linux, GmbH.
# Copyright:: 2014, x-ion GmbH.
# Copyright:: 2016-2020, Oregon State University
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
  include Apache2::Cookbook::Helpers
end

http_bind = node['openstack']['bind_service']['dashboard_http']
http_bind_address = bind_address http_bind
https_bind = node['openstack']['bind_service']['dashboard_https']
https_bind_address = bind_address https_bind

# service['apache2'] is defined in the apache2_default_install resource
# but other resources are currently unable to reference it.  To work
# around this issue, define the following helper in your cookbook:
service 'apache2' do
  extend Apache2::Cookbook::Helpers
  service_name lazy { apache_platform_service_name }
  supports restart: true, status: true, reload: true
  action :nothing
end

# Finds and appends the listen port to the apache2_install[openstack]
# resource which is defined in openstack-identity::server-apache.
apache_resource = find_resource(:apache2_install, 'openstack')

apache_port =
  if node['openstack']['dashboard']['use_ssl']
    ["#{http_bind_address}:#{http_bind['port']}", "#{https_bind_address}:#{https_bind['port']}"]
  else
    "#{http_bind_address}:#{http_bind['port']}"
  end

if apache_resource
  apache_resource.listen = [apache_resource.listen, apache_port].flatten
else
  apache2_install 'openstack' do
    listen apache_port
  end
end

apache2_module 'wsgi'
apache2_module 'rewrite'
apache2_module 'headers'
apache2_module 'ssl' if node['openstack']['dashboard']['use_ssl']

# delete the openstack-dashboard.conf before reload apache2 service on redhat and centos
# since this file is not valid on those platforms for the apache2 service.
file "#{apache_dir}/conf.d/openstack-dashboard.conf" do
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
ssl_cert_file =
  File.join(node['openstack']['dashboard']['ssl']['cert_dir'], node['openstack']['dashboard']['ssl']['cert'])
ssl_key_file =
  File.join(node['openstack']['dashboard']['ssl']['key_dir'], node['openstack']['dashboard']['ssl']['key'])
ssl_chain_file =
  if node['openstack']['dashboard']['ssl']['chain']
    File.join(node['openstack']['dashboard']['ssl']['cert_dir'], node['openstack']['dashboard']['ssl']['chain'])
  end

if node['openstack']['dashboard']['use_ssl'] &&
   node['openstack']['dashboard']['ssl']['use_data_bag']
  unless ssl_cert_file == ssl_key_file
    cert_mode = '644'
    cert_owner = 'root'
    cert_group = 'root'

    file ssl_cert_file do
      content ssl_cert
      mode cert_mode
      owner cert_owner
      group cert_group
    end
  end

  if ssl_chain_file
    cert_mode = '644'
    cert_owner = 'root'
    cert_group = 'root'

    file ssl_chain_file do
      content ssl_chain
      mode cert_mode
      owner cert_owner
      group cert_group
    end
  end

  key_mode = '640'
  key_owner = 'root'
  key_group = node['openstack']['dashboard']['key_group']

  file ssl_key_file do
    content ssl_key
    mode key_mode
    owner key_owner
    group key_group
  end
end

# make sure this file has correct permission
file node['openstack']['dashboard']['secret_key_path'] do
  owner node['openstack']['dashboard']['horizon_user']
  group node['openstack']['dashboard']['horizon_group']
  mode '600'
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
end

template "#{apache_dir}/sites-available/openstack-dashboard.conf" do
  extend Apache2::Cookbook::Helpers
  source 'dash-site.erb'
  variables(
    apache_admin: node['openstack']['dashboard']['server_admin'],
    log_dir: default_log_dir,
    ssl_cert_file: ssl_cert_file.to_s,
    ssl_key_file: ssl_key_file.to_s,
    ssl_chain_file: ssl_chain_file.to_s,
    http_bind_address: http_bind_address,
    http_bind_port: http_bind['port'].to_i,
    https_bind_address: https_bind_address,
    https_bind_port: https_bind['port'].to_i
  )
  notifies :reload, 'service[apache2]', :immediately
end

case node['platform_family']
when 'debian'
  apache2_site '000-default' do
    action :disable
  end
when 'rhel'
  apache2_site 'default' do
    action :disable
  end
end

apache2_site 'openstack-dashboard' do
  notifies :reload, 'service[apache2]', :immediately
end
