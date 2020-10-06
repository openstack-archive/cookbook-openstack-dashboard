require_relative 'spec_helper'

describe 'openstack-dashboard::neutron-lbaas-dashboard' do
  describe 'redhat' do
    cached(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    cached(:node) { runner.node }
    cached(:chef_run) do
      runner.converge('openstack-identity::server-apache', described_recipe)
    end

    include_context 'redhat_stubs'
    include_context 'dashboard_stubs'

    it do
      expect(chef_run).to include_recipe('openstack-dashboard::horizon')
    end

    it do
      expect(chef_run).to install_package('openstack-neutron-lbaas-ui')
    end
  end
end
