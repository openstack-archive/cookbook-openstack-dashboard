require 'chefspec'
require 'chefspec/berkshelf'

RSpec.configure do |config|
  config.color = true
  config.formatter = :documentation
  config.log_level = :warn
end

REDHAT_7 = {
  platform: 'redhat',
  version: '7',
}.freeze

REDHAT_8 = {
  platform: 'redhat',
  version: '8',
}.freeze

ALL_RHEL = [
  REDHAT_7,
  REDHAT_8,
].freeze

UBUNTU_OPTS = {
  platform: 'ubuntu',
  version: '18.04',
}.freeze

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
    allow_any_instance_of(Chef::Recipe).to receive(:secret)
      .with('certs', 'horizon.pem')
      .and_return('horizon_pem_value')
    allow_any_instance_of(Chef::Recipe).to receive(:secret)
      .with('certs', 'horizon-chain.pem')
      .and_return('horizon_chain_pem_value')
    allow_any_instance_of(Chef::Recipe).to receive(:secret)
      .with('certs', 'horizon.key')
      .and_return('horizon_key_value')
    # identity stubs
    allow_any_instance_of(Chef::Recipe).to receive(:secret)
      .with('secrets', 'credential_key0')
      .and_return('thisiscredentialkey0')
    allow_any_instance_of(Chef::Recipe).to receive(:secret)
      .with('secrets', 'credential_key1')
      .and_return('thisiscredentialkey1')
    allow_any_instance_of(Chef::Recipe).to receive(:secret)
      .with('secrets', 'fernet_key0')
      .and_return('thisisfernetkey0')
    allow_any_instance_of(Chef::Recipe).to receive(:secret)
      .with('secrets', 'fernet_key1')
      .and_return('thisisfernetkey1')
    allow_any_instance_of(Chef::Recipe).to receive(:search_for)
      .with('os-identity').and_return(
        [{
          'openstack' => {
            'identity' => {
              'admin_tenant_name' => 'admin',
              'admin_user' => 'admin',
            },
          },
        }]
      )
    allow_any_instance_of(Chef::Recipe).to receive(:rabbit_transport_url)
      .with('identity')
      .and_return('rabbit://openstack:mypass@127.0.0.1:5672')
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('user', anything)
      .and_return('')
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('db', anything)
      .and_return('test-passes')
    allow_any_instance_of(Chef::Recipe).to receive(:db_uri)
      .with(anything, anything, anything)
      .and_return('')
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
