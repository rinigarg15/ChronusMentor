class ConfigureFeedImportForRli < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        organization = Program::Domain.get_organization("chronus.com", "rlicorp")
        feed_import_configuration = organization.create_feed_import_configuration(sftp_user_name: "rlicorp", frequency: FeedImportConfiguration::Frequency::WEEKLY, enabled: false)
        config_options = {
          suspension_required: true,
          reactivate_suspended_users: true,
          login_identifier_header: "UUID"
        }
        source_options = {
          "source_list" => [{}]
        }
        feed_import_configuration.set_config_options!(config_options)
        feed_import_configuration.set_source_options!(source_options)
      end
    end
  end

  def down
    #Do nothing
  end
end
