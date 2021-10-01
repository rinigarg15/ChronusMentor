class MeetingCalendarReportXlsDataService
  include MeetingsHelper

  attr_accessor :meetings, :program, :meeting_feedback_answers, :wob_member, :locale

  def initialize(locale, wob_member, meetings, program, meeting_feedback_answers)
    self.program = program
    self.meetings = meetings
    self.locale = locale
    self.meeting_feedback_answers = meeting_feedback_answers
    self.wob_member = wob_member
  end

  def build_xls_data_for_meeting_report
    GlobalizationUtils.run_in_locale(self.locale) do
      @meeting_term = self.program.term_for(CustomizedTerm::TermType::MEETING_TERM).term
      book = Spreadsheet::Workbook.new
      header_format = Spreadsheet::Format.new(:size => 10, :weight => :bold, :horizontal_align => :merge)

      populate_aggregate_data(book, header_format)

      data = StringIO.new ''
      book.write data
      data.string
    end 
  end

  private

  def populate_aggregate_data(book, header_format)
    mentor_term = self.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term
    mentee_term = self.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term
    sheet = book.create_worksheet
    sheet.name = "feature.reports.header.meeting_calendar_report_v1".translate(:Meeting => @meeting_term)
    # 9 is the number of columns
    9.times do |i|
      sheet.row(0).set_format(i, header_format)
    end

    sheet.row(0).push "feature.reports.label.meeting_title".translate(:Meeting => @meeting_term), mentor_term, "feature.meetings.header.rolename_email_id".translate(role_name: mentor_term), mentee_term, "feature.meetings.header.rolename_email_id".translate(role_name: mentee_term), "feature.meetings.form.start_time".translate, "feature.mentoring_model.label.duration".translate, "feature.meetings.content.Location".translate, "feature.meetings.header.state".translate, "feature.mentoring_slot.report_headers.mentor_survey_completed".translate(:Mentor => mentor_term), "feature.mentoring_slot.report_headers.mentee_survey_completed".translate(:Mentee => mentee_term)
    push_meeting_report_data(sheet)
  end

  def push_meeting_report_data(sheet)
    row_number = 1
    @meetings.each do |meeting|
      add_row_data_to_sheet(sheet, row_number, meeting)
      row_number += 1
    end
  end

  def add_row_data_to_sheet(sheet, row_number, meeting)
    mentor = meeting.get_member_for_role(RoleConstants::MENTOR_NAME)
    mentee = meeting.get_member_for_role(RoleConstants::STUDENT_NAME)
    sheet.row(row_number).push meeting.topic
    sheet.row(row_number).push mentor.name
    sheet.row(row_number).push mentor.email
    sheet.row(row_number).push mentee.name
    sheet.row(row_number).push mentee.email
    sheet.row(row_number).push get_meeting_start_time_for_export(meeting)
    sheet.row(row_number).push get_meeting_duration_for_export(meeting)
    sheet.row(row_number).push get_meeting_location_for_export(meeting)
    sheet.row(row_number).push get_meeting_state(meeting)
    sheet.row(row_number).push member_meeting_feedback_present?(meeting, mentor, row_number-1)
    sheet.row(row_number).push member_meeting_feedback_present?(meeting, mentee, row_number-1)
  end

  def get_meeting_location_for_export(meeting)
    return meeting.location.blank? ? 'feature.meetings.content.no_location'.translate : meeting.location
  end

  def get_meeting_start_time_for_export(meeting)
    current_occurrence_time = meeting.first_occurrence
    return (meeting.calendar_time_available? ? DateTime.localize(current_occurrence_time.in_time_zone(self.wob_member.get_valid_time_zone), format: :full_display_no_day_short_month) : 'feature.meetings.content.no_meeting_time_set'.translate(:meeting => @meeting_term))
  end

  def get_meeting_duration_for_export(meeting)
    (meeting.calendar_time_available? ? meeting.formatted_duration : 'feature.meetings.content.no_meeting_time_set'.translate(:meeting => @meeting_term))
  end

  def member_meeting_feedback_present?(meeting, member, index)
    feedback_of_meeting = self.meeting_feedback_answers[index]
    user = member.users.find{|user| user.program_id == self.program.id} if member.present?
    user_feedback = feedback_of_meeting.include?(user.try(:id))
    return (user_feedback.present? ? 'display_string.Yes'.translate : 'display_string.No'.translate)
  end
end