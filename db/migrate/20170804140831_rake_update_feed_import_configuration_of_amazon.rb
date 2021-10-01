class RakeUpdateFeedImportConfigurationOfAmazon< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:feed_import_configuration_manager:update_options DOMAIN='chronus.com' SUBDOMAIN='amazon-mentoring' CONFIG_OPTIONS_IN_YAML='---\\n:prevent_name_override: true\\n'")
      end
    end
  end

  def down
  end
end