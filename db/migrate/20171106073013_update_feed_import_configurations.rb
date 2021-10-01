class UpdateFeedImportConfigurations< ActiveRecord::Migration[4.2]

  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      FeedImportConfiguration.all.each do |feed_import_configuration|
        config_options = feed_import_configuration.get_config_options
        primary_key = config_options[:primary_key].to_s
        primary_key_db = config_options[:primary_key_db].to_s
        secondary_key = config_options[:secondary_key].to_s
        secondary_key_db = config_options[:secondary_key_db].to_s

        email_column = (primary_key_db.blank? || primary_key_db == "email") ? primary_key : secondary_key
        if email_column.present? && email_column != ChronusSftpFeed::Constant::EMAIL
          csv_options = config_options[:csv_options] || {}
          key_mapping = csv_options[:key_mapping] || {}
          csv_options[:key_mapping] = key_mapping.merge(email_column => ChronusSftpFeed::Constant::EMAIL)
          config_options[:csv_options] = csv_options
        end

        login_name_column =
          if primary_key_db == "login_name"
            config_options[:use_login_identifier] = true
            primary_key
          elsif secondary_key_db == "login_name"
            secondary_key
          end
        config_options[:login_identifier_header] = login_name_column if login_name_column.present?
        config_options.except!(:primary_key, :primary_key_db, :secondary_key, :secondary_key_db)
        feed_import_configuration.set_config_options!(config_options)
      end
    end
  end

  def down
    # do nothing
  end
end
