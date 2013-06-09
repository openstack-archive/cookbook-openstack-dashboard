require_relative "spec_helper"

describe "openstack-dashboard::server" do
  before { dashboard_stubs }

  #describe "fedora" do
  #  before do
  #    @chef_run = ::ChefSpec::ChefRunner.new ::FEDORA_OPTS
  #    @chef_run.converge "openstack-dashboard::server"
  #  end

  #  it "executes restore-selinux-context" do
  #    pending "TODO: how to properly test this"
  #  end

  #  it "removes default virtualhost" do
  #    pending "TODO"
  #  end
  #end
end
