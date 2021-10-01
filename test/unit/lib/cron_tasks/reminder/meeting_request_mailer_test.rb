require_relative './../../../../test_helper'

class CronTasks::Reminder::MeetingRequestMailerTest < ActiveSupport::TestCase

  def test_perform
    MeetingRequest.expects(:send_meeting_request_reminders).once
    CronTasks::Reminder::MeetingRequestMailer.new.perform
  end
end