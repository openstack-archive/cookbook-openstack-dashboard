# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-dashboard::apache2-server' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'dashboard_stubs'
    include_context 'redhat_stubs'

    it 'executes set-selinux-permissive' do
      cmd = '/sbin/setenforce Permissive'

      expect(chef_run).to run_execute(cmd)
    end

    it 'executes set-selinux-enforcing' do
      cmd = '/sbin/setenforce Enforcing ; restorecon -R /etc/httpd'

      expect(chef_run).to run_execute(cmd)
    end

    describe 'certs' do
      let(:crt) { chef_run.cookbook_file('/etc/pki/tls/certs/horizon.pem') }
      let(:key) { chef_run.cookbook_file('/etc/pki/tls/private/horizon.key') }

      it 'creates horizon.pem' do
        expect(chef_run).to create_cookbook_file(crt.name).with(
          user: 'root',
          group: 'root',
          mode: 0644
          )
      end

      it 'creates horizon.key' do
        expect(chef_run).to create_cookbook_file(key.name).with(
          user: 'root',
          group: 'root',
          mode: 0640
          )
      end

      it 'notifies restore-selinux-context' do
        expect(crt).to notify('execute[restore-selinux-context]').to(:run)
        expect(key).to notify('execute[restore-selinux-context]').to(:run)
      end
    end

    it 'deletes openstack-dashboard.conf' do
      file = '/etc/httpd/conf.d/openstack-dashboard.conf'

      expect(chef_run).to delete_file(file)
    end

    it 'does not execute restore-selinux-context' do
      cmd = 'restorecon -Rv /etc/httpd /etc/pki; chcon -R -t httpd_sys_content_t /usr/share/openstack-dashboard || :'

      expect(chef_run).not_to run_execute(cmd)
    end

    it 'sets the WSGI daemon user to attribute default' do
      file = chef_run.template('/etc/httpd/sites-available/openstack-dashboard.conf')
      expect(chef_run).to render_file(file.name).with_content('WSGIDaemonProcess dashboard user=apache')
    end

    it 'has correct ownership on file with attribute defaults' do
      file = chef_run.file('/usr/share/openstack-dashboard/openstack_dashboard/local/.secret_key_store')
      expect(file.owner).to eq('apache')
      expect(file.group).to eq('apache')
    end
  end
end
