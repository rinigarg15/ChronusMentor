class RakeUpdateSamlConfigForWdol< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:auth_config_manager:update DOMAIN='chronus.com' SUBDOMAIN='dol' AUTH_TYPE='SAMLAuth' CONFIG_IN_YAML='---\\nname_parser: http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress\\n'")
      end
    end
  end

  def down
  end
end