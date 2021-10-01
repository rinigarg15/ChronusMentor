require_relative './../../../test_helper'

class CronTasks::EmailMonitorTest < ActiveSupport::TestCase

  def test_perform
    EmailMonitor.any_instance.expects(:send_email).once
    CronTasks::EmailMonitor.new.perform
  end
end