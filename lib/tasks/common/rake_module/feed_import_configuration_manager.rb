module Common::RakeModule::FeedImportConfigurationManager

  def self.fetch_organization_and_feed_import_configuration(domain, subdomain)
    organization = Common::RakeModule::Utils.fetch_programs_and_organization(domain, subdomain)[1]
    feed_import_configuration = organization.feed_import_configuration
    raise "Organization doesn't contain FeedImportConfiguration!" if feed_import_configuration.blank?

    [organization, feed_import_configuration]
  end

  def self.set_frequency(feed_import_configuration, frequency)
    raise "Frequency of FeedImportConfiguration is empty!" if frequency.blank?

    feed_import_configuration.set_frequency!(frequency.to_i.days)
  end

  def self.set_preprocessor(feed_import_configuration, preprocessor)
    raise "Preprocessor of FeedImportConfiguration is empty!" if preprocessor.blank?

    "ChronusSftpFeed::Preprocessor::#{preprocessor}".constantize # To ensure that the preprocessor class is defined
    feed_import_configuration.update_attributes!(preprocessor: preprocessor)
  end

  def self.set_config_and_source_options(feed_import_configuration, config_options, source_options)
    if config_options.present?
      options = feed_import_configuration.get_config_options
      options.merge!(eval(config_options))
      feed_import_configuration.set_config_options!(options)
    end

    if source_options.present?
      options = feed_import_configuration.get_source_options
      options.merge!(eval(source_options))
      feed_import_configuration.set_source_options!(options)
    end
  end

  def self.create_feed_import_configuration(organization, sftp_user_name, options = {})
    feed_import_configuration = organization.create_feed_import_configuration(sftp_user_name: sftp_user_name, enabled: options[:enabled])
    set_frequency(feed_import_configuration, options[:frequency] || FeedImportConfiguration::Frequency::WEEKLY/1.day )
    set_preprocessor(feed_import_configuration, options[:preprocessor]) if options[:preprocessor].present?
    options[:source_options] ||= { source_list: [{}] }.inspect
    set_config_and_source_options(feed_import_configuration, options[:config_options], options[:source_options])
  end
end