class RakeEnableEatonWorkflowForRmit< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:matching_settings_updater:enable_eaton_workflow DOMAIN='edu.au' SUBDOMAIN='mentoring.rmit' ROOTS='p8' MIN_PREFERRED_MENTOR='3'")
      end
    end
  end

  def down
  end
end