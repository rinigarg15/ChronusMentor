require_relative './../../../test_helper'

class CronTasks::MatchingIndexerTest < ActiveSupport::TestCase

  def test_perform
    Matching.expects(:perform_full_index_and_refresh).once
    CronTasks::MatchingIndexer.new.perform
  end
end