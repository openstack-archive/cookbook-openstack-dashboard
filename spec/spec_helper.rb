# encoding: UTF-8
require 'chefspec'
require 'chefspec/berkshelf'

ChefSpec::Coverage.start! { add_filter 'openstack-dashboard' }

LOG_LEVEL = :fatal
FEDORA_OPTS = {
  platform: 'fedora',
  version: '18',
  log_level: LOG_LEVEL
}
REDHAT_OPTS = {
  platform: 'redhat',
  version: '6.5',
  log_level: LOG_LEVEL
}
UBUNTU_OPTS = {
  platform: 'ubuntu',
  version: '12.04',
  log_level: LOG_LEVEL
}
SUSE_OPTS = {
  platform: 'suse',
  version: '11.03',
  log_level: LOG_LEVEL
}

shared_context 'dashboard_stubs' do
  before do
    Chef::Recipe.any_instance.stub(:memcached_servers)
    .and_return ['hostA:port', 'hostB:port']
    Chef::Recipe.any_instance.stub(:get_password)
    .with('db', 'horizon')
    .and_return('test-passes')
  end
end

shared_context 'redhat_stubs' do
  before do
    stub_command("[ ! -e /etc/httpd/conf/httpd.conf ] && [ -e /etc/redhat-release ] && [ $(/sbin/sestatus | grep -c '^Current mode:.*enforcing') -eq 1 ]").and_return(true)
    stub_command("[ -e /etc/httpd/conf/httpd.conf ] && [ -e /etc/redhat-release ] && [ $(/sbin/sestatus | grep -c '^Current mode:.*permissive') -eq 1 ] && [ $(/sbin/sestatus | grep -c '^Mode from config file:.*enforcing') -eq 1 ]").and_return(true)
  end
end

shared_context 'non_redhat_stubs' do
  before do
    stub_command("[ ! -e /etc/httpd/conf/httpd.conf ] && [ -e /etc/redhat-release ] && [ $(/sbin/sestatus | grep -c '^Current mode:.*enforcing') -eq 1 ]").and_return(false)
    stub_command("[ -e /etc/httpd/conf/httpd.conf ] && [ -e /etc/redhat-release ] && [ $(/sbin/sestatus | grep -c '^Current mode:.*permissive') -eq 1 ] && [ $(/sbin/sestatus | grep -c '^Mode from config file:.*enforcing') -eq 1 ]").and_return(false)
  end
end

shared_context 'postgresql_backend' do
  before do
    Chef::Recipe.any_instance.stub(:db)
    .with('dashboard')
    .and_return('service_type' => 'postgresql', 'db_name' => 'flying_elephant')
  end
end

shared_context 'mysql_backend' do
  before do
    Chef::Recipe.any_instance.stub(:db)
    .with('dashboard')
    .and_return('service_type' => 'mysql', 'db_name' => 'flying_dolphin')
  end
end
