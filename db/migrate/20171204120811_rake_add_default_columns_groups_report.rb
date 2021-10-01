class RakeAddDefaultColumnsGroupsReport< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(:has_downtime => false) do
      DeploymentRakeRunner.add_rake_task("single_time:added_default_columns_in_groups_report")
    end
  end

  def down
    #nothing
  end
end
