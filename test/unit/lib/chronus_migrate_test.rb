require_relative './../../test_helper.rb'

class ChronusMigrateTest < ActiveSupport::TestCase
  include ChronusMigrate

  def test_data_migration_without_downtime
    ChronusMigrate.expects(:set_maintenance_page).never
    ChronusMigrate.data_migration do
      #Data migrations
    end
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("development"))
    ChronusMigrate.data_migration do
      #Data migrations
    end
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("production"))
    ChronusMigrate.data_migration(:has_downtime => false) do
      #Data migrations
    end
  end

  def test_data_migration_with_downtime
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("production"))
    ChronusMigrate.expects(:set_maintenance_page)
    ChronusMigrate.data_migration do
      #Data migrations
    end
  end

  def test_custom_db_migrations
    lhm_introduction_date = "20170412000000"
    db_migration_path = "db/migrate"
    migration_files = Dir.entries(db_migration_path).reject{|d| d == "." || d == ".."}
    migration_files.reject! {|f| f.split("_").first < lhm_introduction_date}
    migration_files.each do |migration_file|
      assert File.readlines(File.join(db_migration_path, migration_file)).grep(/ChronusMigrate.ddl_migration|ChronusMigrate.data_migration/).any?
    end
  end
end