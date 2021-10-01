class RakeSetLogoutPathForWpcMentors< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:organization_manager:set_logout_path DOMAIN='chronus.com' SUBDOMAIN='wpcmentors' LOGOUT_PATH='https://wpcmentors.chronus.com/about'")
      end
    end
  end

  def down
    #Do nothing
  end
end
