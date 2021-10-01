require_relative './../../../../test_helper'

class CronTasks::Reminder::MentorRequestMailerTest < ActiveSupport::TestCase

  def test_perform
    MentorRequest.expects(:send_mentor_request_reminders).once
    CronTasks::Reminder::MentorRequestMailer.new.perform
  end
end