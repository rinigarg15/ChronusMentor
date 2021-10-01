class RakeSetLogoutPathForUq< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.productioneu?
        DeploymentRakeRunner.add_rake_task("common:organization_manager:set_logout_path DOMAIN='edu.au' SUBDOMAIN='mentoring.app.uq' LOGOUT_PATH='https://my.uq.edu.au/mentoring'")
      end
    end
  end

  def down
  end
end