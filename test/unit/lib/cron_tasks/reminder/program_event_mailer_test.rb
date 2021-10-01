require_relative './../../../../test_helper'

class CronTasks::Reminder::ProgramEventMailerTest < ActiveSupport::TestCase

  def test_perform
    ProgramEvent.expects(:send_program_event_reminders).once
    CronTasks::Reminder::ProgramEventMailer.new.perform
  end
end