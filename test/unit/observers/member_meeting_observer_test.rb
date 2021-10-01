require_relative './../../test_helper.rb'

class MemberMeetingObserverTest < ActiveSupport::TestCase
  def setup
    super
    # Required for testing mails
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    chronus_s3_utils_stub
  end

  def test_after_update
    meeting = meetings(:f_mentor_mkr_student)
    meeting.start_time = Time.now + 2.days
    meeting.end_time = meeting.start_time + 30.minutes
    meeting.duration = 30.minutes
    meeting.update_schedule
    meeting.save!
    member_meeting = meeting.member_meetings.last
    assert_equal [member_meeting.member], meeting.guests

    Meeting.any_instance.stubs(:can_be_synced?).returns(false)

    assert_difference "RecentActivity.count" do
      assert_emails 1 do
        member_meeting.update_attribute(:attending, false)
      end
    end

    meeting = create_meeting(force_non_group_meeting: true)
    member_meeting = meeting.member_meetings.last
    assert_no_difference "RecentActivity.count" do
      assert_emails 0 do
        member_meeting.update_attributes!(attending: false)
      end
    end

    time = Time.now + 2.days
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    member_meeting = meeting.member_meetings.last
    assert_difference "RecentActivity.count" do
      assert_emails 1 do
        member_meeting.update_attributes!(attending: false)
      end
    end

    time = Time.now + 2.days
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    member_meeting = meeting.member_meetings.last
    assert_no_difference "RecentActivity.count" do
      assert_emails 1 do
        member_meeting.update_attributes!(attending: false)
      end
    end

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    Meeting.expects(:update_calendar_event_rsvp).twice
    member_meeting.perform_sync_to_calendar = true

    member_meeting.skip_mail_for_calendar_sync = true
    assert_emails 0 do
      member_meeting.update_attributes!(attending: true)
    end

    member_meeting.skip_mail_for_calendar_sync = false
    assert_emails 2 do
      member_meeting.update_attributes!(attending: true)
    end

    member_meeting.perform_sync_to_calendar = false
    assert_emails 1 do
      member_meeting.update_attributes!(attending: false)
    end
  end

  def test_after_destroy
    meeting = meetings(:psg_mentor_psg_student)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(meeting.member_meetings.size).with(Meeting, [meeting.id])
    meeting.update_column(:group_id, nil)
    assert meeting.active?
    meeting.member_meetings.destroy_all
    assert_equal false, meeting.active?

    member_meeting = member_meetings(:member_meetings_1)
    member_meeting.stubs(:meeting).returns(nil)
    assert_difference "MemberMeeting.count", -1 do
      member_meeting.destroy
    end
  end
end
