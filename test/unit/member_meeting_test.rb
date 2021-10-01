require_relative './../test_helper.rb'

class MemberMeetingTest < ActiveSupport::TestCase
  def setup
    super
    # Required for testing mails
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  def test_presence_of_member_meeting
    m = MemberMeeting.new
    assert_false m.valid?
    assert_equal ["can't be blank"], m.errors[:meeting]
    assert_equal ["can't be blank"], m.errors[:member]
    m.member = Member.first
    m.meeting = Meeting.first
    assert m.valid?
  end

  def test_survey_answer_association
    time = Time.now.change(:usec => 0)
    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :members => [members(:f_admin), members(:mkr_student)],
                :owner_id => members(:mkr_student).id, :program_id => programs(:albers).id, :repeats_end_date => time + 2.days, :start_time => time, :end_time => time + 5.hours)
    meeting.complete!
    member_meeting = meeting.member_meetings.find_by(member_id: members(:mkr_student))
    survey = programs(:albers).surveys.of_meeting_feedback_type.first
    question_id = survey.survey_questions.pluck(:id)
    assert_equal [], member_meeting.survey_answers
    survey.update_user_answers({question_id[0] => "Extremely satisfying", question_id[1] => "Great use of time"}, {user_id: users(:mkr_student).id, :meeting_occurrence_time => meeting.occurrences.first.start_time, member_meeting_id: member_meeting.id})
    assert_equal SurveyAnswer.last(2), member_meeting.reload.survey_answers
  end

  def test_association_has_many_checkins
    member_meeting = MemberMeeting.first
    meeting = member_meeting.meeting
    group = meeting.group
    program_id = meeting.program_id
    member = member_meeting.member
    occur1 = meeting.occurrences.first
    occur2 = Time.now
    meeting.occurrences.push(occur2)

    #saving a checkin
    checkin1 = member_meeting.checkins.new
    checkin1.title = meeting.topic
    checkin1.comment = meeting.description
    checkin1.date = occur1
    checkin1.duration = meeting.schedule.duration
    checkin1.user = member.user_in_program(program_id)
    checkin1.program_id = program_id
    checkin1.group_id = group.id
    assert checkin1.save

    #saving another checkin
    checkin2 = member_meeting.checkins.new
    checkin2.title = meeting.topic
    checkin2.comment = meeting.description
    checkin2.date = occur2
    checkin2.duration = meeting.schedule.duration
    checkin2.user = member.user_in_program(program_id)
    checkin2.program_id = program_id
    checkin2.group_id = group.id
    assert checkin2.save

    #checkin dependent destroy
    member_meeting.destroy
    assert_raises(ActiveRecord::RecordNotFound) { checkin1.reload }
    assert_raises(ActiveRecord::RecordNotFound) { checkin2.reload }
  end

  def test_check_delta_of_meeting_after_update_attending_column
    mm1 = meetings(:f_mentor_mkr_student).member_meetings.first
    mm2 = meetings(:student_2_not_req_mentor).member_meetings.first
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Meeting, [mm1.id]).once
    mm1.update_attributes :attending => false
    mm2.update_attributes :feedback_request_sent => true
  end

  def test_is_owner
    mm1 = meetings(:f_mentor_mkr_student).member_meetings.first
    assert mm1.is_owner?
    mm2 = meetings(:f_mentor_mkr_student).member_meetings.last
    assert_false mm2.is_owner?
  end

  def test_with_time
    meeting = create_meeting
    member_meetings = meeting.member_meetings
    assert_equal 2, member_meetings.size
    assert MemberMeeting.with_time.include?(member_meetings[0])
    assert MemberMeeting.with_time.include?(member_meetings[1])

    meeting = create_meeting(force_non_time_meeting: true)
    member_meetings = meeting.member_meetings
    assert_equal 2, member_meetings.size
    assert_false MemberMeeting.with_time.include?(member_meetings[0])
    assert_false MemberMeeting.with_time.include?(member_meetings[1])
  end

  def test_active
    meeting = Meeting.last
    assert_equal 2, meeting.member_meetings.size
    mm1 = meeting.member_meetings.first
    mm2 = meeting.member_meetings.last

    assert MemberMeeting.active.include?(mm1)
    assert MemberMeeting.active.include?(mm2)

    meeting.update_attributes!(active: false)

    assert_false MemberMeeting.active.include?(mm1)
    assert_false MemberMeeting.active.include?(mm2)
  end

  def accepted_or_not_responded
  end

  def test_get_feedback_answers_and_can_send_feedback_request
    time = Time.now.change(:usec => 0)
    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :members => [members(:f_admin), members(:mkr_student)],
                :owner_id => members(:mkr_student).id, :program_id => programs(:albers).id, :repeats_end_date => time + 2.days, :start_time => time, :end_time => time + 5.hours)
    meeting.complete!
    member_meeting = meeting.member_meetings.find_by(member_id: members(:mkr_student))
    survey = programs(:albers).surveys.of_meeting_feedback_type.first
    question_id = survey.survey_questions.pluck(:id)
    assert_equal [], member_meeting.reload.get_feedback_answers(meeting.occurrences.first.start_time)
    assert_equal [], member_meeting.reload.get_feedback_answers(meeting.occurrences.last.start_time)

    survey.update_user_answers({question_id[0] => "Extremely satisfying", question_id[1] => "Great use of time"}, {user_id: users(:mkr_student).id, :meeting_occurrence_time => meeting.occurrences.first.start_time, member_meeting_id: member_meeting.id})
    assert_equal SurveyAnswer.last(2), member_meeting.reload.get_feedback_answers(meeting.occurrences.first.start_time)
    assert_equal [], member_meeting.get_feedback_answers(meeting.occurrences.last.start_time)
  end

  def test_get_meeting
    meeting = create_meeting(force_non_time_meeting: true)
    mm = meeting.member_meetings.first

    assert_equal meeting, mm.get_meeting
    assert_equal meeting, mm.meeting

    meeting.update_attributes!(active: false)
    mm = meeting.member_meetings.first
    assert_equal meeting, mm.get_meeting
    assert_nil mm.reload.meeting
  end

  def test_other_members
    m = create_meeting(force_non_group_meeting: true)
    mm = m.member_meetings.first
    assert_equal members(:f_mentor), mm.member
    assert_equal [members(:mkr_student)], mm.other_members
  end

  def test_due_date_for_campaigns
    mm = MemberMeeting.first
    assert_equal mm.meeting.end_time, mm.due_date_for_campaigns
  end

  def test_user
    m = create_meeting
    mm = m.member_meetings.first
    assert_equal members(:f_mentor), mm.member
    assert_equal users(:f_mentor), mm.user
  end

  def test_can_send_campaign_email
    m = create_meeting
    mm = m.member_meetings.first
    assert mm.can_send_campaign_email?

    mm.stubs(:user).returns(nil)
    assert_false mm.can_send_campaign_email?

    mm.stubs(:user).returns("something")
    Meeting.any_instance.stubs(:end_time).returns(20.minutes.from_now)
    assert_false mm.can_send_campaign_email?

    Meeting.any_instance.stubs(:end_time).returns(20.minutes.ago)
    mm.stubs(:get_feedback_answers).returns(["something"])
    assert_false mm.can_send_campaign_email?

    mm.stubs(:get_feedback_answers).returns([])
    assert mm.can_send_campaign_email?
  end

  def test_get_members_and_meetings_count
    program = programs(:albers)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::STUDENT_NAME)
    time = 4.weeks.ago.change(:usec => 0)
    m1 = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true})
    time = 5.weeks.ago.change(:usec => 0)
    user2 = members(:not_requestable_mentor).user_in_program(programs(:albers))
    m2 = create_meeting({:program => programs(:albers), :topic => "Arbit Topic2", :start_time => time, :end_time => (time + 30.minutes), :members => [members(:student_2), members(:not_requestable_mentor)], :requesting_student => users(:student_2), :requesting_mentor => user2, :force_non_group_meeting => true, owner_id: members(:student_2).id})

    member_meeting_ids = [m1.member_meetings.where(:member_id => members(:f_mentor).id).first.id, m2.member_meetings.where(:member_id => members(:student_2).id).first.id]
    members_count, meetings_count = MemberMeeting.get_members_and_meetings_count(member_meeting_ids)
    assert_equal 2, members_count
    assert_equal 2, meetings_count

    member_meeting_ids = []
    members_count, meetings_count = MemberMeeting.get_members_and_meetings_count(member_meeting_ids)
    assert_equal 0, members_count
    assert_equal 0, meetings_count
  end

  def test_for_mentor_role
    program = programs(:albers)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::MENTOR_NAME)
    filter_params = {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"July 06, 2016"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>1.minute.ago}}
    filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})
    time = 50.minutes.ago.change(:usec => 0)
    m1 = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :requesting_student => users(:mkr_student), :force_non_group_meeting => true})
    time = 70.minutes.ago.change(:usec => 0)
    user2 = members(:not_requestable_mentor).user_in_program(programs(:albers))
    m2 = create_meeting({:program => programs(:albers), :topic => "Arbit Topic2", :start_time => time, :end_time => (time + 20.minutes), :members => [members(:student_2), members(:not_requestable_mentor)], :requesting_student => users(:student_2), :requesting_mentor => user2, :force_non_group_meeting => true, owner_id: members(:student_2).id})
    filtered_meetings = program.meetings.non_group_meetings.pluck(:id)
    filtered_member_meetings = MemberMeeting.where(:meeting_id => filtered_meetings)
    assert_equal_unordered filtered_member_meetings.for_mentor_role, [meetings(:upcoming_calendar_meeting).member_meetings.where(:member_id => members(:f_mentor).id).first, meetings(:past_calendar_meeting).member_meetings.where(:member_id => members(:f_mentor).id).first, meetings(:completed_calendar_meeting).member_meetings.where(:member_id => members(:f_mentor).id).first, meetings(:cancelled_calendar_meeting).member_meetings.where(:member_id => members(:f_mentor).id).first, m1.member_meetings.where(:member_id => members(:f_mentor).id).first, m2.member_meetings.where(:member_id => members(:not_requestable_mentor).id).first]
  end

  def test_for_mentee_role
    program = programs(:albers)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::STUDENT_NAME)
    filter_params = {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"July 06, 2016"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>1.minute.ago}}
    filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})
    time = 50.minutes.ago.change(:usec => 0)
    m1 = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :requesting_student => users(:mkr_student), :force_non_group_meeting => true})
    time = 70.minutes.ago.change(:usec => 0)
    user2 = members(:not_requestable_mentor).user_in_program(programs(:albers))
    m2 = create_meeting({:program => programs(:albers), :topic => "Arbit Topic2", :start_time => time, :end_time => (time + 20.minutes), :members => [members(:student_2), members(:not_requestable_mentor)], :requesting_student => users(:student_2), :requesting_mentor => user2, :force_non_group_meeting => true, owner_id: members(:student_2).id})

    filtered_meetings = program.meetings.non_group_meetings.pluck(:id)
    filtered_member_meetings = MemberMeeting.where(:meeting_id => filtered_meetings)
    assert_equal_unordered filtered_member_meetings.for_mentee_role, [meetings(:upcoming_calendar_meeting).member_meetings.where(:member_id => members(:mkr_student).id).first, meetings(:past_calendar_meeting).member_meetings.where(:member_id => members(:mkr_student).id).first, meetings(:completed_calendar_meeting).member_meetings.where(:member_id => members(:mkr_student).id).first, meetings(:cancelled_calendar_meeting).member_meetings.where(:member_id => members(:mkr_student).id).first, m1.member_meetings.where(:member_id => members(:mkr_student).id).first, m2.member_meetings.where(:member_id => members(:student_2).id).first]
  end

  def test_handle_reply_via_email_for_meeting_request_accepted_emails
    invalidate_albers_calendar_meetings
    meeting_request = create_meeting_request(:mentor => users(:f_mentor), :student => users(:mkr_student), :status => AbstractRequest::Status::ACCEPTED)
    meeting = meeting_request.meeting
    email_params = {obj_type: ReplyViaEmail::MEETING_REQUEST_ACCEPTED_CALENDAR, original_sender_member: members(:f_mentor), subject: "test subject", content: "test content" }
    assert_difference 'Scrap.count',1 do
      assert meeting.member_meetings.find_by(member_id: members(:mkr_student).id).handle_reply_via_email(email_params)
      assert_equal 'test content', Scrap.last.content
      assert_equal 'test subject', Scrap.last.subject
      assert_equal "Meeting", Scrap.last.ref_obj_type
    end
    #non calendar meeting
    email_params = {obj_type: ReplyViaEmail::MEETING_REQUEST_ACCEPTED_NON_CALENDAR, original_sender_member: members(:f_mentor), subject: "test subject", content: "test content" }
    assert_difference 'Scrap.count',1 do
      assert meeting.member_meetings.find_by(member_id: members(:mkr_student).id).handle_reply_via_email(email_params)
      assert_equal 'test content', Scrap.last.content
      assert_equal 'test subject', Scrap.last.subject
      assert_equal "Meeting", Scrap.last.ref_obj_type
    end

    #should create a message when meeting becomes inactive and no ther upcoming connection present
    meeting.update_column(:active, false)
    Group.first.update_column(:status, 2)
    assert_difference 'Message.count',1 do
      assert meeting.member_meetings.find_by(member_id: members(:mkr_student).id).handle_reply_via_email(email_params)
      assert_equal 'test content', Message.last.content
      assert_equal 'test subject', Message.last.subject
    end
  end

  def test_handle_reply_via_email_for_meeting_update_emails
    invalidate_albers_calendar_meetings
    time = 2.days.from_now
    email_params = {obj_type: ReplyViaEmail::MEETING_UPDATE_NOTIFICATION, original_sender_member: members(:f_mentor), subject: "test subject", content: "test content" }

    #group meeting
    meeting = create_meeting(force_non_group_meeting: false, start_time: time, end_time: time + 30.minutes)
    assert_difference 'Scrap.count',1 do
      assert meeting.member_meetings.find_by(member_id: members(:mkr_student).id).handle_reply_via_email(email_params)
      assert_equal 'test content', Scrap.last.content
      assert_equal 'test subject', Scrap.last.subject
      assert_equal "Group", Scrap.last.ref_obj_type
    end

    #inactive group
    Group.first.update_column(:status, 2)
    meeting = create_meeting(force_non_group_meeting: false, start_time: time, end_time: time + 30.minutes, :members => [members(:f_mentor), members(:mkr_student)])
    assert_difference 'Message.count',1 do
      assert meeting.member_meetings.find_by(member_id: members(:mkr_student).id).handle_reply_via_email(email_params)
    end

    #flash meeting
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    assert_difference 'Scrap.count',1 do
      assert meeting.member_meetings.find_by(member_id: members(:mkr_student).id).handle_reply_via_email(email_params)
      assert_equal 'test content', Scrap.last.content
      assert_equal 'test subject', Scrap.last.subject
      assert_equal "Meeting", Scrap.last.ref_obj_type
    end
  end

  def test_handle_reply_via_email_for_meeting_rsvp_emails
    invalidate_albers_calendar_meetings
    time = 2.days.from_now
    email_params = {obj_type: ReplyViaEmail::MEETING_RSVP_NOTIFICATION_OWNER, original_sender_member: members(:mkr_student), subject: "test subject", content: "test content" }
    #group meeting
    meeting = create_meeting(force_non_group_meeting: false, start_time: time, end_time: time + 30.minutes)
    assert_difference 'Scrap.count',1 do
      assert meeting.member_meetings.find_by(member_id: members(:f_mentor).id).handle_reply_via_email(email_params)
      assert_equal 'test content', Scrap.last.content
      assert_equal 'test subject', Scrap.last.subject
      assert_equal "Group", Scrap.last.ref_obj_type
    end

    #group inactive
    Group.first.update_column(:status, 2)
    meeting = create_meeting(force_non_group_meeting: false, start_time: time, end_time: time + 30.minutes, :members => [members(:f_mentor), members(:mkr_student), members(:student_2)])
    assert_difference 'Message.count',1 do
      assert meeting.member_meetings.find_by(member_id: members(:f_mentor).id).handle_reply_via_email(email_params)
    end

    #flash meeting
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    assert_difference 'Scrap.count',1 do
      assert meeting.member_meetings.find_by(member_id: members(:f_mentor).id).handle_reply_via_email(email_params)
      assert_equal 'test content', Scrap.last.content
      assert_equal 'test subject', Scrap.last.subject
      assert_equal "Meeting", Scrap.last.ref_obj_type
    end
  end

  def test_handle_reply_via_email_for_meeting_created_notification_email
    invalidate_albers_calendar_meetings
    time = 2.days.from_now
    email_params = {obj_type: ReplyViaEmail::MEETING_CREATED_NOTIFICATION, original_sender_member: members(:f_mentor), subject: "test subject", content: "test content" }

    #group meeting
    meeting = create_meeting(force_non_group_meeting: false, start_time: time, end_time: time + 30.minutes)
    assert_difference 'Scrap.count',1 do
      assert meeting.member_meetings.find_by(member_id: members(:mkr_student).id).handle_reply_via_email(email_params)
      assert_equal 'test content', Scrap.last.content
      assert_equal 'test subject', Scrap.last.subject
      assert_equal "Group", Scrap.last.ref_obj_type
    end

    #inactive group
    Group.first.update_column(:status, 2)
    meeting = create_meeting(force_non_group_meeting: false, start_time: time, end_time: time + 30.minutes, :members => [members(:f_mentor), members(:mkr_student)])
    assert_difference 'Message.count',1 do
      assert meeting.member_meetings.find_by(member_id: members(:mkr_student).id).handle_reply_via_email(email_params)
    end
  end

  def test_handle_reply_via_email_for_meeting_reminder_notification_email
    invalidate_albers_calendar_meetings
    time = 2.days.from_now
    email_params = {obj_type: ReplyViaEmail::MEETING_REMINDER_NOTIFICATION, original_sender_member: nil, subject: "test subject", content: "test content" }

    #group meeting
    meeting = create_meeting(force_non_group_meeting: false, start_time: time, end_time: time + 30.minutes)
    assert_difference 'Scrap.count',1 do
      assert meeting.member_meetings.find_by(member_id: members(:mkr_student).id).handle_reply_via_email(email_params)
      assert_equal 'test content', Scrap.last.content
      assert_equal 'test subject', Scrap.last.subject
      assert_equal "Group", Scrap.last.ref_obj_type
    end

    #inactive group
    Group.first.update_column(:status, 2)
    meeting = create_meeting(force_non_group_meeting: false, start_time: time, end_time: time + 30.minutes, :members => [members(:f_mentor), members(:mkr_student)])
    assert_difference 'Message.count',1 do
      assert meeting.member_meetings.find_by(member_id: members(:mkr_student).id).handle_reply_via_email(email_params)
    end
  end

  def test_create_message_or_scrap_for_reply_to_flash_meeting
    invalidate_albers_calendar_meetings
    time = 2.days.from_now
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    member_meeting = meeting.member_meetings.first
    assert_difference 'Scrap.count',1 do
      member_meeting.create_message_or_scrap_for_reply_to_meeting("Scrap", member_meeting.member, [members(:mkr_student)], {subject: "test subject", content: "test content"})
      assert_equal 'test content', Scrap.last.content
      assert_equal 'test subject', Scrap.last.subject
      assert_equal "Meeting", Scrap.last.ref_obj_type
      assert_equal members(:f_mentor), Scrap.last.sender
      assert_equal [members(:mkr_student)], Scrap.last.receivers
      assert Scrap.last.posted_via_email
    end
    #should create a message when meeting is not upcoming and no other upcoming connection present
    meeting.update_column(:active, false)
    Group.first.update_column(:status, 2)
    assert_difference 'Message.count',1 do
      member_meeting.create_message_or_scrap_for_reply_to_meeting("Message", member_meeting.member, [members(:mkr_student)], {subject: "test subject", content: "test content"})
      assert_equal 'test content', Message.last.content
      assert_equal 'test subject', Message.last.subject
      assert_equal members(:f_mentor), Message.last.sender
      assert_equal [members(:mkr_student)], Message.last.receivers
      assert Message.last.posted_via_email
    end
  end

  def test_create_message_or_scrap_for_reply_to_group_meeting
    invalidate_albers_calendar_meetings
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: false, start_time: time, end_time: time + 30.minutes)
    member_meeting = meeting.member_meetings.first
    assert_difference 'Scrap.count',1 do
      member_meeting.create_message_or_scrap_for_reply_to_meeting("Message", member_meeting.member, [members(:mkr_student)], {subject: "test subject", content: "test content"})
      assert_equal 'test content', Scrap.last.content
      assert_equal 'test subject', Scrap.last.subject
      assert_equal "Group", Scrap.last.ref_obj_type
      assert_equal members(:f_mentor), Scrap.last.sender
      assert_equal [members(:mkr_student)], Scrap.last.receivers
      assert Scrap.last.posted_via_email
    end
    #should create a message when group is not active
    Group.first.update_column(:status, 2)
    assert_difference 'Message.count',1 do
      member_meeting.create_message_or_scrap_for_reply_to_meeting("Message", member_meeting.member, [members(:mkr_student)], {subject: "test subject", content: "test content"})
      assert_equal 'test content', Message.last.content
      assert_equal 'test subject', Message.last.subject
      assert_equal members(:f_mentor), Message.last.sender
      assert_equal [members(:mkr_student)], Message.last.receivers
      assert Message.last.posted_via_email
    end
  end

  def test_get_meeting_occurrence_rsvp
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    occurrence_start_time = meeting.first_occurrence
    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    mentor_member_meeting_occurrence_response = mentor_member_meeting.member_meeting_responses.find_by(meeting_occurrence_time: occurrence_start_time)
    assert_equal mentor_member_meeting_occurrence_response.attending, mentor_member_meeting.get_meeting_occurrence_rsvp(occurrence_start_time)
    assert_equal mentor_member_meeting.attending, mentor_member_meeting.get_meeting_occurrence_rsvp(meeting.first_occurrence + 5.days)
  end

  def test_handle_rsvp_from_meeting_and_calendar_event
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    assert_equal MemberMeeting::ATTENDING::YES, mentor_member_meeting.attending
    mentor_member_meeting.handle_rsvp_from_meeting_and_calendar_event(Meeting::CalendarEventPartStatValues::DECLINED)
    assert_equal MemberMeeting::ATTENDING::NO, mentor_member_meeting.reload.attending

    mentor_member_meeting.handle_rsvp_from_meeting_and_calendar_event(Meeting::CalendarEventPartStatValues::DECLINED)
    assert_equal MemberMeeting::ATTENDING::NO, mentor_member_meeting.reload.attending

    mentor_member_meeting.handle_rsvp_from_meeting_and_calendar_event(Meeting::CalendarEventPartStatValues::NEEDS_ACTION)
    assert_equal MemberMeeting::ATTENDING::NO, mentor_member_meeting.reload.attending

    mentor_member_meeting.handle_rsvp_from_meeting_and_calendar_event("RANDOM")
    assert_equal MemberMeeting::ATTENDING::NO, mentor_member_meeting.reload.attending
  end

  def test_users
    assert_equal_unordered MemberMeeting.all.collect(&:user).pluck(:id).uniq, MemberMeeting.users(MemberMeeting.ids)
  end

  def test_versioning
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    assert_no_difference "member_meeting.versions.size" do
      assert_no_difference "ChronusVersion.count" do
        member_meeting.update_attributes(attending: MemberMeeting::ATTENDING::NO)
      end
    end

    assert_difference "member_meeting.versions.size", 1 do
      assert_difference "ChronusVersion.count", 1 do
        member_meeting.update_attributes(rsvp_change_source: MemberMeeting::RSVP_SOURCE::MEETING_AREA)
      end
    end
  end
end
