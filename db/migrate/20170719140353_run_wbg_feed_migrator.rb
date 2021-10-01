class RunWbgFeedMigrator< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("customer_feed:migrator CLIENT_NAME='wbg'")
      end
    end
  end

  def down
    # Do nothing
  end
end
