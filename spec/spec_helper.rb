# encoding: UTF-8
require 'chefspec'
require 'chefspec/berkshelf'

ChefSpec::Coverage.start! { add_filter 'openstack-dashboard' }

LOG_LEVEL = :fatal
REDHAT_OPTS = {
  platform: 'redhat',
  version: '7.1',
  log_level: LOG_LEVEL
}
UBUNTU_OPTS = {
  platform: 'ubuntu',
  version: '14.04',
  log_level: LOG_LEVEL
}
SUSE_OPTS = {
  platform: 'suse',
  version: '11.3',
  log_level: LOG_LEVEL
}

# Build a regex for a section of lines
def build_section(lines)
  lines.map! { |line| Regexp.quote(line) }
  /^#{lines.join('\n')}/
end

shared_context 'dashboard_stubs' do
  before do
    allow_any_instance_of(Chef::Recipe).to receive(:memcached_servers)
      .and_return ['hostA:port', 'hostB:port']
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('db', 'horizon')
      .and_return('test-passes')
  end
end

shared_context 'redhat_stubs' do
  before do
    stub_command("[ ! -e /etc/httpd/conf/httpd.conf ] && [ -e /etc/redhat-release ] && [ $(/sbin/sestatus | grep -c '^Current mode:.*enforcing') -eq 1 ]").and_return(true)
    stub_command("[ -e /etc/httpd/conf/httpd.conf ] && [ -e /etc/redhat-release ] && [ $(/sbin/sestatus | grep -c '^Current mode:.*permissive') -eq 1 ] && [ $(/sbin/sestatus | grep -c '^Mode from config file:.*enforcing') -eq 1 ]").and_return(true)
    stub_command('/usr/sbin/httpd -t').and_return(true)
  end
end

shared_context 'non_redhat_stubs' do
  before do
    stub_command("[ ! -e /etc/httpd/conf/httpd.conf ] && [ -e /etc/redhat-release ] && [ $(/sbin/sestatus | grep -c '^Current mode:.*enforcing') -eq 1 ]").and_return(false)
    stub_command("[ -e /etc/httpd/conf/httpd.conf ] && [ -e /etc/redhat-release ] && [ $(/sbin/sestatus | grep -c '^Current mode:.*permissive') -eq 1 ] && [ $(/sbin/sestatus | grep -c '^Mode from config file:.*enforcing') -eq 1 ]").and_return(false)
    stub_command('/usr/sbin/httpd2 -t').and_return(true)
    stub_command('/usr/sbin/apache2 -t').and_return(true)
  end
end

shared_context 'postgresql_backend' do
  before do
    allow_any_instance_of(Chef::Recipe).to receive(:db)
      .with('dashboard')
      .and_return('service_type' => 'postgresql', 'db_name' => 'flying_elephant')
  end
end

shared_context 'mysql_backend' do
  before do
    allow_any_instance_of(Chef::Recipe).to receive(:db)
      .with('dashboard')
      .and_return('service_type' => 'mysql', 'db_name' => 'flying_dolphin')
  end
end
