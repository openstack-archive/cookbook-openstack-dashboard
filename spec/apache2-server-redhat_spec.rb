require_relative 'spec_helper'

describe 'openstack-dashboard::apache2-server' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      runner.converge(described_recipe)
    end
    include_context 'dashboard_stubs'
    include_context 'redhat_stubs'

    describe 'certs' do
      describe 'get secret' do
        let(:pem) { chef_run.file('/etc/pki/tls/certs/horizon.pem') }
        let(:key) { chef_run.file('/etc/pki/tls/private/horizon.key') }

        it 'create files and restarts apache' do
          expect(chef_run).to create_file('/etc/pki/tls/certs/horizon.pem').with(
            user: 'root',
            group: 'root',
            mode: '644'
          )
          expect(chef_run).to create_file('/etc/pki/tls/private/horizon.key').with(
            user: 'root',
            group: 'root',
            mode: '640'
          )
        end

        context 'does not mess with certs if ssl not enabled' do
          cached(:chef_run) do
            node.override['openstack']['dashboard']['use_ssl'] = false
            runner.converge(described_recipe)
          end
          it do
            expect(chef_run).not_to create_file('/etc/ssl/certs/horizon.pem')
            expect(chef_run).not_to create_file('/etc/pki/tls/private/horizon.key')
          end
        end
      end
    end
    it 'deletes openstack-dashboard.conf' do
      file = '/etc/httpd/conf.d/openstack-dashboard.conf'
      expect(chef_run).to delete_file(file)
    end

    it do
      expect(chef_run).to_not disable_apache2_site('000-default')
    end

    it do
      expect(chef_run).to disable_apache2_site('default')
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
