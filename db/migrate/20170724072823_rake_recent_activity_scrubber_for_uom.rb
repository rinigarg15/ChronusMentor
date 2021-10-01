class RakeRecentActivityScrubberForUom< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.productioneu?
        program = Common::RakeModule::Utils.fetch_programs_and_organization('edu.au', 'mentoring.unimelb', 'p1')[0][0]
        ids = program.recent_activities.where('recent_activities.created_at < ?', DateTime.new(2017,06,01)).pluck(:id).join(",")
        DeploymentRakeRunner.add_rake_task("common:data_scrubber:scrub DOMAIN='edu.au' SUBDOMAIN='mentoring.unimelb' ROOTS='p1' SCRUB_ITEM='recent_activities' IDS='#{ids}'")
      end
    end
  end

  def down
    #Do nothing
  end
end
