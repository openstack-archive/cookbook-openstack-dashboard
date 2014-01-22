# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-dashboard::server' do
  before { dashboard_stubs }

  describe 'redhat' do
    before do
      redhat_stubs
      @chef_run = ::ChefSpec::Runner.new ::REDHAT_OPTS
      @chef_run.converge 'openstack-dashboard::server'
    end

    it 'executes set-selinux-permissive' do
      cmd = '/sbin/setenforce Permissive'

      expect(@chef_run).to run_execute(cmd)
    end

    it 'installs packages' do
      expect(@chef_run).to upgrade_package 'openstack-dashboard'
      expect(@chef_run).to upgrade_package 'MySQL-python'
    end

    it 'installs db2 python packages if explicitly told' do
      chef_run = ::ChefSpec::Runner.new ::REDHAT_OPTS
      node = chef_run.node
      node.set['openstack']['db']['dashboard']['db_type'] = 'db2'
      chef_run.converge 'openstack-dashboard::server'
      %w{db2-odbc python-ibm-db python-ibm-db-django python-ibm-db-sa}.each do |pkg|
        expect(chef_run).to upgrade_package pkg
      end
    end

    it 'executes set-selinux-enforcing' do
      cmd = '/sbin/setenforce Enforcing ; restorecon -R /etc/httpd'

      expect(@chef_run).to run_execute(cmd)
    end

    describe 'local_settings' do
      before do
        @file = @chef_run.template '/etc/openstack-dashboard/local_settings'
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('root')
        expect(@file.group).to eq('root')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '644'
      end

      it 'rh specific template' do
        expect(@chef_run).to render_file(@file.name).with_content('WEBROOT')
      end
    end

    describe 'certs' do
      before do
        @crt = @chef_run.cookbook_file '/etc/pki/tls/certs/horizon.pem'
        @key = @chef_run.cookbook_file '/etc/pki/tls/private/horizon.key'
      end

      it 'has proper owner' do
        [@crt, @key].each do |file|
          expect(file.owner).to eq('root')
          expect(file.group).to eq('root')
        end
      end

      it 'has proper modes' do
        expect(sprintf('%o', @crt.mode)).to eq '644'
        expect(sprintf('%o', @key.mode)).to eq '640'
      end

      it 'notifies restore-selinux-context' do
        expect(@crt).to notify('execute[restore-selinux-context]').to(:run)
        expect(@key).to notify('execute[restore-selinux-context]').to(:run)
      end
    end

    it 'deletes openstack-dashboard.conf' do
      file = '/etc/httpd/conf.d/openstack-dashboard.conf'

      expect(@chef_run).to delete_file file
    end

    it 'does not remove openstack-dashboard-ubuntu-theme package' do

      expect(@chef_run).not_to purge_package 'openstack-dashboard-ubuntu-theme'
    end

    it 'does not execute restore-selinux-context' do
      cmd = 'restorecon -Rv /etc/httpd /etc/pki; chcon -R -t httpd_sys_content_t /usr/share/openstack-dashboard || :'

      expect(@chef_run).not_to run_execute(cmd)
    end
  end
end
