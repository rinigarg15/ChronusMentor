require_relative './../../../test_helper'

class CronTasks::CirclesAutoPublisherTest < ActiveSupport::TestCase

  def test_perform
    Group.expects(:auto_publish_circles).once
    CronTasks::CirclesAutoPublisher.new.perform
  end
end