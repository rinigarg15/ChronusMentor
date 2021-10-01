class RakeDisableOngoingMentoringForUwcomotion< ActiveRecord::Migration[4.2]

  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:matching_settings_updater:disable_ongoing_mentoring DOMAIN='chronus.com' SUBDOMAIN='uwcomotion' ROOTS='p3'")
      end
    end
  end

  def down
  end
end