# TASK: :enable
# USAGE: rake common:feed_import_configuration_manager:enable DOMAIN=<domain> SUBDOMAIN=<subdomain>
# EXAMPLE: rake common:feed_import_configuration_manager:enable DOMAIN="localhost.com" SUBDOMAIN="ceg"

# TASK: :disable
# USAGE: rake common:feed_import_configuration_manager:disable DOMAIN=<domain> SUBDOMAIN=<subdomain>
# EXAMPLE: rake common:feed_import_configuration_manager:disable DOMAIN="localhost.com" SUBDOMAIN="ceg"

# TASK: :update_options
# USAGE: rake common:feed_import_configuration_manager:update_options DOMAIN=<domain> SUBDOMAIN=<subdomain> CONFIG_OPTIONS=<> SOURCE_OPTIONS=<>
# EXAMPLE: rake common:feed_import_configuration_manager:update_options DOMAIN="localhost.com" SUBDOMAIN="ceg" CONFIG_OPTIONS="{:prevent_name_override=>true}"

# TASK: :set_frequency
# USAGE: rake common:feed_import_configuration_manager:set_frequency DOMAIN=<domain> SUBDOMAIN=<subdomain> FREQUENCY=<frequency_in_days>
# EXAMPLE: rake common:feed_import_configuration_manager:set_frequency DOMAIN="localhost.com" SUBDOMAIN="ceg" FREQUENCY=7

# TASK: :set_preprocessor
# USAGE: rake common:feed_import_configuration_manager:set_preprocessor DOMAIN=<domain> SUBDOMAIN=<subdomain> PREPROCESSOR=<preprocessor_class_name>
# EXAMPLE: rake common:feed_import_configuration_manager:set_preprocessor DOMAIN="localhost.com" SUBDOMAIN="ceg" PREPROCESSOR="WbgPreprocessor"


# TASK: :create
# USAGE: rake common:feed_import_configuration_manager:create DOMAIN=<domain> SUBDOMAIN=<subdomain> FREQUENCY=<frequency_in_days> CONFIG_OPTIONS=<> SOURCE_OPTIONS=<>
# EXAMPLE: rake common:feed_import_configuration_manager:create DOMAIN="localhost.com" SUBDOMAIN="iitm" FREQUENCY=7 CONFIG_OPTIONS="{:reactivation_required=>true, \"suspension_required\"=>true}"


namespace :common do
  namespace :feed_import_configuration_manager do
    desc "Enable feed_import_configuration of an organization"
    task enable: :environment do
      Common::RakeModule::Utils.execute_task do
        organization, feed_import_configuration = Common::RakeModule::FeedImportConfigurationManager.fetch_organization_and_feed_import_configuration(ENV["DOMAIN"], ENV["SUBDOMAIN"])
        unless feed_import_configuration.enabled?
          feed_import_configuration.enable!
          Common::RakeModule::Utils.print_success_messages("Feed Import Configuration has been enabled for #{organization.url}!")
        end
      end
    end

    desc "Disable feed_import_configuration of an organization"
    task disable: :environment do
      Common::RakeModule::Utils.execute_task do
        organization, feed_import_configuration = Common::RakeModule::FeedImportConfigurationManager.fetch_organization_and_feed_import_configuration(ENV["DOMAIN"], ENV["SUBDOMAIN"])
        if feed_import_configuration.enabled?
          feed_import_configuration.disable!
          Common::RakeModule::Utils.print_success_messages("Feed Import Configuration has been disabled for #{organization.url}!")
        end
      end
    end

    desc "Update configuration/source options of feed_import_configuration of an organization"
    task update_options: :environment do
      Common::RakeModule::Utils.execute_task do
        organization, feed_import_configuration = Common::RakeModule::FeedImportConfigurationManager.fetch_organization_and_feed_import_configuration(ENV["DOMAIN"], ENV["SUBDOMAIN"])
        Common::RakeModule::FeedImportConfigurationManager.set_config_and_source_options(feed_import_configuration, ENV["CONFIG_OPTIONS"], ENV["SOURCE_OPTIONS"])
        Common::RakeModule::Utils.print_success_messages("Feed Import Configuration of #{organization.url} has been updated!")
      end
    end

    desc "Set frequency for feed_import_configuration of an organization"
    task set_frequency: :environment do
      Common::RakeModule::Utils.execute_task do
        organization, feed_import_configuration = Common::RakeModule::FeedImportConfigurationManager.fetch_organization_and_feed_import_configuration(ENV["DOMAIN"], ENV["SUBDOMAIN"])
        Common::RakeModule::FeedImportConfigurationManager.set_frequency(feed_import_configuration, ENV['FREQUENCY'])
        Common::RakeModule::Utils.print_success_messages("Frequency has been set to #{ENV['FREQUENCY']} day(s) for #{organization.url}!")
      end
    end

    desc "Set preprocessor for feed_import_configuration of an organization"
    task set_preprocessor: :environment do
      Common::RakeModule::Utils.execute_task do
        organization, feed_import_configuration = Common::RakeModule::FeedImportConfigurationManager.fetch_organization_and_feed_import_configuration(ENV["DOMAIN"], ENV["SUBDOMAIN"])
        Common::RakeModule::FeedImportConfigurationManager.set_preprocessor(feed_import_configuration, ENV['PREPROCESSOR'])
        Common::RakeModule::Utils.print_success_messages("Preprocessor has been set to #{ENV['PREPROCESSOR']} for #{organization.url}!")
      end
    end

    desc "Create feed_import_configuration of an organization"
    task create: :environment do
      Common::RakeModule::Utils.execute_task do
        organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])[1]
        unless organization.feed_import_configuration.present?
          raise "Sftp user name not provided" unless ENV["SFTP_USER_NAME"].present?
          enabled = ENV["ENABLED"].to_s.to_boolean
          options = { frequency: ENV['FREQUENCY'], preprocessor: ENV['PREPROCESSOR'], config_options: ENV["CONFIG_OPTIONS"], source_options: ENV["SOURCE_OPTIONS"],  enabled: enabled }
          Common::RakeModule::FeedImportConfigurationManager.create_feed_import_configuration(organization, ENV["SFTP_USER_NAME"], options)
          Common::RakeModule::Utils.print_success_messages("Feed import configuration has been created for #{organization.url}!")
        else
          Common::RakeModule::Utils.print_error_messages("Feed import configuration already exists for #{organization.url}!")
        end
      end
    end
  end
end