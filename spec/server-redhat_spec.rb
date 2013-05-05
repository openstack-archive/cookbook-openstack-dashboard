require "spec_helper"

describe "horizon::server" do
  before do
    ::Chef::Recipe.any_instance.stub(:memcached_servers).
      and_return "hostA:port,hostB:port"
    ::Chef::Recipe.any_instance.stub(:db_password).with("horizon").
      and_return "test-pass"
  end

  describe "redhat" do
    before do
      @chef_run = ::ChefSpec::ChefRunner.new ::REDHAT_OPTS
      @chef_run.converge "horizon::server"
    end

    it "executes set-selinux-permissive" do
      pending "TODO: how to properly test this"
    end

    it "installs packages" do
      expect(@chef_run).to upgrade_package "openstack-dashboard"
      expect(@chef_run).to upgrade_package "MySQL-python"
    end

    it "executes set-selinux-enforcing" do
      pending "TODO: how to properly test this"
    end

    describe "local_settings" do
      before do
        @file = @chef_run.template "/etc/openstack-dashboard/local_settings"
      end

      it "has proper owner" do
        expect(@file).to be_owned_by "root", "root"
      end

      it "has proper modes" do
        expect(sprintf("%o", @file.mode)).to eq "644"
      end

      it "rh specific template" do
        pending
      end
    end

    describe "certs" do
      before do
        @crt = @chef_run.cookbook_file "/etc/pki/tls/certs/horizon.pem"
        @key = @chef_run.cookbook_file "/etc/pki/tls/private/horizon.key"
      end

      it "has proper owner" do
        expect(@crt).to be_owned_by "root", "root"
        expect(@key).to be_owned_by "root", "root"
      end

      it "has proper modes" do
        expect(sprintf("%o", @crt.mode)).to eq "644"
        expect(sprintf("%o", @key.mode)).to eq "640"
      end

      it "notifies restore-selinux-context" do
        expect(@crt).to notify "execute[restore-selinux-context]", :run
        expect(@key).to notify "execute[restore-selinux-context]", :run
      end
    end

    describe "openstack-dashboard virtual host" do
      before do
        f = "/etc/httpd/sites-available/openstack-dashboard"
        @file = @chef_run.template f
      end

      it "has proper owner" do
        expect(@file).to be_owned_by "root", "root"
      end

      it "has proper modes" do
        expect(sprintf("%o", @file.mode)).to eq "644"
      end

      it "template contents" do
        pending
      end

      it "notifies restore-selinux-context" do
        expect(@file).to notify "execute[restore-selinux-context]", :run
      end
    end

    it "deletes openstack-dashboard.conf" do
      file = "/etc/httpd/conf.d/openstack-dashboard.conf"
      expect(@chef_run).to delete_file file
    end

    it "does not remove openstack-dashboard-ubuntu-theme package" do
      pending "TODO: how to properly test this will not run"
    end

    it "doesn't execute restore-selinux-context" do
      pending "TODO: how to properly test this will not run"
    end

    it "doesn't remove default virtualhost" do
      pending "TODO: how to properly test this will not run"
    end
  end
end
