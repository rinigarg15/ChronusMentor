require_relative './../../../../test_helper'

class CronTasks::Reminder::MeetingMailerTest < ActiveSupport::TestCase

  def test_perform
    MemberMeeting.expects(:send_meeting_reminders).once
    CronTasks::Reminder::MeetingMailer.new.perform
  end
end