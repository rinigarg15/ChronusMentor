class RakeScrubAdminMessagesAndSurveyAnswersForEy< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        program_ids = Common::RakeModule::Utils.fetch_programs_and_organization("chronus.com", "eycollegemap", "p7,p11")[0].map(&:id)
        Article.joins(:publications).where(article_publications: { program_id: program_ids }).update_all(view_count: 0)
        DeploymentRakeRunner.add_rake_task("common:data_scrubber:scrub DOMAIN='chronus.com' SUBDOMAIN='eycollegemap' ROOTS='p7,p11' SCRUB_ITEM='survey_answers'")
        DeploymentRakeRunner.add_rake_task("common:data_scrubber:scrub DOMAIN='chronus.com' SUBDOMAIN='eycollegemap' ROOTS='p7,p11' SCRUB_ITEM='admin_messages'")
      end
    end
  end

  def down
    #Do nothing
  end
end
