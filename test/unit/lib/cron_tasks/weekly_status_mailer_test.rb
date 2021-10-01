require_relative './../../../test_helper'

class CronTasks::WeeklyStatusMailerTest < ActiveSupport::TestCase

  def test_perform
    Notify.expects(:admins_weekly_status).once
    CronTasks::WeeklyStatusMailer.new.perform
  end
end