require "chefspec"

describe "horizon::server" do
  before do
    ::Chef::Recipe.any_instance.stub(:memcached_servers).
      and_return "hostA:port,hostB:port"
    ::Chef::Recipe.any_instance.stub(:db_password).with("horizon").
      and_return "test-pass"
  end

  # Fedora doesn't seem to be supported by fauxhai.

  #describe "fedora" do
  #  before do
  #    @chef_run = ::ChefSpec::ChefRunner.new(
  #      platform: "fedora"
  #    ).converge "horizon::server"
  #  end

  #  it "executes restore-selinux-context" do
  #    pending "TODO: how to properly test this"
  #  end

  #  it "removes default virtualhost" do
  #    pending "TODO"
  #  end
  #end

  describe "redhat" do
    before do
      @chef_run = ::ChefSpec::ChefRunner.new(
        platform: "redhat"
      ).converge "horizon::server"
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
        @file = @chef_run.template "/etc/httpd/sites-available/openstack-dashboard"
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
      expect(@chef_run).to delete_file "/etc/httpd/conf.d/openstack-dashboard.conf"
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

  describe "ubuntu" do
    before do
      @chef_run = ::ChefSpec::ChefRunner.new(
        platform: "ubuntu",
        version: "12.04"
      ).converge "horizon::server"
    end

    it "doesn't execute set-selinux-permissive" do
      pending "TODO: how to properly test this will not run"
    end

    it "installs apache packages" do
      expect(@chef_run).to include_recipe "apache2"
      expect(@chef_run).to include_recipe "apache2::mod_wsgi"
      expect(@chef_run).to include_recipe "apache2::mod_rewrite"
      expect(@chef_run).to include_recipe "apache2::mod_ssl"
    end

    it "doesn't execute set-selinux-enforcing" do
      pending "TODO: how to properly test this will not run"
    end

    it "installs packages" do
      expect(@chef_run).to upgrade_package "lessc"
      expect(@chef_run).to upgrade_package "openstack-dashboard"
      expect(@chef_run).to upgrade_package "python-mysqldb"
    end

    describe "local_settings.py" do
      before do
        @file = @chef_run.template "/etc/openstack-dashboard/local_settings.py"
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

      it "notifies apache2 restart" do
        expect(@file).to notify "service[apache2]", :restart
      end
    end

    it "executes openstack-dashboard syncdb" do
      cmd = "python manage.py syncdb --noinput"
      expect(@chef_run).to execute_command(cmd).with(
        :cwd         => "/usr/share/openstack-dashboard",
        :environment => {"PYTHONPATH" => "/etc/openstack-dashboard:/usr/share/openstack-dashboard:$PYTHONPATH"}
      )
    end

    describe "certs" do
      before do
        @crt = @chef_run.cookbook_file "/etc/ssl/certs/horizon.pem"
        @key = @chef_run.cookbook_file "/etc/ssl/private/horizon.key"
      end

      it "has proper owner" do
        expect(@crt).to be_owned_by "root", "root"
        expect(@key).to be_owned_by "root", "ssl-cert"
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

    it "creates .blackhole dir with proper owner" do
      dir = "/usr/share/openstack-dashboard/openstack_dashboard/.blackhole"
      expect(@chef_run.directory(dir)).to be_owned_by "root"
    end

    describe "openstack-dashboard virtual host" do
      before do
        @file = @chef_run.template "/etc/apache2/sites-available/openstack-dashboard"
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

    it "does not delete openstack-dashboard.conf" do
      pending "TODO: how to properly test this will not run"
    end

    it "removes openstack-dashboard-ubuntu-theme package" do
      expect(@chef_run).to purge_package "openstack-dashboard-ubuntu-theme"
    end

    it "removes default virtualhost" do
      chef_run = ::ChefSpec::ChefRunner.new(
        platform: "ubuntu",
        version: "12.04",
        :step_into => ["apache_site"]
      ).converge "horizon::server"

      cmd = "/usr/sbin/a2dissite 000-default"
      expect(chef_run).to execute_command cmd
    end

    it "enables virtualhost" do
      f = ::ChefSpec::ChefRunner.new(
        platform: "ubuntu",
        version: "12.04",
        :step_into => ["apache_site"]
      )
      b = f.converge "horizon::server"

      cmd = "/usr/sbin/a2ensite openstack-dashboard"
      expect(b).to execute_command cmd
    end

    it "notifies apache2 restart" do
      pending "TODO: how to test when tied to an LWRP"
    end

    it "doesn't execute restore-selinux-context" do
      pending "TODO: how to properly test this will not run"
    end
  end
end
