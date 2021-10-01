class RakeAuthConfigManagerUpdateSsoTitle< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("common:auth_config_manager:update DOMAIN='edu.au' SUBDOMAIN='mentoring.app.uq' AUTH_TYPE='SAMLAuth' ATTRIBUTES_IN_YAML='---\\n:title: My UQ Login\\n'") if Rails.env.productioneu?
    end
  end

  def down
    # Do nothing
  end
end