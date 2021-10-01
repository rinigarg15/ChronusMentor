class SettingsImporter < SolutionPack::Importer

  FolderName = 'settings/'
  FileName = 'settings'

  AssociatedImporters = ["ProgramSettingsExporter", "CalendarSettingExporter"]
  CareerDevAssociatedImporters = ["ProgramSettingsExporter"]

  def initialize(parent_importer)
    self.file_name = FileName
    self.parent_importer = parent_importer
    self.solution_pack = parent_importer.solution_pack
  end

  def import
    settings_hash = {}
    populate_settings_hash(settings_hash)

    import_features
    import_general_settings(settings_hash)
    import_membership_settings(settings_hash)
    import_matching_settings(settings_hash)
    import_mentoring_connection_settings(settings_hash)
  end

  def import_general_settings(settings_hash)
    solution_pack.program.published = settings_hash["Program"][0][:published]
    solution_pack.program.save!
  end

  def import_membership_settings(settings_hash)
    solution_pack.program.show_multiple_role_option = settings_hash["Program"][0][:show_multiple_role_option]
    solution_pack.program.save!
  end

  def import_matching_settings(settings_hash)
    matching_settings_program_attributes = ["engagement_type", "allow_mentoring_mode_change", "mentor_request_style", "max_pending_requests_for_mentee", "needs_mentoring_request_reminder", "mentoring_request_reminder_duration", "mentor_request_expiration_days", "allow_mentoring_requests", "allow_mentoring_requests_message", "allow_mentee_withdraw_mentor_request", "allow_preference_mentor_request", "mentor_offer_needs_acceptance", "allow_user_to_send_message_outside_mentoring_area", "prevent_past_mentor_matching", "allow_non_match_connection", "zero_match_score_message", "prevent_manager_matching", "manager_matching_level", "default_max_connections_limit", "connection_limit_permission", "max_connections_for_mentee", "allow_end_users_to_see_match_scores", "allow_track_admins_to_access_all_users"]
    import_setting_attributes_into_object(matching_settings_program_attributes, solution_pack.program, settings_hash["Program"][0])

    if solution_pack.program.calendar_enabled?
      self.solution_pack.program.create_calendar_setting if self.solution_pack.program.calendar_setting.nil?
      self.solution_pack.program.reload

      matching_settings_calendar_setting_attributes = ["allow_mentor_to_configure_availability_slots", "allow_mentor_to_describe_meeting_preference", "slot_time_in_minutes", "allow_create_meeting_for_mentor", "advance_booking_time", "max_meetings_for_mentee", "max_pending_meeting_requests_for_mentee"]
      import_setting_attributes_into_object(matching_settings_calendar_setting_attributes, solution_pack.program.calendar_setting, settings_hash["CalendarSetting"][0])

      matching_settings_program_attributes = ["needs_meeting_request_reminder", "meeting_request_reminder_duration", "meeting_request_auto_expiration_days"]
      import_setting_attributes_into_object(matching_settings_program_attributes, solution_pack.program, settings_hash["Program"][0])
    end
  end

  def import_mentoring_connection_settings(settings_hash)
    # attribute_id as key and it's associated model name as value of the hash
    attributes_to_be_processed_hash = {"auto_terminate_reason_id" => "GroupClosureReason"}
    mentoring_connection_settings_program_attributes = ["allow_one_to_many_mentoring", "allow_users_to_leave_connection", "allow_to_change_connection_expiry_date", "inactivity_tracking_period", "feedback_survey_id", "auto_terminate_reason_id", "admin_access_to_mentoring_area"]
    import_setting_attributes_into_object(mentoring_connection_settings_program_attributes, solution_pack.program, settings_hash["Program"][0], attributes_to_be_processed_hash)

    if solution_pack.program.calendar_enabled?
      self.solution_pack.program.create_calendar_setting if self.solution_pack.program.calendar_setting.nil?
      self.solution_pack.program.reload

      mentoring_connection_settings_calendar_setting_attributes = ["feedback_survey_delay_not_time_bound"]
      import_setting_attributes_into_object(mentoring_connection_settings_calendar_setting_attributes, solution_pack.program.calendar_setting, settings_hash["CalendarSetting"][0])
    end
    #group closure reasons imported through associated importers of settings importer
  end

  def import_features
    features_path = self.solution_pack.base_directory_path + FolderName + "features.csv"
    exported_feature_rows = CSV.read(features_path)
    features_for_enabling = exported_feature_rows[0]
    features_for_disabling = exported_feature_rows[1]

    organization_level_features = FeatureName.organization_level_features
    features_for_enabling -= organization_level_features

    handle_org_or_prog_level_feature_update(solution_pack.program.organization, solution_pack.program, features_for_enabling, features_for_disabling, solution_pack.program.organization.standalone?)
  end

  def handle_org_or_prog_level_feature_update(organization, program, features_for_enabling, features_for_disabling, org_level)
    if org_level
      program_level_features = FeatureName.program_level_only
      features_for_enabling_in_program = program_level_features & features_for_enabling
      features_for_disabling_in_program = program_level_features & features_for_disabling
      enable_or_disable_features(program, features_for_enabling_in_program, true)
      enable_or_disable_features(program, features_for_disabling_in_program, false)
      features_for_enabling -= features_for_enabling_in_program
      features_for_disabling -= features_for_disabling_in_program
      enable_or_disable_features(organization, features_for_enabling, true)
      enable_or_disable_features(organization, features_for_disabling, false)
    else
      enable_or_disable_features(program, features_for_enabling, true)
      enable_or_disable_features(program, features_for_disabling, false)
    end
  end

  def enable_or_disable_features(program_or_org, features, enable)
    features.each do |feature|
      unless Feature.find_by(name: feature).nil?
      program_or_org.enable_feature(feature, enable)
      end
    end
  end

  private

  def populate_settings_hash(settings_hash)
    associated_setting_exporters.each do |setting_exporter|
      settings_hash[setting_exporter.constantize::AssociatedModel] = {}
      settings_path = self.solution_pack.base_directory_path + FolderName + setting_exporter.constantize::FileName + '.csv'
      setting_rows_with_column_names = CSV.read(settings_path)
      column_names = setting_rows_with_column_names[0]
      setting_rows = setting_rows_with_column_names[1..-1]
      setting_rows.each_with_index do |setting_row, row_index|
        settings_hash[setting_exporter.constantize::AssociatedModel][row_index] = {}
        column_names.each_with_index do |column_name, column_index|
          settings_hash[setting_exporter.constantize::AssociatedModel][row_index][column_name.to_sym] = setting_row[column_index]
        end
      end
    end
  end

  def import_setting_attributes_into_object(setting_attributes, object, settings_sub_hash, attributes_to_be_processed_hash = {})
    setting_attributes.each do |attribute|
      if attributes_to_be_processed_hash[attribute].present?
        object.send("#{attribute}=", process_settings_attribute(attributes_to_be_processed_hash[attribute], settings_sub_hash[attribute.to_sym]))
      else
        object.send("#{attribute}=", settings_sub_hash[attribute.to_sym])
      end
    end
    object.save!
  end

  def associated_setting_exporters
    associated_importers
  end

  def process_settings_attribute(associated_klass_name, id_to_be_processed)
    return if id_to_be_processed.blank?
    self.solution_pack.id_mappings[associated_klass_name][id_to_be_processed.to_i]
  end
end