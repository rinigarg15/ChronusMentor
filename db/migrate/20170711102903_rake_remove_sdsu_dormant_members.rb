class RakeRemoveSdsuDormantMembers< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:member_manager:remove_dormant_members DOMAIN='sdsu.edu' SUBDOMAIN='amp'")
      end
    end
  end

  def down
    # Do nothing
  end
end