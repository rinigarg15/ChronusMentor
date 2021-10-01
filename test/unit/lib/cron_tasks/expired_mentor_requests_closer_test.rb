require_relative './../../../test_helper'

class CronTasks::ExpiredMentorRequestsCloserTest < ActiveSupport::TestCase

  def test_perform
    MentorRequest.expects(:notify_expired_mentor_requests).once
    CronTasks::ExpiredMentorRequestsCloser.new.perform
  end
end