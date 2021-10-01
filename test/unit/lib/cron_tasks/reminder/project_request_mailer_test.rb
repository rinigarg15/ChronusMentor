require_relative './../../../../test_helper'

class CronTasks::Reminder::ProjectRequestMailerTest < ActiveSupport::TestCase

  def test_perform
    ProjectRequest.expects(:send_project_request_reminders).once
    CronTasks::Reminder::ProjectRequestMailer.new.perform
  end
end