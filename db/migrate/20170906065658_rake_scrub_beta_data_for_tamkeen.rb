class RakeScrubBetaDataForTamkeen< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:data_scrubber:scrub DOMAIN='chronus.com' SUBDOMAIN='tamkeen' ROOTS='p1' SCRUB_ITEM='admin_messages'")
        DeploymentRakeRunner.add_rake_task("common:data_scrubber:scrub DOMAIN='chronus.com' SUBDOMAIN='tamkeen' ROOTS='p1' SCRUB_ITEM='program_invitations'")
        DeploymentRakeRunner.add_rake_task("common:data_scrubber:scrub DOMAIN='chronus.com' SUBDOMAIN='tamkeen' ROOTS='p1' SCRUB_ITEM='program_invitation_campaign_analytics'")
      end
    end
  end

  def down
    #Do nothing
  end
end
