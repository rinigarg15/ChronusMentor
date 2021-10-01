class ProgramSettingsExporter < SettingsExporter

  SettingAttributes = ["published", "show_multiple_role_option", "engagement_type", "allow_mentoring_mode_change", "mentor_request_style", "max_pending_requests_for_mentee", "needs_mentoring_request_reminder", "mentoring_request_reminder_duration", "mentor_request_expiration_days", "allow_mentoring_requests", "allow_mentoring_requests_message", "allow_mentee_withdraw_mentor_request", "allow_preference_mentor_request", "mentor_offer_needs_acceptance", "allow_user_to_send_message_outside_mentoring_area", "prevent_past_mentor_matching", "allow_non_match_connection", "zero_match_score_message", "prevent_manager_matching", "manager_matching_level", "default_max_connections_limit", "max_connections_for_mentee", "needs_meeting_request_reminder", "meeting_request_reminder_duration", "meeting_request_auto_expiration_days", "allow_one_to_many_mentoring", "allow_users_to_leave_connection", "allow_to_change_connection_expiry_date", "inactivity_tracking_period", "auto_terminate_reason_id", "admin_access_to_mentoring_area", "admin_access_to_mentoring_area", "connection_limit_permission", "allow_end_users_to_see_match_scores", "allow_track_admins_to_access_all_users"]
  AttrAccessors = ["feedback_survey_id"]

  AssociatedExporters = []
  FileName = 'program_settings'
  AssociatedModel = "Program"

  def initialize(program, parent_exporter)
    self.objs = [program]
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end