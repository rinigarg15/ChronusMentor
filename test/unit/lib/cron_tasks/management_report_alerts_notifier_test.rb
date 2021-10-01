require_relative './../../../test_helper'

class CronTasks::ManagementReportAlertsNotifierTest < ActiveSupport::TestCase

  def test_perform
    Report::Alert.expects(:send_alert_mails).once
    CronTasks::ManagementReportAlertsNotifier.new.perform
  end
end