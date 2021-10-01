require_relative './../../../test_helper'

class CronTasks::FacilitationMessagesMailerTest < ActiveSupport::TestCase

  def test_perform
    Notify.expects(:facilitation_messages).once
    CronTasks::FacilitationMessagesMailer.new.perform
  end
end