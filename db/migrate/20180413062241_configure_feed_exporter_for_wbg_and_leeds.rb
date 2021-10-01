class ConfigureFeedExporterForWbgAndLeeds < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        ActiveRecord::Base.transaction do
          leeds_org = Program::Domain.find_by(subdomain: "leedsmentoring", domain: "colorado.edu").organization
          leeds_feed_exporter = leeds_org.feed_exporter
          leeds_feed_exporter.update_attributes!(sftp_account_name: "leeds")
          leeds_member_config = FeedExporter::MemberConfiguration.new(feed_exporter_id: leeds_feed_exporter.id, enabled: true)
          leeds_member_config.set_config_options!({headers: [FeedExporter::MemberConfiguration::DefaultHeaders::MEMBER_ID, FeedExporter::MemberConfiguration::DefaultHeaders::FIRST_NAME, FeedExporter::MemberConfiguration::DefaultHeaders::LAST_NAME, FeedExporter::MemberConfiguration::DefaultHeaders::EMAIL, FeedExporter::MemberConfiguration::DefaultHeaders::MEMBER_STATUS, FeedExporter::MemberConfiguration::DefaultHeaders::JOINED_ON, FeedExporter::MemberConfiguration::DefaultHeaders::ACTIVE_CONNECTIONS_COUNT, FeedExporter::MemberConfiguration::DefaultHeaders::LAST_SUSPENDED_ON, FeedExporter::MemberConfiguration::DefaultHeaders::PROGRAM, FeedExporter::MemberConfiguration::DefaultHeaders::ROLE_ID, FeedExporter::MemberConfiguration::DefaultHeaders::ROLE_NAME, FeedExporter::MemberConfiguration::DefaultHeaders::USER_STATUS,  FeedExporter::MemberConfiguration::DefaultHeaders::LAST_DEACTIVATED_ON], profile_question_texts: ["Are you a CU or Leeds Alumnus?", "Alternate Email Address", "Local Street Address (Home or Business)", "Current Company Name (or former)", "Are you a first-generation college student? (i.e., neither of your parents received a college degree)", "Race", "Current Title (or former)", "What is your CU Student ID #?", "EID", "I have a degree or work experience in the following areas that I would be willing to share with my student mentee:", "I have experience in the following industry areas that I could share with my student mentee:", "Alternate Contact (or Assistant): Name", "Alternate Contact (or Assistant): Phone Number", "Alternate Contact (or Assistant): Email Address", "Additional Mentoring Opportunities", "Current City", "Current State", "Current Zip", "Gender"] })

          leeds_connection_config = FeedExporter::ConnectionConfiguration.new(feed_exporter_id: leeds_feed_exporter.id, enabled: true)
          leeds_connection_config.set_config_options!({headers: [FeedExporter::ConnectionConfiguration::DefaultHeaders::GROUP_ID, FeedExporter::ConnectionConfiguration::DefaultHeaders::GROUP_NAME, FeedExporter::ConnectionConfiguration::DefaultHeaders::PROGRAM_ROOT, FeedExporter::ConnectionConfiguration::DefaultHeaders::ROLE_NAMES, FeedExporter::ConnectionConfiguration::DefaultHeaders::ROLE_IDS, FeedExporter::ConnectionConfiguration::DefaultHeaders::GROUP_STATUS, FeedExporter::ConnectionConfiguration::DefaultHeaders::GROUP_NOTES, FeedExporter::ConnectionConfiguration::DefaultHeaders::ACTIVE_SINCE, FeedExporter::ConnectionConfiguration::DefaultHeaders::LAST_ACTIVITY_AT, FeedExporter::ConnectionConfiguration::DefaultHeaders::EXPIRES_ON], profile_question_texts: []})

          wbg_org = Program::Domain.find_by(subdomain: "wbg", domain: "chronus.com").organization
          wbg_feed_exporter = wbg_org.create_feed_exporter(sftp_account_name: "wbg")

          wbg_connection_config = FeedExporter::ConnectionConfiguration.new(feed_exporter_id: wbg_feed_exporter.id, enabled: true)
          wbg_connection_config.set_config_options!({headers: [FeedExporter::ConnectionConfiguration::DefaultHeaders::GROUP_ID, FeedExporter::ConnectionConfiguration::DefaultHeaders::GROUP_NAME, FeedExporter::ConnectionConfiguration::DefaultHeaders::PROGRAM_ROOT, FeedExporter::ConnectionConfiguration::DefaultHeaders::PROGRAM_NAME, FeedExporter::ConnectionConfiguration::DefaultHeaders::ROLE_NAMES, FeedExporter::ConnectionConfiguration::DefaultHeaders::GROUP_STATUS, FeedExporter::ConnectionConfiguration::DefaultHeaders::GROUP_NOTES, FeedExporter::ConnectionConfiguration::DefaultHeaders::ACTIVE_SINCE, FeedExporter::ConnectionConfiguration::DefaultHeaders::LAST_ACTIVITY_AT, FeedExporter::ConnectionConfiguration::DefaultHeaders::EXPIRES_ON], profile_question_texts: ["UPI"]})
        end
      end
    end
  end

  def down
    ChronusMigrate.data_migration(has_downtime: false) do
      # nothing
    end
  end
end
