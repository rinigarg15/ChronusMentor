require_relative './../test_helper.rb'

class MeetingTest < ActiveSupport::TestCase

  def setup
    super
    programs(:org_primary).enable_feature(FeatureName::CALENDAR_SYNC, false)
    chronus_s3_utils_stub
  end

  def test_validations
    m = Meeting.new
    assert_false m.valid?
    assert_equal ["can't be blank"], m.errors[:end_time]
    assert_equal ["can't be blank"], m.errors[:start_time]
    assert_equal ["can't be blank"], m.errors[:topic]
    assert_equal [], m.errors[:description]
    assert_equal ["can't be blank"], m.errors[:mentee_id]

    m = meetings(:f_mentor_mkr_student_daily_meeting)
    assert m.members.include?(members(:f_mentor))
    assert m.members.include?(members(:mkr_student))
    assert_nil m.mentee_id
    m.update_attribute(:group_id, nil)
    m.mentee_id = members(:f_student).id
    assert_false m.valid?
    assert_equal ["Student should be part of the meeting"], m.errors[:meeting]

    m.update_attributes(:mentee_id => members(:mkr_student).id)

    users(:mkr_student).destroy
    m.reload.save
    assert m.valid?
    assert_equal [], m.errors[:meeting]

    members(:mkr_student).destroy
    m.reload.save
    assert m.valid?
    assert_equal [], m.errors[:meeting]
  end

  def test_survey_answer_association
    time = Time.now.change(:usec => 0)
    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :members => [members(:f_admin), members(:mkr_student)],
                :owner_id => members(:mkr_student).id, :program_id => programs(:albers).id, :repeats_end_date => time + 2.days, :start_time => time, :end_time => time + 5.hours)
    meeting.complete!
    member_meeting = meeting.member_meetings.find_by(member_id: members(:mkr_student))
    survey = programs(:albers).get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME)
    question_id = survey.survey_questions.pluck(:id)
    assert_equal [], meeting.survey_answers
    survey.update_user_answers({question_id[0] => "Extremely satisfying", question_id[1] => "Great use of time"}, {user_id: users(:mkr_student).id, :meeting_occurrence_time => meeting.occurrences.first.start_time, member_meeting_id: member_meeting.id})
    assert_equal SurveyAnswer.last(2), meeting.reload.survey_answers
    assert_equal 6, SurveyAnswer.count
  end

  def test_update_meeting_time_for_recurring_single_meeting
    time = Time.current.change(:usec => 0)
    duration = 30.minutes
    meeting = create_meeting(recurrent: true, repeat_every: 1, schedule_rule: Meeting::Repeats::MONTHLY, repeats_end_date: time + 5.days, start_time: time, end_time: time + duration)
    assert_equal meeting.occurrences.count, 1
    meeting.update_meeting_time(time + 2.day, duration, {updated_by_member: meeting.owner, meeting_time_zone: "America/Los_Angeles"})
    assert_equal meeting.schedule.last, meeting.start_time
    assert_equal meeting.recurrent, false
  end

  def test_belongs_to_meeting_request
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    # meetings for group
    assert_nil meeting.meeting_request

    meeting = create_meeting(force_non_time_meeting: true)
    meeting_request = meeting.meeting_request
    assert_equal MeetingRequest.last, meeting_request
  end

  def test_get_action_links_for_meeting_description_recurrent
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    user = users(:f_mentor)
    meeting.stubs(:can_be_edited_by_member?).with(user.member).returns(true)
    desc = meeting.get_action_links_for_recurrent_meeting_description(user)
    assert_match "To reschedule/ view your meetings,", desc
    assert_match "http://#{meeting.program.url}/meetings?group_id=#{meeting.group.id}&src=mamlc", desc
    user = users(:f_mentor)
    meeting.stubs(:can_be_edited_by_member?).with(user.member).returns(false)
    desc = meeting.get_action_links_for_recurrent_meeting_description(user)
    assert_no_match "To reschedule/ view your meetings,", desc
    assert_no_match "http://#{meeting.program.url}/meetings?group_id=#{meeting.group.id}&src=mamlc", desc

    meeting.stubs(:can_be_edited_by_member?).with(nil).returns(false)
    desc = meeting.get_action_links_for_recurrent_meeting_description
    assert_no_match "To reschedule/ view your meetings,", desc
    assert_no_match "http://#{meeting.program.url}/meetings?group_id=#{meeting.group.id}&src=mamlc", desc
  end

  def test_mark_meeting_members_attending
    meeting = meetings(:f_mentor_mkr_student)

    meeting.member_meetings.update_all(attending: MemberMeeting::ATTENDING::NO)

    meeting.reload
    assert_equal [MemberMeeting::ATTENDING::NO], meeting.member_meetings.pluck(:attending).uniq

    meeting.mark_meeting_members_attending

    meeting.reload
    assert_equal [MemberMeeting::ATTENDING::YES], meeting.member_meetings.pluck(:attending).uniq
  end

  def test_check_start_time_should_be_lesser
    m = create_meeting
    m.update_attributes(:start_time => 10.minutes.ago, :end_time => 20.minutes.ago)
    assert_false m.valid?
    assert_equal ["start time should be before end time"], m.errors[:meeting]
  end

  def test_check_members_can_be_unconnected
    m = create_meeting(:group_id => groups(:group_2).id, :owner => groups(:group_2).members.first.member)
    assert m.valid?
    assert_equal [], m.errors[:meeting]
  end

  def test_get_millisecond
    time = Time.new(2018, 5, 15)
    assert_equal (time.to_f * 1000).to_i, Meeting.get_millisecond(time)
  end

  def test_owned_by
    m = meetings(:f_mentor_mkr_student)
    assert m.owned_by?(m.owner)
  end

  def test_completed_scope
    g1 = groups(:mygroup)
    g2 = groups(:group_2)
    m1 = meetings(:f_mentor_mkr_student)
    m2 = meetings(:student_2_not_req_mentor)
    m3 = meetings(:f_mentor_mkr_student_daily_meeting)
    m3.update_attribute(:state, Meeting::State::COMPLETED)
    assert_equal [m3, meetings(:completed_calendar_meeting)], Meeting.completed
    m2.update_attribute(:state, Meeting::State::COMPLETED)
    assert_equal_unordered [m2, m3, meetings(:completed_calendar_meeting)], Meeting.completed
    m3.update_attribute(:state, Meeting::State::CANCELLED)
    assert_equal [m2, meetings(:completed_calendar_meeting)], Meeting.completed
  end

  def test_cancelled_scope
    m2 = meetings(:student_2_not_req_mentor)
    m3 = meetings(:f_mentor_mkr_student_daily_meeting)
    m3.update_attribute(:state, Meeting::State::CANCELLED)
    assert_equal [m3, meetings(:cancelled_calendar_meeting)], Meeting.cancelled
    m2.update_attribute(:state, Meeting::State::CANCELLED)
    assert_equal_unordered [m2, m3, meetings(:cancelled_calendar_meeting)], Meeting.cancelled
    m3.update_attribute(:state, Meeting::State::COMPLETED)
    assert_equal [m2, meetings(:cancelled_calendar_meeting)], Meeting.cancelled
  end

  def test_mentee_created_meeting_scope
    g1 = groups(:mygroup)
    g2 = groups(:group_2)
    m1 = meetings(:f_mentor_mkr_student)
    m2 = meetings(:student_2_not_req_mentor)
    m3 = meetings(:f_mentor_mkr_student_daily_meeting)
    m3.update_attribute(:mentee_id, m3.owner_id)
    assert_equal_unordered [m3, meetings(:completed_calendar_meeting), meetings(:past_calendar_meeting), meetings(:cancelled_calendar_meeting)], Meeting.mentee_created_meeting
    m2.update_attribute(:mentee_id, m2.owner_id)
    assert_equal_unordered [m2, m3, meetings(:completed_calendar_meeting), meetings(:past_calendar_meeting), meetings(:cancelled_calendar_meeting)], Meeting.mentee_created_meeting
    m2.update_attribute(:mentee_id, m2.member_meetings.where.not(member_id: m2.mentee_id).first.member_id)
    assert_equal_unordered [m3, meetings(:completed_calendar_meeting), meetings(:past_calendar_meeting), meetings(:cancelled_calendar_meeting)], Meeting.mentee_created_meeting
  end

  def test_of_group_scope
    g1 = groups(:mygroup)
    g2 = groups(:group_2)
    m1 = meetings(:f_mentor_mkr_student)
    m2 = meetings(:student_2_not_req_mentor)
    m3 = meetings(:f_mentor_mkr_student_daily_meeting)
    assert_equal [m1, m3], Meeting.of_group(g1)
    assert_equal [m2], Meeting.of_group(g2)

    m2.group = g1
    m2.save!

    assert_equal [m1, m2, m3], Meeting.of_group(g1)
    assert_blank Meeting.of_group(g2)
  end

  def test_in_programs_scope
    m1 = meetings(:upcoming_psg_calendar_meeting)
    m2 = meetings(:f_mentor_mkr_student_daily_meeting)
    meetings = Meeting.in_programs([m1.program_id])
    assert meetings.include?(m1)
    assert_false meetings.include?(m2)
  end

  def test_get_ics_file_url
    assert S3Helper.respond_to?(:embed_timestamp)
    assert SecureRandom.respond_to?(:hex)
    assert S3Helper.respond_to?(:transfer)
    meeting = meetings(:f_mentor_mkr_student)
    assert meeting.respond_to?(:generate_ics_calendar)
    File.expects(:write).once.returns(true)
    S3Helper.expects(:embed_timestamp).once.returns("")
    S3Helper.expects(:transfer).once.returns("")
    meeting.get_ics_file_url(meetings(:f_mentor_mkr_student).participant_users.first)
  end

  def test_accepted_meetings_scope
    assert_equal Meeting.first(11), Meeting.accepted_meetings
    Meeting.all.collect(&:destroy)
    time = 2.days.from_now
    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    assert_equal [], Meeting.accepted_meetings
    meeting.meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    assert_equal [meeting], Meeting.accepted_meetings
  end

  def test_accepted_or_pending_meetings_scope
    Meeting.all.collect(&:destroy)
    time = 2.days.from_now

    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)

    assert meeting.meeting_request.active?
    assert_false meeting.calendar_time_available?
    assert_equal [], Meeting.accepted_or_pending_meetings

    meeting.update_attributes(calendar_time_available: true)
    assert meeting.calendar_time_available?
    assert_equal [meeting], Meeting.accepted_or_pending_meetings

    meeting.update_attributes(calendar_time_available: false)

    meeting.meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    assert_equal [meeting], Meeting.accepted_or_pending_meetings

    meeting.meeting_request.update_attributes(status: AbstractRequest::Status::REJECTED)
    assert_equal [], Meeting.accepted_or_pending_meetings

    meeting.meeting_request.destroy
    assert_equal [meeting], Meeting.accepted_or_pending_meetings
  end

  def test_group_meeting_and_calendar_meeting_scope
    g1 = groups(:mygroup)
    g2 = groups(:group_2)
    m1 = meetings(:f_mentor_mkr_student)
    m2 = meetings(:student_2_not_req_mentor)
    assert_equal 6, Meeting.group_meetings.size
    assert_false Meeting.non_group_meetings.empty?
    assert_equal 5, Meeting.non_group_meetings.size
  end

  def test_cancel
    meeting = meetings(:f_mentor_mkr_student)
    meeting.cancel!
    assert_equal meeting.state, Meeting::State::CANCELLED
  end

  def test_complete
    meeting = meetings(:f_mentor_mkr_student)
    meeting.complete!
    assert_equal meeting.state, Meeting::State::COMPLETED
  end

  def test_completed
    meeting = meetings(:f_mentor_mkr_student)
    assert_false  meeting.completed?
    meeting.complete!
    assert_equal true, meeting.completed?
  end

  def test_cancelled
    meeting = meetings(:f_mentor_mkr_student)
    assert_false  meeting.cancelled?
    meeting.cancel!
    assert_equal true, meeting.cancelled?
  end

  def test_involving_scope
    student = members(:mkr_student)
    mentor = members(:f_mentor)
    meeting = meetings(:f_mentor_mkr_student)
    daily_meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    other_student = members(:rahim)
    other_mentor = members(:robert)
    m2 = meetings(:upcoming_calendar_meeting)
    m3 = meetings(:past_calendar_meeting)
    m4 = meetings(:completed_calendar_meeting)
    m5 = meetings(:cancelled_calendar_meeting)

    assert_equal_unordered [meeting, daily_meeting, m2, m3, m4, m5], Meeting.involving(student, mentor)
    assert Meeting.involving(student, other_mentor).empty?
    assert Meeting.involving(mentor, other_student).empty?
  end

  def test_group_meeting
    meeting = meetings(:psg_mentor_psg_student)
    response  = meeting.group_meeting?
    assert_equal true, response
  end

  def test_can_display_owner
    group = groups(:multi_group)
    mentee = users(:psg_student3)
    time = 2.days.from_now
    meeting = create_meeting(
      start_time: time,
      end_time: time + 30.minutes,
      members: [ mentee.member, members(:psg_mentor1), members(:psg_mentor2), members(:psg_student1), members(:psg_student2)],
      program_id: programs(:psg).id,
      group_id: groups(:multi_group).id,
      owner_id: mentee.id
    )
    assert meeting.can_display_owner?
    group.update_attributes!(students: [users(:psg_student1), users(:psg_student2)])
    assert_false meeting.can_display_owner?

    group.update_attributes!(students: [mentee, users(:psg_student1), users(:psg_student2)])
    assert meeting.can_display_owner?
    mentee.destroy
    assert_false meeting.can_display_owner?
  end


  def test_attendee_ids
    meeting = Meeting.new(:topic => "General Topic", :start_time => 1.hour.from_now, :end_time => 3.hours.from_now)

    assert meeting.guests.empty?
    m1 = members(:f_mentor)
    m2 = members(:f_student)
    meeting.attendee_ids = [m1.id, m2.id]

    assert_equal_unordered [m1,m2], meeting.members
  end

  def test_belongs_to_program
    meeting = meetings(:f_mentor_mkr_student)
    assert_equal programs(:albers), meeting.program

    assert meeting.valid?
    meeting.program = nil
    assert_false meeting.valid?
  end

  def test_hours_and_duration_in_hours
    invalidate_albers_calendar_meetings
    meetings(:upcoming_psg_calendar_meeting).update_attribute(:active, false)
    meetings = Meeting.all
    m1 = meetings[0]
    m2 = meetings[1]

    assert_floats_equal 0.5, m1.duration_in_hours
    assert_floats_equal 1.0/3, m2.duration_in_hours

    r_m1 = Meeting.recurrent_meetings([m1], {get_merged_list: true})
    assert_floats_equal 0.5, Meeting.hours(r_m1)
    r_m2 = Meeting.recurrent_meetings([m2], {get_merged_list: true})
    assert_floats_equal 1.0/3, Meeting.hours(r_m2)
    recurrent_meetings = Meeting.recurrent_meetings(meetings, {get_merged_list: true})
    assert_floats_equal   54.66666666666667, Meeting.hours(recurrent_meetings), 0.1
  end

  def test_with_endtime_less_than
    m1 = meetings(:psg_mentor_psg_student)
    m2 = meetings(:upcoming_psg_mentor_psg_student)
    m3 = meetings(:past_psg_mentor_psg_student)
    time_now = Time.now.utc

    m1.update_attributes(:start_time => (time_now - 4.hours), :end_time => (time_now - 3.hours))
    m2.update_attributes(:start_time => (time_now - 5.hours), :end_time => (time_now - 4.hours))
    m3.update_attributes(:start_time => (time_now - 5.hours), :end_time => (time_now - 4.hours))
    assert_equal_unordered [m1,m2,m3], programs(:psg).meetings.with_endtime_less_than(Time.now.utc)
  end

  def test_schedulable
    meeting = create_meeting
    assert_false meeting.schedulable?(programs(:albers))
    time = 2.days.from_now
    meeting = create_meeting(:start_time => time, :end_time => time + 30.minutes)
    assert meeting.schedulable?(programs(:albers))
  end


