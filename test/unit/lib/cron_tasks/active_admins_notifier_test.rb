require_relative './../../../test_helper'

class CronTasks::ActiveAdminsNotifierTest < ActiveSupport::TestCase

  def test_perform
    mailer = mock
    mailer.expects(:deliver_now).once
    active_admins_csv = "#{Rails.root}/tmp/active_admins.csv"
    CronTasks::ActiveAdminsNotifier.any_instance.expects(:pull_active_admins_in_csv).with(active_admins_csv).once
    InternalMailer.expects(:notify_active_admins).with(active_admins_csv).once.returns(mailer)
    CronTasks::ActiveAdminsNotifier.new.perform
  end

  def test_perform_with_config_disabled
    modify_const(:APP_CONFIG, notify_active_admins_to_cs: false) do
      self.expects(:pull_active_admins_in_csv).never
      InternalMailer.expects(:notify_active_admins).never
      CronTasks::ActiveAdminsNotifier.new.perform
    end
  end
end