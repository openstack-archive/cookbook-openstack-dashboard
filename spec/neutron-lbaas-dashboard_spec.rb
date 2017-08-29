# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-dashboard::neutron-lbaas-dashboard' do
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
      expect(chef_run).to install_python_runtime('2')
    end

    it do
      expect(chef_run).to install_python_package('neutron-lbaas-dashboard')
    end

    it do
      expect(chef_run).to create_remote_file(
        "#{node['openstack']['dashboard']['django_path']}/openstack_dashboard/local/enabled/_1481_project_ng_loadbalancersv2_panel.py"
      ).with(
        mode: 0o0644,
        owner: 'root',
        source: 'https://raw.githubusercontent.com/openstack/neutron-lbaas-dashboard/stable/ocata/neutron_lbaas_dashboard/enabled/_1481_project_ng_loadbalancersv2_panel.py'
      )
    end

    it do
      expect(chef_run.remote_file("#{node['openstack']['dashboard']['django_path']}/openstack_dashboard/local/enabled/_1481_project_ng_loadbalancersv2_panel.py"))
        .to notify('execute[openstack-dashboard collectstatic]')
    end
  end
end
