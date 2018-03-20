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
      expect(chef_run).to install_python_runtime('2')
    end

    it do
      expect(chef_run).to install_python_package('neutron-fwaas-dashboard')
    end

    it do
      expect(chef_run).to create_remote_file(
        "#{node['openstack']['dashboard']['django_path']}/openstack_dashboard/local/enabled/_7010_project_firewalls_panel.py"
      ).with(
        mode: 0o0644,
        owner: 'root',
        source: 'https://raw.githubusercontent.com/openstack/neutron-fwaas-dashboard/stable/pike/neutron_fwaas_dashboard/enabled/_7010_project_firewalls_panel.py'
      )
    end

    it do
      expect(chef_run.remote_file("#{node['openstack']['dashboard']['django_path']}/openstack_dashboard/local/enabled/_7010_project_firewalls_panel.py"))
        .to notify('execute[openstack-dashboard collectstatic]').to(:run)
      notify('execute[neutron-fwaas-dashboard compilemessages]').to(:run)
    end

    it do
      expect(chef_run).to create_remote_file(
        "#{node['openstack']['dashboard']['policy_files_path']}/neutron-fwaas-policy.json"
      ).with(
        mode: 0o0644,
        owner: 'root',
        source: 'https://raw.githubusercontent.com/openstack/neutron-fwaas-dashboard/stable/pike/etc/neutron-fwaas-policy.json'
      )
    end

    it do
      expect(chef_run.remote_file("#{node['openstack']['dashboard']['policy_files_path']}/neutron-fwaas-policy.json"))
        .to notify('execute[openstack-dashboard collectstatic]').to(:run)
      notify('execute[neutron-fwaas-dashboard compilemessages]').to(:run)
      notify('service[apache2]').to(:restart).delayed
    end
  end
end
