require_relative './../../test_helper.rb'

class MeetingUtilsTest < ActiveSupport::TestCase
  include MeetingUtils

  def test_construct_meeting
    program = programs(:albers)
    self.expects(:build_from_params).with("params", "action", program: program)
    self.expects(:set_meeting_attributes)
    meeting = construct_meeting("params", "action", program: program)
    assert_equal program, meeting.program

    meeting_attributes = { topic: "topic", description: "description", attendee_ids: "attendee_ids" }
    options = { program: program, is_dual_request_mode: true, owner_member: "member", group: "group", student_name: "student_name" }
    self.expects(:build_from_params).with("params", "action", options.merge(meeting_params: meeting_attributes))
    self.expects(:set_meeting_attributes)
    meeting = construct_meeting("params", "action", meeting_attributes.merge(options))
    assert_equal program, meeting.program
  end

  def test_build_from_params
    program = programs(:albers)
    meeting = meetings(:f_mentor_mkr_student)
    options = {meeting_date_changed: "meeting_date_changed", group: "group", meeting: meeting, owner_member: "owner", new_action: true, is_non_time_meeting: true, program: program}
    self.expects(:get_meeting_params).with("action_name").returns({})
    self.expects(:merge_date).with(meeting, {}, true, "meeting_date_changed")
    self.expects(:merge_repeats_end_date).with({})
    self.expects(:merge_attendee_ids)
    self.expects(:merge_meeting_time_and_duration).with("params", {}, program, true)
    meeting_params = build_from_params("params", "action_name", options)
    assert_nil meeting_params[:ics_sequence]

    options = {new_action: false, is_non_time_meeting: false, program: program, meeting: meeting, is_dual_request_mode: true, meeting_params: { title: "title"}}
    self.expects(:get_meeting_params).never
    self.expects(:merge_date).never
    self.expects(:merge_repeats_end_date).never
    self.expects(:merge_attendee_ids).never
    self.expects(:merge_meeting_time_and_duration).with("params", {title: "title"}, program, false)
    Meeting.any_instance.expects(:ics_sequence).returns(1)
    meeting_params = build_from_params("params", "action_name", options)
    assert_equal 2, meeting_params[:ics_sequence]
  end

  def test_set_meeting_attributes
    program = programs(:albers)
    meeting = program.meetings.new
    self.expects(:set_meeting_memberships).with(meeting, "is_group_meeting")
    set_meeting_attributes(meeting, members(:f_mentor), "is_group_meeting", "is_mentor_created_meeting")

    assert_equal members(:f_mentor), meeting.owner
    assert_equal members(:f_mentor).get_valid_time_zone, meeting.time_zone
    assert_equal "is_mentor_created_meeting", meeting.mentor_created_meeting
  end

  def test_set_meeting_memberships
    program = programs(:albers)
    meeting = program.meetings.new
    set_meeting_memberships(meeting, true)
    assert_nil meeting.mentee_id

    Meeting.any_instance.expects(:owner).returns(members(:f_student))
    Meeting.any_instance.expects(:guests).returns([members(:f_mentor)])
    Meeting.any_instance.expects(:mentor_created_meeting).returns(false)
    set_meeting_memberships(meeting, false)
    assert_equal members(:f_student).id, meeting.mentee_id
    assert_equal users(:f_student), meeting.requesting_student
    assert_equal users(:f_mentor), meeting.requesting_mentor

    Meeting.any_instance.expects(:owner).returns(members(:f_mentor))
    Meeting.any_instance.expects(:guests).returns([members(:f_student)])
    Meeting.any_instance.expects(:mentor_created_meeting).returns(true)
    set_meeting_memberships(meeting, false)
    assert_equal members(:f_student).id, meeting.mentee_id
    assert_equal users(:f_student), meeting.requesting_student
    assert_equal users(:f_mentor), meeting.requesting_mentor
  end

  def test_merge_date
    meeting = meetings(:f_mentor_mkr_student)
    meeting_params = { date: "Aug 08, 2100" }
    merge_date(meeting, meeting_params, true)
    assert_equal "Aug 08, 2100", meeting_params[:date]

    meeting_params = {}
    merge_date(meeting, meeting_params, true)
    assert_nil meeting_params[:date]

    meeting_params = {}
    merge_date(meeting, meeting_params, false, true)
    assert_nil meeting_params[:date]

    meeting_params = {}
    merge_date(meeting, meeting_params, false)
    assert_equal meeting.occurrences.first.start_time.strftime('time.formats.full_display_no_time'.translate), meeting_params[:date]
  end

  def test_merge_repeats_end_date
    meeting_params = {}
    merge_repeats_end_date(meeting_params)
    assert_equal({}, meeting_params)

    end_date_str = "August 08, 2018 08:30 pm"
    meeting_params = { repeats_end_date: end_date_str, start_time_of_day: "8.30 am" }
    merge_repeats_end_date(meeting_params)
    assert_equal({ repeats_end_date: Time.zone.parse(end_date_str), start_time_of_day: "8.30 am" }, meeting_params)
  end

  def test_merge_attendee_ids_from_params
    params = {}
    meeting_params = {}
    merge_attendee_ids_from_params(params, meeting_params)
    assert_equal({}, meeting_params)

    params = { meeting: { attendee_ids: "1,2,,4" } }
    meeting_params = {}
    merge_attendee_ids_from_params(params, meeting_params)
    assert_equal(["1", "2", "", "4"], meeting_params[:attendee_ids])
  end

  def test_get_meeting_group
    meeting = meetings(:f_mentor_mkr_student)
    assert_equal "group", get_meeting_group("group", meeting, true)
    assert_equal "group", get_meeting_group("group", meeting, false)
    assert_equal meeting.group, get_meeting_group(nil, meeting, false)
  end

  def test_merge_attendee_ids_from_group
    student, mentor = members(:mkr_student, :f_mentor)
    meeting = meetings(:f_mentor_mkr_student)
    group = groups(:mygroup)
    Meeting.any_instance.stubs(:attendee_ids).returns([mentor])

    meeting_params = {}
    merge_attendee_ids_from_group(group, meeting, meeting_params, student, true)
    assert_equal_unordered [mentor, student].collect(&:id), meeting_params[:attendee_ids]

    meeting_params = {}
    merge_attendee_ids_from_group(group, meeting, meeting_params, student, false)
    assert_equal [mentor], meeting_params[:attendee_ids]

    meeting_params = {}
    self.stubs(:get_meeting_group).returns(nil)
    merge_attendee_ids_from_group(group, meeting, meeting_params, student, true)
    assert_equal [student.id], meeting_params[:attendee_ids]

    meeting_params = {}
    merge_attendee_ids_from_group(group, meeting, meeting_params, student, false)
    assert_equal [mentor], meeting_params[:attendee_ids]
  end

  def test_merge_meeting_time_and_duration
    program = programs(:albers)
    time_now = DateTime.current

    Timecop.freeze(time_now) do
      params = {}
      meeting_params = {}
      merge_meeting_time_and_duration(params, meeting_params, program, true)
      assert_false meeting_params[:calendar_time_available]
      assert_equal (time_now + 15.days).to_time.utc.round_to_next(timezone: 'utc').to_datetime, meeting_params[:start_time].to_datetime
      assert_equal 30.minutes, meeting_params[:duration]
      assert_equal (meeting_params[:start_time] + 30.minutes).to_datetime, meeting_params[:end_time].to_datetime

      program.calendar_setting.update_attributes!(slot_time_in_minutes: 0)
      merge_meeting_time_and_duration(params, meeting_params, program, true)
      assert_equal 1.hour, meeting_params[:duration]

      ActionView::Base.any_instance.expects(:is_next_day?).with("slot_start_time", "slot_end_time", "start_time_of_day", "end_time_of_day", program.get_calendar_slot_time).returns([false, "start_time_next_day", "end_time_next_day"])
      MentoringSlot.expects(:fetch_start_and_end_time).with(time_now.to_date, "start_time_of_day", "end_time_of_day", "start_time_next_day", "end_time_next_day").returns([time_now, time_now + 30.minutes])
      params = { meeting: { slot_start_time: "slot_start_time", slot_end_time: "slot_end_time"} }
      meeting_params = { date: time_now.to_date, start_time_of_day: "start_time_of_day", end_time_of_day: "end_time_of_day" }
      merge_meeting_time_and_duration(params, meeting_params, program, false)
      assert_nil meeting_params[:calendar_time_available]
      assert_equal time_now.to_datetime, meeting_params[:start_time].to_datetime
      assert_equal (time_now + 30.minutes).to_datetime, meeting_params[:end_time].to_datetime
      assert_equal meeting_params[:end_time] - meeting_params[:start_time], meeting_params[:duration]
    end
  end

  private

  def get_en_datetime_str(datetime_str)
    datetime_str
  end

  def view_context
    ActionView::Base.new
  end
end