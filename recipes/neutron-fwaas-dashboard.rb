# encoding: UTF-8
#
# Cookbook Name:: openstack-dashboard
# Recipe:: neutron-lbaas-dashboard
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

include_recipe 'openstack-dashboard::horizon'

django_path = node['openstack']['dashboard']['django_path']
policy_file_path = node['openstack']['dashboard']['policy_files_path']

# use system python for fwaas dashboard
python_runtime '2' do
  provider :system
  version '2.7'
end

python_package 'neutron-fwaas-dashboard'

remote_file "#{django_path}/openstack_dashboard/local/enabled/_7010_project_firewalls_panel.py" do
  source 'https://raw.githubusercontent.com/openstack/neutron-fwaas-dashboard/stable/pike/neutron_fwaas_dashboard/enabled/_7010_project_firewalls_panel.py'
  owner 'root'
  mode 0o0644
  notifies :run, 'execute[neutron-fwaas-dashboard compilemessages]'
  notifies :run, 'execute[openstack-dashboard collectstatic]'
end

remote_file "#{policy_file_path}/neutron-fwaas-policy.json" do
  source 'https://raw.githubusercontent.com/openstack/neutron-fwaas-dashboard/stable/pike/etc/neutron-fwaas-policy.json'
  owner 'root'
  mode 0o0644
  notifies :run, 'execute[neutron-fwaas-dashboard compilemessages]'
  notifies :run, 'execute[openstack-dashboard collectstatic]'
  notifies :restart, 'service[apache2]', :delayed
end

execute 'neutron-fwaas-dashboard compilemessages' do
  cwd django_path
  environment 'PYTHONPATH' => "/etc/openstack-dashboard:#{django_path}:$PYTHONPATH"
  command 'python manage.py compilemessages'
  action :nothing
end
