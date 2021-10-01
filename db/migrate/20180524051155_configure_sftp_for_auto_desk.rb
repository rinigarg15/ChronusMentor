class ConfigureSftpForAutoDesk < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        organization = Program::Domain.get_organization("chronus.com", "autodeskmentoring")
        feed_import_configuration = organization.create_feed_import_configuration(sftp_user_name: "autodesk", frequency: FeedImportConfiguration::Frequency::DAILY, enabled: false)
        config_options = {
          suspension_required: true,
          reactivate_suspended_users: true,
          login_identifier_header: "Unique Identifier",
          secondary_questions_map: { ProfileQuestion::Type::MANAGER.to_s => "Manager" },
          ignore_column_headers: ["Location"]
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
