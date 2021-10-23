require_relative 'spec_helper'

describe 'openstack-dashboard::horizon' do
  ALL_RHEL.each do |p|
    context "redhat #{p[:version]}" do
      let(:runner) { ChefSpec::SoloRunner.new(p) }
      let(:node) { runner.node }
      cached(:chef_run) do
        runner.converge('openstack-identity::server-apache', described_recipe)
      end

      include_context 'dashboard_stubs'
      include_context 'redhat_stubs'

      case p
      when REDHAT_7
        it 'installs packages' do
          expect(chef_run).to upgrade_package %w(openstack-dashboard MySQL-python)
        end
      when REDHAT_8
        it 'installs packages' do
          expect(chef_run).to upgrade_package %w(openstack-dashboard python3-PyMySQL)
        end
      end

      describe 'local_settings' do
        let(:file) { chef_run.template('/etc/openstack-dashboard/local_settings') }

        it 'creates local_settings' do
          expect(chef_run).to create_template(file.name).with(
            user: 'root',
            group: 'apache',
            mode: '640'
          )
        end

        it 'has urls set' do
          [
            %r{^LOGIN_URL = '/auth/login/'$},
            %r{^LOGOUT_URL = '/auth/logout/'$},
            %r{^LOGIN_REDIRECT_URL = '/'$},
          ].each do |line|
            expect(chef_run).to render_file(file.name).with_content(line)
          end
        end

        it 'has policy file path set' do
          expect(chef_run).to render_file(file.name)
            .with_content(%r{^POLICY_FILES_PATH = '/etc/openstack-dashboard'$})
        end
      end
    end
  end
end
