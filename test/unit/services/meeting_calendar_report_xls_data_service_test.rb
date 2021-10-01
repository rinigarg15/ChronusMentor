require_relative './../../test_helper.rb'

class MeetingCalendarReportXlsDataServiceTest < ActiveSupport::TestCase
  def test_build_xls_data_for_meeting_report
    program = programs(:albers)
    meetings = program.meetings.where.not(mentee_id: nil).first(1)
    meeting = meetings.first
    mentor = meeting.get_member_for_role(RoleConstants::MENTOR_NAME)
    mentee = meeting.get_member_for_role(RoleConstants::STUDENT_NAME)


    book = Spreadsheet::Workbook.new
    feedback_answers = meetings.map { |meeting| meeting.survey_answers.collect(&:user_id) }
    data_service = MeetingCalendarReportXlsDataService.new("en", members(:f_admin), meetings, program, feedback_answers)
    data_service.instance_variable_set(:@meeting_term, "Meeting")
    data_service.send(:populate_aggregate_data, book, {})
    rows = book.worksheets.first.rows.map(&:to_a)
    headers = ["Meeting Title", "Mentor", "Mentor Email", "Student", "Student Email", "Start Time", "Duration", "Location", "Status", "Mentor Survey Completed", "Student Survey Completed"]
    assert_equal headers, rows[0]
    assert_equal [meeting.topic, mentor.name, mentor.email, mentee.name, mentee.email], rows[1][0..4]
  end
end