# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-dashboard::neutron-fwaas-dashboard' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'non_redhat_stubs'
    include_context 'dashboard_stubs'

    it do
      expect(chef_run).to include_recipe('openstack-dashboard::horizon')
    end

    it do
      expect(chef_run).to install_package('python3-neutron-fwaas-dashboard')
    end
  end
end
