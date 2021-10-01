class RemoveTrackForAtkins< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("common:programs_remover:remove DOMAIN='chronus.com' SUBDOMAIN='atkinsglobal' ROOTS='mentoring-circles'") if Rails.env.production?
    end
  end

  def down
    # Do Nothing
  end
end
