class RakeSurveyAnswerScrubberForFbFs< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:data_scrubber:scrub DOMAIN='chronus.com' SUBDOMAIN='fbfs' ROOTS='p1' SCRUB_ITEM='survey_answers' IDS='8637'")
      end
    end
  end

  def down
    #Do nothing
  end
end
