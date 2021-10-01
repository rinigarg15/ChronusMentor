class RemoveTrackForEdwardJones< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("common:programs_remover:remove DOMAIN='chronus.com' SUBDOMAIN='edwardjones.demo' ROOTS='academic-mentoring'") if Rails.env.demo?
    end
  end

  def down
    # Do Nothing
  end
end
