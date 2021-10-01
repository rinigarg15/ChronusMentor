require_relative './../../../test_helper'

class CronTasks::GroupsExpirerTest < ActiveSupport::TestCase

  def test_perform
    Group.expects(:terminate_expired_connections).once
    CronTasks::GroupsExpirer.new.perform
  end
end