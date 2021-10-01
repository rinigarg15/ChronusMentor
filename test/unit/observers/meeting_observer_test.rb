require_relative './../../test_helper.rb'

class MeetingObserverTest < ActiveSupport::TestCase
  def setup
    super
    # Required for testing mails
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  def test_after_create
    assert_difference "RecentActivity.count", 1 do
      assert_emails 0 do
        create_meeting(:start_time => 40.minutes.since, :end_time => 60.minutes.since)
      end
    end
    
    assert_no_difference "RecentActivity.count" do
      assert_emails 0 do
        create_meeting(force_non_group_meeting: true)
      end
    end
    assert_equal MemberMeeting::ATTENDING::YES, Meeting.last.guests.first.member_meetings.find_by(meeting_id: Meeting.last.id).attending
    # RA should not created for non time meetings
    assert_no_difference "RecentActivity.count" do
      create_meeting(force_non_time_meeting: true)
    end

    Meeting.any_instance.expects(:create_meeting_requests).with("true")
    create_meeting(force_non_group_meeting: true, skip_email_notification: "true")
  end

  def test_after_save
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [meeting.group_id])
    meeting.save
  end

  def test_after_destroy
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).twice.with(Meeting, [meeting.id])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [meeting.group_id])
    meeting.destroy
  end

  def test_after_create_cal_sync
    Meeting.any_instance.stubs(:accepted?).returns(false)
    assert_difference "RecentActivity.count", 1 do
      assert_emails 0 do
        create_meeting(:start_time => 40.minutes.since, :end_time => 60.minutes.since)
      end
    end

    Meeting.any_instance.stubs(:accepted?).returns(true)
    Meeting.any_instance.stubs(:can_be_synced?).returns(false)
    assert_difference "RecentActivity.count", 1 do
      assert_emails 0 do
        create_meeting(:start_time => 40.minutes.since, :end_time => 60.minutes.since)
      end
    end

    Meeting.any_instance.stubs(:accepted?).returns(true)
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    assert_difference "RecentActivity.count", 1 do
      assert_emails 0 do
        create_meeting(:start_time => 40.minutes.since, :end_time => 60.minutes.since, force_non_time_meeting: true, mentor_created_meeting: true, skip_rsvp_change_email: true)
      end
    end

    assert_difference "RecentActivity.count", 1 do
      assert_emails 0 do
        create_meeting(:start_time => 40.minutes.since, :end_time => 60.minutes.since, skip_rsvp_change_email: true)
      end
    end

    assert_difference "RecentActivity.count", 1 do
      assert_emails 0 do
        create_meeting(:start_time => 40.minutes.since, :end_time => 60.minutes.since, skip_rsvp_change_email: true, skip_create_calendar_event: true)
      end
    end
  end

  def test_after_update
    meeting = meetings(:f_mentor_mkr_student)
    assert_difference "RecentActivity.count" do
      assert_emails 0 do
        meeting.update_attribute(:topic, "Some other new topic")
      end
    end

    meeting = create_meeting(force_non_time_meeting: true)
    assert_difference "RecentActivity.count" do
      meeting.update_attribute(:description, "Some other new topic")
    end
  end

  def test_should_not_send_meeting_deleted_notifications_when_meeting_is_archived
    meeting = meetings(:f_mentor_mkr_student)
    meeting.update_attribute :end_time, Time.now - 20.minutes
    
    assert_difference "Meeting.count", -1 do
      assert_emails 0 do
        meeting.false_destroy!
      end
    end
    meeting = create_meeting(force_non_time_meeting: true)
    meeting_request = meeting.meeting_request
    meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::ACCEPTED)
    assert_equal MeetingRequest.last, meeting_request
    assert_equal AbstractRequest::Status::ACCEPTED, meeting_request.reload.status
    meeting.false_destroy!
    assert_equal AbstractRequest::Status::ACCEPTED, meeting_request.reload.status #destroying a meeting should not affect the status of meeting request
  end

end
