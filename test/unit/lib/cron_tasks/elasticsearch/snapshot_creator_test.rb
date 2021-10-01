require_relative './../../../../test_helper'

class CronTasks::Elasticsearch::SnapshotCreatorTest < ActiveSupport::TestCase

  def test_perform
    EsSnapshot.expects(:create)
    CronTasks::Elasticsearch::SnapshotCreator.new.perform
  end
end