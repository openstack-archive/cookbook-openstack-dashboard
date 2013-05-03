require "chefspec"

describe "horizon::db" do
  it "installs mysql packages" do
    @chef_run = converge.call

    expect(@chef_run).to include_recipe "mysql::client"
    expect(@chef_run).to include_recipe "mysql::ruby"
  end

  it "creates database and user" do
    ::Chef::Recipe.any_instance.should_receive(:db_create_with_user).
      with "dashboard", "dash", "test-pass"

    converge.call
  end

  def converge
    Proc.new {
      ::Chef::Recipe.any_instance.stub(:db_password).with("horizon").
        and_return "test-pass"

      ::ChefSpec::ChefRunner.new(
        :platform  => "ubuntu",
        :version   => "12.04",
        :log_level => :fatal
      ).converge "horizon::db"
    }
  end
end
