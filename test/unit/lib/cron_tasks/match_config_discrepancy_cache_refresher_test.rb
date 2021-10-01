require_relative './../../../test_helper'

class CronTasks::MatchConfigDiscrepancyCacheRefresherTest < ActiveSupport::TestCase

  def test_perform
    MatchConfigDiscrepancyCache.expects(:refresh_top_discrepancies).once
    CronTasks::MatchConfigDiscrepancyCacheRefresher.new.perform
  end
end