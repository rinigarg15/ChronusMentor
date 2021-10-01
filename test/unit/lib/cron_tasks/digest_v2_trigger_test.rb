require_relative './../../../test_helper'

class CronTasks::DigestV2TriggerTest < ActiveSupport::TestCase

  def test_perform
    trigger = mock
    trigger.expects(:start).once
    DigestV2Utils::Trigger.expects(:new).once.returns(trigger)
    CronTasks::DigestV2Trigger.new.perform
  end
end