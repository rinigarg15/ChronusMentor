class RakeAuthConfigManagerUpdateSsoDescriptionForUq< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("common:auth_config_manager:update DOMAIN='edu.au' SUBDOMAIN='mentoring.app.uq' AUTH_TYPE='SAMLAuth' ATTRIBUTES_IN_YAML='---\\n:description: Please use your My UQ Login to access this mentoring program\\n'") if Rails.env.productioneu?
    end
  end

  def down
    # Do nothing
  end
end
