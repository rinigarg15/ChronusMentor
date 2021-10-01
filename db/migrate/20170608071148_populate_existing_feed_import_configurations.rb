class PopulateExistingFeedImportConfigurations< ActiveRecord::Migration[4.2]
  def up
    # ChronusMigrate.data_migration(has_downtime: false) do
    #   ActiveRecord::Base.transaction do
    #     feed_import_configurations = YAML::load(ERB.new(IO.read("#{Rails.root}/config/feed_import_configurations.yml")).result(binding))
    #     feed_import_configurations.select! { |feed_import_configuration| feed_import_configuration.delete("environment") == Rails.env.to_s }
    #     feed_import_configurations.each do |feed_import_configuration|
    #       subdomain = feed_import_configuration.delete("subdomain")
    #       organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME, subdomain)
    #       if organization.present?
    #         import_configuration = organization.build_feed_import_configuration(feed_import_configuration.slice("sftp_user_name", "enabled", "frequency", "preprocessor"))
    #         config_options = feed_import_configuration["configuration_options"]
    #         source_options = feed_import_configuration["source_options"]
    #         import_configuration.update_attributes!(enabled: organization.active?)
    #         import_configuration.set_config_options!(config_options)
    #         import_configuration.set_source_options!(source_options)
    #       end
    #     end
    #   end
    # end
  end

  def down
    ChronusMigrate.data_migration(has_downtime: false) do
      FeedImportConfiguration.destroy_all
    end
  end
end