#   ##############################################################################
#   # MENTORING SESSIONS ELASTICSEARCH TEST
#   ##############################################################################

  def test_not_cancelled
    create_meeting(:start_time => 2.days.from_now, :end_time => 3.days.from_now)
    meeting = Meeting.last
    assert meeting.not_cancelled

    meeting.member_meetings.first.destroy

    assert_false meeting.not_cancelled
  end

  def test_get_meetings_creation_message
    assert_equal "test", Meeting.get_meetings_creation_message(nil, "test")
    assert_equal "old<br/>test", Meeting.get_meetings_creation_message("old", "test")
  end

  def test_archived_future
    meeting = Meeting.first
    assert meeting.archived?(meeting.start_time)
    assert meeting.archived?
    assert_false meeting.future?
    meeting = create_meeting(start_time: 20.minutes.from_now, end_time: 50.minutes.from_now)
    assert_false meeting.archived?(meeting.start_time)
    assert meeting.future?
    meeting = create_meeting(force_non_time_meeting: true)
    assert meeting.archived?(meeting.start_time)
    assert_false meeting.future?

    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    assert meeting.archived?(meeting.occurrences.first.to_time)
    assert_false meeting.archived?
    assert_false meeting.archived?(meeting.occurrences.last.to_time)

    meeting = create_meeting(start_time: 20.minutes.ago, end_time: 50.minutes.from_now)
    assert_false meeting.archived?
    assert meeting.future?
  end

  def test_create_meeting_requests
    meeting = meetings(:f_mentor_mkr_student)
    assert_no_difference "MeetingRequest.count" do
      meeting.create_meeting_requests
    end
    assert_nil meeting.create_meeting_requests

    time = Time.now.utc + 2.days
    assert_difference "MeetingRequest.count" do
      meeting = create_meeting(start_time: time, end_time: time + 30.minutes, force_non_time_meeting: true)
    end
    meeting_request = MeetingRequest.last
    assert_equal AbstractRequest::Status::NOT_ANSWERED, meeting_request.status

    time = Time.now.utc - 2.days
    assert_difference "MeetingRequest.count" do
      meeting = create_meeting(start_time: time, end_time: time + 30.minutes, mentor_created_meeting: true, force_non_time_meeting: true)
    end
    meeting_request = MeetingRequest.last
    assert_equal AbstractRequest::Status::ACCEPTED, meeting_request.status

    time = Time.now.utc + 2.days
    assert_no_difference "MeetingRequest.count" do
      meeting = create_meeting(start_time: time, end_time: time + 30.minutes, mentor_created_meeting: true, force_non_group_meeting: true)
    end
  end

  def test_create_meeting_requests_with_slots
    time = Time.now.utc + 2.days
    meeting = nil
    assert_difference "MeetingRequest.count" do
      meeting = create_meeting(start_time: time, end_time: time + 30.minutes, force_non_time_meeting: true, proposed_slots_details_to_create: [OpenStruct.new(location: "chennai", start_time: time, end_time: time + 30.minutes)])
    end
    meeting_request = meeting.meeting_request
    assert_equal 1, meeting_request.meeting_proposed_slots.size
    slot = meeting_request.meeting_proposed_slots[0]
    assert_equal time.to_i, slot.start_time.to_i
    assert_equal (time+30.minutes).to_i, slot.end_time.to_i
    assert_equal "chennai", slot.location
    assert_equal meeting_request.student.id, slot.proposer_id
  end

  def test_slot_availability_meetings
    meeting = create_meeting
    assert Meeting.slot_availability_meetings.include?(meeting)
    meeting = create_meeting(force_non_time_meeting: true)
    assert_false Meeting.slot_availability_meetings.include?(meeting)
  end

  def test_false_destroy
    meeting = create_meeting
    assert meeting.active?
    assert_difference "Meeting.count", -1 do
      meeting.false_destroy!
    end
    assert_false meeting.active?
  end

  def test_false_destroy_without_email
    meeting_request = create_meeting_request
    meeting = meeting_request.meeting
    assert meeting.reload.active?
    assert_no_difference "ActionMailer::Base.deliveries.count" do
      Meeting.false_destroy_without_email!(meeting.id)
    end
    assert_false meeting.reload.active?
  end

  def test_formatted_duration
    meeting = create_meeting
    assert_equal "20 min", meeting.formatted_duration
    start = Time.now
    meeting = create_meeting(start_time: start, end_time: start + 1.hour)
    assert_equal "1 hr", meeting.formatted_duration
  end

  def test_destroy_of_milestone_with_meeting
    milestone1 = create_mentoring_model_milestone
    group = groups(:mygroup)
    t1 = create_mentoring_model_task
    time = group.meetings[0].start_time
    t1.update_attributes!(due_date: time + 3.days, required: true, milestone_id: milestone1.id)
    items_list = group.reload.get_tasks_list([])
    assert_equal milestone1.id, t1.milestone_id
    assert_equal milestone1.id, items_list.first[:milestone_id]
    t1.destroy
    milestone1.destroy
    items_list = group.reload.get_tasks_list([])
    assert [], items_list
  end

  def test_build_rule
    time =  Time.new(2013, 12, 31, 0, 0, 0, "+05:30")
    meeting = create_meeting(:recurrent => false, :repeat_every => 1, :schedule_rule => Meeting::Repeats::MONTHLY)
    assert_equal 'Daily', meeting.build_rule.to_s

    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY)
    assert_equal 'Daily', meeting.build_rule.to_s

    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::WEEKLY, :repeats_on_week => ['1', '2'], :end_time => time + 1.days, :start_time => time - 1.hour, :duration => 1.hour, :repeats_end_date => time + 1.days)
    assert_equal 'Weekly on Mondays and Tuesdays', meeting.build_rule.to_s

    meeting = create_meeting(:recurrent => true, :repeat_every => 3, :schedule_rule => Meeting::Repeats::MONTHLY, :repeats_by_month_date => 'true', :end_time => time + 1.day, :start_time => time - 1.hour, :repeats_end_date => time + 4.month)
    assert_equal 'Every 3 months on the 30th day of the month', meeting.build_rule.to_s

    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::MONTHLY, :repeats_by_month_date => 'false', :end_time => time + 2.month, :start_time => time - 1.hour, :repeats_end_date => time + 2.month, :duration => 1.hour)
    assert_equal 'Monthly on the 5th Monday', meeting.build_rule.to_s
  end

  def test_update_schedule
    time =  Time.new(2013, 12, 31, 0, 0, 0, "+05:30")
    Time.zone = "Asia/Kolkata"
    meeting = create_meeting(:recurrent => false, :repeat_every => 1, :schedule_rule => Meeting::Repeats::WEEKLY, :start_time => time, :end_time => time + 5.hours)
    assert_equal [meeting.start_time.to_date], meeting.occurrences.map(&:to_date)

    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :repeats_end_date => time + 2.days, :start_time => time, :end_time => time + 5.hours)
    assert_equal [meeting.start_time.to_date, meeting.start_time.to_date + 1.day, meeting.start_time.to_date + 2.days], meeting.occurrences.map(&:to_date)

    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::WEEKLY, :repeats_on_week => ['1', '2'], :end_time => time + 10.days, :start_time => time - 1.hour, repeats_end_date: time + 10.days, :duration => 1.hour)
    assert_equal ["2013-12-30", "2013-12-31", "2014-01-06", "2014-01-07"], meeting.occurrences.map(&:to_date).map(&:to_s)

    time = time + 10.hours
    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::MONTHLY, :repeats_by_month_date => 'true', :end_time => time + 5.months, :start_time => time - 1.hour, repeats_end_date: time + 5.months, :duration => 1.hour)
    assert_equal ["2013-12-31", "2014-01-31", "2014-03-31", "2014-05-31"], meeting.occurrences.map(&:to_date).map(&:to_s)

    time = time + (5.days - 10.hours)
    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::MONTHLY, :repeats_by_month_date => 'false', :end_time => time + 1.month, :start_time => time - 1.hour, repeats_end_date: time + 1.month, :duration => 1.hour)
    assert_equal ["2014-01-04", "2014-02-01"], meeting.occurrences.map(&:to_date).map(&:to_s)
  end

  def test_recurrent_meetings
    meeting = meetings(:f_mentor_mkr_student)
    daily_meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    past_meeting = meetings(:past_psg_mentor_psg_student)
    upcoming_meeting = meetings(:upcoming_psg_mentor_psg_student)

    #Get upcoming, past meet separately
    upcoming_meet, past_meet = Meeting.recurrent_meetings([past_meeting, upcoming_meeting])
    assert_equal 1, upcoming_meet.count
    assert_equal upcoming_meeting, upcoming_meet.first[:meeting]
    assert_equal upcoming_meeting.start_time, upcoming_meet.first[:current_occurrence_time]
    assert_equal 1, past_meet.count
    assert_equal past_meeting, past_meet.first[:meeting]
    assert_equal past_meeting.start_time, past_meet.first[:current_occurrence_time]

    #Get upcoming, past meet in one array
    recurrent_meets = Meeting.recurrent_meetings([upcoming_meeting, past_meeting], get_merged_list: true)
    assert_equal 2, recurrent_meets.count
    assert_equal upcoming_meeting, recurrent_meets.first[:meeting]
    assert_equal upcoming_meeting.start_time, recurrent_meets.first[:current_occurrence_time]
    assert_equal past_meeting, recurrent_meets.last[:meeting]
    assert_equal past_meeting.start_time, recurrent_meets.last[:current_occurrence_time]

    recurrent_meets = Meeting.recurrent_meetings([daily_meeting, past_meeting], get_merged_list: true)
    time = daily_meeting.start_time
    occurrence_times = []
    for i in 0..10
      occurrence_times << time
      time += 1.day
    end
    assert_equal [daily_meeting], recurrent_meets.first(11).collect{|m| m[:meeting]}.uniq
    assert_equal past_meeting, recurrent_meets.last[:meeting]
    assert_equal past_meeting.start_time, recurrent_meets.last[:current_occurrence_time]
    assert_equal occurrence_times, recurrent_meets.first(11).collect{|m| m[:current_occurrence_time]}

    upcoming_meets, past_meets = Meeting.recurrent_meetings([daily_meeting, past_meeting, upcoming_meeting])
    time = daily_meeting.start_time
    past_occurrence_times = []
    upcoming_occurrence_times = []
    current_time = Time.now
    for i in 0..10
      if (time+daily_meeting.schedule.duration) < current_time
        past_occurrence_times << time
      else
        upcoming_occurrence_times << time
      end
      time += 1.day
    end
    assert_equal [daily_meeting, upcoming_meeting], upcoming_meets.collect{|m| m[:meeting]}.uniq
    assert_equal upcoming_occurrence_times + [upcoming_meeting.start_time], upcoming_meets.collect{|m| m[:current_occurrence_time]}
    assert_equal past_occurrence_times.reverse + [past_meeting.start_time], past_meets.collect{|m| m[:current_occurrence_time]}
    assert_equal [daily_meeting, past_meeting], past_meets.collect{|m| m[:meeting]}.uniq

    upcoming_meets, past_meets = Meeting.recurrent_meetings([daily_meeting, past_meeting, upcoming_meeting], {:start_time => daily_meeting.start_time + 2.days, :end_time => daily_meeting.start_time + 6.days})
    assert_equal (upcoming_occurrence_times + [upcoming_meeting.start_time]).count, upcoming_meets.count
    assert_equal (past_occurrence_times.reverse + [past_meeting.start_time]).count, past_meets.count

    upcoming_meets, past_meets = Meeting.recurrent_meetings([daily_meeting, past_meeting, upcoming_meeting], {:start_time => daily_meeting.start_time + 2.days, :end_time => daily_meeting.start_time + 7.days, :get_occurrences_between_time => true})

    assert_equal 6, upcoming_meets.count + past_meets.count
    assert_equal [daily_meeting], upcoming_meets.collect{|m| m[:meeting]}.uniq
    assert_equal [daily_meeting], past_meets.collect{|m| m[:meeting]}.uniq

    upcoming_meets, past_meets = Meeting.recurrent_meetings([daily_meeting, past_meeting, upcoming_meeting], {:start_time => daily_meeting.start_time + 300.days, :end_time => daily_meeting.start_time + 307.days, :get_occurrences_between_time => true})
    assert_equal [], upcoming_meets
    assert_equal [], past_meets

    upcoming_meets, past_meets = Meeting.recurrent_meetings([daily_meeting, past_meeting, upcoming_meeting], {:start_time => upcoming_meeting.start_time, :end_time => upcoming_meeting.start_time + 35.days, :get_occurrences_between_time => true})
    assert_equal [{:current_occurrence_time => upcoming_meeting.start_time, :meeting => upcoming_meeting}], upcoming_meets
    assert_equal [], past_meets

    upcoming_meets, past_meets = Meeting.recurrent_meetings([daily_meeting, past_meeting, upcoming_meeting], {:start_time => past_meeting.start_time, :end_time => past_meeting.start_time + 5.days, :get_occurrences_between_time => true})
    assert_equal [], upcoming_meets
    assert_equal [{:current_occurrence_time => past_meeting.start_time, :meeting => past_meeting}], past_meets

    time_now = Time.now
    new_meet = create_meeting(start_time: time_now - 50.minutes, end_time: time_now + 20.minutes, :group_id => groups(:mygroup).id, :members => [users(:f_mentor).member, users(:mkr_student).member], :owner_id => users(:f_mentor).member_id)
    meets = Meeting.recurrent_meetings([new_meet], {:start_time => 1.hour.ago, :end_time => time_now, :with_in_time => true})
    assert_equal 0, meets.flatten.count
    meets = Meeting.recurrent_meetings([new_meet], {:start_time => 1.hour.ago, :end_time => time_now, :get_occurrences_between_time => true})
    assert_equal 1, meets.flatten.count
  end

  def test_can_send_create_email_notification
    time = Time.now
    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :repeats_end_date => time + 2.days, :start_time => time - 5.days, :end_time => time + 5.hours)
    assert meeting.can_send_create_email_notification?
    group_id = meeting.group_id
    meeting.group_id = nil
    assert_false meeting.can_send_create_email_notification?
    meeting.group_id = group_id
    meeting.active = false
    assert_false meeting.can_send_create_email_notification?
    meeting.active = true
    meeting.stubs(:archived?).with(meeting.schedule.last).returns(true)
    assert_false meeting.can_send_create_email_notification?
    meeting.unstub(:archived?)
    assert meeting.can_send_create_email_notification?
  end

  def test_send_create_email
    template = Mailer::Template.where(:uid => MeetingCreationNotificationToOwner.mailer_attributes[:uid]).first
    if template.present?
      template.update_attribute(:enabled, true)
      assert template.enabled?
    end
    time = Time.now
    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :repeats_end_date => time + 2.days, :start_time => time - 5.days, :end_time => time + 5.hours)
    Push::Base.expects(:queued_notify).once
    meeting.expects(:generate_ics_calendar).with(true, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, user: meeting.owner_user).once
    meeting.expects(:generate_ics_calendar).with(false, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, user: meeting.guests_users.first).once
    assert_emails 2 do
      meeting.send_create_email
    end
    assert_equal MemberMeeting::ATTENDING::NO_RESPONSE, Meeting.last.guests.first.member_meetings.find_by(meeting_id: Meeting.last.id).attending

    Push::Base.expects(:queued_notify).never
    assert_emails 0 do
      create_meeting.send_create_email
    end
    assert_equal MemberMeeting::ATTENDING::YES, Meeting.last.guests.first.member_meetings.find_by(meeting_id: Meeting.last.id).attending
  end

  def test_can_send_update_email_notification
    time = Time.now
    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :repeats_end_date => time + 2.days, :start_time => time - 5.days, :end_time => time + 5.hours)
    assert meeting.can_send_update_email_notification?
    meeting.active = false
    assert_false meeting.can_send_update_email_notification?
    meeting.active = true
    meeting.stubs(:archived?).with(meeting.schedule.last).returns(true)
    assert_false meeting.can_send_update_email_notification?
    meeting.unstub(:archived?)
    assert meeting.can_send_update_email_notification?
    meeting.stubs(:archived?).with(meeting.schedule.last).returns(true)
    meeting.stubs(:can_be_synced?).returns(true)
    assert meeting.can_send_update_email_notification?
  end

  def test_send_update_email_only_to_guests
    time = Time.now
    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :repeats_end_date => time + 2.days, :start_time => time - 5.days, :end_time => time + 5.hours)
    member_responses_hash = {}
    meeting.member_meetings.each { |member_meeting| member_responses_hash[member_meeting.member_id] = MemberMeeting::ATTENDING::YES }
    MemberMeeting.any_instance.stubs(:not_responded?).returns(false)
    Push::Base.expects(:queued_notify).never
    meeting.expects(:generate_ics_calendar).with(false, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, user: meeting.guests_users.first).once
    assert_emails 1 do
      meeting.send_update_email(member_responses_hash: member_responses_hash, updated_by_member_id: meeting.owner.id)
    end
    email = ActionMailer::Base.deliveries.last
    assert_match /Confirmed the previous/, get_text_part_from(email).gsub("\n", " ")
    assert_no_match(/update your response/, get_text_part_from(email).gsub("\n", " "))
  end

  def test_send_update_email_to_all
    time = Time.now
    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :repeats_end_date => time + 2.days, :start_time => time - 5.days, :end_time => time + 5.hours)
    member_responses_hash = {}
    meeting.member_meetings.each { |member_meeting| member_responses_hash[member_meeting.member_id] = MemberMeeting::ATTENDING::YES }

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)

    MemberMeeting.any_instance.stubs(:not_responded?).returns(true)
    meeting.expects(:generate_ics_calendar).times(4)
    Push::Base.expects(:queued_notify).once
    assert_emails 2 do
      meeting.send_update_email(updated_by_member_id: meeting.owner.id, :send_push_notifications => true)
    end

    email = ActionMailer::Base.deliveries.last
    assert_no_match(/confirmed the previous/, get_text_part_from(email).gsub("\n", " "))
    assert_match /Attending\?/, get_text_part_from(email).gsub("\n", " ")

    Meeting.any_instance.stubs(:can_be_synced?).returns(false)

    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :repeats_end_date => time + 2.days, :start_time => time - 5.days, :end_time => time + 5.hours)
    updating_member = (meeting.members - [meeting.owner]).first
    member_responses_hash = {}
    meeting.member_meetings.each { |member_meeting| member_responses_hash[member_meeting.member_id] = MemberMeeting::ATTENDING::YES }
    MemberMeeting.any_instance.stubs(:not_responded?).returns(false)
    Push::Base.expects(:queued_notify).never
    meeting.expects(:generate_ics_calendar).times(1)
    assert_emails 1 do
      meeting.send_update_email(member_responses_hash: member_responses_hash, updated_by_member_id: updating_member.id)
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal meeting.owner.email, email.to[0]
    assert_match /Confirmed the previous/, get_text_part_from(email).gsub("\n", " ")
    assert_no_match(/update your response/, get_text_part_from(email).gsub("\n", " "))
  end

  def test_send_destroy_email
    time = Time.now
    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :repeats_end_date => time + 2.days, :start_time => time - 5.days, :end_time => time + 5.hours)
    meeting.stubs(:false_destroyed?).returns(true)

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    assert_emails 2 do
      Meeting.send_destroy_email(meeting.id)
    end

    Meeting.any_instance.stubs(:can_be_synced?).returns(false)
    assert_emails 1 do
      Meeting.send_destroy_email(meeting.id)
    end

    Meeting.any_instance.stubs(:guests).returns([])
    assert_emails 0 do
      Meeting.send_destroy_email(meeting.id)
    end
  end

  def test_ics_organizer
    # without owner
    meeting = create_meeting
    Meeting.any_instance.stubs(:owner).returns(nil)
    assert_equal ({:name=>"Removed User", :email=>"Removed User"}), Meeting.ics_organizer(meeting)

    # with owner
    Meeting.any_instance.stubs(:owner).returns(members(:f_mentor))
    assert_equal ({:name=>"Good unique name", :email=>"robert@example.com"}), Meeting.ics_organizer(meeting)

    #with calendar sync enabled
    encypted_meeting_id = EncryptionEngine::DesEde3Cbc.new(CalendarUtils::ENCRYPTION_KEY).encrypt(meeting.id)
    scheduling_email = "#{APP_CONFIG[:reply_to_calendar_notification]}+#{encypted_meeting_id}@#{MAILGUN_DOMAIN}"
    Meeting.any_instance.stubs(:owner).returns(members(:f_mentor))
    meeting.stubs(:can_be_synced?).returns(true)
    assert_equal ({:name=>"Apollo Services", :email=>scheduling_email}), Meeting.ics_organizer(meeting)
  end

  def test_fetch_rrule
    time = Time.new(2013, 12, 31, 0, 0, 0, "+00:00")
    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :repeats_end_date => time + 2.days, :start_time => time - 5.days, :end_time => time + 5.hours)
    assert_equal ["FREQ=DAILY;UNTIL=20140102T000000Z", ""], meeting.fetch_rrule
    meeting.add_exception_rule_at(meeting.first_occurrence.to_s)
    assert_equal ["FREQ=DAILY;UNTIL=20140102T000000Z", "20131226T000000Z"], meeting.fetch_rrule

    meeting.update_attribute(:recurrent, false)
    assert_equal [nil, nil], meeting.fetch_rrule

    meeting.update_attribute(:recurrent, true)

    Meeting.any_instance.stubs(:schedule).raises(->{StandardError.new("Some error")})

    assert_difference "CalendarSyncErrorCases.count", 1 do
      meeting.fetch_rrule
    end

    error_case = CalendarSyncErrorCases.last
    assert_equal CalendarSyncErrorCases::ScenarioType::RRULE_CREATION, error_case.scenario
    assert_equal_unordered [:meeting_id, :error_message], error_case.details.keys
    assert_equal meeting.id, error_case.details[:meeting_id]
  end

  def test_paginated_meetings
    time = Time.new(2013, 12, 31, 0, 0, 0, "+05:30")
    archived_meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :repeats_end_date => time - 2.days, :start_time => time - 5.days, :end_time => time - 5.hours)
    upcoming_meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :repeats_end_date => time + 4.days, :start_time => time - 5.days, :end_time => time + 4.days)
    paginated_archived_meeting = wp_collection_from_array([archived_meeting], 1)
    paginated_upcoming_meeting = wp_collection_from_array([upcoming_meeting], 1)
    assert_equal [paginated_upcoming_meeting, paginated_archived_meeting], Meeting.paginated_meetings([upcoming_meeting], [archived_meeting], {:upcoming_page => 1, :archived_page => 1}, members(:f_mentor))
    assert_equal [paginated_upcoming_meeting, []], Meeting.paginated_meetings([upcoming_meeting], [archived_meeting], {:archived_page => 5}, members(:f_mentor))
    meetings_to_be_held, archived_meetings = Meeting.recurrent_meetings(Meeting.all)
    paginated_archived_meeting = archived_meetings.last((archived_meetings.count) % (Meeting::UPCOMING_PER_PAGE))
    assert_equal [meetings_to_be_held, paginated_archived_meeting], Meeting.paginated_meetings(meetings_to_be_held, archived_meetings, {:meeting_id => archived_meetings.last[:meeting].id, :current_occurrence_time => archived_meetings.last[:current_occurrence_time]}, members(:f_mentor))
  end

  def test_occurrence_end_time
    time = Time.new(2013, 12, 31, 0, 0, 0, "+05:30")
    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :repeats_end_date => time + 2.days, :start_time => time - 5.days, :end_time => time + 2.days + 5.hours, :duration => 5.hours)
    assert_equal "2014-01-01T23:30:00Z", DateTime.localize(meeting.occurrence_end_time(meeting.occurrences.last), format: :full_date_full_time_utc)
  end

  def test_generate_ics_calendar_events
    meeting = create_meeting
    is_owner = true

    meeting.update_attribute(:time_zone, "America/Los_Angeles")

    Meeting.any_instance.stubs(:ics_guests_details).returns([{email: "roger@example.com", name: "Roger", part_stat: "testpartstat"}])

    ics_event = Meeting.get_ics_event(meeting, user: meeting.participant_users.first)
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, is_owner)
    assert_match "PUBLISH",calendar.icalendar_method
    assert_match "SUMMARY:#{meeting.topic}", calendar.to_s
    assert_match /Message description.*This is a description of the meeting/, calendar.to_s
    assert_match /Attendees.*Good unique name.*mkr_student madankumarrajan/, calendar.to_s
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, is_owner, {calendar_sync_enabled: true})
    assert_match "REQUEST",calendar.icalendar_method
    assert_match /PARTSTAT=testpartstat/, calendar.to_s

    Meeting.any_instance.stubs(:ics_guests_details).returns([{email: "roger@example.com", name: "Roger"}])
    ics_event = Meeting.get_ics_event(meeting, user: meeting.participant_users.first)
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, is_owner)
    assert_match /PARTSTAT=NEEDS-ACTION/, calendar.to_s


    meeting.update_attribute(:recurrent, true)
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    Meeting.any_instance.stubs(:fetch_rrule).returns(["rrule", "exdates"])
    Meeting.any_instance.stubs(:fetch_rdates).returns(["rdates"])
    ics_event = Meeting.get_ics_event(meeting, user: meeting.participant_users.first)
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, is_owner)
    assert_match /BEGIN:VTIMEZONE/, calendar.to_s
    assert_match /END:VTIMEZONE/, calendar.to_s
    assert_match /EXDATE/, calendar.to_s
    assert_match /exdates/, calendar.to_s
    assert_match /RRULE:rrule/, calendar.to_s
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    occurrence_start_time = meeting.first_occurrence
    ics_event = Meeting.get_ics_event(meeting, {user: meeting.participant_users.first, current_occurrence_time: occurrence_start_time})
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, is_owner, {calendar_sync_enabled: true})
    start_time = DateTime.localize(occurrence_start_time, format: :ics_full_time)
    parsed_start_time = DateTime.localize(start_time.to_time.utc, format: :ics_full_time)
    assert_match /DTSTART;TZID=Etc\/UTC;VALUE=DATE-TIME:#{parsed_start_time}/, calendar.to_s

    Meeting.any_instance.stubs(:get_vtimezone_component).returns("chronus time zone component")
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, is_owner).export
    assert_match(/chronus time zone component/, calendar)
    assert_no_match(/BEGIN:VTIMEZONE/, calendar.to_s)

    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, is_owner, {ics_cal_feed: true}).export
    assert_no_match(/chronus time zone component/, calendar)
    assert_match(/BEGIN:VTIMEZONE/, calendar.to_s)
  end

  def test_get_event_start_and_end_time
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    occurrence_time = meeting.first_occurrence
    start_time = DateTime.localize(occurrence_time, format: :ics_full_time)
    end_time = DateTime.localize(occurrence_time + 1800.0, format: :ics_full_time)
    assert_equal [start_time, end_time], Meeting.get_event_start_and_end_time(meeting, {current_occurrence_time: occurrence_time})
    start_time = DateTime.localize(meeting.start_time, format: :ics_full_time)
    end_time = DateTime.localize(meeting.start_time + 1800.0, format: :ics_full_time)
    assert_equal [start_time, end_time], Meeting.get_event_start_and_end_time(meeting, {current_occurrence_time: occurrence_time})
  end

  def test_ics_guests_details
    RoleQuestion.any_instance.stubs(:visible_for?).returns(true)
    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: Time.now, end_time: Time.now + 30.minutes)

    members(:f_mentor).mark_attending!(meeting)
    members(:mkr_student).mark_attending!(meeting, {:attending => MemberMeeting::ATTENDING::NO})

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)

    guests_details = [{email: members(:f_mentor).email, name: members(:f_mentor).name, part_stat: "ACCEPTED"}, {email: members(:mkr_student).email, name: members(:mkr_student).name, part_stat: "DECLINED"}]

    assert_equal_unordered guests_details, meeting.ics_guests_details(meeting.participant_users.first)

    Meeting.any_instance.stubs(:can_be_synced?).returns(false)

    guests_details = [{email: members(:mkr_student).email, name: members(:mkr_student).name}]

    assert_equal guests_details, meeting.ics_guests_details(meeting.participant_users.first)

    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    occurrence_start_time = meeting.first_occurrence
    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    mentor_member_meeting_occurrence_response = mentor_member_meeting.member_meeting_responses.find_by(meeting_occurrence_time: occurrence_start_time)
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)

    guests_details = [{email: members(:f_mentor).email, name: members(:f_mentor).name, part_stat: "ACCEPTED"}, {email: members(:mkr_student).email, name: members(:mkr_student).name, part_stat: "NEEDS-ACTION"}]
    assert_equal guests_details, meeting.ics_guests_details(members(:f_mentor).user_in_program(meeting.program), false, current_occurrence_time: occurrence_start_time)
    members(:f_mentor).mark_attending_for_an_occurrence!(meeting, MemberMeeting::ATTENDING::NO, occurrence_start_time)
    meeting.reload
    guests_details = [{email: members(:f_mentor).email, name: members(:f_mentor).name, part_stat: "DECLINED"}, {email: members(:mkr_student).email, name: members(:mkr_student).name, part_stat: "NEEDS-ACTION"}]
    assert_equal guests_details, meeting.ics_guests_details(members(:f_mentor).user_in_program(meeting.program), false, current_occurrence_time: occurrence_start_time)
  end

  def test_ics_guests_details_without_email_visibility
    RoleQuestion.any_instance.stubs(:visible_for?).returns(false)
    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: Time.now, end_time: Time.now + 30.minutes)

    members(:f_mentor).mark_attending!(meeting)
    members(:mkr_student).mark_attending!(meeting, {:attending => MemberMeeting::ATTENDING::NO})

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)

    guests_details = []

    assert_equal_unordered guests_details, meeting.ics_guests_details(meeting.participant_users.first)

    Meeting.any_instance.stubs(:can_be_synced?).returns(false)

    guests_details = [{email: members(:mkr_student).email, name: members(:mkr_student).name}]

    assert_equal guests_details, meeting.ics_guests_details(meeting.participant_users.first)
  end

  def test_ics_guests_details_with_partial_email_visibility
    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: Time.now, end_time: Time.now + 30.minutes)

    members(:f_mentor).mark_attending!(meeting)
    members(:mkr_student).mark_attending!(meeting, {:attending => MemberMeeting::ATTENDING::NO})

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    user1 = members(:f_mentor).user_in_program(meeting.program)
    user2 = members(:mkr_student).user_in_program(meeting.program)
    RoleQuestion.any_instance.expects(:visible_for?).with(user1, user2).returns(false)
    RoleQuestion.any_instance.expects(:visible_for?).with(user1, user1).returns(true)

    guests_details = [{email: members(:f_mentor).email, name: members(:f_mentor).name, part_stat: "ACCEPTED"}]

    assert_equal_unordered guests_details, meeting.ics_guests_details(user1)

    Meeting.any_instance.stubs(:can_be_synced?).returns(false)

    guests_details = [{email: members(:mkr_student).email, name: members(:mkr_student).name}]

    assert_equal guests_details, meeting.ics_guests_details(meeting.participant_users.first)
  end

  def test_fetch_start_end_time_for_the_month
    view_date = "August 25, 2025".to_time.in_time_zone
    start_time, end_time = Meeting.fetch_start_end_time_for_the_month(view_date)
    assert_equal DateTime.localize(start_time, format: :full_display_no_time), "August 01, 2025"
    assert_equal DateTime.localize(end_time, format: :full_display_no_time), "August 31, 2025"
  end

  def test_get_meetings_for_view
    g1 = groups(:mygroup)
    g2 = groups(:group_2)
    m1 = meetings(:f_mentor_mkr_student)
    m2 = meetings(:student_2_not_req_mentor)
    m3 = meetings(:f_mentor_mkr_student_daily_meeting)
    m4 = meetings(:upcoming_calendar_meeting)
    m5 = meetings(:completed_calendar_meeting)
    m6 = meetings(:cancelled_calendar_meeting)
    m7 = meetings(:past_calendar_meeting)
    assert_equal [m1, m3], Meeting.of_group(g1)
    assert_equal [m2], Meeting.of_group(g2)

    assert_equal [m1, m3], Meeting.get_meetings_for_view(g1, true, nil, nil)
    assert_equal [m2], Meeting.get_meetings_for_view(g2, true, nil, nil)
    assert_equal [m1, m3], Meeting.get_meetings_for_view(g1, false, members(:f_mentor), nil)
    m1.member_meetings.find_by(member_id: members(:f_mentor).id).destroy
    m1.reload
    assert_equal [m3], Meeting.get_meetings_for_view(g1, false, members(:f_mentor), nil)
    assert_equal_unordered [m3,m4,m5,m6,m7], Meeting.get_meetings_for_view(nil, true, members(:f_mentor), programs(:albers))
    assert_equal [], Meeting.get_meetings_for_view(nil, true, members(:f_mentor), programs(:nwen))
    assert_equal [m2], Meeting.get_meetings_for_view(nil, true, members(:student_2), programs(:albers))

    assert_equal [], Meeting.get_meetings_for_view(nil, true, members(:student_2), programs(:albers), {from_my_availability: true})
    m2.update_attribute(:group_id, nil)
    assert_equal [m2], Meeting.get_meetings_for_view(nil, true, members(:student_2), programs(:albers), {from_my_availability: true})
    m2.update_attribute(:group_id, g2.id)
    programs(:albers).expects(:mentoring_connection_meeting_enabled?).once.returns(true)
    assert_equal [m2], Meeting.get_meetings_for_view(nil, true, members(:student_2), programs(:albers), {from_my_availability: true})

    members(:f_mentor).meetings.collect(&:destroy)
    time = 2.days.from_now
    programs(:albers).expects(:mentoring_connection_meeting_enabled?).twice.returns(false)
    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    assert_equal [], Meeting.get_meetings_for_view(nil, true, members(:f_mentor), programs(:albers), {from_my_availability: true})
    assert_equal [], Meeting.get_meetings_for_view(nil, true, members(:f_mentor), programs(:albers))
    meeting.meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    assert_equal [meeting], Meeting.get_meetings_for_view(nil, true, members(:f_mentor), programs(:albers), {from_my_availability: true})
    assert_equal [meeting], Meeting.get_meetings_for_view(nil, true, members(:f_mentor), programs(:albers))
  end

  def test_any_attending
    m = meetings(:f_mentor_mkr_student)
    member_ids = [members(:mkr_student).id]
    assert m.any_attending?(m.start_time, member_ids)

    m.member_meetings.map{|mm| mm.update_column(:attending, MemberMeeting::ATTENDING::NO)}
    assert_false m.any_attending?(m.start_time, member_ids)
  end

  def test_update_meeting_time_for_recurrent_meeting
    m = meetings(:f_mentor_mkr_student_daily_meeting)
    m.complete!
    m.member_meetings.update_all(attending: MemberMeeting::ATTENDING::YES)
    member_meeting = m.member_meetings.first
    survey = programs(:albers).surveys.of_meeting_feedback_type.first
    question_id = survey.survey_questions.pluck(:id)
    survey.update_user_answers({question_id[0] => "Extremely satisfying", question_id[1] => "Great use of time"}, {user_id: member_meeting.member.user_in_program(programs(:albers)).id, :meeting_occurrence_time => m.occurrences.first.start_time, member_meeting_id: member_meeting.id})
    assert_equal 2, m.reload.survey_answers.count
    old_start_time = m.start_time
    old_duration = m.schedule.duration
    assert_equal 4, m.member_meeting_responses.count
    m.update_meeting_time(old_start_time + 30.minutes, old_duration + 30.minutes, {updated_by_member: m.owner, meeting_time_zone: "America/Los_Angeles"})
    m.reload
    owner_response = m.member_meetings.where(member_id: m.owner.id).first.attending
    assert_equal MemberMeeting::ATTENDING::YES, owner_response
    other_responses = m.member_meetings.where("member_id != ?", m.owner.id).collect(&:attending).uniq
    assert_equal [MemberMeeting::ATTENDING::NO_RESPONSE], other_responses
    assert_equal 0, m.member_meeting_responses.count
    assert_equal (old_start_time + 30.minutes), m.start_time
    assert_equal (old_duration + 30.minutes), m.schedule.duration
    assert_equal 2, m.survey_answers.count
    assert_equal "America/Los_Angeles", m.time_zone
  end

  def test_update_meeting_time_fake_update
    m = meetings(:f_mentor_mkr_student_daily_meeting)
    m.complete!
    m.member_meetings.update_all(attending: MemberMeeting::ATTENDING::YES)
    member_meeting = m.member_meetings.first
    survey = programs(:albers).surveys.of_meeting_feedback_type.first
    question_id = survey.survey_questions.pluck(:id)
    survey.update_user_answers({question_id[0] => "Extremely satisfying", question_id[1] => "Great use of time"}, {user_id: member_meeting.member.user_in_program(programs(:albers)).id, :meeting_occurrence_time => m.occurrences.first.start_time, member_meeting_id: member_meeting.id})
    assert_equal 2, m.reload.survey_answers.count
    old_start_time = m.start_time
    old_duration = m.schedule.duration
    assert_equal 4, m.member_meeting_responses.count
    m.update_meeting_time(old_start_time + 30.minutes, old_duration + 30.minutes, fake_update: true)
    m.reload
    assert_equal [MemberMeeting::ATTENDING::YES], m.member_meetings.where("member_id != ?", m.owner.id).collect(&:attending).uniq
    assert_equal 4, m.member_meeting_responses.count
    assert_equal old_start_time, m.start_time
    assert_equal old_duration, m.schedule.duration
    assert_equal 2, m.survey_answers.count
  end

  def test_dont_update_meeting_time_for_recurrent_meeting
    m = meetings(:f_mentor_mkr_student_daily_meeting)
    old_start_time = m.start_time
    old_duration = m.schedule.duration
    assert_equal 4, m.member_meeting_responses.count
    m.update_meeting_time(old_start_time, old_duration, meeting_time_zone: "America/Los_Angeles")
    m.reload
    assert_equal 4, m.member_meeting_responses.count
    assert_equal old_start_time, m.start_time
    assert_equal old_duration, m.schedule.duration
    assert_nil m.time_zone
  end

  def test_update_meeting_time_with_no_time_change
    time = 2.days.from_now
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    assert_false meeting.calendar_time_available
    meeting.update_meeting_time(time, 1800.0, {calendar_time_available: true, meeting_time_zone: "America/Los_Angeles"})
    assert meeting.reload.calendar_time_available
    assert_equal "America/Los_Angeles", meeting.time_zone
  end

  def test_update_meeting_time_for_non_recurrent_meeting
    m = meetings(:f_mentor_mkr_student)
    old_start_time = m.start_time
    old_duration = m.schedule.duration
    m.update_meeting_time(old_start_time + 30.minutes, old_duration + 30.minutes, {location: "Test location", updated_by_member: members(:f_mentor), meeting_time_zone: "America/Los_Angeles"})
    m.reload
    assert_equal (old_start_time + 30.minutes), m.start_time
    assert_equal (old_duration + 30.minutes), m.schedule.duration
    assert_equal "Test location", m.location
    assert_equal MemberMeeting::ATTENDING::NO_RESPONSE, members(:mkr_student).member_meetings.find_by(meeting_id: m.id).attending
    assert_equal MemberMeeting::ATTENDING::YES, members(:f_mentor).member_meetings.find_by(meeting_id: m.id).attending
    assert_equal "America/Los_Angeles", m.time_zone
  end

  def test_get_vtimezone_component
    m = meetings(:f_mentor_mkr_student)
    m.update_attribute(:time_zone, "America/Los_Angeles")

    timezone_component = m.get_vtimezone_component
    assert_match(/BEGIN:VTIMEZONE/, timezone_component)
    assert_match(/TZID:America\/Los_Angeles/, timezone_component)
    assert_match(/BEGIN:DAYLIGHT/, timezone_component)
    assert_match(/TZOFFSETFROM:-0800/, timezone_component)
    assert_match(/TZOFFSETTO:-0700/, timezone_component)
    assert_match(/END:DAYLIGHT/, timezone_component)
    assert_match(/BEGIN:STANDARD/, timezone_component)
    assert_match(/TZOFFSETFROM:-0700/, timezone_component)
    assert_match(/TZOFFSETTO:-0800/, timezone_component)
    assert_match(/END:STANDARD/, timezone_component)
    assert_match(/END:VTIMEZONE/, timezone_component)
  end

  def test_meeting_time_zone
    m = meetings(:f_mentor_mkr_student)

    assert_nil m.time_zone
    assert_equal TimezoneConstants::DEFAULT_TIMEZONE, m.meeting_time_zone

    m.update_attribute(:time_zone, "America/Los_Angeles")
    assert_equal "America/Los_Angeles", m.meeting_time_zone
  end

  def test_update_single_meeting
    m = meetings(:f_mentor_mkr_student_daily_meeting)
    m.updated_by_member = members(:f_mentor)
    old_meeting_attributes = m.attributes
    current_occurrence_time = m.occurrences.sort.second.to_time
    assert m.occurrences.include?(current_occurrence_time)
    assert_equal 1, m.member_meeting_responses.where(meeting_occurrence_time: current_occurrence_time).count
    new_meeting_params = {"location" => "new location", "topic" => "new topic", "description" => "new description", "attendee_ids" => m.attendee_ids, "start_time" => current_occurrence_time + 30.minutes, "end_time" => current_occurrence_time + m.schedule.duration + 1.hour, "duration" => m.schedule.duration + 30.minutes, "ics_sequence" => 1, "group_id" => m.group_id, "recurrent" => false}
    assert_difference('Meeting.count') do
      assert_difference 'RecentActivity.count', 1 do
        new_meeting = m.update_single_meeting(new_meeting_params, current_occurrence_time.to_s, members(:f_mentor))
        assert_false new_meeting.recurrent?
        assert_equal new_meeting_params["location"], new_meeting.location
        assert_equal new_meeting_params["topic"], new_meeting.topic
        assert_equal new_meeting_params["description"], new_meeting.description
        assert_equal new_meeting_params["attendee_ids"], new_meeting.attendee_ids
        assert_equal new_meeting_params["start_time"], new_meeting.start_time
        assert_equal new_meeting_params["duration"], new_meeting.schedule.duration
        assert_equal new_meeting_params["group_id"], new_meeting.group_id
        assert_equal members(:f_mentor).get_valid_time_zone, new_meeting.time_zone
        assert_equal members(:f_mentor), new_meeting.updated_by_member
        assert new_meeting.skip_create_calendar_event
      end
    end
    m.reload
    recent_activity = RecentActivity.last
    assert m.recurrent?
    assert_equal old_meeting_attributes["location"], m.location
    assert_equal old_meeting_attributes["topic"], m.topic
    assert_equal old_meeting_attributes["description"], m.description
    assert_equal old_meeting_attributes["start_time"], m.start_time
    assert_equal old_meeting_attributes["schedule"].duration, m.schedule.duration
    assert_equal old_meeting_attributes["group_id"], m.group_id
    assert_false m.occurrences.include?(current_occurrence_time)
    assert_equal 0, m.member_meeting_responses.where(meeting_occurrence_time: current_occurrence_time).count
    assert_equal Meeting.last, recent_activity.ref_obj
    assert_equal RecentActivityConstants::Type::MEETING_UPDATED, recent_activity.action_type
    assert_equal members(:f_mentor), recent_activity.member
  end

  def test_update_following_meetings
    m = meetings(:f_mentor_mkr_student_daily_meeting)
    m.updated_by_member = members(:f_mentor)
    old_meeting_attributes = m.attributes
    old_meeting_attributes["duration"] = m.schedule.duration
    current_occurrence_time = m.occurrences.sort.second.to_time
    old_occurrences = m.occurrences
    assert m.occurrences.include?(current_occurrence_time)
    assert_equal 3, m.member_meeting_responses.where("meeting_occurrence_time >= ?", current_occurrence_time).count
    assert_equal 4, m.member_meeting_responses.count
    new_meeting_params = {"location" => "new location", "topic" => "new topic", "description" => "new description", "attendee_ids" => m.attendee_ids, "start_time" => current_occurrence_time + 30.minutes, "end_time" => current_occurrence_time + m.schedule.duration + 1.hour, "duration" => m.schedule.duration + 30.minutes, "ics_sequence" => 1, "group_id" => m.group_id, "recurrent" => true}
    assert_difference('Meeting.count') do
      assert_difference 'RecentActivity.count', 1 do
        new_meeting = m.update_following_meetings(new_meeting_params, current_occurrence_time.to_s, members(:f_mentor))
        assert new_meeting.recurrent?
        assert_equal new_meeting_params["location"], new_meeting.location
        assert_equal new_meeting_params["topic"], new_meeting.topic
        assert_equal new_meeting_params["description"], new_meeting.description
        assert_equal new_meeting_params["attendee_ids"], new_meeting.attendee_ids
        assert_equal new_meeting_params["start_time"], new_meeting.start_time
        assert_equal new_meeting_params["duration"], new_meeting.schedule.duration
        assert_equal new_meeting_params["group_id"], new_meeting.group_id
        assert_equal members(:f_mentor).get_valid_time_zone, new_meeting.time_zone
        assert_equal members(:f_mentor), new_meeting.updated_by_member
        assert new_meeting.skip_create_calendar_event
      end
    end
    m.reload
    recent_activity = RecentActivity.last
    assert m.recurrent?
    assert_equal old_meeting_attributes["location"], m.location
    assert_equal old_meeting_attributes["topic"], m.topic
    assert_equal old_meeting_attributes["description"], m.description
    assert_equal old_meeting_attributes["start_time"], m.start_time
    assert_equal old_meeting_attributes["duration"], m.schedule.duration
    assert_equal old_meeting_attributes["group_id"], m.group_id
    assert_equal 0, m.member_meeting_responses.where("meeting_occurrence_time >= ?", current_occurrence_time).count
    assert_equal 1, m.member_meeting_responses.count
    assert_equal old_occurrences.size, Meeting.last.occurrences.size + m.occurrences.size
    assert_equal Meeting.last, recent_activity.ref_obj
    assert_equal RecentActivityConstants::Type::MEETING_UPDATED, recent_activity.action_type
    assert_equal members(:f_mentor), recent_activity.member
  end

  def test_append_to_recent_activity_stream_for_flash_and_no_guests
    meeting = meetings(:f_mentor_mkr_student)
    meeting.update_attribute(:mentee_id, members(:mkr_student).id)
    meeting.update_attribute(:group_id, nil)

    assert_difference "RecentActivity.count", 1 do
      meeting.topic = "changed topic"
      meeting.save!
    end

    meeting.stubs(:guests).returns([])

    assert_no_difference "RecentActivity.count" do
      meeting.topic = "changed topic again"
      meeting.save!
    end
  end

  def test_details_updated
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    old_attributes = meeting.attributes
    old_attributes["schedule_duration"] = meeting.schedule.duration
    assert_false meeting.datetime_updated?(old_attributes)
    assert_false meeting.details_updated?(old_attributes)

    meeting.location = "Updated location"
    assert_false meeting.datetime_updated?(old_attributes)
    assert meeting.details_updated?(old_attributes)

    meeting.reload
    assert meeting.location == old_attributes["location"]
    meeting.start_time = old_attributes["start_time"].to_datetime + 30.minutes
    assert meeting.datetime_updated?(old_attributes)
    assert meeting.details_updated?(old_attributes)

    meeting.reload
    meeting.schedule.duration = meeting.schedule.duration + 1800.0
    assert meeting.datetime_updated?(old_attributes)
    assert meeting.details_updated?(old_attributes)

    meeting.reload
    meeting.topic = "updated topic"
    assert_false meeting.datetime_updated?(old_attributes)
    assert meeting.details_updated?(old_attributes)

    meeting.reload
    meeting.description = "updated desc"
    assert_false meeting.datetime_updated?(old_attributes)
    assert meeting.details_updated?(old_attributes)
  end

  def test_reset_responses
    m = meetings(:f_mentor_mkr_student_daily_meeting)
    meeting_responses_count = m.member_meeting_responses.size
    assert m.member_meeting_responses.present?
    m.member_meetings.update_all(attending: MemberMeeting::ATTENDING::YES)

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)

    assert_no_difference 'MemberMeeting.count' do
      assert_difference 'MemberMeetingResponse.count', -(meeting_responses_count) do
        assert_emails 0 do
          m.reset_responses(members(:f_mentor))
        end
      end
    end

    assert_equal MemberMeeting::ATTENDING::NO_RESPONSE, members(:mkr_student).member_meetings.find_by(meeting_id: m.id).attending
    assert_equal MemberMeeting::ATTENDING::YES, members(:f_mentor).member_meetings.find_by(meeting_id: m.id).attending

    m.member_meetings.update_all(attending: MemberMeeting::ATTENDING::NO)

    Meeting.any_instance.stubs(:can_be_synced?).returns(false)

    assert_emails 1 do
      m.reset_responses(nil, true)
    end

    assert_equal MemberMeeting::ATTENDING::YES, members(:mkr_student).member_meetings.find_by(meeting_id: m.id).attending
    assert_equal MemberMeeting::ATTENDING::YES, members(:f_mentor).member_meetings.find_by(meeting_id: m.id).attending
  end

  def test_future_or_group_meeting
    meeting = meetings(:f_mentor_mkr_student)
    current_occurrence_time = meeting.occurrences.first.start_time
    assert_equal true, meeting.future_or_group_meeting?(current_occurrence_time)

    time = 2.days.from_now
    meeting = create_meeting(force_non_time_meeting: true, start_time: time, end_time: time + 30.minutes)
    current_occurrence_time = meeting.occurrences.first.start_time
    assert_equal true, meeting.future_or_group_meeting?(current_occurrence_time)

    time = 2.days.ago
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    current_occurrence_time = meeting.occurrences.first.start_time
    assert_false meeting.future_or_group_meeting?(current_occurrence_time)
  end

  def test_owner_and_owner_user_present
    meeting = meetings(:f_mentor_mkr_student)
    assert_equal members(:f_mentor), meeting.owner
    assert meeting.owner_and_owner_user_present?

    Member.any_instance.stubs(:user_in_program).returns(nil)
    assert_false meeting.owner_and_owner_user_present?

    Member.any_instance.unstub(:user_in_program)
    meeting.owner = nil
    assert_false meeting.owner_and_owner_user_present?
  end

  def test_location_can_be_set_by_member
    meeting = meetings(:f_mentor_mkr_student)
    member = members(:f_mentor)

    member_meeting = meeting.member_meetings.find_by(member_id: member.id)

    Meeting.any_instance.stubs(:can_be_edited_by_member?).returns(true)
    assert meeting.calendar_time_available?
    assert member_meeting.accepted?
    assert meeting.location_can_be_set_by_member?(member, meeting.first_occurrence)

    Meeting.any_instance.stubs(:can_be_edited_by_member?).returns(false)
    assert_false meeting.location_can_be_set_by_member?(member, meeting.first_occurrence)

    Meeting.any_instance.stubs(:can_be_edited_by_member?).returns(true)
    meeting.update_attribute(:calendar_time_available, false)
    assert_false meeting.location_can_be_set_by_member?(member, meeting.first_occurrence)

    meeting.update_attribute(:calendar_time_available, true)
    member.mark_attending!(meeting, attending: MemberMeeting::ATTENDING::NO)
    assert_false meeting.location_can_be_set_by_member?(member, meeting.first_occurrence)

    member.mark_attending!(meeting, attending: MemberMeeting::ATTENDING::YES)
    assert meeting.location_can_be_set_by_member?(member, meeting.first_occurrence)

    meeting.update_attribute(:recurrent, true)
    assert_false meeting.location_can_be_set_by_member?(member, meeting.first_occurrence)

    meeting.update_attribute(:recurrent, false)
    member_meeting.destroy
    assert_false meeting.location_can_be_set_by_member?(member, meeting.first_occurrence)
  end

  def test_can_be_edited_by_member
    meeting = meetings(:f_mentor_mkr_student)

    assert_equal members(:f_mentor).id, meeting.owner_id
    assert_false meeting.program.allow_one_to_many_mentoring?
    assert meeting.has_member?(members(:f_mentor))
    assert meeting.has_member?(members(:mkr_student))
    assert_false meeting.has_member?(members(:f_student))

    group = meeting.group
    assert group.active?
    # in one-one mentoring either of both can edit meeting
    assert meeting.can_be_edited_by_member?(members(:f_mentor))
    assert meeting.can_be_edited_by_member?(members(:mkr_student))
    assert_false meeting.can_be_edited_by_member?(members(:f_student))
    meeting.program.update_attributes!(allow_one_to_many_mentoring: true)

    assert meeting.can_be_edited_by_member?(members(:f_mentor))
    assert_false meeting.can_be_edited_by_member?(members(:mkr_student))
    assert_false meeting.can_be_edited_by_member?(members(:f_student))

    Group.any_instance.stubs(:active?).returns(false)
    Group.any_instance.stubs(:expired?).returns(true)
    assert_false meeting.can_be_edited_by_member?(members(:mkr_student))

    # only meeting owner or mentor or circles owner can edit meeting
    group.membership_of(users(:mkr_student)).update_attributes!(owner: true)
    assert meeting.can_be_edited_by_member?(members(:mkr_student))
    assert meeting.can_be_edited_by_member?(members(:f_mentor))
    group.membership_of(users(:mkr_student)).update_attributes!(owner: false)

    meeting.update_attributes!(owner_id: members(:mkr_student).id)
    assert_equal members(:mkr_student).id, meeting.owner_id
    assert meeting.can_be_edited_by_member?(members(:mkr_student))
    assert meeting.can_be_edited_by_member?(members(:f_mentor))

    Group.any_instance.unstub(:expired?)
    Group.any_instance.stubs(:expired?).returns(false)
    assert_false meeting.reload.can_be_edited_by_member?(members(:mkr_student))

    meeting.update_attribute(:group_id, nil)
    assert meeting.reload.can_be_edited_by_member?(members(:mkr_student))
  end

  def test_can_be_deleted_by_member
    meeting = meetings(:f_mentor_mkr_student)

    assert meeting.has_member?(members(:f_mentor))
    assert meeting.has_member?(members(:mkr_student))

    assert_equal members(:f_mentor), meeting.owner

    assert meeting.can_be_edited_by_member?(members(:f_mentor))
    assert meeting.can_be_deleted_by_member?(members(:f_mentor))
    assert_false meeting.can_be_deleted_by_member?(members(:mkr_student))

    meeting.stubs(:can_be_edited_by_member?).with(members(:f_mentor)).returns(false)
    assert_false meeting.can_be_deleted_by_member?(members(:f_mentor))
  end

  def test_has_attendance_more_than
    non_recurrent_meeting = meetings(:f_mentor_mkr_student)
    recurrent_meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    first_occurrence = recurrent_meeting.occurrences.first.start_time

    non_recurrent_meeting_hash = { current_occurrence_time: non_recurrent_meeting.start_time, meeting: non_recurrent_meeting }
    assert_equal [MemberMeeting::ATTENDING::YES], non_recurrent_meeting.member_meetings.pluck(:attending).uniq
    assert_equal [non_recurrent_meeting_hash], Meeting.has_attendance_more_than([non_recurrent_meeting_hash], 0)
    assert_equal [non_recurrent_meeting_hash], Meeting.has_attendance_more_than([non_recurrent_meeting_hash], 1)
    assert_empty Meeting.has_attendance_more_than([non_recurrent_meeting_hash], 2)

    members(:mkr_student).mark_attending!(non_recurrent_meeting, attending: MemberMeeting::ATTENDING::NO)
    non_recurrent_meeting_hash = { current_occurrence_time: non_recurrent_meeting.start_time, meeting: non_recurrent_meeting.reload }
    assert_equal [non_recurrent_meeting_hash], Meeting.has_attendance_more_than([non_recurrent_meeting_hash], 0)
    assert_empty Meeting.has_attendance_more_than([non_recurrent_meeting_hash], 1)

    members(:f_mentor).mark_attending!(recurrent_meeting, attending: MemberMeeting::ATTENDING::YES)
    members(:mkr_student).mark_attending!(recurrent_meeting, attending: MemberMeeting::ATTENDING::YES)
    recurrent_meeting_hash = { current_occurrence_time: first_occurrence, meeting: recurrent_meeting.reload }
    assert_equal [recurrent_meeting_hash], Meeting.has_attendance_more_than([recurrent_meeting_hash], 1)
    assert_empty Meeting.has_attendance_more_than([recurrent_meeting_hash], 2)

    members(:mkr_student).mark_attending_for_an_occurrence!(recurrent_meeting, MemberMeeting::ATTENDING::NO, first_occurrence)
    recurrent_meeting_hash = { current_occurrence_time: first_occurrence, meeting: recurrent_meeting.reload }
    assert_empty Meeting.has_attendance_more_than([recurrent_meeting_hash], 1)
  end

  def test_has_many_scraps_association
    meeting = meetings(:f_mentor_mkr_student)

    scraps = [messages(:meeting_scrap)]
    time_traveller(2.days.ago) do
      scraps << Scrap.create!(:ref_obj => meeting, :subject => "hello", :content => "Scrap Message Content", :sender => members(:mkr_student), :program => programs(:albers))
    end

    time_traveller(1.days.ago) do
      scraps << Scrap.create!(:ref_obj => meeting, :subject => "hai", :content => "Scrap Message Content", :sender => members(:f_mentor), :program => programs(:albers))
    end

    assert_equal_unordered scraps, meeting.scraps

    assert_equal 3, Scrap.where(ref_obj_id: meeting.id, ref_obj_type: Meeting.to_s).size
    assert_no_difference "Scrap.count" do
      meeting.destroy
    end
    assert_blank Scrap.where(ref_obj_id: meeting.id, ref_obj_type: Meeting.to_s)
  end

  def test_participant_users
    meeting = meetings(:f_mentor_mkr_student)
    assert_equal_unordered [users(:mkr_student), users(:f_mentor)], meeting.participant_users
  end

  def test_get_coparticipants
    meeting = meetings(:f_mentor_mkr_student)
    assert_equal [users(:mkr_student)], meeting.get_coparticipants(users(:f_mentor))
    assert_equal [users(:f_mentor)], meeting.get_coparticipants(users(:mkr_student))
  end

  def test_member_can_send_new_message
    meeting = meetings(:f_mentor_mkr_student)

    assert_false meeting.member_can_send_new_message?(members(:f_admin))

    assert meeting.member_can_send_new_message?(members(:f_mentor))
    assert meeting.member_can_send_new_message?(members(:mkr_student))

    users(:f_mentor).suspend_from_program!(users(:f_admin), "Not really good")
    assert_false meeting.member_can_send_new_message?(members(:mkr_student))

    meeting.complete!
    assert_false meeting.member_can_send_new_message?(members(:f_mentor))
  end

  def test_get_role_of_user
    time = Time.now
    meeting1 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    assert_equal RoleConstants::STUDENT_NAME, meeting1.get_role_of_user(users(:mkr_student))
    assert_equal RoleConstants::MENTOR_NAME, meeting1.get_role_of_user(users(:f_mentor))

    meeting2 = meetings(:psg_mentor_psg_student)
    assert_equal RoleConstants::STUDENT_NAME, meeting2.get_role_of_user(users(:psg_student1))
    assert_equal RoleConstants::MENTOR_NAME, meeting2.get_role_of_user(users(:psg_mentor1))

    meeting2.update_attribute(:mentee_id, members(:psg_mentor1).id)
    meeting2.update_attribute(:group_id, nil)
    assert_equal RoleConstants::MENTOR_NAME, meeting2.get_role_of_user(users(:psg_student1))
    assert_equal RoleConstants::STUDENT_NAME, meeting2.get_role_of_user(users(:psg_mentor1))
  end

  def test_accepted
    meeting = meetings(:psg_mentor_psg_student)
    assert meeting.accepted?
    meeting_request = create_meeting_request
    assert_false meeting_request.accepted?
    meeting.meeting_request = meeting_request
    assert_false meeting.accepted?
    meeting_request.status = AbstractRequest::Status::ACCEPTED
    assert meeting_request.accepted?
  end

  def test_is_valid_occurrence
    #non recurrent meeting
    meeting = meetings(:f_mentor_mkr_student)
    current_occurrence_time = meeting.occurrences.first.start_time
    assert meeting.is_valid_occurrence?(current_occurrence_time)
    current_occurrence_time = current_occurrence_time + 1.day
    assert_false meeting.is_valid_occurrence?(current_occurrence_time)

    #recurrent meeting
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    #past occurrence
    current_occurrence_time = meeting.occurrences.first.start_time
    assert meeting.is_valid_occurrence?(current_occurrence_time)
    #future occurrence
    current_occurrence_time = meeting.occurrences.last.start_time
    assert meeting.is_valid_occurrence?(current_occurrence_time)
    #middle occurrence
    current_occurrence_time = meeting.occurrences[8].start_time
    assert meeting.is_valid_occurrence?(current_occurrence_time)
    #random time
    assert_false meeting.is_valid_occurrence?(current_occurrence_time+30.minutes)
  end

  def test_past_scope
    m_past = create_meeting(end_time: 20.minutes.ago)
    m_future = create_meeting(end_time: 20.minutes.from_now)
    past_ids = Meeting.past.pluck :id
    assert past_ids.include?(m_past.id)
    assert_false past_ids.include?(m_future.id)
  end

  def test_upcoming_scope
    m_past = create_meeting(end_time: 20.minutes.ago)
    m_future = create_meeting(end_time: 20.minutes.from_now)
    upcoming_ids = Meeting.upcoming.pluck :id
    assert upcoming_ids.include?(m_future.id)
    assert_false upcoming_ids.include?(m_past.id)
  end

  def test_get_member_meeting_for_role
    meeting = create_meeting
    mms = meeting.member_meetings
    mentor_mm = mms.find{|mm| mm.member_id == users(:f_mentor).member_id}
    mentee_mm = mms.find{|mm| mm.member_id == users(:mkr_student).member_id}

    assert_equal mentee_mm, meeting.get_member_meeting_for_role(RoleConstants::STUDENT_NAME)
    assert_equal mentor_mm, meeting.get_member_meeting_for_role(RoleConstants::MENTOR_NAME)
  end

  def test_get_member_for_role
    meeting = create_meeting
    mms = meeting.members
    mentor_mem = mms.find{|mm| mm.id == users(:f_mentor).member_id}
    mentee_mem = mms.find{|mm| mm.id == users(:mkr_student).member_id}

    assert_equal mentee_mem, meeting.get_member_for_role(RoleConstants::STUDENT_NAME)
    assert_equal mentor_mem, meeting.get_member_for_role(RoleConstants::MENTOR_NAME)
  end

  def test_first_occurrence
    meeting = meetings(:f_mentor_mkr_student)
    assert_equal meeting.occurrences.first, meeting.first_occurrence
  end

  def test_get_reply_to_token
    time = 2.days.from_now
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    api_token_string = meeting.member_meetings.pluck(:api_token).join('-')
    assert_equal api_token_string, meeting.get_reply_to_token(members(:f_mentor).id, members(:mkr_student).id)
  end

  def test_get_meetings_for_upcoming_widget
    member1 = members(:f_mentor)
    member2 = members(:mkr_student)

    program = programs(:albers)

    meetings = program.meetings.accepted_meetings.involving(member1.id, member2.id).between_time(Time.now, Time.now + Meeting::UPCOMING_MEETINGS_WIDGET_END_DAYS.days).to_a

    assert_equal [meetings(:f_mentor_mkr_student_daily_meeting), meetings(:upcoming_calendar_meeting)], meetings

    assert_equal Meeting.upcoming_recurrent_meetings(meetings).first(Meeting::MEETINGS_COUNT_IN_UPCOMING_MEETINGS_WIDGET), Meeting.get_meetings_for_upcoming_widget(program, member1, member2)

    time = Time.now + 30.minutes

    # accepted meeting
    meeting1 = create_meeting(owner_id: member1.id, members: [member1, member2], force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting1.meeting_request.update_attribute(:status, AbstractRequest::Status::ACCEPTED)

    # non accepted meeting
    meeting2 = create_meeting(owner_id: member1.id, members: [member1, member2], force_non_time_meeting: true, force_non_group_meeting: true, start_time: time + 3.days, end_time: time + 3.days + 30.minutes)

    meeting3 = create_meeting(owner_id: member1.id, members: [member1, member2], force_non_time_meeting: true, force_non_group_meeting: true, start_time: time + 35.day, end_time: time + 35.day + 30.minutes)
    meeting3.meeting_request.update_attribute(:status, AbstractRequest::Status::ACCEPTED)

    meeting4 = create_meeting(owner_id: member1.id, members: [member1, member2], force_non_time_meeting: true, force_non_group_meeting: true, start_time: time + 4.day, end_time: time + 4.day + 30.minutes)
    meeting4.meeting_request.update_attribute(:status, AbstractRequest::Status::ACCEPTED)

    meetings = program.reload.meetings.accepted_meetings.involving(member1.id, member2.id).between_time(Time.now, Time.now + Meeting::UPCOMING_MEETINGS_WIDGET_END_DAYS.days).to_a

    assert_equal_unordered [meetings(:f_mentor_mkr_student_daily_meeting), meeting1, meeting4, meetings(:upcoming_calendar_meeting)], meetings

    assert_equal Meeting.upcoming_recurrent_meetings(meetings).first(Meeting::MEETINGS_COUNT_IN_UPCOMING_MEETINGS_WIDGET), Meeting.get_meetings_for_upcoming_widget(program, member1, member2)
  end

  def test_versioning
    time = Time.now.utc + 2.days    
    meeting = meetings(:f_mentor_mkr_student)
    assert meeting.versions.empty?
    new_params_array = [{topic: "new topic"}, {description: "new description"}, {location: "new location"}]
    new_params_array.each do |params|
      assert_no_difference "meeting.versions.size" do
        assert_no_difference "ChronusVersion.count" do
          meeting.update_attributes(params)
        end
      end
    end
    old_start_time = meeting.start_time
    old_duration = meeting.schedule.duration
    #versioning is done only when meeting time is update
    assert_difference "meeting.versions.size", 1 do
      assert_difference "ChronusVersion.count", 1 do
        meeting.update_meeting_time(old_start_time + 30.minutes, old_duration + 30.minutes, {updated_by_member: members(:f_mentor)})
      end
    end
  end

  def test_get_calendar_event_options
    time = Time.now.utc + 2.days
    meeting = create_meeting(start_time: time, end_time: time + 30.minutes, mentor_created_meeting: true, force_non_group_meeting: true)
    start_time = DateTime.localize(meeting.start_time.in_time_zone("America/Los_Angeles"), format: :full_date_full_time_cal_sync)
    end_time = DateTime.localize(meeting.end_time.in_time_zone("America/Los_Angeles"), format: :full_date_full_time_cal_sync)
    attendees = meeting.get_attendees_for_calendar_event
    topic = meeting.topic
    meeting.stubs(:get_meeting_description_for_calendar_event).returns("This is a description of the meeting")
    description = "This is a description of the meeting"
    location = meeting.location
    scheduling_email = meeting.get_scheduling_email

    Meeting.any_instance.stubs(:meeting_time_zone).returns("America/Los_Angeles")

    options = meeting.get_calendar_event_options
    details = {
      id: meeting.get_calendar_event_uid,
      start_time: start_time,
      end_time: end_time,
      attendees: attendees,
      topic: topic,
      description: description,
      location: location,
      guests_can_see_other_guests: meeting.guests_can_see_other_guests?,
      sequence: meeting.ics_sequence,
      scheduling_assistant_email: scheduling_email,
      time_zone: "America/Los_Angeles"
    }
    assert_equal details, options

    meeting.update_attribute(:recurrent, true)

    Meeting.any_instance.stubs(:fetch_rrule).returns(["sample rrule"])
    options = meeting.get_calendar_event_options
    assert_equal ["RRULE:sample rrule"], options[:recurrence]

    Meeting.any_instance.stubs(:fetch_rrule).returns(["sample rrule", "sample exdates"])
    options = meeting.get_calendar_event_options
    assert_equal ["RRULE:sample rrule", "EXDATE:sample exdates"], options[:recurrence]
  end

  def test_sync_rsvp_with_calendar_event
    event = get_calendar_event_resource

    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: Time.now, end_time: Time.now + 30.minutes, calendar_event_id: event.id)
    scheduling_account_email = meeting.scheduling_email
    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    student_member_meeting = meeting.member_meetings.find_by(member_id: members(:mkr_student).id)

    members(:f_mentor).mark_attending!(meeting, {:perform_sync_to_calendar => false, :attending => MemberMeeting::ATTENDING::NO})
    members(:mkr_student).mark_attending!(meeting, {:perform_sync_to_calendar => false, :attending => MemberMeeting::ATTENDING::YES})

    Meeting.any_instance.stubs(:can_be_synced?).returns(false)

    Meeting.sync_rsvp_with_calendar_event(event, scheduling_account_email)

    assert_equal MemberMeeting::ATTENDING::NO, mentor_member_meeting.reload.attending
    assert_equal MemberMeeting::ATTENDING::YES, student_member_meeting.reload.attending

    Meeting.any_instance.unstub(:can_be_synced?)
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)

    Meeting.sync_rsvp_with_calendar_event(event, scheduling_account_email)

    assert_equal MemberMeeting::ATTENDING::YES, mentor_member_meeting.reload.attending
    assert_equal MemberMeeting::ATTENDING::NO, student_member_meeting.reload.attending
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::CALENDAR, mentor_member_meeting.rsvp_change_source
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::CALENDAR, student_member_meeting.rsvp_change_source

    members(:f_mentor).mark_attending!(meeting, {:perform_sync_to_calendar => false, :attending => MemberMeeting::ATTENDING::NO})
    members(:mkr_student).mark_attending!(meeting, {:perform_sync_to_calendar => false, :attending => MemberMeeting::ATTENDING::YES})

    Meeting.sync_rsvp_with_calendar_event(event, "different_account@chronus.com")

    assert_equal MemberMeeting::ATTENDING::NO, mentor_member_meeting.reload.attending
    assert_equal MemberMeeting::ATTENDING::YES, student_member_meeting.reload.attending
  end

  def test_perform_sync_from_calendar_to_app
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    scheduling_account_email = "test_apollo_services@chronus.com"

    occurrence_start_time = meeting.first_occurrence
    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    mentor_member_meeting_occurrence_response = mentor_member_meeting.member_meeting_responses.find_by(meeting_occurrence_time: occurrence_start_time)

    first_occurrence_timestamp = DateTime.localize(mentor_member_meeting_occurrence_response.meeting_occurrence_time, format: :ics_full_time)
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    event = get_calendar_event_resource

    Meeting.expects(:sync_rsvp_with_calendar_event).with(event, scheduling_account_email).once
    Meeting.perform_rsvp_sync_from_calendar_to_app([event], scheduling_account_email)

    event = get_calendar_event_resource({id: "calendar_event_id_#{first_occurrence_timestamp}", recurring_event_id: "calendar_event_id"})
    meeting.update_attributes(:calendar_event_id => event.recurring_event_id, :scheduling_email => scheduling_account_email)
    occurrence_start_time = Meeting.get_recurring_event_start_time(event)
    occurrence_time_response_hash = {members(:f_mentor).id=>{}, members(:mkr_student).id=>{occurrence_start_time=>MemberMeeting::ATTENDING::NO}}

    Meeting.any_instance.expects(:handle_sync_for_recurring_event).with(occurrence_time_response_hash).once
    Meeting.perform_rsvp_sync_from_calendar_to_app([event], scheduling_account_email)

    meeting.update_attribute(:scheduling_email, "different_account@chronus.com")
    Meeting.any_instance.expects(:handle_sync_for_recurring_event).with(occurrence_time_response_hash).never
    Meeting.perform_rsvp_sync_from_calendar_to_app([event], scheduling_account_email)
  end

  def test_perform_sync_for_non_recurring_events
    event = get_calendar_event_resource
    scheduling_account_email = "test_apollo_services@chronus.com"

    Meeting.expects(:sync_rsvp_with_calendar_event).with(event, scheduling_account_email).once
    Meeting.perform_sync_for_non_recurring_events([event], scheduling_account_email)
  end

  def test_perform_sync_for_recurring_events
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    scheduling_account_email = "test_apollo_services@chronus.com"

    occurrence_start_time = meeting.first_occurrence
    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    mentor_member_meeting_occurrence_response = mentor_member_meeting.member_meeting_responses.find_by(meeting_occurrence_time: occurrence_start_time)

    first_occurrence_timestamp = DateTime.localize(mentor_member_meeting_occurrence_response.meeting_occurrence_time, format: :ics_full_time)
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)


    event = get_calendar_event_resource({id: "calendar_event_id_#{first_occurrence_timestamp}", recurring_event_id: "calendar_event_id"})
    meeting.update_attributes(:calendar_event_id => event.recurring_event_id, :scheduling_email => scheduling_account_email)
    occurrence_start_time = Meeting.get_recurring_event_start_time(event)
    occurrence_time_response_hash = {members(:f_mentor).id=>{}, members(:mkr_student).id=>{occurrence_start_time=>MemberMeeting::ATTENDING::NO}}

    Meeting.any_instance.expects(:handle_sync_for_recurring_event).with(occurrence_time_response_hash).once
    Meeting.perform_sync_for_recurring_events([event], scheduling_account_email)

    Meeting.any_instance.expects(:handle_sync_for_recurring_event).with(occurrence_time_response_hash).never
    Meeting.perform_sync_for_recurring_events([event], "different_account@chronus.com")
  end

  def test_get_recurring_event_id
    event = get_calendar_event_resource
    assert_nil Meeting.get_recurring_event_id(event)
    event = get_calendar_event_resource({id: "event_id", recurring_event_id: "calendar_event_id"})
    assert_equal "calendar_event_id", Meeting.get_recurring_event_id(event)
    event = get_calendar_event_resource({id: "event_id", recurring_event_id: "calendar_event_id_R20170708T103020"})
    assert_equal "calendar_event_id", Meeting.get_recurring_event_id(event)

    event.stubs(:recurring_event_id).raises(->{StandardError.new("Some error")})
    assert_difference "CalendarSyncErrorCases.count", 1 do
      Meeting.get_recurring_event_id(event)
    end

    error_case = CalendarSyncErrorCases.last
    assert_equal CalendarSyncErrorCases::ScenarioType::FETCH_RECURRENT_ID, error_case.scenario
    assert_equal_unordered [:event_id, :error_message], error_case.details.keys
  end

  def test_handle_sync_for_recurring_events
    #individual occurrences
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    occurrence_start_time = meeting.first_occurrence
    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    student_member_meeting = meeting.member_meetings.find_by(member_id: members(:mkr_student).id)
    mentor_member_meeting_occurrence_response = mentor_member_meeting.member_meeting_responses.find_by(meeting_occurrence_time: occurrence_start_time)
    members(:f_mentor).mark_attending_for_an_occurrence!(meeting, MemberMeeting::ATTENDING::NO, occurrence_start_time)

    mentor_member_meeting_occurrence_response.reload
    assert_equal MemberMeeting::ATTENDING::NO, mentor_member_meeting_occurrence_response.attending

    first_occurrence_timestamp = DateTime.localize(mentor_member_meeting_occurrence_response.meeting_occurrence_time, format: :ics_full_time)
    event = get_calendar_event_resource({id: "calendar_event_id_#{first_occurrence_timestamp}", recurring_event_id: "calendar_event_id"})
    occurrence_start_time = Meeting.get_recurring_event_start_time(event)
    meeting.update_column(:calendar_event_id, event.recurring_event_id)
    occurrence_time_response_hash = {members(:f_mentor).id=>{occurrence_start_time=>MemberMeeting::ATTENDING::YES}, members(:mkr_student).id=>{occurrence_start_time=>MemberMeeting::ATTENDING::YES}}

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    meeting.handle_sync_for_recurring_event(occurrence_time_response_hash)
    mentor_member_meeting_occurrence_response.reload
    assert_equal MemberMeeting::ATTENDING::YES, mentor_member_meeting_occurrence_response.attending
    assert_equal MemberMeeting::ATTENDING::YES, student_member_meeting.member_meeting_responses.find_by(meeting_occurrence_time: occurrence_start_time).attending
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::CALENDAR, mentor_member_meeting_occurrence_response.rsvp_change_source

    #all occurrences
    meeting.occurrences.each do |occurrence_time|
      occurrence_time_response_hash[members(:f_mentor).id][occurrence_time] = MemberMeeting::ATTENDING::YES
    end
    Meeting.any_instance.expects(:handle_sync_for_all_occurrences).with(members(:f_mentor), occurrence_time_response_hash[members(:f_mentor).id]).once
    meeting.handle_sync_for_recurring_event(occurrence_time_response_hash)
  end

  def test_build_meeting_occurrence_response_hash
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    occurrence_start_time = meeting.first_occurrence
    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    mentor_member_meeting_occurrence_response = mentor_member_meeting.member_meeting_responses.find_by(meeting_occurrence_time: occurrence_start_time)

    first_occurrence_timestamp = DateTime.localize(mentor_member_meeting_occurrence_response.meeting_occurrence_time, format: :ics_full_time)
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)


    event = get_calendar_event_resource({id: "calendar_event_id_#{first_occurrence_timestamp}", recurring_event_id: "calendar_event_id"})
    meeting.update_column(:calendar_event_id, event.recurring_event_id)
    occurrence_start_time = Meeting.get_recurring_event_start_time(event)
    occurrence_time_response_hash = {members(:f_mentor).id=>{}, members(:mkr_student).id=>{occurrence_start_time=>MemberMeeting::ATTENDING::NO}}
    assert_equal occurrence_time_response_hash, meeting.build_meeting_occurrence_response_hash([event])
    event.attendees.find{|attendee|attendee.email == members(:mkr_student).email}.response_status = "no_response"
    occurrence_time_response_hash = {members(:f_mentor).id=>{}, members(:mkr_student).id=>{}}
    assert_equal occurrence_time_response_hash, meeting.build_meeting_occurrence_response_hash([event])
  end

  def test_initialize_occurrence_time_response_hash
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    response_hash = {members(:f_mentor).id => {}, members(:mkr_student).id => {}}
    assert_equal response_hash, meeting.initialize_occurrence_time_response_hash
  end

  def test_get_member_for_event_attendee
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    member_meeting_hash = meeting.member_meetings.group_by(&:member)
    event = get_calendar_event_resource({id: "event_id", recurring_event_id: "calendar_event_id"})
    event_attendee = event.attendees.first
    assert_equal members(:f_mentor), meeting.get_member_for_event_attendee(event_attendee.email, member_meeting_hash)
  end

  def test_get_event_occurrence_rsvp
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    event = get_calendar_event_resource({id: "event_id", recurring_event_id: "calendar_event_id"})
    event_attendee = event.attendees.first
    assert_equal MemberMeeting::ATTENDING::YES, meeting.get_event_occurrence_rsvp(event_attendee)
  end

  def test_handle_sync_for_all_occurrences
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    first_occurrence_start_time = meeting.first_occurrence
    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)

    attendee_occurrence_time_response_hash = {}
    meeting.occurrences.collect{|occurrence|Time.zone.parse(occurrence.to_s)}.each do |occurrence_time|
      attendee_occurrence_time_response_hash[occurrence_time] = MemberMeeting::ATTENDING::NO
    end
    attendee_occurrence_time_response_hash[first_occurrence_start_time] = MemberMeeting::ATTENDING::YES

    assert_equal MemberMeeting::ATTENDING::YES, mentor_member_meeting.attending
    meeting.handle_sync_for_all_occurrences(members(:f_mentor), attendee_occurrence_time_response_hash)

    assert_equal MemberMeeting::ATTENDING::NO, mentor_member_meeting.reload.attending
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::CALENDAR, mentor_member_meeting.rsvp_change_source
    mentor_member_meeting_first_occurrence_response = mentor_member_meeting.member_meeting_responses.find_by(meeting_occurrence_time: first_occurrence_start_time)
    assert_equal MemberMeeting::ATTENDING::YES, mentor_member_meeting_first_occurrence_response.attending
    assert_equal 1, mentor_member_meeting.member_meeting_responses.size
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::CALENDAR, mentor_member_meeting_first_occurrence_response.rsvp_change_source

    #when number of mails to send is greater than threshold, we just skip the mail and update rsvp

    Meeting.any_instance.stubs(:archived?).returns(false)
    MemberMeetingResponse.any_instance.expects(:send_rsvp_mail).never
    CalendarSyncErrorCases.expects(:create_error_case).once

    change_const_of(Meeting, :MAXIMUM_NUMBER_OF_SYNC_EMAILS, 1) do
      occurrence_time_response_hash = {members(:f_mentor).id => {}}
      meeting.occurrences.first(2).each do |occurrence_time|
        occurrence_time_response_hash[members(:f_mentor).id][occurrence_time] = MemberMeeting::ATTENDING::YES
      end
      meeting.handle_sync_for_all_occurrences(members(:f_mentor), occurrence_time_response_hash[members(:f_mentor).id])
    end
  end

  def test_sync_rsvp_for_event_occurrences
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    first_occurrence_start_time = meeting.first_occurrence
    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    occurrence_response = mentor_member_meeting.member_meeting_responses.first
    assert_equal MemberMeeting::ATTENDING::YES, occurrence_response.attending
    meeting.sync_rsvp_for_event_occurrences({occurrence_response.meeting_occurrence_time => MemberMeeting::ATTENDING::NO}, mentor_member_meeting, members(:f_mentor))
    assert_equal MemberMeeting::ATTENDING::NO, occurrence_response.reload.attending

    assert_equal MemberMeeting::ATTENDING::YES, mentor_member_meeting.attending
    meeting.sync_rsvp_for_event_occurrences({occurrence_response.meeting_occurrence_time => MemberMeeting::ATTENDING::YES}, mentor_member_meeting, members(:f_mentor), {mark_all_occurrences: true, response_to_update: MemberMeeting::ATTENDING::NO})
    assert_equal MemberMeeting::ATTENDING::YES, mentor_member_meeting.member_meeting_responses.find_by(meeting_occurrence_time: occurrence_response.meeting_occurrence_time).attending
    assert_equal MemberMeeting::ATTENDING::NO, mentor_member_meeting.reload.attending
  end

  def test_get_meeting_occurrences_start_times
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    occurrences = meeting.occurrences.collect{|occurrence|Time.zone.parse(occurrence.to_s)}
    assert_equal occurrences, meeting.get_meeting_occurrences_start_times
  end

  def test_get_maximum_occurring_response
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    attendee_occurrence_time_response_hash = {}
    meeting.occurrences.collect{|occurrence|Time.zone.parse(occurrence.to_s)}.each do |occurrence_time|
      attendee_occurrence_time_response_hash[occurrence_time] = MemberMeeting::ATTENDING::NO
    end
    assert_equal MemberMeeting::ATTENDING::NO, meeting.get_maximum_occurring_response(attendee_occurrence_time_response_hash)
    meeting.occurrences.first(10).collect{|occurrence|Time.zone.parse(occurrence.to_s)}.each do |occurrence_time|
      attendee_occurrence_time_response_hash[occurrence_time] = MemberMeeting::ATTENDING::YES
    end
    assert_equal MemberMeeting::ATTENDING::YES, meeting.get_maximum_occurring_response(attendee_occurrence_time_response_hash)
  end

  def test_get_meetings_to_render_in_home_page_widget
    member = members(:f_mentor)
    program = programs(:albers)

    current_time = Time.now
    Time.stubs(:now).returns(current_time)

    start_time = current_time.in_time_zone(member.get_valid_time_zone)
    end_time = start_time.end_of_day + Meeting::FLASH_WIDGET_MEETING_END_TIME

    meeting1 = meetings(:f_mentor_mkr_student)
    meeting1.update_attribute(:start_time, end_time.utc - 1.hour)

    Meeting.stubs(:get_meetings_for_view).with(nil, nil, member, program).returns(Meeting.where(id: meeting1.id))

    Meeting.stubs(:upcoming_recurrent_meetings).with([meeting1]).returns([meeting1])

    Meeting.stubs(:has_attendance_more_than).with([meeting1], Meeting::MIN_ATTENDEES_PRESENT_IN_FLASH_WIDGET_MEETS).returns("meetings to render")

    assert_equal "meetings to render", Meeting.get_meetings_to_render_in_home_page_widget(member, program)
  end

  def test_get_minimum_individual_occurrences_for_rsvp_update
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    attendee_occurrence_time_response_hash = {}
    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    meeting.occurrences.first(3).collect{|occurrence|Time.zone.parse(occurrence.to_s)}.each do |occurrence_time|
      attendee_occurrence_time_response_hash[occurrence_time] = MemberMeeting::ATTENDING::NO
    end
    original_response_hash = attendee_occurrence_time_response_hash.deep_dup
    meeting.occurrences.collect{|occurrence|Time.zone.parse(occurrence.to_s)}.each do |occurrence_time|
      attendee_occurrence_time_response_hash[occurrence_time] = MemberMeeting::ATTENDING::YES unless attendee_occurrence_time_response_hash[occurrence_time].present?
    end
    assert_equal [original_response_hash, false], meeting.get_minimum_individual_occurrences_for_rsvp_update(original_response_hash, attendee_occurrence_time_response_hash, MemberMeeting::ATTENDING::NO)

    mentor_member_meeting.member_meeting_responses.delete_all
    meeting.occurrences.collect{|occurrence|Time.zone.parse(occurrence.to_s)}.each do |occurrence_time|
      attendee_occurrence_time_response_hash[occurrence_time] = MemberMeeting::ATTENDING::NO
    end
    attendee_occurrence_time_response_hash[meeting.first_occurrence] = MemberMeeting::ATTENDING::YES
    assert_equal [{meeting.first_occurrence => MemberMeeting::ATTENDING::YES}, true], meeting.get_minimum_individual_occurrences_for_rsvp_update(attendee_occurrence_time_response_hash, attendee_occurrence_time_response_hash, MemberMeeting::ATTENDING::NO)
  end


  def test_get_attendees_for_calendar_event
    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: Time.now, end_time: Time.now + 30.minutes)

    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    student_member_meeting = meeting.member_meetings.find_by(member_id: members(:mkr_student).id)

    mentor_member_meeting.update_attribute(:attending, MemberMeeting::ATTENDING::NO_RESPONSE)
    student_member_meeting.update_attribute(:attending, MemberMeeting::ATTENDING::YES)

    assert_equal_unordered [{email: "robert@example.com", response_status: "needsAction", display_name: members(:f_mentor).name}, {email: "mkr@example.com", response_status: "accepted", display_name: members(:mkr_student).name}], meeting.reload.get_attendees_for_calendar_event

    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    occurrence_start_time = meeting.first_occurrence
    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    mentor_member_meeting_occurrence_response = mentor_member_meeting.member_meeting_responses.find_by(meeting_occurrence_time: occurrence_start_time)
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)

    guests_details = [{email: "robert@example.com", response_status: "accepted", display_name: members(:f_mentor).name}, {email: "mkr@example.com", response_status: "needsAction", display_name: members(:mkr_student).name}]
    assert_equal guests_details, meeting.get_attendees_for_calendar_event( current_occurrence_time: occurrence_start_time)
    members(:f_mentor).mark_attending_for_an_occurrence!(meeting, MemberMeeting::ATTENDING::NO, occurrence_start_time)
    meeting.reload
    guests_details = [{email: "robert@example.com", response_status: "declined", display_name: members(:f_mentor).name}, {email: "mkr@example.com", response_status: "needsAction", display_name: members(:mkr_student).name}]
    assert_equal guests_details, meeting.get_attendees_for_calendar_event( current_occurrence_time: occurrence_start_time)
  end

  def test_update_calendar_event_rsvp
    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: Time.now, end_time: Time.now + 30.minutes, calendar_event_id: "calendar_event_id")

    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    student_member_meeting = meeting.member_meetings.find_by(member_id: members(:mkr_student).id)

    mentor_member_meeting.update_attribute(:attending, MemberMeeting::ATTENDING::NO_RESPONSE)
    student_member_meeting.update_attribute(:attending, MemberMeeting::ATTENDING::YES)
    api = mock()
    api.stubs(:update_calendar_event).returns(nil)
    Calendar::GoogleApi.stubs(:new).returns(api)

    Meeting.any_instance.stubs(:meeting_time_zone).returns("America/Los_Angeles")

    options = {attendees: meeting.reload.get_attendees_for_calendar_event, description: meeting.get_meeting_description_for_calendar_event, time_zone: "America/Los_Angeles"}

    api.expects(:update_calendar_event).with(options, "calendar_event_id").once

    Meeting.update_calendar_event_rsvp(meeting.id)

    meeting.update_attribute(:calendar_event_id, nil)

    Meeting.update_calendar_event_rsvp(meeting.id)

    meeting.false_destroy!

    Meeting.update_calendar_event_rsvp(meeting.id)
  end

  def test_send_update_email_for_recurring_meeting_deletion
    meeting = meetings(:f_mentor_mkr_student)
    meeting_occurrences = meeting.occurrences
    member_responses_hash = {}
    meeting.member_meetings.each { |member_meeting| member_responses_hash[member_meeting.member_id] = member_meeting.attending }
    Meeting.any_instance.expects(:send_update_email).with(member_responses_hash: member_responses_hash, updated_by_member_id: members(:f_mentor).id).once
    Meeting.send_update_email_for_recurring_meeting_deletion(meeting.id, members(:f_mentor).id)
  end

  def test_update_calendar_event_rsvp_for_single_occurrence
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    occurrence_start_time = meeting.first_occurrence
    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    student_member_meeting = meeting.member_meetings.find_by(member_id: members(:mkr_student).id)
    mentor_member_meeting_occurrence_response = mentor_member_meeting.member_meeting_responses.find_by(meeting_occurrence_time: occurrence_start_time)
    members(:f_mentor).mark_attending_for_an_occurrence!(meeting, MemberMeeting::ATTENDING::NO, occurrence_start_time)
    members(:mkr_student).mark_attending_for_an_occurrence!(meeting, MemberMeeting::ATTENDING::YES, occurrence_start_time)

    Meeting.any_instance.stubs(:meeting_time_zone).returns("America/Los_Angeles")

    members(:mkr_student).reload
    mentor_member_meeting_occurrence_response.reload
    options = {attendees: meeting.get_attendees_for_calendar_event(current_occurrence_time: occurrence_start_time), description: meeting.get_meeting_description_for_calendar_event, time_zone: "America/Los_Angeles"}

    meeting.update_column(:calendar_event_id, "calendar_event_id")
    meeting.set_scheduling_email
    meeting.reload
    event_id = meeting.get_calendar_event_id({current_occurrence_time: occurrence_start_time})
    Calendar::GoogleApi.any_instance.expects(:update_calendar_event).with(options, event_id).once
    Meeting.update_calendar_event_rsvp(meeting.id, {current_occurrence_time: occurrence_start_time})
  end

  def test_remove_calendar_event
    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: Time.now, end_time: Time.now + 30.minutes, calendar_event_id: "calendar_event_id")

    meeting.update_attribute(:active, false)

    api = mock()
    api.stubs(:remove_calendar_event).returns(nil)
    api.expects(:remove_calendar_event).with("calendar_event_id").once
    Calendar::GoogleApi.stubs(:new).returns(api)

    Meeting.remove_calendar_event(meeting.id)
  end

  def test_start_rsvp_sync
    scheduling_account = scheduling_accounts(:scheduling_account_1)
    channel = CalendarSyncNotificationChannel.create!(channel_id: "channelId", resource_id: "resourceId", expiration_time: Time.now, scheduling_account_id: scheduling_account.id)

    current_time = Time.now
    Time.stubs(:now).returns(current_time)

    api = mock()
    api.stubs(:perform_rsvp_sync).returns(nil)
    api.expects(:perform_rsvp_sync).with(current_time, channel).once
    Calendar::GoogleApi.stubs(:new).returns(api)

    Meeting.start_rsvp_sync(current_time, channel)
  end

  def test_start_rsvp_sync_for_different_channels
    channel = CalendarSyncNotificationChannel.create!(channel_id: "channelId", resource_id: "resourceId", expiration_time: Time.now)

    current_time = Time.now
    Time.stubs(:now).returns(current_time)

    Meeting.stubs(:start_rsvp_sync).with(current_time, channel).returns("calling start_rsvp_sync for #{channel.id}")

    assert_equal "calling start_rsvp_sync for #{channel.id}", Meeting.send("start_rsvp_sync_#{channel.id}", current_time)
  end

  def test_send_update_emails_and_update_calendar_event
    meeting1 = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: Time.now, end_time: Time.now + 30.minutes, calendar_event_id: "calendar_event_id_1")
    meeting2 = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: Time.now, end_time: Time.now + 30.minutes, calendar_event_id: "calendar_event_id_1")

    member_responses_hash_1 = {}
    meeting1.member_meetings.each { |member_meeting| member_responses_hash_1[member_meeting.member_id] = member_meeting.attending }

    member_responses_hash_2 = {}
    meeting2.member_meetings.each { |member_meeting| member_responses_hash_2[member_meeting.member_id] = member_meeting.attending }

    Meeting.stubs(:handle_update_calendar_event).returns(nil)
    Meeting.any_instance.stubs(:can_be_synced?).returns(false)
    Meeting.expects(:handle_update_calendar_event).never
    assert_emails do
      Meeting.send_update_emails_and_update_calendar_event(meeting1.id, meeting2.id, {member_responses_hash: member_responses_hash_1, updated_by_member_id: members(:f_mentor).id})
    end
    assert_emails do
      Meeting.send_update_emails_and_update_calendar_event(meeting1.id, meeting1.id, {member_responses_hash: member_responses_hash_1, updated_by_member_id: members(:f_mentor).id})
    end

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    Meeting.expects(:handle_update_calendar_event).times(3)
    assert_emails 2 do
      Meeting.send_update_emails_and_update_calendar_event(meeting1.id, meeting1.id, {member_responses_hash: member_responses_hash_1, updated_by_member_id: members(:f_mentor).id})
    end
    assert_emails 4 do
      Meeting.send_update_emails_and_update_calendar_event(meeting1.id, meeting2.id, {member_responses_hash: member_responses_hash_2, updated_by_member_id: members(:f_mentor).id})
    end
  end

  def test_send_rsvp_sync_notification_failure_mail
    meeting = meetings(:f_mentor_mkr_student)
    rsvp_change_user = users(:f_mentor)

    assert_equal 1, meeting.get_coparticipants(rsvp_change_user).count
    assert_emails 0 do
      Meeting.send_rsvp_sync_notification_failure_mail(-1, rsvp_change_user)
    end
    assert_emails 1 do
      Meeting.send_rsvp_sync_notification_failure_mail(meeting.id, rsvp_change_user)
    end
  end

  def test_create_calendar_event_for_event_creation_failure
    meeting = meetings(:f_mentor_mkr_student)

    assert_nil meeting.calendar_event_id

    options = {description: "Meeting description"}
    Meeting.any_instance.stubs(:get_calendar_event_options).returns(options)

    api = mock()
    api.stubs(:insert_calendar_event).returns(nil)
    api.expects(:insert_calendar_event).with(options).once
    Calendar::GoogleApi.stubs(:new).returns(api)

    meeting.create_calendar_event
    assert_nil meeting.reload.calendar_event_id
  end

  def test_handle_update_calendar_event
    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: Time.now, end_time: Time.now + 30.minutes, calendar_event_id: "calendar_event_id")

    options = {description: "Meeting description"}

    api = mock()
    api.stubs(:update_calendar_event).returns(nil)
    api.stubs(:create_calendar_event).returns(nil)
    api.expects(:update_calendar_event).with(options, "calendar_event_id").once
    Calendar::GoogleApi.stubs(:new).returns(api)

    Meeting.any_instance.stubs(:get_calendar_event_options).returns(options)

    Meeting.handle_update_calendar_event(meeting.id)

    meeting.update_attribute(:calendar_event_id, nil)

    Meeting.any_instance.expects(:create_calendar_event).never

    Meeting.handle_update_calendar_event(meeting.id)

    meeting.false_destroy!

    Meeting.handle_update_calendar_event(meeting.id)
  end

  def test_synchronizable
    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: Time.now, end_time: Time.now + 30.minutes)

    assert meeting.active?
    assert_false meeting.program.calendar_sync_enabled?
    assert_false meeting.calendar_time_available?

    assert_false meeting.synchronizable?(false)

    Program.any_instance.stubs(:calendar_sync_enabled?).returns(true)
    assert_false meeting.synchronizable?(false)

    meeting.update_attribute(:calendar_time_available, true)
    assert meeting.synchronizable?(false)

    Program.any_instance.stubs(:calendar_sync_enabled?).returns(false)
    assert_false meeting.synchronizable?(false)

    Program.any_instance.stubs(:calendar_sync_enabled?).returns(true)

    meeting.update_attribute(:active, false)
    assert_false meeting.synchronizable?(false)

    assert meeting.synchronizable?(true)

    meeting.update_attribute(:active, true)
    assert meeting.synchronizable?(false)
  end

  def test_get_calendar_event_id
    time = Time.now.utc + 2.days
    meeting = create_meeting(start_time: time, end_time: time + 30.minutes, mentor_created_meeting: true, force_non_group_meeting: true, description: "calendar event in Google", calendar_event_id: "event_id")
    assert_equal meeting.calendar_event_id, meeting.get_calendar_event_id
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    occurrence_start_time = meeting.first_occurrence
    parsed_start_time = DateTime.localize(occurrence_start_time.utc, format: :ics_full_time)
    meeting.update_column(:calendar_event_id, "event_id")
    assert_equal "event_id", meeting.get_calendar_event_id
    assert_equal "event_id_#{parsed_start_time}Z", meeting.get_calendar_event_id(current_occurrence_time: occurrence_start_time)
  end

  def test_get_meeting_edit_and_update_link
    time = Time.now.utc + 2.days
    meeting = create_meeting(start_time: time, end_time: time + 30.minutes, mentor_created_meeting: true, force_non_group_meeting: true, description: "calendar event in Google")
    meeting_links_hash = meeting.get_meeting_edit_and_update_link(meeting.first_occurrence, meeting.program)
    meeting_link = "http://#{meeting.program.organization.subdomain}.#{meeting.program.organization.domain}/p/#{meeting.program.root}/meetings/#{meeting.id}?current_occurrence_time=#{CGI.escape(meeting.first_occurrence.to_s)}"
    assert_equal meeting_link, meeting_links_hash[:meeting_link]
    assert_equal meeting_link+"&open_edit_popup=true", meeting_links_hash[:edit_meeting_link]
  end

  def test_get_meeting_description_for_calendar_event
    time = Time.now.utc + 2.days
    meeting = create_meeting(start_time: time, end_time: time + 30.minutes, mentor_created_meeting: true, force_non_group_meeting: true, description: "calendar event in Google")
    meeting.expects(:get_attendees_for_meeting_description).once.returns("Attendee Text for Meeting")
    meeting.expects(:get_action_links_for_non_recurrent_meeting_description).once.returns("Action Link for Meeting \n https://www.chronus.com")
    desc = meeting.get_meeting_description_for_calendar_event
    assert_match /calendar event in Google/, desc
    assert_match /Attendee Text for Meeting/, desc
    assert_match /Action Link for Meeting \n https:\/\/www.chronus.com/, desc
    assert_match /Message description:/, desc
    assert_match /Attendees:/, desc
    meeting.expects(:get_attendees_for_meeting_description).once.returns("Attendee Text for Meeting")
    meeting.expects(:get_action_links_for_non_recurrent_meeting_description).once.returns("Action Link for Meeting \n https://www.chronus.com")
    meeting.update_attribute(:description, "")
    desc = meeting.get_meeting_description_for_calendar_event
    assert_no_match(/Message description:/, desc)
  end

  def test_get_attendees_for_meeting_description
    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: Time.now, end_time: Time.now + 30.minutes)

    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)

    name1 = members(:f_mentor).name
    name2 = members(:mkr_student).name

    desc = meeting.get_attendees_for_meeting_description

    assert_match /\n#{name1}/, desc
    assert_match /\n#{name2}/, desc

    mentor_member_meeting.update_attribute(:attending, MemberMeeting::ATTENDING::NO)

    desc = meeting.reload.get_attendees_for_meeting_description

    assert_no_match(/\n#{name1}/, desc)
    assert_match /\n#{name2}/, desc
  end

  def test_get_action_links_for_meeting_description
    meeting = meetings(:past_psg_mentor_psg_student)
    user = users(:psg_mentor1)
    meeting.stubs(:can_be_edited_by_member?).with(user.member).returns(true)
    meeting.stubs(:first_occurrence).returns("2017-06-14 00:00:00 +0530")
    desc = meeting.get_action_links_for_non_recurrent_meeting_description(user)
    assert_match /To go to the meeting area/, desc
    assert_match /http:\/\/#{meeting.program.url}\/meetings\/#{meeting.id}\?current_occurrence_time=/, desc
    assert_match /2017-06-14\+00\%3A00\%3A00\+\%2B0530/, desc
    assert_match /To reschedule the meeting/, desc
    assert_match /http:\/\/#{meeting.program.url}\/meetings\/#{meeting.id}\?current_occurrence_time=2017-06-14\+00\%3A00\%3A00\+\%2B0530\&open_edit_popup=true/, desc

    meeting.stubs(:can_be_edited_by_member?).with(user.member).returns(false)
    desc = meeting.get_action_links_for_non_recurrent_meeting_description(user)
    assert_match /To go to the meeting area/, desc
    assert_match /http:\/\/#{meeting.program.url}\/meetings\/#{meeting.id}\?current_occurrence_time=/, desc
    assert_match /2017-06-14\+00\%3A00\%3A00\+\%2B0530/, desc
    assert_no_match /To reschedule the meeting/, desc
    assert_no_match /http:\/\/#{meeting.program.url}\/meetings\/#{meeting.id}\?current_occurrence_time=2017-06-14\+00\%3A00\%3A00\+\%2B0530\&open_edit_popup=true/, desc

    meeting.stubs(:can_be_edited_by_member?).with(nil).returns(false)
    desc = meeting.get_action_links_for_non_recurrent_meeting_description
    assert_match /To go to the meeting area/, desc
    assert_match /http:\/\/#{meeting.program.url}\/meetings\/#{meeting.id}\?current_occurrence_time=/, desc
    assert_match /2017-06-14\+00\%3A00\%3A00\+\%2B0530/, desc
    assert_no_match /To reschedule the meeting/, desc
    assert_no_match /http:\/\/#{meeting.program.url}\/meetings\/#{meeting.id}\?current_occurrence_time=2017-06-14\+00\%3A00\%3A00\+\%2B0530\&open_edit_popup=true/, desc
  end

  def test_add_exception_rule_at
    # Intentionally testing with dst times
    Time.stubs(:zone).returns(ActiveSupport::TimeZone.new("America/New_York"))
    end_date = "Thu, 27 Jul 2017".to_date
    meeting = create_meeting(
      start_time: "Thu, 23 Feb 2017".to_date.beginning_of_day,
      end_time: end_date.beginning_of_day,
      recurrent: true,
      schedule_rule: Meeting::Repeats::WEEKLY,
      repeat_every: "1",
      repeats_end_date: end_date,
      duration: 30.minutes
    )

    exception_time_str = "2017-03-23 00:00:00 -0400"
    exception_time = exception_time_str.to_datetime
    assert meeting.occurrences.include? exception_time

    assert_equal exception_time, meeting.add_exception_rule_at(exception_time_str)
    assert_false meeting.occurrences.include? exception_time
  end

  def test_get_calendar_event_uid
    meeting = meetings(:f_mentor_mkr_student)
    meeting_created_at = DateTime.localize(meeting.created_at.utc, format: :ics_full_time)
    assert_equal "meeting_#{meeting_created_at}@chronus.com", meeting.get_calendar_event_uid
  end

  def test_get_meeting_messages_hash
    member = members(:f_mentor)
    all_messages = Meeting.get_unread_or_read_messages_hash(member, [meetings(:upcoming_calendar_meeting).id])
    unread_messages = Meeting.get_unread_messages_hash(member, [meetings(:upcoming_calendar_meeting).id])
    expected_hash = {all: all_messages, unread: unread_messages}
    assert_equal expected_hash, Meeting.get_meeting_messages_hash(members(:f_mentor), [{meeting: meetings(:upcoming_calendar_meeting)}, {meeting: meetings(:f_mentor_mkr_student)}])
  end

  def test_get_scheduling_email
    meeting = meetings(:f_mentor_mkr_student)
    assert_nil meeting.get_scheduling_email
    meeting.update_column(:scheduling_email, "scheduling_email@test.realizegoal.com")
    assert_equal "scheduling_email@test.realizegoal.com", meeting.get_scheduling_email
  end

  def test_set_scheduling_email
    meeting = meetings(:f_mentor_mkr_student)
    meeting.update_column(:scheduling_email, nil)
    active_scheduling_emails = SchedulingAccount.active.pluck(:email)
    meeting.set_scheduling_email
    assert active_scheduling_emails.include?(meeting.scheduling_email)
  end

  def test_get_unread_or_read_messages_hash
    flash_meeting = meetings(:upcoming_calendar_meeting)
    member = members(:f_mentor)
    expected_hash = {}
    assert_equal expected_hash, Meeting.get_unread_or_read_messages_hash(member, [flash_meeting.id])
    scrap = create_scrap(group: flash_meeting, sender: members(:mkr_student))
    expected_hash = {flash_meeting.id => 1}
    assert_equal expected_hash, Meeting.get_unread_or_read_messages_hash(member, [flash_meeting.id])

    create_scrap(group: flash_meeting, sender: members(:mkr_student), parent_id: scrap.id)
    assert_equal expected_hash, Meeting.get_unread_or_read_messages_hash(member, [flash_meeting.id])

    create_scrap(group: flash_meeting, sender: members(:f_mentor))
    expected_hash = {flash_meeting.id => 2}
    assert_equal expected_hash, Meeting.get_unread_or_read_messages_hash(member, [flash_meeting.id])

    create_scrap(group: flash_meeting, sender: members(:mkr_student))
    expected_hash = {flash_meeting.id => 3}
    assert_equal expected_hash, Meeting.get_unread_or_read_messages_hash(member, [flash_meeting.id])

    flash_meeting_2 = meetings(:completed_calendar_meeting)
    create_scrap(group: flash_meeting_2, sender: members(:mkr_student))
    expected_hash = {flash_meeting.id => 3, flash_meeting_2.id => 1}
    assert_equal expected_hash, Meeting.get_unread_or_read_messages_hash(member, [flash_meeting.id, flash_meeting_2.id])
  end

  def test_get_unread_messages_hash
    flash_meeting = meetings(:upcoming_calendar_meeting)
    member = members(:f_mentor)
    expected_hash = {}
    assert_equal expected_hash, Meeting.get_unread_messages_hash(member, [flash_meeting.id])
    scrap = create_scrap(group: flash_meeting, sender: members(:mkr_student))
    expected_hash = {flash_meeting.id => 1}
    assert_equal expected_hash, Meeting.get_unread_messages_hash(member, [flash_meeting.id])

    create_scrap(group: flash_meeting, sender: members(:mkr_student), parent_id: scrap.id)
    assert_equal expected_hash, Meeting.get_unread_messages_hash(member, [flash_meeting.id])

    create_scrap(group: flash_meeting, sender: members(:f_mentor))
    assert_equal expected_hash, Meeting.get_unread_messages_hash(member, [flash_meeting.id])

    create_scrap(group: flash_meeting, sender: members(:mkr_student))
    expected_hash = {flash_meeting.id => 2}
    assert_equal expected_hash, Meeting.get_unread_messages_hash(member, [flash_meeting.id])

    flash_meeting_2 = meetings(:completed_calendar_meeting)
    create_scrap(group: flash_meeting_2, sender: members(:mkr_student))
    expected_hash = {flash_meeting.id => 2, flash_meeting_2.id => 1}
    assert_equal expected_hash, Meeting.get_unread_messages_hash(member, [flash_meeting.id, flash_meeting_2.id])
  end

  def test_get_meeting_notes_hash
    meeting = meetings(:f_mentor_mkr_student)
    member = members(:f_mentor)
    notes_hash = {meeting.id=>5}
    assert_equal notes_hash, Meeting.get_meeting_notes_hash([{meeting: meeting}])
    group_meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    note = PrivateMeetingNote.new_for(group_meeting, member, {:text => 'hello'})
    note.save
    notes_hash = {meeting.id=>5, group_meeting.id=>1}
    assert_equal notes_hash, Meeting.get_meeting_notes_hash([{meeting: meeting}, {meeting: group_meeting}])
  end

  def test_get_non_recurrent_meeting_ids_from_collection
    m1 = meetings(:upcoming_calendar_meeting)
    m2 = meetings(:f_mentor_mkr_student_daily_meeting)
    assert_equal [meetings(:upcoming_calendar_meeting).id], Meeting.get_non_group_meeting_ids_from_collection([{meeting: m1}, {meeting: m2}])
  end

  def test_get_meeting_by_event
    assert_equal meetings(:past_calendar_meeting), Meeting.get_meeting_by_event("calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(meetings(:past_calendar_meeting).id)}@testmg.realizegoal.com")

    assert_nil Meeting.get_meeting_by_event("calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(8888)}@testmg.realizegoal.com")
  end

  def test_get_email_address
    assert_equal "calendar-assistant-dev+1234@testmg.realizegoal.com", CalendarUtils.get_email_address("Apollo Services <calendar-assistant-dev+1234@testmg.realizegoal.com>")
    assert_equal "calendar-assistant-dev+1234@testmg", CalendarUtils.get_email_address("Apollo Services <calendar-assistant-dev+1234@testmg>")
    assert_raise Mail::Field::ParseError do
      CalendarUtils.get_email_address("Apollo Services <>")
    end
    assert_raise Mail::Field::ParseError do
      CalendarUtils.get_email_address("Apollo Services")
    end
  end

  def test_update_rsvp
    m1 = meetings(:upcoming_calendar_meeting)
    mm1 = member_meetings(:member_meetings_13)
    non_recurring_response = "BEGIN:VCALENDAR\nPRODID:-//Google Inc//Google Calendar 70.9054//EN\nVERSION:2.0\nCALSCALE:GREGORIAN\nMETHOD:REPLY\nBEGIN:VEVENT\nDTSTART:#{DateTime.localize(m1.start_time.utc, format: :ics_full_time)}\nDTEND:#{DateTime.localize(m1.end_time.utc, format: :ics_full_time)}\nDTSTAMP:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nORGANIZER;CN=Apollo Services:mailto:calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}\n @testmg.realizegoal.com\nUID:meeting_20171218T112713@chronus.com\nATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=DECLINED;CN=Arun K\n umar N;X-NUM-GUESTS=0:mailto:robert@example.com\nCREATED:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nDESCRIPTION:Message description\,\nLAST-MODIFIED:#{DateTime.localize(m1.updated_at.utc, format: :ics_full_time)}\nLOCATION:\nSEQUENCE:0\nSTATUS:CONFIRMED\nSUMMARY:as\nTRANSP:OPAQUE\nEND:VEVENT\nEND:VCALENDAR"

    event = Icalendar::Calendar.parse(non_recurring_response).first.events.first

    assert_equal MemberMeeting::ATTENDING::YES, mm1.attending
    m1.update_rsvp!(event)
    assert_equal MemberMeeting::ATTENDING::YES, mm1.reload.attending

    m1.expects(:can_be_synced?).returns(true)
    m1.update_rsvp!(event)
    assert_equal MemberMeeting::ATTENDING::NO, mm1.reload.attending

    m2 = meetings(:f_mentor_mkr_student_daily_meeting)
    mm2 = member_meetings(:member_meetings_11)
    until_date = m2.schedule.to_ical(true).split("\n").last.split(":").last

    recurring_response = "BEGIN:VCALENDAR\nPRODID:-//Google Inc//Google Calendar 70.9054//EN\nVERSION:2.0\nCALSCALE:GREGORIAN\nMETHOD:REPLY\nBEGIN:VEVENT\nDTSTART:#{DateTime.localize(m2.start_time.utc, format: :ics_full_time)}\nDTEND:#{DateTime.localize(m2.end_time.utc, format: :ics_full_time)}\nDTSTAMP:#{DateTime.localize(m2.created_at.utc, format: :ics_full_time)}\nORGANIZER;CN=Apollo Services:mailto:calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m2.id)}\n @testmg.realizegoal.com\nRRULE:FREQ=DAILY;UNTIL=#{until_date}\nUID:meeting_20171218T112713@chronus.com\nATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=DECLINED;CN=Arun K\n umar N;X-NUM-GUESTS=0:mailto:robert@example.com\nCREATED:#{DateTime.localize(m2.created_at.utc, format: :ics_full_time)}\nDESCRIPTION:Message description\,\nLAST-MODIFIED:#{DateTime.localize(m2.updated_at.utc, format: :ics_full_time)}\nLOCATION:\nSEQUENCE:0\nSTATUS:CONFIRMED\nSUMMARY:as\nTRANSP:OPAQUE\nEND:VEVENT\nEND:VCALENDAR"

    event = Icalendar::Calendar.parse(recurring_response).first.events.first
    assert_equal [MemberMeeting::ATTENDING::YES, MemberMeeting::ATTENDING::NO], mm2.member_meeting_responses.pluck(:attending).uniq
    assert_equal MemberMeeting::ATTENDING::YES, mm2.attending
    m2.expects(:can_be_synced?).times(1).returns(true)
    m2.update_rsvp!(event)
    assert_equal MemberMeeting::ATTENDING::NO, mm2.reload.attending
    assert_equal 0, mm2.member_meeting_responses.size

    m2.reload

    recurring_response_following_events = "BEGIN:VCALENDAR\nPRODID:-//Google Inc//Google Calendar 70.9054//EN\nVERSION:2.0\nCALSCALE:GREGORIAN\nMETHOD:REPLY\nBEGIN:VEVENT\nDTSTART:#{DateTime.localize(m2.start_time.utc + 2.days, format: :ics_full_time)}\nDTEND:#{DateTime.localize(m2.end_time.utc, format: :ics_full_time)}\nDTSTAMP:#{DateTime.localize(m2.created_at.utc, format: :ics_full_time)}\nORGANIZER;CN=Apollo Services:mailto:calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m2.id)}\n @testmg.realizegoal.com\nRRULE:FREQ=DAILY;UNTIL=#{until_date}\nUID:meeting_20171218T112713@chronus.com\nATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=ACCEPTED;CN=Arun K\n umar N;X-NUM-GUESTS=0:mailto:robert@example.com\nCREATED:#{DateTime.localize(m2.created_at.utc, format: :ics_full_time)}\nDESCRIPTION:Message description\,\nLAST-MODIFIED:#{DateTime.localize(m2.updated_at.utc, format: :ics_full_time)}\nLOCATION:\nSEQUENCE:0\nSTATUS:CONFIRMED\nSUMMARY:as\nTRANSP:OPAQUE\nEND:VEVENT\nEND:VCALENDAR" # 2.days

    event = Icalendar::Calendar.parse(recurring_response_following_events).first.events.first
    assert_equal MemberMeeting::ATTENDING::NO, mm2.reload.attending
    assert_equal 0, mm2.member_meeting_responses.size
    m2.expects(:can_be_synced?).times(3).returns(true)
    assert_difference 'MemberMeetingResponse.count', 2 do
      m2.update_rsvp!(event)
    end
    assert_equal [MemberMeeting::ATTENDING::NO], mm2.reload.member_meeting_responses.pluck(:attending).uniq
    assert_equal MemberMeeting::ATTENDING::YES, mm2.attending


    recurring_response_single_event = "BEGIN:VCALENDAR\nPRODID:-//Google Inc//Google Calendar 70.9054//EN\nVERSION:2.0\nCALSCALE:GREGORIAN\nMETHOD:REPLY\nBEGIN:VEVENT\nDTSTART:#{DateTime.localize(m2.start_time.utc + 4.days, format: :ics_full_time)}\nDTEND:#{DateTime.localize(m2.end_time.utc, format: :ics_full_time)}\nDTSTAMP:#{DateTime.localize(m2.created_at.utc, format: :ics_full_time)}\nORGANIZER;CN=Apollo Services:mailto:calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m2.id)}\n @testmg.realizegoal.com\nRECURRENCE-ID;TZID=Asia/Calcutta:#{DateTime.localize(m2.reload.occurrences[2].utc, format: :ics_full_time)}\nUID:meeting_20171218T112713@chronus.com\nATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=DECLINED;CN=Arun K\n umar N;X-NUM-GUESTS=0:mailto:robert@example.com\nCREATED:#{DateTime.localize(m2.created_at.utc, format: :ics_full_time)}\nDESCRIPTION:Message description\,\nLAST-MODIFIED:#{DateTime.localize(m2.updated_at.utc, format: :ics_full_time)}\nLOCATION:\nSEQUENCE:0\nSTATUS:CONFIRMED\nSUMMARY:as\nTRANSP:OPAQUE\nEND:VEVENT\nEND:VCALENDAR"

    event = Icalendar::Calendar.parse(recurring_response_single_event).first.events.first
    assert_difference 'MemberMeetingResponse.count', 1 do
      m2.update_rsvp!(event)
    end
    assert_equal MemberMeeting::ATTENDING::YES, mm2.reload.attending
    assert_equal [MemberMeeting::ATTENDING::NO], mm2.member_meeting_responses.pluck(:attending).uniq

    recurring_response_single_event_wrong_occurrence = "BEGIN:VCALENDAR\nPRODID:-//Google Inc//Google Calendar 70.9054//EN\nVERSION:2.0\nCALSCALE:GREGORIAN\nMETHOD:REPLY\nBEGIN:VEVENT\nDTSTART:#{DateTime.localize(m2.start_time.utc  + 5.hours, format: :ics_full_time)}\nDTEND:#{DateTime.localize(m2.end_time.utc, format: :ics_full_time)}\nDTSTAMP:#{DateTime.localize(m2.created_at.utc, format: :ics_full_time)}\nORGANIZER;CN=Apollo Services:mailto:calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m2.id)}\n @testmg.realizegoal.com\nRECURRENCE-ID;TZID=Asia/Calcutta:#{DateTime.localize((m2.reload.occurrences[2]).utc, format: :ics_full_time)}\nUID:meeting_20171218T112713@chronus.com\nATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=ACCEPTED;CN=Arun K\n umar N;X-NUM-GUESTS=0:mailto:robert@example.com\nCREATED:#{DateTime.localize(m2.created_at.utc, format: :ics_full_time)}\nDESCRIPTION:Message description\,\nLAST-MODIFIED:#{DateTime.localize(m2.updated_at.utc, format: :ics_full_time)}\nLOCATION:\nSEQUENCE:0\nSTATUS:CONFIRMED\nSUMMARY:as\nTRANSP:OPAQUE\nEND:VEVENT\nEND:VCALENDAR"

    event = Icalendar::Calendar.parse(recurring_response_single_event_wrong_occurrence).first.events.first
    Airbrake.expects(:notify).once
    m2.update_rsvp!(event)
  end

  def test_es_reindex
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [meeting.group_id])
    Meeting.es_reindex(meeting)
  end

  def test_reindex_group
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [meeting.group_id])
    Meeting.reindex_group([meeting.group_id])
  end

  def test_update_rsvp_with_calendar
    m1 = meetings(:upcoming_calendar_meeting)
    mm1 = member_meetings(:member_meetings_13)
    non_recurring_response = "BEGIN:VCALENDAR\nPRODID:-//Google Inc//Google Calendar 70.9054//EN\nVERSION:2.0\nCALSCALE:GREGORIAN\nMETHOD:REPLY\nBEGIN:VEVENT\nDTSTART:#{DateTime.localize(m1.start_time.utc, format: :ics_full_time)}\nDTEND:#{DateTime.localize(m1.end_time.utc, format: :ics_full_time)}\nDTSTAMP:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nORGANIZER;CN=Apollo Services:mailto:calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}\n @testmg.realizegoal.com\nUID:meeting_20171218T112713@chronus.com\nATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=DECLINED;CN=Arun K\n umar N;X-NUM-GUESTS=0:mailto:robert@example.com\nCREATED:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nDESCRIPTION:Message description\,\nLAST-MODIFIED:#{DateTime.localize(m1.updated_at.utc, format: :ics_full_time)}\nLOCATION:\nSEQUENCE:0\nSTATUS:CONFIRMED\nSUMMARY:as\nTRANSP:OPAQUE\nEND:VEVENT\nEND:VCALENDAR"

    assert_equal MemberMeeting::ATTENDING::YES, mm1.attending
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    Meeting.update_rsvp_with_calendar("calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com", non_recurring_response)
    assert_equal MemberMeeting::ATTENDING::NO, mm1.reload.attending


    non_recurring_response_wrong_case_email_address = "BEGIN:VCALENDAR\nPRODID:-//Google Inc//Google Calendar 70.9054//EN\nVERSION:2.0\nCALSCALE:GREGORIAN\nMETHOD:REPLY\nBEGIN:VEVENT\nDTSTART:#{DateTime.localize(m1.start_time.utc, format: :ics_full_time)}\nDTEND:#{DateTime.localize(m1.end_time.utc, format: :ics_full_time)}\nDTSTAMP:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nORGANIZER;CN=Apollo Services:mailto:calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}\n @testmg.realizegoal.com\nUID:meeting_20171218T112713@chronus.com\nATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=ACCEPTED;CN=Arun K\n umar N;X-NUM-GUESTS=0:mailto:Robert@Example.com\nCREATED:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nDESCRIPTION:Message description\,\nLAST-MODIFIED:#{DateTime.localize(m1.updated_at.utc, format: :ics_full_time)}\nLOCATION:\nSEQUENCE:0\nSTATUS:CONFIRMED\nSUMMARY:as\nTRANSP:OPAQUE\nEND:VEVENT\nEND:VCALENDAR"

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    Meeting.update_rsvp_with_calendar("calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com", non_recurring_response_wrong_case_email_address)
    assert_equal MemberMeeting::ATTENDING::YES, mm1.reload.attending

    non_recurring_response = "BEGIN:VCALENDAR\nPRODID:-//Google Inc//Google Calendar 70.9054//EN\nVERSION:2.0\nCALSCALE:GREGORIAN\nMETHOD:REPLY\nBEGIN:VEVENT\nDTSTART:#{DateTime.localize(m1.start_time.utc, format: :ics_full_time)}\nDTEND:#{DateTime.localize(m1.end_time.utc, format: :ics_full_time)}\nDTSTAMP:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nORGANIZER;CN=Apollo Services:mailto:calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(8888)}\n @testmg.realizegoal.com\nUID:meeting_20171218T112713@chronus.com\nATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=DECLINED;CN=Arun K\n umar N;X-NUM-GUESTS=0:mailto:robert@example.com\nCREATED:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nDESCRIPTION:Message description\,\nLAST-MODIFIED:#{DateTime.localize(m1.updated_at.utc, format: :ics_full_time)}\nLOCATION:\nSEQUENCE:0\nSTATUS:CONFIRMED\nSUMMARY:as\nTRANSP:OPAQUE\nEND:VEVENT\nEND:VCALENDAR"

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    Meeting.any_instance.expects(:update_rsvp!).never
    Meeting.update_rsvp_with_calendar("calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(8888)}@testmg.realizegoal.com", non_recurring_response)

    Icalendar::Calendar.expects(:parse).never
    Meeting.update_rsvp_with_calendar("calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(8888)}@testmg.realizegoal.com", "")    
  end

  def test_valid_start_time_boundaries
    start_time_boundaries = Meeting.valid_start_time_boundaries
    assert_equal 48, start_time_boundaries.size
    assert_equal "12:30 am", start_time_boundaries[1]

    start_time_boundaries = Meeting.valid_start_time_boundaries(slot_time: 15, slots_per_day: 96)
    assert_equal 96, start_time_boundaries.size
    assert_equal "12:15 am", start_time_boundaries[1]
  end

  def test_valid_end_time_boundaries
    end_time_boundaries = Meeting.valid_end_time_boundaries
    assert_equal 48, end_time_boundaries.size
    assert_equal "12:30 am", end_time_boundaries[0]

    end_time_boundaries = Meeting.valid_end_time_boundaries(slot_time: 15, slots_per_day: 96)
    assert_equal 96, end_time_boundaries.size
    assert_equal "12:15 am", end_time_boundaries[0]
  end
end