class RakeUpdatePositiveOutcomeOptionsManagementReport< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(:has_downtime => false) do
      DeploymentRakeRunner.add_rake_task("single_time:update_positive_outcome_options_management_report")
    end
  end

  def down
    #nothing
  end
end
