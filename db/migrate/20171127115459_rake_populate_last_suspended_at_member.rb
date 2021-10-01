class RakePopulateLastSuspendedAtMember< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("single_time:populate_last_suspended_at_for_members")
    end
  end

  def down
    #Do Nothing
  end
end
