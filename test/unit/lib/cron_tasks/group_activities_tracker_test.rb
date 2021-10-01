require_relative './../../../test_helper'

class CronTasks::GroupActivitiesTrackerTest < ActiveSupport::TestCase

  def test_perform
    Group.expects(:track_inactivities).once
    CronTasks::GroupActivitiesTracker.new.perform
  end
end