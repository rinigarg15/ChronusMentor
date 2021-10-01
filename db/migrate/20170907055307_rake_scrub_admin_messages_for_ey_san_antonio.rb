class RakeScrubAdminMessagesForEySanAntonio< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:data_scrubber:scrub DOMAIN='chronus.com' SUBDOMAIN='eycollegemap' ROOTS='p26' SCRUB_ITEM='admin_messages'")
      end
    end
  end

  def down
  end
end