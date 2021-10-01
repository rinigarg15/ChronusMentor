#usage rake single_time:update_allow_manager_update
#Example rake single_time:update_allow_manager_update

namespace :single_time do
  desc "Import manager attributes"
  task add_allow_manager_update: :environment do
    feed_import_configurations = FeedImportConfiguration.where(sftp_user_name: ENV["SFTP_USER_NAMES"].split(",").map(&:strip))
    feed_import_configurations.each do |feed_import_configuration|
      Common::RakeModule::FeedImportConfigurationManager.set_config_and_source_options(feed_import_configuration, { allow_manager_updates: true }.inspect, nil)
    end
  end
end