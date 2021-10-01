require_relative './../../../test_helper'

class ChronusSftpFeed::ConfigurationTest < ActiveSupport::TestCase

  def setup
    @organization = programs(:org_primary)
    @organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    @feed_import = FeedImportConfiguration.create!(organization: @organization, frequency: 1.day.to_i, enabled: true, sftp_user_name: "org_primary")
    super
  end

  def test_default_configuration
    config = ChronusSftpFeed::Configuration.new(nil, @feed_import)

    assert_equal @organization, config.organization
    assert_equal @organization.members.where(admin: true).first, config.mentor_admin
    assert_equal "Administrator", config.custom_term_for_admin
    assert_equal [ProfileQuestion::Type::MANAGER.to_s, ProfileQuestion::Type::LOCATION.to_s], config.secondary_questions_map.keys
    assert_equal ["Manager", "Location"], config.secondary_questions_map.values
    assert_equal ["chunk_size", "keep_original_headers", "file_encoding", "row_sep", "remove_empty_values", "remove_zero_values", "convert_values_to_numeric"], config.csv_options.keys
    assert_equal [1000, true, 'ISO-8859-1', :auto, false, false, false], config.csv_options.values
    assert_equal 1000, config.chunk_size
    assert_equal "Tags", config.user_tags_header
    assert_equal "Track", config.program_name_header
    assert_equal ChronusSftpFeed::Constant::IMPORT_QUESTION_TEXT, config.import_question_text
    assert_equal ChronusSftpFeed::Constant::EMAIL, config.primary_key_header
    assert_empty config.ignore_column_headers
    assert_empty config.data_map
    assert_empty config.suspend_logic_map
    assert_empty config.supplement_questions_map
    assert_nil config.login_identifier_header
    assert_nil config.import_file_name
    assert_match /#{@organization.subdomain}_\h+_error/, config.error_stream_name
    assert_match /#{@organization.subdomain}_\h+_log/ , config.log_stream_name

    assert_false config.allow_manager_updates?(["Manager"])
    assert_false config.suspension_required?
    assert_false config.import_user_tags
    assert_false config.allow_user_tags_import?(["Tags", "Track"])
    assert_false config.allow_import_question
    assert_false config.allow_location_updates
    assert_false config.allow_location_updates?(["Location"])
    assert_false config.use_login_identifier
    assert_false config.prevent_name_override
  end

  def test_non_default_configuration
    options = {
      csv_options: { chunk_size: 100 },
      import_file_name: "test_file.csv",
      secondary_questions_map: { ProfileQuestion::Type::LOCATION.to_s => "Location", ProfileQuestion::Type::MANAGER.to_s => "Manager" },
      suspension_required: true,
      allow_location_updates: true,
      allow_manager_updates: true,
      login_identifier_header: "Employee ID",
      use_login_identifier: true,
      import_user_tags: true,
      prevent_name_override: true
    }
    @feed_import.set_config_options!(options)
    config = ChronusSftpFeed::Configuration.new("test_file.csv", @feed_import)

    assert_equal @organization, config.organization
    assert_equal @organization.members.where(admin: true).first, config.mentor_admin
    assert_equal "Administrator", config.custom_term_for_admin
    assert_equal [ProfileQuestion::Type::LOCATION.to_s, ProfileQuestion::Type::MANAGER.to_s], config.secondary_questions_map.keys
    assert_equal ["Location", "Manager"], config.secondary_questions_map.values
    assert_equal ["chunk_size", "keep_original_headers", "file_encoding", "row_sep", "remove_empty_values", "remove_zero_values", "convert_values_to_numeric"], config.csv_options.keys
    assert_equal [100, true, 'ISO-8859-1', :auto, false, false, false], config.csv_options.values
    assert_equal 100, config.chunk_size
    assert_equal "Employee ID", config.login_identifier_header
    assert_equal "Employee ID", config.primary_key_header
    assert_equal "test_file.csv", config.import_file_name
    assert_match /#{@organization.subdomain}_\h+_error/, config.error_stream_name
    assert_match /#{@organization.subdomain}_\h+_log/ , config.log_stream_name
    assert_empty config.data_map
    assert_empty config.suspend_logic_map

    assert config.suspension_required?
    assert config.import_user_tags
    assert config.allow_user_tags_import?(["Tags", "Track"])
    assert config.allow_location_updates
    assert config.allow_location_updates?(["Location"])
    assert config.use_login_identifier
    assert config.prevent_name_override
    assert_false config.allow_location_updates?
    assert config.allow_manager_updates?(["Manager"])
  end
end