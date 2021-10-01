require_relative './../../../test_helper'

class CronTasks::BackupServerDetectorTest < ActiveSupport::TestCase

  def test_perform
    MultipleServersUtils.expects(:detect_multiple_servers_running).once
    CronTasks::BackupServerDetector.new.perform
  end
end