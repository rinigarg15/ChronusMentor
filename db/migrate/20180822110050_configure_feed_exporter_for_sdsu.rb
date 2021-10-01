class ConfigureFeedExporterForSdsu < ActiveRecord::Migration[5.1]
  def up
    if Rails.env.production?
      ChronusMigrate.data_migration(has_downtime: false) do
        organization = Program::Domain.get_organization("sdsu.edu", "amp")
        feed_exporter = organization.feed_exporter || organization.create_feed_exporter(sftp_account_name: "sdsuamp", frequency: 7)
        options = Base64.encode64(Marshal.dump(ActiveSupport::HashWithIndifferentAccess.new({
          headers: ["member_id", "first_name", "last_name", "email",  "program", "user_status", "role_name", "active_connections_count", "recent_connection_started_on", "connection_plan_template_names", "tags"],
          profile_question_texts: ["Ethnicity", "RedID", "First Generation College Student?", "Military Affiliation Status", "Gender Identity", "Referral Source"]
        })))
        feed_exporter.feed_exporter_configurations.create!(type: FeedExporter::MemberConfiguration, configuration_options: options, enabled: true)
      end
    end
  end

  def down
  end
end
