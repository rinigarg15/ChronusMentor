require_relative './../../test_helper.rb'

class MeetingRequestObserverTest < ActiveSupport::TestCase
  def test_after_update
    chronus_s3_utils_stub
    meeting = create_meeting(force_non_group_meeting: true, mentor_created_meeting: true)
    meeting_request = meeting.meeting_request
    # Past meetings will have accepted state
    assert_equal AbstractRequest::Status::ACCEPTED, meeting_request.status

    time = Time.now + 2.days
    meeting = create_meeting(force_non_time_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    assert_equal AbstractRequest::Status::NOT_ANSWERED, meeting_request.status

    Push::Base.expects(:queued_notify).with(PushNotification::Type::MEETING_REQUEST_ACCEPTED, meeting_request).once
    User.any_instance.expects(:withdraw_active_meeting_requests!).with(meeting.start_time)
    MeetingRequest.expects(:send_meeting_request_status_changed_notification).with(meeting_request.id)
    assert_no_difference "MemberMeeting.count" do
      assert_no_difference "Meeting.count" do
        meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::ACCEPTED)
      end
    end

    assert_equal AbstractRequest::Status::ACCEPTED, meeting_request.status
    assert_equal MemberMeeting::ATTENDING::YES, meeting_request.member_meetings.find_by!(member_id: members(:f_mentor)).attending

    Push::Base.expects(:queued_notify).once
    meeting = create_meeting(force_non_time_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: users(:mkr_student).member.id)
    meeting_request = meeting.meeting_request

    Push::Base.expects(:queued_notify).never
    User.any_instance.expects(:withdraw_active_meeting_requests!).never
    MeetingRequest.expects(:send_meeting_request_status_changed_notification).with(meeting_request.id)
    assert_no_difference "MemberMeeting.count" do
      assert_difference "Meeting.count", -1 do
        meeting_request.update_status!(users(:mkr_student), AbstractRequest::Status::WITHDRAWN)
      end
    end

    assert_equal AbstractRequest::Status::WITHDRAWN, meeting_request.status
    assert_false meeting.reload.active?

    Push::Base.expects(:queued_notify).once
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes,owner_id: users(:mkr_student).member.id)
    meeting_request = meeting.meeting_request
    Push::Base.expects(:queued_notify).never
    User.any_instance.expects(:withdraw_active_meeting_requests!).never
    MeetingRequest.expects(:send_meeting_request_status_changed_notification).with(meeting_request.id)
    MeetingRequest.expects(:send_meeting_request_status_accepted_notification_to_self).never
    assert_no_difference "MemberMeeting.count" do
      assert_difference "Meeting.count", -1 do
        meeting_request.update_status!(users(:mkr_student), AbstractRequest::Status::WITHDRAWN)
      end
    end

    assert_equal AbstractRequest::Status::WITHDRAWN, meeting_request.status
    assert_false meeting.reload.active?

    Push::Base.expects(:queued_notify).once
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes,owner_id: users(:mkr_student).member.id)
    meeting_request = meeting.meeting_request

    Push::Base.expects(:queued_notify).once
    User.any_instance.expects(:withdraw_active_meeting_requests!).with(meeting.start_time)
    MeetingRequest.expects(:send_meeting_request_status_changed_notification).with(meeting_request.id)
    MeetingRequest.expects(:send_meeting_request_status_accepted_notification_to_self).with(meeting_request.id)
    assert_no_difference "MemberMeeting.count" do
      assert_no_difference "Meeting.count" do
        meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::ACCEPTED)
      end
    end
    assert_equal AbstractRequest::Status::ACCEPTED, meeting_request.status
    assert meeting.reload.active?
  end

  def test_after_create
    chronus_s3_utils_stub
    Push::Base.expects(:queued_notify).never
    MeetingRequest.expects(:send_meeting_request_sent_notification).never
    MeetingRequest.expects(:send_meeting_request_created_notification).never
    assert_no_emails do
      assert_difference "MeetingRequest.count" do
        assert_difference "Meeting.count" do
          create_meeting(force_non_group_meeting: true)
        end
      end
    end

    time = Time.now + 10.days
    Push::Base.expects(:queued_notify).once
    MeetingRequest.expects(:send_meeting_request_sent_notification).never
    MeetingRequest.expects(:send_meeting_request_created_notification).once
    assert_difference "MeetingRequest.count" do
      assert_difference "Meeting.count" do
        create_meeting(start_time: time, end_time: time + 30.minutes, force_non_time_meeting: true)
      end
    end

    Push::Base.expects(:queued_notify).never
    MeetingRequest.expects(:send_meeting_request_sent_notification).never
    MeetingRequest.expects(:send_meeting_request_created_notification).never
    assert_no_emails do
      assert_difference "MeetingRequest.count" do
        assert_difference "Meeting.count" do
          create_meeting(start_time: time, end_time: time + 30.minutes, force_non_time_meeting: true, skip_email_notification: true)
        end
      end
    end

    Push::Base.expects(:queued_notify).once
    MeetingRequest.expects(:send_meeting_request_sent_notification).once
    MeetingRequest.expects(:send_meeting_request_created_notification).once
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, proposed_slots_details_to_create: [OpenStruct.new(location: "chennai", start_time: time, end_time: time + 30.minutes)])
    meeting_request = meeting.meeting_request
    assert_equal 1, meeting_request.reload.meeting_proposed_slots.size
    slot = meeting_request.meeting_proposed_slots[0]
    assert_equal time.to_i, slot.start_time.to_i
    assert_equal (time+30.minutes).to_i, slot.end_time.to_i
    assert_equal "chennai", slot.location
    assert_equal meeting_request.student.id, slot.proposer_id
  end
end