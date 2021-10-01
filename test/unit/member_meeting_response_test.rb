require_relative './../test_helper.rb'

class MemberMeetingResponseTest < ActiveSupport::TestCase

  def test_associations
    response = MemberMeetingResponse.first
    assert_equal meetings(:f_mentor_mkr_student_daily_meeting).member_meetings.first, response.member_meeting
    assert_equal meetings(:f_mentor_mkr_student_daily_meeting), response.meeting
  end

  def test_responces
    response = MemberMeetingResponse.first
    assert response.accepted?
    assert response.accepted_or_not_responded?
    assert_false response.not_responded?
    response.update_attribute(:attending, MemberMeeting::ATTENDING::NO_RESPONSE)
    assert_false response.accepted?
    assert response.not_responded?
    assert response.accepted_or_not_responded?

    response = MemberMeetingResponse.last
    assert_false response.accepted?
    assert_false response.not_responded?
    assert response.rejected?
    assert_false response.accepted_or_not_responded?
  end

  def test_post_status_update_on_creation
    member_meeting = meetings(:f_mentor_mkr_student_daily_meeting).member_meetings.last
    response = MemberMeetingResponse.first
    Meeting.any_instance.expects(:archived?).returns(false)
    MemberMeetingResponse.any_instance.expects(:delay).returns(response)
    response.expects(:send_rsvp_mail).with(member_meeting.meeting, member_meeting, nil)
    member_meeting.member_meeting_responses.create(:attending => MemberMeeting::ATTENDING::YES, :meeting_occurrence_time => member_meeting.meeting.occurrences.last.to_time )
  end

  def test_post_status_update_after_update_when_attending_changed
    response = MemberMeetingResponse.last
    Meeting.any_instance.expects(:archived?).returns(false)
    Meeting.any_instance.stubs(:can_be_synced?).returns(false)
    MemberMeetingResponse.any_instance.expects(:saved_change_to_attending?).returns(true)
    MemberMeetingResponse.any_instance.expects(:delay).returns(response)
    response.expects(:send_rsvp_mail).with(response.member_meeting.meeting, response.member_meeting, nil)
    response.update_attribute(:attending, MemberMeeting::ATTENDING::YES)

    response.reload
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    response.perform_sync_to_calendar = true
    Meeting.any_instance.expects(:archived?).returns(false)
    MemberMeetingResponse.any_instance.expects(:saved_change_to_attending?).times(2).returns(true)
    MemberMeetingResponse.any_instance.expects(:delay).returns(response)
    response.expects(:send_rsvp_mail).with(response.member_meeting.meeting, response.member_meeting, true)
    Meeting.expects(:update_calendar_event_rsvp).times(1).with(response.meeting.id, {current_occurrence_time: response.meeting_occurrence_time})
    response.update_attribute(:attending, MemberMeeting::ATTENDING::NO)
  end

  def test_post_status_update_after_update_when_attending_not_changed
    response = MemberMeetingResponse.last
    Meeting.any_instance.expects(:archived?).returns(false)
    Meeting.any_instance.stubs(:can_be_synced?).returns(false)
    MemberMeetingResponse.any_instance.expects(:saved_change_to_attending?).returns(false)
    MemberMeetingResponse.any_instance.expects(:delay).times(0)
    response.expects(:send_rsvp_mail).with(response.member_meeting.meeting, response.member_meeting, nil).times(0)
    response.update_attribute(:meeting_occurrence_time, Time.now)
  end

  def test_send_rsvp_mail
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    occurrence_start_time = meeting.first_occurrence
    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    student_member_meeting = meeting.member_meetings.find_by(member_id: members(:mkr_student).id)
    members(:mkr_student).mark_attending_for_an_occurrence!(meeting, MemberMeeting::ATTENDING::YES, occurrence_start_time)
    response = student_member_meeting.member_meeting_responses.find_by(meeting_occurrence_time: occurrence_start_time)
    meeting = response.member_meeting.meeting
    Meeting.any_instance.stubs(:can_be_synced?).returns(false)
    response.expects(:send_rsvp_mail_for_owner).times(1).with(meeting, response.member_meeting)
    response.send_rsvp_mail(meeting, response.member_meeting, true)

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    response.expects(:send_rsvp_mail_for_all_users).times(1).with(meeting, response.member_meeting, true)
    response.send_rsvp_mail(meeting, response.member_meeting, true)
  end

  def test_send_rsvp_mail_for_all_users
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    occurrence_start_time = meeting.first_occurrence
    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    student_member_meeting = meeting.member_meetings.find_by(member_id: members(:mkr_student).id)
    members(:mkr_student).mark_attending_for_an_occurrence!(meeting, MemberMeeting::ATTENDING::YES, occurrence_start_time)
    response = student_member_meeting.member_meeting_responses.find_by(meeting_occurrence_time: occurrence_start_time)
    meeting = response.member_meeting.meeting

    ChronusMailer.expects(:meeting_rsvp_notification).times(1).with(meeting.owner.user_in_program(meeting.program), response.member_meeting, response.meeting_occurrence_time).returns(stub(:deliver_now))
    
    ChronusMailer.expects(:meeting_rsvp_notification_to_self).times(1).with(members(:mkr_student).user_in_program(meeting.program), response.member_meeting, response.meeting_occurrence_time).returns(stub(:deliver_now))
    response.send_rsvp_mail_for_all_users(meeting, response.member_meeting, true)
  end

  def test_send_rsvp_mail_owner
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    occurrence_start_time = meeting.first_occurrence
    mentor_member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    student_member_meeting = meeting.member_meetings.find_by(member_id: members(:mkr_student).id)
    members(:mkr_student).mark_attending_for_an_occurrence!(meeting, MemberMeeting::ATTENDING::YES, occurrence_start_time)
    response = student_member_meeting.member_meeting_responses.find_by(meeting_occurrence_time: occurrence_start_time)
    meeting = response.member_meeting.meeting

    ChronusMailer.expects(:meeting_rsvp_notification).times(1).with(meeting.owner.user_in_program(meeting.program), response.member_meeting, response.meeting_occurrence_time).returns(stub(:deliver_now))
    ChronusMailer.expects(:meeting_rsvp_notification_to_self).never
    response.send_rsvp_mail_for_owner(meeting, response.member_meeting)
  end

  def test_versioning
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    occurrence_start_time = meeting.first_occurrence
    student_member_meeting = meeting.member_meetings.find_by(member_id: members(:mkr_student).id)
    members(:mkr_student).mark_attending_for_an_occurrence!(meeting, MemberMeeting::ATTENDING::YES, occurrence_start_time)
    response = student_member_meeting.member_meeting_responses.find_by(meeting_occurrence_time: occurrence_start_time)
    assert_no_difference "response.versions.size" do
      assert_no_difference "ChronusVersion.count" do
        members(:mkr_student).mark_attending_for_an_occurrence!(meeting, MemberMeeting::ATTENDING::NO, occurrence_start_time)
      end
    end
    assert_difference "response.reload.versions.size", 1 do
      assert_difference "ChronusVersion.count", 1 do
        members(:mkr_student).mark_attending_for_an_occurrence!(meeting, MemberMeeting::ATTENDING::YES, occurrence_start_time, rsvp_change_source: MemberMeeting::RSVP_SOURCE::MEETING_AREA)
      end
    end
  end
end
