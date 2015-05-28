# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-dashboard::server' do
  let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
  let(:node) { runner.node }
  let(:chef_run) do
    runner.converge(described_recipe)
  end

  include_context 'non_redhat_stubs'
  include_context 'dashboard_stubs'

  it 'installs the horizon dashboard' do
    expect(chef_run).to include_recipe('openstack-dashboard::horizon')
  end

  it 'by default installs the apache2 webserver' do
    expect(chef_run).to include_recipe('openstack-dashboard::apache2-server')
  end
end
