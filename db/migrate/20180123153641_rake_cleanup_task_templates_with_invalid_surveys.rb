class RakeCleanupTaskTemplatesWithInvalidSurveys< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("single_time:cleanup_task_templates_with_invalid_surveys")
    end
  end

  def down
    #Do nothing
  end
end
