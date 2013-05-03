require "chefspec"

describe "horizon::db" do
  before do
    ::Chef::Recipe.any_instance.stub(:include_recipe)
  end

  it "creates database and user" do
    ::Chef::Recipe.any_instance.stub(:db_password).with("horizon").
      and_return "test-pass"

    ::Chef::Recipe.any_instance.should_receive(:db_create_with_user).
      with "dashboard", "dash", "test-pass"

    ::ChefSpec::ChefRunner.new.converge "horizon::db"
  end
end
