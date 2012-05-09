#
# Cookbook Name:: horizon
# Recipe:: default
#
# Copyright 2012, Rackspace Hosting, Inc.
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

include_recipe "apache2"
include_recipe "apache2::mod_wsgi"
include_recipe "apache2::mod_rewrite"
include_recipe "apache2::mod_ssl"
include_recipe "mysql::client"

# Perform search to grab attributes for use later on
if Chef::Config[:solo]
  Chef::Log.warn("This recipe uses search. Chef Solo does not support search.")
else
  # Lookup mysql ip address and root pass
  mysql_server, start, arbitary_value = Chef::Search::Query.new.search(:node, "roles:mysql-master AND chef_environment:#{node.chef_environment}")
  if mysql_server.length > 0
    Chef::Log.info("horizon::server/mysql: using search")
    db_ip_address = mysql_server[0]['mysql']['bind_address']
    db_root_password = mysql_server[0]['mysql']['server_root_password']
  else
    Chef::Log.info("horizon::server/mysql: NOT using search")
    db_ip_address = node['mysql']['bind_address']
    db_root_password = node['mysql']['server_root_password']
  end

  # Lookup keystone api ip address
  keystone, start, arbitary_value = Chef::Search::Query.new.search(:node, "roles:keystone AND chef_environment:#{node.chef_environment}")
  if keystone.length > 0
    Chef::Log.info("horizon::server/keystone: using search")
    keystone_api_ip = keystone[0]['keystone']['api_ipaddress']
    keystone_service_port = keystone[0]['keystone']['service_port']
    keystone_admin_port = keystone[0]['keystone']['admin_port']
    keystone_admin_token = keystone[0]['keystone']['admin_token']
  else
    Chef::Log.info("horizon::server/keystone: NOT using search")
    keystone_api_ip = node['keystone']['api_ipaddress']
    keystone_service_port = node['keystone']['service_port']
    keystone_admin_port = node['keystone']['admin_port']
    keystone_admin_token = node['keystone']['admin_token']
  end
end

# build connection string using attributes grabbed above
connection_info = {:host => db_ip_address, :username => "root", :password => db_root_password}

# create horizon database
mysql_database "create horizon database" do
  connection connection_info
  database_name node["horizon"]["db"]["name"]
  action :create
end

# create horizon user
mysql_database_user node["horizon"]["db"]["username"] do
  connection connection_info
  password node["horizon"]["db"]["password"]
  action :create
end

# grant privs to horizon user
mysql_database_user node["horizon"]["db"]["username"] do
  connection connection_info
  password node["horizon"]["db"]["password"]
  database_name node["horizon"]["db"]["name"]
  host '%'
  privileges [:all]
  action :grant 
end

package "openstack-dashboard" do
    action :upgrade
end


template "/etc/openstack-dashboard/local_settings.py" do
  source "local_settings.py.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(
            :user => node["horizon"]["db"]["username"],
            :passwd => node["horizon"]["db"]["password"],
            :db_name => node["horizon"]["db"]["name"],
            :db_ipaddress => db_ip_address,
            :keystone_api_ipaddress => keystone_api_ip,
            :service_port => keystone_service_port,
            :admin_port => keystone_admin_port,
            :admin_token => keystone_admin_token
  )
end

execute "openstack-dashboard syncdb" do
  cwd "/usr/share/openstack-dashboard"
  environment ({'PYTHONPATH' => '/etc/openstack-dashboard:/usr/share/openstack-dashboard:$PYTHONPATH'})
  command "python manage.py syncdb"
  action :run
  only_if do platform?("ubuntu","debian") end
  # not_if "/usr/bin/mysql -u root -e 'describe #{node["dash"]["db"]}.django_content_type'"
end

cookbook_file "#{node["horizon"]["ssl"]["dir"]}/certs/#{node["horizon"]["ssl"]["cert"]}" do
  source "horizon.pem"
  mode 0644
  owner "root"
  group "root"
end

case node["platform"]
when "ubuntu","debian"
    grp = "ssl-cert"
else
    grp = "root"
end

cookbook_file "#{node["horizon"]["ssl"]["dir"]}/private/#{node["horizon"]["ssl"]["key"]}" do
  source "horizon.key"
  mode 0640
  owner "root"
  group grp # Don't know about fedora
end

template value_for_platform(
  [ "ubuntu","debian","fedora" ] => { "default" => "#{node["apache"]["dir"]}/sites-available/openstack-dashboard" },
  [ "redhat","centos" ] => { "default" => "#{node["apache"]["dir"]}/vhost.d/openstack-dashboard" },
  "default" => { "default" => "#{node["apache"]["dir"]}/openstack-dashboard" }
  ) do
  source "dash-site.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(
      :use_ssl => node["horizon"]["use_ssl"],
      :apache_contact => node["apache"]["contact"],
      :ssl_cert_file => "#{node["horizon"]["ssl"]["dir"]}/certs/#{node["horizon"]["ssl"]["cert"]}",
      :ssl_key_file => "#{node["horizon"]["ssl"]["dir"]}/private/#{node["horizon"]["ssl"]["key"]}",
      :apache_log_dir => node["apache"]["log_dir"],
      :django_wsgi_path => node["horizon"]["wsgi_path"],
      :dash_path => node["horizon"]["dash_path"],
      :wsgi_user => node["apache"]["user"],
      :wsgi_group => node["apache"]["group"]
  )
end

# fedora includes this file in the package - we need to delete
# it because we do it better
file "#{node["apache"]["dir"]}/conf.d/openstack-dashboard.conf" do
  action :delete
  backup false
  only_if do platform?("fedora") end
end

# ubuntu includes their own branding - we need to delete this
file "/usr/share/openstack-dashboard/openstack_dashboard/static/dashboard/css/ubuntu.css" do
  action :delete
  backup false
  only_if do platform?("ubuntu") end
end

file "/usr/share/openstack-dashboard/openstack_dashboard/static/dashboard/img/favicon-ubuntu.ico" do
  action :delete
  backup false
  only_if do platform?("ubuntu") end
end

apache_site "openstack-dashboard" do
  enable true
end

if platform?("debian","ubuntu") then 
  apache_site "000-default" do
    enable false
  end
elsif platform?("fedora") then
  apache_site "default" do
    enable false
  end
end

# This is a dirty hack to deal with https://bugs.launchpad.net/nova/+bug/932468
directory "/var/www/.novaclient" do
  owner node["apache"]["user"]
  group node["apache"]["group"]
  mode "0755"
  action :create
end

# TODO(shep)
# Horizon has a forced dependency on their being a volume service endpoint in your keystone catalog
# https://answers.launchpad.net/horizon/+question/189551

service "apache2" do
   action :restart
end
