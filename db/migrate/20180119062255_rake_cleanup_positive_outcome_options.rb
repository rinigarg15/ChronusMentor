class RakeCleanupPositiveOutcomeOptions< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(:has_downtime => false) do
      if Rails.env.production? || Rails.env.productioneu?
        DeploymentRakeRunner.add_rake_task("single_time:cleanup_positive_outcome_options")
      end
    end
  end

  def down
    #nothing
  end
end
