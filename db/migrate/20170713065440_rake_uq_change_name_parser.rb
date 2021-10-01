class RakeUqChangeNameParser< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("common:auth_config_manager:update DOMAIN='edu.au' SUBDOMAIN='mentoring.app.uq' AUTH_TYPE='SAMLAuth' CONFIG_IN_YAML='---\nname_parser: urn:oid:0.9.2342.19200300.100.1.1\n'") if Rails.env.productioneu?
    end
  end

  def down
    # Do nothing
  end
end
