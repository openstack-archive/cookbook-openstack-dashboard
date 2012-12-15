#
# Cookbook Name:: horizon
# Recipe:: server
#
# Copyright 2012, Rackspace US, Inc.
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

#
# Workaround to install apache2 on a fedora machine with selinux set to enforcing
# TODO(breu): this should move to a subscription of the template from the apache2 recipe
#             and it should simply be a restorecon on the configuration file(s) and not
#             change the selinux mode
#
execute "set-selinux-permissive" do
  command "/sbin/setenforce Permissive"
  action :run
  only_if "[ ! -e /etc/httpd/conf/httpd.conf ] && [ -e /etc/redhat-release ] && [ $(/sbin/sestatus | grep -c '^Current mode:.*enforcing') -eq 1 ]"
end

platform_options = node["horizon"]["platform"]

if not node['package_component'].nil?
    release = node['package_component']
else
    release = "essex-final"
end

include_recipe "apache2"
include_recipe "apache2::mod_wsgi"
include_recipe "apache2::mod_rewrite"
include_recipe "apache2::mod_ssl"

#
# Workaround to re-enable selinux after installing apache on a fedora machine that has
# selinux enabled and is currently permissive and the configuration set to enforcing.
# TODO(breu): get the other one working and this won't be necessary
#
execute "set-selinux-enforcing" do
  command "/sbin/setenforce Enforcing ; restorecon -R /etc/httpd"
  action :run
  only_if "[ -e /etc/httpd/conf/httpd.conf ] && [ -e /etc/redhat-release ] && [ $(/sbin/sestatus | grep -c '^Current mode:.*permissive') -eq 1 ] && [ $(/sbin/sestatus | grep -c '^Mode from config file:.*enforcing') -eq 1 ]"
end

ks_admin_endpoint = get_access_endpoint("keystone", "keystone", "admin-api")
ks_service_endpoint = get_access_endpoint("keystone", "keystone", "service-api")
keystone = get_settings_by_role("keystone", "keystone")

#creates db and user
#returns connection info
#defined in osops-utils/libraries
mysql_info = create_db_and_user("mysql",
                                node["horizon"]["db"]["name"],
                                node["horizon"]["db"]["username"],
                                node["horizon"]["db"]["password"])

platform_options["horizon_packages"].each do |pkg|
  package pkg do
    action :upgrade
    options platform_options["package_overrides"]
  end
end

template node["horizon"]["local_settings_path"] do
  source "#{release}/local_settings.py.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(
            :user => node["horizon"]["db"]["username"],
            :passwd => node["horizon"]["db"]["password"],
            :db_name => node["horizon"]["db"]["name"],
            :db_ipaddress => mysql_info["bind_address"],
            :keystone_api_ipaddress => ks_admin_endpoint["host"],
            :service_port => ks_service_endpoint["port"],
            :admin_port => ks_admin_endpoint["port"],
            :admin_token => keystone["admin_token"],
            :swift_enable => node["horizon"]["swift"]["enabled"]
  )
end

# FIXME: this shouldn't run every chef run
execute "openstack-dashboard syncdb" do
  cwd "/usr/share/openstack-dashboard"
  environment ({'PYTHONPATH' => '/etc/openstack-dashboard:/usr/share/openstack-dashboard:$PYTHONPATH'})
  command "python manage.py syncdb --noinput"
  action :run
  # not_if "/usr/bin/mysql -u root -e 'describe #{node["dash"]["db"]}.django_content_type'"
end

cookbook_file "#{node["horizon"]["ssl"]["dir"]}/certs/#{node["horizon"]["ssl"]["cert"]}" do
  source "horizon.pem"
  mode 0644
  owner "root"
  group "root"
  notifies :run, "execute[restore-selinux-context]", :immediately
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
  notifies :run, "execute[restore-selinux-context]", :immediately
end
#
# stop apache bitching
directory "#{node["horizon"]["dash_path"]}/.blackhole" do
  owner "root"
  action :create
end

