class RakePopulateLastDeactivatedAt< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("single_time:populate_last_deactivated_at")
    end
  end

  def down
    #Do Nothing
  end
end
