class RakeRemoveChronusAuthForCobank< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:auth_config_manager:remove DOMAIN='chronus.com' SUBDOMAIN='cobank' AUTH_TYPE='ChronusAuth'")
      end
    end
  end

  def down
  end
end