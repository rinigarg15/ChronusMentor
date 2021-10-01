require_relative './../../../test_helper'

class CronTasks::DelayedJobStatusNotifierTest < ActiveSupport::TestCase

  def test_perform
    dj_notifier = mock
    dj_notifier.expects(:notify_status).once
    DjNotifier.expects(:new).once.returns(dj_notifier)
    CronTasks::DelayedJobStatusNotifier.new.perform
  end
end