# TODO(breu): verify this for fedora
template value_for_platform(
  [ "ubuntu","debian","fedora" ] => { "default" => "#{node["apache"]["dir"]}/sites-available/openstack-dashboard" },
  "fedora" => { "default" => "#{node["apache"]["dir"]}/vhost.d/openstack-dashboard" },
  [ "redhat","centos" ] => { "default" => "#{node["apache"]["dir"]}/conf.d/openstack-dashboard" },
  "default" => { "default" => "#{node["apache"]["dir"]}/openstack-dashboard" }
  ) do
  source "#{release}/dash-site.erb"
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
  notifies :run, "execute[restore-selinux-context]", :immediately
end

# fedora includes this file in the package - we need to delete
# it because we do it better
file "#{node["apache"]["dir"]}/conf.d/openstack-dashboard.conf" do
  action :delete
  backup false
  only_if { platform?("fedora","redhat","centos") }
end

# ubuntu includes their own branding - we need to delete this until ubuntu makes this a
# configurable paramter
package "openstack-dashboard-ubuntu-theme" do
  action :purge
  only_if {platform?("ubuntu")}
end

if platform?("debian","ubuntu") then
  apache_site "000-default" do
    enable false
  end
elsif platform?("fedora") then
  apache_site "default" do
    enable false
    notifies :run, resources(:execute => "restore-selinux-context"), :immediately
  end
end

apache_site "openstack-dashboard" do
  enable true
  notifies :run, resources(:execute => "restore-selinux-context"), :immediately
  notifies :reload, resources(:service => "apache2"), :immediately
end

execute "restore-selinux-context" do
    command "restorecon -Rv /etc/httpd /etc/pki; chcon -R -t httpd_sys_content_t /usr/share/openstack-dashboard || :"
    action :nothing
    only_if { platform?("fedora") }
end

# TODO(shep)
# Horizon has a forced dependency on their being a volume service endpoint in your keystone catalog
# https://answers.launchpad.net/horizon/+question/189551

# This is a dirty hack to deal with https://bugs.launchpad.net/nova/+bug/932468
directory "/var/www/.novaclient" do
  owner node["apache"]["user"]
  group node["apache"]["group"]
  mode "0755"
  action :create
end

cookbook_file "#{node["horizon"]["dash_path"]}/static/dashboard/css/folsom.css" do
	only_if { node["horizon"]["theme"] == "Rackspace" and node["package_component"] == "folsom" }
	source "css/folsom.css"
	mode 0644
	owner "root"
	group grp
end

template node["horizon"]["stylesheet_path"] do
	only_if { node["package_component"] == "folsom" }
	if node["horizon"]["theme"] == "Rackspace"
	        source "rs_stylesheets.html.erb"
	else
		source "default_stylesheets.html.erb"
	end
	mode 0644
	owner "root"
	group grp
end

["PrivateCloud.png", "Rackspace_Cloud_Company.png", "Rackspace_Cloud_Company_Small.png", "alert_red.png", "body_bkg.gif", "selected_arrow.png"].each do |imgname|
	# Register remote_file resource
	remote_file "#{node["horizon"]["dash_path"]}/static/dashboard/img/#{imgname}" do
		source "http://2a3f85ca3f24efb48c75-a90b34915fe2401d418a3390713e5cce.r22.cf1.rackcdn.com/#{imgname}"
		mode "0644"
		action :nothing
	end

	# See if modified before trying to run
	http_request "HEAD http://2a3f85ca3f24efb48c75-a90b34915fe2401d418a3390713e5cce.r22.cf1.rackcdn.com/#{imgname}" do
		only_if { node["horizon"]["theme"] == "Rackspace" and node["package_component"] == "folsom" }
		message ""
		url "http://2a3f85ca3f24efb48c75-a90b34915fe2401d418a3390713e5cce.r22.cf1.rackcdn.com/#{imgname}"
		action :head
		if File.exists?("#{node["horizon"]["dash_path"]}/static/dashboard/img/#{imgname}")
			headers "If-Modified-Since" => File.mtime("#{node["horizon"]["dash_path"]}/static/dashboard/img/#{imgname}").httpdate
		end
		notifies :create, resources(:remote_file => "#{node["horizon"]["dash_path"]}/static/dashboard/img/#{imgname}"), :immediately
	end
end
