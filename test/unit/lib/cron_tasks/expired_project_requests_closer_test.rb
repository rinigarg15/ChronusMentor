require_relative './../../../test_helper'

class CronTasks::ExpiredProjectRequestsCloserTest < ActiveSupport::TestCase

  def test_perform
    ProjectRequest.expects(:notify_expired_project_requests).once
    CronTasks::ExpiredProjectRequestsCloser.new.perform
  end
end