# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-dashboard::server' do
  before { dashboard_stubs }

  describe 'fedora' do
    before do
      non_redhat_stubs
      @chef_run = ::ChefSpec::Runner.new ::FEDORA_OPTS
      @chef_run.converge 'openstack-dashboard::server'
    end

    it 'deletes openstack-dashboard.conf' do
      file = '/etc/httpd/conf.d/openstack-dashboard.conf'

      expect(@chef_run).to delete_file file
    end

    it 'does not remove the default ubuntu virtualhost' do
      resource = @chef_run.find_resource(
        'execute',
        'a2dissite 000-default'
      )

      expect(resource).to be_nil
    end

    it 'removes default virtualhost' do
      resource = @chef_run.find_resource(
        'execute',
        'a2dissite default'
      ).to_hash

      expect(resource[:params]).to include(
        enable: false
      )
    end

    it 'notifies restore-selinux-context' do
      pending "TODO: how to test this occured on apache_site 'default'"
    end

    it 'executes restore-selinux-context' do
      cmd = 'restorecon -Rv /etc/httpd /etc/pki; chcon -R -t httpd_sys_content_t /usr/share/openstack-dashboard || :'

      expect(@chef_run).not_to run_execute(cmd)
    end
  end
end
