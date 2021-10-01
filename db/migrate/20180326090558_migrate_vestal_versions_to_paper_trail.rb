class MigrateVestalVersionsToPaperTrail < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("single_time:migrate_vestal_versions_to_paper_trial")
    end
  end
end
