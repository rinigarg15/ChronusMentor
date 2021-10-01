class RemoveManagerFromMediaoceanFeedImport< ActiveRecord::Migration[4.2]
  def up
    # ChronusMigrate.data_migration(has_downtime: false) do
    #   if Rails.env.production?
    #     organization, feed_import_configuration = Common::RakeModule::FeedImportConfigurationManager.fetch_organization_and_feed_import_configuration("chronus.com", "mediaocean")
    #     configurations = YAML::load(ERB.new(IO.read("#{Rails.root}/config/feed_import_configurations.yml")).result(binding))
    #     options = configurations.select {|configuration| configuration["subdomain"] == "mediaocean"}.first["configuration_options"]
    #     feed_import_configuration.set_config_options!(options)
    #   end
    # end
  end

  def down
    # Do nothing
  end
end
