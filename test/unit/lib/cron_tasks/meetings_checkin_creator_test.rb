require_relative './../../../test_helper'

class CronTasks::MeetingsCheckinCreatorTest < ActiveSupport::TestCase

  def test_perform
    GroupCheckin.expects(:meetings_checkin_creation).once
    CronTasks::MeetingsCheckinCreator.new.perform
  end
end