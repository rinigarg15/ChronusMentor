require_relative './../test_helper.rb'

class GroupCheckinTest < ActiveSupport::TestCase

  def test_association
    task = create_mentoring_model_task
    assert_equal [], task.checkins

    checkin1 = create_task_checkin(task)
    sleep 2
    checkin2 = create_task_checkin(task)
    assert_equal [checkin1, checkin2], task.checkins
  end

  def test_field_validation
    task = create_mentoring_model_task
    assert_equal [], task.checkins

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :duration, "Check-in duration must be added in multiple of 15 minutes" do
      checkin = create_task_checkin(task, hours: 0, minutes: -20)
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :duration, "Check-in duration must be added in multiple of 15 minutes" do
      checkin = create_task_checkin(task, hours: 0, minutes: 20)
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :title do
      checkin = create_task_checkin(task)
      checkin.title = nil;
      checkin.save!
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :date do
      checkin = create_task_checkin(task)
      checkin.date = nil;
      checkin.save!
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :user do
      checkin = create_task_checkin(task)
      checkin.user = nil;
      checkin.save!
    end

    assert_nothing_raised do
      checkin = create_task_checkin(task)
      checkin.comment = nil;
      checkin.save!
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :group_id do
      checkin = create_task_checkin(task)
      checkin.group_id = nil;
      checkin.save!
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :checkin_ref_obj_id do
      checkin = create_task_checkin(task)
      checkin.checkin_ref_obj_id = nil;
      checkin.save!
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :checkin_ref_obj_type do
      checkin = create_task_checkin(task)
      checkin.checkin_ref_obj_type = nil;
      checkin.save!
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :program_id do
      checkin = create_task_checkin(task)
      checkin.program_id = nil;
      checkin.save!
    end
  end

  def test_accessors
    task = create_mentoring_model_task
    checkin = create_task_checkin(task, :duration => 60)
    assert_equal checkin.hours, 1
    assert_equal checkin.minutes, 0
    checkin = create_task_checkin(task, :duration => 75)
    assert_equal checkin.hours, 1
    assert_equal checkin.minutes, 15
    checkin = create_task_checkin(task, :duration => 15)
    assert_equal checkin.hours, 0
    assert_equal checkin.minutes, 15
  end

  def test_create_meeting_checkin_obj
    meeting = Meeting.first
    member_meeting = meeting.member_meetings.first
    member = member_meeting.member
    program = meeting.program
    user = member.user_in_program(program.id)
    current_occurrence_time = meeting.occurrences.first
    checkin_count = GroupCheckin.count

    GroupCheckin.create_meeting_checkin_obj(user, member_meeting, current_occurrence_time, program, meeting)
    assert_equal GroupCheckin.count, checkin_count + 1
    checkin = GroupCheckin.last

    assert_equal checkin.title, meeting.topic , "creating checkins for meetings with non nil comments"
    assert_equal checkin.checkin_ref_obj_type, MemberMeeting.name
    assert_equal checkin.checkin_ref_obj_id, member_meeting.id
    assert_equal checkin.duration, meeting.schedule.duration / 60
    assert_equal checkin.date, current_occurrence_time
    assert_equal checkin.user_id, user.id
    assert_equal checkin.program_id, program.id
  end

  def test_can_create_checkin
    meeting = Meeting.first
    program = meeting.program
    response = nil

    mentor_member_meeting = meeting.member_meetings.first
    mentor_member = mentor_member_meeting.member
    mentor_user = mentor_member.user_in_program(program.id)

    mentee_member_meeting = meeting.member_meetings[1]
    mentee_member = mentee_member_meeting.member
    mentee_user = mentee_member.user_in_program(program.id)

    current_occurrence_time = meeting.occurrences.first

    #return false if the user is not a mentor
    assert_equal false, GroupCheckin.can_create_checkin?(mentee_user, mentee_member_meeting, current_occurrence_time, response), "created meeting checkin for mentee"

    #return true if a user is a mentor and no meeting occurrence is found for the given time
    assert_equal true, GroupCheckin.can_create_checkin?(mentor_user, mentor_member_meeting, current_occurrence_time + 30.minutes, response), "couldnt create meeting checkin for mentor"

    #return false if a response is rejected
    response = MemberMeetingResponse.create!(meeting_occurrence_time: current_occurrence_time, member_meeting_id: mentor_member_meeting.id, attending: MemberMeeting::ATTENDING::NO)

    assert_equal false, GroupCheckin.can_create_checkin?(mentor_user, mentor_member_meeting, current_occurrence_time, response), "could create meeting checkin even when the response is rejected"

    #should not create the same checkin twice
    GroupCheckin.create_meeting_checkin_obj(mentor_user, mentor_member_meeting, current_occurrence_time, program, meeting)
    assert_equal false, GroupCheckin.can_create_checkin?(mentor_user, mentor_member_meeting, current_occurrence_time, response), "made the same checkin twice"
  end

  def test_meetings_checkin_creation
    meeting = Meeting.first
    program = programs(:albers)
    user = users(:f_mentor)
    meeting.start_time = meeting.start_time - 10.days
    meeting.end_time = meeting.end_time - 10.days
    meeting.schedule.start_time = meeting.schedule.start_time - 10.days
    meeting.schedule.end_time = meeting.schedule.end_time - 10.days
    meeting.save!
    occurrence = meeting.occurrences.first
    assert_equal 14, GroupCheckin.count
    program.enable_feature("contract_management")
    Timecop.freeze(occurrence.start_time + 90.minutes)
    GroupCheckin.meetings_checkin_creation
    assert_equal 15, GroupCheckin.count, "Checkins not made for all meeting in time window of the time"
    checkin = GroupCheckin.last
    assert_equal checkin.title, meeting.topic, "Checkin creates comment for meetings"
    assert_equal checkin.checkin_ref_obj_type, "MemberMeeting", "Checkin does not have right checkin ref obj type"
    assert_equal checkin.checkin_ref_obj_id, 1, "Checkin not made for the first member_meeting"
    assert_equal checkin.duration, meeting.schedule.duration / 60, "Checkin does not have right meeting duration"
    assert_equal checkin.date, occurrence, "Checkin not made for the first occurence of the meeting"
    assert_nil checkin.comment, "checkin not made with right title"
    assert_equal checkin.user_id, user.id
    assert_equal checkin.program_id, program.id
    Timecop.return
  end

  def test_meetings_checkin_creation_with_deleted_user
    meeting = Meeting.first
    program = programs(:albers)
    user = users(:f_mentor)
    meeting.start_time = meeting.start_time - 10.days
    meeting.end_time = meeting.end_time - 10.days
    meeting.schedule.start_time = meeting.schedule.start_time - 10.days
    meeting.schedule.end_time = meeting.schedule.end_time - 10.days
    meeting.save!
    occurrence = meeting.occurrences.first
    user.destroy
    count = GroupCheckin.count
    program.enable_feature("contract_management")
    Timecop.freeze(occurrence.start_time + 90.minutes)
    GroupCheckin.meetings_checkin_creation
    assert_equal count, GroupCheckin.count
    Timecop.return
  end

  def test_meetings_checkin_creation_with_past_meeting
    program = programs(:albers)
    program.enable_feature("contract_management")
    meeting  = program.meetings.group_meetings.slot_availability_meetings.first
    past_time = 10.days.ago
    meeting.start_time = past_time
    meeting.end_time = past_time + 1.hour
    meeting.created_at = Time.now
    meeting.save!
    mentor_user = meeting.group.mentors.first
    mentor_user.group_checkins.destroy_all
    GroupCheckin.meetings_checkin_creation
    member_meeting = meeting.member_meetings.find{ |mm| mm.member_id == mentor_user.member_id }
    assert mentor_user.group_checkins.where(checkin_ref_obj_id: member_meeting.id, checkin_ref_obj_type: MemberMeeting.name).present?
  end
end