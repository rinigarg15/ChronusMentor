class RakeUpdateMentoringModelForHorizons< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:mentoring_model_updater:change_mentoring_model DOMAIN='chronus.com' SUBDOMAIN='horizons' ROOT='lawmentoring' MENTORING_MODEL_ID='903' NEW_MENTORING_MODEL_ID='2991'")
      end
    end
  end

  def down
    # do nothing
  end
end