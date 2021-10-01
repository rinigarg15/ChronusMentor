require_relative './../../../test_helper'

class CronTasks::ExpiredPasswordsCleanerTest < ActiveSupport::TestCase

  def test_perform
    Password.expects(:destroy_expired).once
    CronTasks::ExpiredPasswordsCleaner.new.perform
  end
end