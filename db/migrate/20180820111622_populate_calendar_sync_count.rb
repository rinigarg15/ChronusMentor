class PopulateCalendarSyncCount < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("single_time:populate_calendar_sync_count")
    end
  end

  def down
  end
end
