# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-dashboard::apache2-server' do
  describe 'suse' do
    let(:runner) { ChefSpec::SoloRunner.new(SUSE_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'non_redhat_stubs'
    include_context 'dashboard_stubs'

    it 'creates .blackhole dir with proper owner' do
      dir = '/srv/www/openstack-dashboard/openstack_dashboard/.blackhole'
      expect(chef_run.directory(dir).owner).to eq('root')
    end

    it 'has correct ownership on file with attribute defaults' do
      file = chef_run.file('/srv/www/openstack-dashboard/openstack_dashboard/local/.secret_key_store')
      expect(file.owner).to eq('wwwrun')
      expect(file.group).to eq('www')
    end
  end
end
