class CalendarSettingExporter < SettingsExporter

  SettingAttributes = ["allow_mentor_to_configure_availability_slots", "allow_mentor_to_describe_meeting_preference", "slot_time_in_minutes", "allow_create_meeting_for_mentor", "advance_booking_time", "max_meetings_for_mentee", "max_pending_meeting_requests_for_mentee", "feedback_survey_delay_not_time_bound"]

  AssociatedExporters = []
  FileName = "calendar_setting"
  AssociatedModel = "CalendarSetting"

  def initialize(program, parent_exporter)
    self.objs = Array(program.calendar_setting)
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end