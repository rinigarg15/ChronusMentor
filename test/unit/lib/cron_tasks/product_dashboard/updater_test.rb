require_relative './../../../../test_helper'

class CronTasks::ProductDashboard::UpdaterTest < ActiveSupport::TestCase

  def test_perform
    product_dashboard = mock
    product_dashboard.expects(:allowed_for_env).once.returns(true)
    product_dashboard.expects(:update).once
    ProductDashboard.expects(:new).once.returns(product_dashboard)
    CronTasks::ProductDashboard::Updater.new.perform
  end

  def test_perform_when_not_allowed_for_env
    ProductDashboard.any_instance.expects(:update).never
    CronTasks::ProductDashboard::Updater.new.perform
  end
end