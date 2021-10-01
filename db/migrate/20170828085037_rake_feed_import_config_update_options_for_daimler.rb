class RakeFeedImportConfigUpdateOptionsForDaimler< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:feed_import_configuration_manager:update_options DOMAIN='chronus.com' SUBDOMAIN='daimler-trucksnorthamerica' CONFIG_OPTIONS_IN_YAML='---\\n:allow_location_updates: false\\n'")
      end
    end
  end

  def down
  end
end
