require_relative './../../../test_helper'

class CronTasks::ActiveMembersMonitorTest < ActiveSupport::TestCase

  def test_perform
    AccountMonitor::MonitoringActiveMembers.expects(:active_member_monitor).once
    CronTasks::ActiveMembersMonitor.new.perform
  end
end