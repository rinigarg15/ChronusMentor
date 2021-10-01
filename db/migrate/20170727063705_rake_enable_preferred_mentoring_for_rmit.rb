class RakeEnablePreferredMentoringForRmit< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:matching_settings_updater:change_mentor_request_style DOMAIN='edu.au' SUBDOMAIN='mentoring.rmit' ROOTS='p8' MENTOR_REQUEST_STYLE='1'")
      end
    end
  end

  def down
  end
end