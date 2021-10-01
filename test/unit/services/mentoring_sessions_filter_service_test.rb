require_relative "./../../test_helper.rb"

class MentoringSessionsFilterServiceTest < ActiveSupport::TestCase

  def test_get_attendee_id
    meeting_ids = Meeting.pluck(:id)

    msfs = MentoringSessionsFilterService.new(programs(:albers), {mentoring_session: {attendee: "Some one who doesnt exist <2foh2gf34e@chronus.com>"}})
    assert_equal 0, msfs.get_attendee_id

    attendee = members(:f_mentor)
    assert attendee.meetings.present?
    msfs = MentoringSessionsFilterService.new(programs(:albers), {mentoring_session: {attendee: attendee.name_with_email}})
    assert_equal attendee.id, msfs.get_attendee_id
  end

  def test_get_filtered_meetings
    program = programs(:albers)

    assert_equal_unordered members(:f_mentor).meetings.group_meetings, MentoringSessionsFilterService.new(program, {mentoring_session: {attendee: members(:f_mentor).name_with_email}}).get_filtered_meetings

    meeting_ids = Meeting.pluck(:id)
    Meeting.stubs(:get_meeting_ids_by_conditions).with({not_cancelled: true, program_id: program.id, active: true, "attendees.id": 0}).returns(meeting_ids)

    assert_equal_unordered Meeting.group_meetings, MentoringSessionsFilterService.new(program, {mentoring_session: {attendee: "somename"}}).get_filtered_meetings
  end

  def test_get_meetings
    program = programs(:albers)

    meeting_ids = Meeting.pluck(:id)
    assert_equal_unordered Meeting.group_meetings, MentoringSessionsFilterService.new(program, {}).get_meetings(meeting_ids)

    meeting_ids = program.meetings.pluck(:id)
    assert_equal_unordered program.meetings.group_meetings, MentoringSessionsFilterService.new(program, {}).get_meetings(meeting_ids)
  end

  def test_get_number_of_filters
    program = programs(:albers)
    assert_equal 0, MentoringSessionsFilterService.new(program, {}).get_number_of_filters
    assert_equal 0, MentoringSessionsFilterService.new(program, {mentoring_session: {}}).get_number_of_filters
    assert_equal 1, MentoringSessionsFilterService.new(program, {mentoring_session: {attendee: 1}}).get_number_of_filters
  end
end