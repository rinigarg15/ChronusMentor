require_relative './../../../test_helper'

class CronTasks::ExpiredMeetingRequestsCloserTest < ActiveSupport::TestCase

  def test_perform
    MeetingRequest.expects(:notify_expired_meeting_requests).once
    CronTasks::ExpiredMeetingRequestsCloser.new.perform
  end
end