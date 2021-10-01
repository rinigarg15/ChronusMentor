require_relative './../../../../test_helper.rb'

class SettingsImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_general_settings_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    include_importers(:forum, :survey, :mentoring_model, :section, :admin_view, :abstract_campaign, :resource, :mailer_template, :group_closure_reason, :overview_pages)

    exported_program_settings = {}
    program_settings_file_path = File.join(IMPORT_CSV_BASE_PATH, "settings", "program_settings.csv")
    csv_content = fixture_file_upload(program_settings_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    exported_program_settings = csv.first.to_hash

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack).import
    new_program.reload

    general_settings_program_attributes = ["published"]

    imported_general_settings = {}
    general_settings_program_attributes.each do |attribute|
      attribute_value = new_program.send(attribute)
      imported_general_settings[attribute] = (attribute_value.nil? ? nil : attribute_value.to_s)
    end

    imported_general_settings.each do |setting_name, imported_setting_value|
      assert_equal imported_setting_value, exported_program_settings[setting_name]
    end

    delete_base_dir_for_import
  end

  def test_membership_settings_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    ForumImporter.any_instance.expects(:import).once
    SurveyImporter.any_instance.expects(:import).once
    MentoringModelImporter.any_instance.expects(:import).once
    SectionImporter.any_instance.expects(:import).once
    AdminViewImporter.any_instance.expects(:import).once
    AbstractCampaignImporter.any_instance.expects(:import).once
    ResourceImporter.any_instance.expects(:import).once
    MailerTemplateImporter.any_instance.expects(:import).once
    GroupClosureReasonImporter.any_instance.expects(:import).once
    OverviewPagesImporter.any_instance.expects(:import).once

    exported_program_settings = {}
    program_settings_file_path = File.join(IMPORT_CSV_BASE_PATH, "settings", "program_settings.csv")
    csv_content = fixture_file_upload(program_settings_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    exported_program_settings = csv.first.to_hash

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack).import
    new_program.reload

    membership_settings_program_attributes = ["show_multiple_role_option"]

    imported_membership_settings = {}
    membership_settings_program_attributes.each do |attribute|
      attribute_value = new_program.send(attribute)
      imported_membership_settings[attribute] = (attribute_value.nil? ? nil : attribute_value.to_s)
    end

    imported_membership_settings.each do |setting_name, imported_setting_value|
      assert_equal imported_setting_value, exported_program_settings[setting_name]
    end

    delete_base_dir_for_import
  end

  def test_matching_settings_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!
    new_program.reload

    ForumImporter.any_instance.expects(:import).once
    SurveyImporter.any_instance.expects(:import).once
    MentoringModelImporter.any_instance.expects(:import).once
    SectionImporter.any_instance.expects(:import).once
    AdminViewImporter.any_instance.expects(:import).once
    AbstractCampaignImporter.any_instance.expects(:import).once
    ResourceImporter.any_instance.expects(:import).once
    MailerTemplateImporter.any_instance.expects(:import).once
    GroupClosureReasonImporter.any_instance.expects(:import).once
    OverviewPagesImporter.any_instance.expects(:import).once

    exported_program_settings = {}
    program_settings_file_path = File.join(IMPORT_CSV_BASE_PATH, "settings", "program_settings.csv")
    csv_content = fixture_file_upload(program_settings_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    exported_program_settings = csv.first.to_hash

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack).import
    new_program.reload

    matching_settings_program_attributes = ["engagement_type", "allow_mentoring_mode_change", "mentor_request_style", "max_pending_requests_for_mentee", "needs_mentoring_request_reminder", "mentoring_request_reminder_duration", "mentor_request_expiration_days", "allow_mentoring_requests", "allow_mentoring_requests_message", "allow_mentee_withdraw_mentor_request", "allow_preference_mentor_request", "mentor_offer_needs_acceptance", "allow_user_to_send_message_outside_mentoring_area", "prevent_past_mentor_matching", "allow_non_match_connection", "zero_match_score_message", "prevent_manager_matching", "manager_matching_level", "default_max_connections_limit", "can_increase_connection_limit", "can_decrease_connection_limit", "max_connections_for_mentee", "allow_track_admins_to_access_all_users"]

    imported_matching_program_settings = {}
    matching_settings_program_attributes.each do |attribute|
      if ProgramSettingsExporter::SettingAttributes.include?(attribute)
        attribute_value = new_program.attributes[attribute]
      else
        attribute_value = new_program.send(attribute)
      end
      imported_matching_program_settings[attribute] = (attribute_value.nil? ? nil : attribute_value.to_s)
    end

    imported_matching_program_settings.each do |setting_name, imported_setting_value|
      assert_dynamic_expected_nil_or_equal imported_setting_value, exported_program_settings[setting_name]
    end

    delete_base_dir_for_import
  end

  def test_mentoring_connection_settings_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = programs(:albers)
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!
    new_program.enable_feature(FeatureName::CALENDAR)

    ForumImporter.any_instance.expects(:import).once
    SurveyImporter.any_instance.expects(:import).once
    MentoringModelImporter.any_instance.expects(:import).once
    SectionImporter.any_instance.expects(:import).once
    AdminViewImporter.any_instance.expects(:import).once
    AbstractCampaignImporter.any_instance.expects(:import).once
    ResourceImporter.any_instance.expects(:import).once
    MailerTemplateImporter.any_instance.expects(:import).once
    OverviewPagesImporter.any_instance.expects(:import).once

    exported_program_settings = {}
    program_settings_file_path = File.join(IMPORT_CSV_BASE_PATH, "settings", "program_settings.csv")
    csv_content = fixture_file_upload(program_settings_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    exported_program_settings = csv.first.to_hash
    exported_calendar_settings = csv.first.to_hash

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack).import
    new_program.reload

    exported_program_settings["auto_terminate_reason_id"] = solution_pack.id_mappings["GroupClosureReason"][1].to_s

    mentoring_connection_settings_program_attributes = ["allow_one_to_many_mentoring", "allow_users_to_leave_connection", "allow_to_change_connection_expiry_date", "inactivity_tracking_period", "feedback_survey_id", "auto_terminate_reason_id", "admin_access_to_mentoring_area"]

    imported_mentoring_connection_program_settings = {}
    mentoring_connection_settings_program_attributes.each do |attribute|
      if ProgramSettingsExporter::SettingAttributes.include?(attribute)
        attribute_value = new_program.attributes[attribute]
      else
        attribute_value = new_program.send(attribute)
      end
      imported_mentoring_connection_program_settings[attribute] = (attribute_value.nil? ? nil : attribute_value.to_s)
    end

    imported_mentoring_connection_program_settings.each do |setting_name, imported_setting_value|
      assert_dynamic_expected_nil_or_equal imported_setting_value, exported_program_settings[setting_name]
    end

    mentoring_connection_settings_calendar_attributes = ["feedback_survey_delay_not_time_bound"]

    imported_mentoring_connection_calendar_settings = {}
    mentoring_connection_settings_calendar_attributes.each do |attribute|
      if CalendarSettingExporter::SettingAttributes.include?(attribute)
        attribute_value = new_program.attributes[attribute]
      else
        attribute_value = new_program.send(attribute)
      end
      imported_mentoring_connection_calendar_settings[attribute] = (attribute_value.nil? ? nil : attribute_value.to_s)
    end

    imported_mentoring_connection_calendar_settings.each do |setting_name, imported_setting_value|
      assert_dynamic_expected_nil_or_equal imported_setting_value, exported_calendar_settings[setting_name]
    end

    delete_base_dir_for_import
  end

  def test_features_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    ForumImporter.any_instance.expects(:import).once
    SurveyImporter.any_instance.expects(:import).once
    MentoringModelImporter.any_instance.expects(:import).once
    SectionImporter.any_instance.expects(:import).once
    AdminViewImporter.any_instance.expects(:import).once
    AbstractCampaignImporter.any_instance.expects(:import).once
    ResourceImporter.any_instance.expects(:import).once
    MailerTemplateImporter.any_instance.expects(:import).once
    GroupClosureReasonImporter.any_instance.expects(:import).once
    OverviewPagesImporter.any_instance.expects(:import).once
    organization_level_features = FeatureName.organization_level_features
    features_file_path = File.join(IMPORT_CSV_BASE_PATH, "settings", "features.csv")
    csv_content = fixture_file_upload(features_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => false)
    exported_features_for_enabling = csv[0] - organization_level_features
    exported_features_for_disabling = csv[1]

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack).import
    new_program.reload

    enabled_features = new_program.enabled_features
    disabled_features = new_program.disabled_features

    exported_features_for_enabling.each do |feature|
      assert enabled_features.include?(feature)
    end
    exported_features_for_disabling.each do |feature|
      assert disabled_features.include?(feature)
    end

    delete_base_dir_for_import
  end

  def test_features_import_for_standalone_org
    org = nil
    new_program = nil
    org = Organization.create!({:name => "Some Organization"})
    delete_base_dir_for_import
    copy_base_dir_for_import
    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!
    org.reload
    new_program.reload

    ForumImporter.any_instance.expects(:import).once
    SurveyImporter.any_instance.expects(:import).once
    MentoringModelImporter.any_instance.expects(:import).once
    SectionImporter.any_instance.expects(:import).once
    AdminViewImporter.any_instance.expects(:import).once
    AbstractCampaignImporter.any_instance.expects(:import).once
    ResourceImporter.any_instance.expects(:import).once
    MailerTemplateImporter.any_instance.expects(:import).once
    GroupClosureReasonImporter.any_instance.expects(:import).once
    OverviewPagesImporter.any_instance.expects(:import).once
    organization_level_features = FeatureName.organization_level_features
    features_file_path = File.join(IMPORT_CSV_BASE_PATH, "settings", "features.csv")
    csv_content = fixture_file_upload(features_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => false)
    pgm_level = FeatureName.program_level_only
    exported_features_for_enabling = csv[0] - organization_level_features
    exported_features_for_disabling = csv[1]
    pgm_level_imported_features_enabled = exported_features_for_enabling & pgm_level
    pgm_level_imported_features_disabled = exported_features_for_disabling & pgm_level
    exported_features_for_enabling -= pgm_level_imported_features_enabled
    exported_features_for_disabling -= pgm_level_imported_features_disabled

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack).import
    new_program.reload
    
    assert_equal new_program.enabled_db_features.collect(&:name).sort, pgm_level_imported_features_enabled.sort
    enabled_features = org.reload.enabled_features
    disabled_features = org.disabled_features

    exported_features_for_enabling.each do |feature|
      assert enabled_features.include?(feature)
    end
    
    exported_features_for_disabling.each do |feature|
      assert disabled_features.include?(feature)
    end

    delete_base_dir_for_import
  end
end