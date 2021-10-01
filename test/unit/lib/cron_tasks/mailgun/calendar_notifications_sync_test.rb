require_relative './../../../../test_helper'

class CronTasks::Mailgun::CalendarNotificationsSyncTest < ActiveSupport::TestCase

  def test_perform
    pull_notification = mock
    pull_notification.expects(:update_meetings_and_program_events_with_calendars).once
    Calendar::PullNotification.expects(:new).returns(pull_notification)
    CronTasks::Mailgun::CalendarNotificationsSync.new.perform
  end
end