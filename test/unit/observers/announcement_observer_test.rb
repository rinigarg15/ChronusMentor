require_relative './../../test_helper.rb'

class AnnouncementObserverTest < ActiveSupport::TestCase

  def test_new_recent_activity_is_added
    announcement = nil
    current_job_logs = JobLog.count
    assert_difference('RecentActivity.count') do
      announcement = create_announcement(email_notification: UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE)
    end
    notifiable_users_size = announcement.notification_list.size
    assert_equal 2*notifiable_users_size + current_job_logs, JobLog.count

    recent_activity = RecentActivity.last
    # Omit the one corresponding to the post
    assert_equal announcement.id, recent_activity.ref_obj_id
    assert_equal announcement.class.to_s, recent_activity.ref_obj_type
    assert_equal RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, recent_activity.action_type
    assert_nil recent_activity.for
    assert_equal RecentActivityConstants::Target::ALL, recent_activity.target

    # Announcement is updated
    # As the creation and update are done too closely, created at is changed.
    assert_difference "JobLog.count", 2*notifiable_users_size do
      assert_no_difference('RecentActivity.count') do
        announcement.update_attributes(title: "how are you", created_at: 2.days.ago, email_notification: UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE)
      end
    end
  end

  def test_publish_notification
    dj_stub = mock()
    Announcement.expects(:delay).returns(dj_stub).once
    dj_stub.expects(:notify_users).once
    push_mock = mock()
    Push::Base.expects(:delay).returns(push_mock).once
    push_mock.expects(:notify).once

    create_announcement(:title => "Hello", :email_notification => UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, :program => programs(:albers), :admin => users(:f_admin))
  end

  def test_draft_announcement_creation_notification
    assert_no_difference "JobLog.count" do
      assert_no_difference('RecentActivity.count') do
        create_announcement(status: Announcement::Status::DRAFTED, email_notification: UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE)
      end
    end
  end

  def test_update_published_announcement_notification
    announcement = announcements(:assemble)
    notifiable_users_size = announcement.notification_list.size
    emailable_users_size = announcement.notification_list.where("users.program_notification_setting = ?", UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE).where("users.state IN (?)", AnnouncementNotification.mailer_attributes[:user_states]).size
    Announcement.expects(:delay).returns(Announcement).once
    announcement.email_notification = UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE
    PushNotifier.expects(:push).times(notifiable_users_size)

    assert_difference "JobLog.count", 2*notifiable_users_size do
      assert_emails emailable_users_size do
        announcement.update_attributes!(:title => 'new title')
      end
    end

    Announcement.expects(:delay).returns(Announcement).once
    PushNotifier.expects(:push).times(notifiable_users_size)
    assert_difference "JobLog.count", 2*notifiable_users_size do
      assert_emails emailable_users_size do
        announcement.update_attributes!(:body => 'new body')
      end
    end

    Announcement.expects(:delay).returns(Announcement).never
    announcement.email_notification = UserConstants::DigestV2Setting::ProgramUpdates::DONT_SEND
    PushNotifier.expects(:push).never
    assert_no_difference "JobLog.count" do
      assert_no_emails do
        announcement.update_attributes!(:title => 'some title')
      end
    end
  end

  def test_update_drafted_announcement_notification
    announcement = announcements(:drafted_announcement)
    notifiable_users_size = announcement.notification_list.size

    assert_no_difference "JobLog.count" do
      assert_no_difference('RecentActivity.count') do
        announcement.update_attributes(email_notification: UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE)
      end
    end

    assert_difference "JobLog.count", 2*notifiable_users_size do
      assert_difference('RecentActivity.count') do
        announcement.update_attributes(email_notification: UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, status: Announcement::Status::PUBLISHED)
      end
    end
  end

  def test_notification_not_sent_when_email_notification_is_not_set
    Announcement.expects(:delay).never

    announcement = create_announcement
    announcement.update_attributes(:title => "How are you")
  end

  def test_assert_push_notifications_for_published_announcement
    announcement = announcements(:drafted_announcement)
    notifiable_users_size = announcement.notification_list.size

    PushNotifier.expects(:push).times(notifiable_users_size)
    announcement.update_attributes!(status: Announcement::Status::PUBLISHED, email_notification: UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE)
  end

  def test_announcemnt_notification_not_if_block_mail
    announcement = announcements(:assemble)
    announcement.block_mail = true
    announcement.email_notification = UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE

    Announcement.expects(:delay).never
    PushNotifier.expects(:push).never

    assert_no_emails do
      announcement.update_attributes!(:title => 'new title')
    end
  end
end
