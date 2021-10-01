class RakeSamlConfigForUomSandbox< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.demo?
        DeploymentRakeRunner.add_rake_task("common:auth_config_manager:update DOMAIN='chronus.com' SUBDOMAIN='uom-sandbox.demo' AUTH_TYPE='SAMLAuth' CONFIG_IN_YAML='---\\n:idp_slo_target_url: https://authidm3tst.unimelb.edu.au/oamfed/idp/samlv20\\n:import_data:\\n  name_identifier: Name\\n  attributes:\\n    Member:\\n      first_name: givenName\\n      last_name: sn\\n      email: mail\\n:name_parser: milleniumID\\n'")
      end
    end
  end

  def down
  end
end