require_relative './../../../test_helper'

class CronTasks::SessionsCleanerTest < ActiveSupport::TestCase

  def test_perform
    session = ActiveRecord::SessionStore::Session.new
    session.session_id = 1
    session.data = "Test"
    session.updated_at = SESSION_DATA_CLEARANCE_PERIOD.ago - 1.day
    session.save!

    session_2 = ActiveRecord::SessionStore::Session.new
    session_2.session_id = 2
    session_2.data = "Test"
    session_2.save!

    assert_difference "ActiveRecord::SessionStore::Session.count", -1 do
      CronTasks::SessionsCleaner.new.perform
    end
    assert_nothing_raised { session_2.reload }
  end
end