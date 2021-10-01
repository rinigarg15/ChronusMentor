require_relative './../../../../test_helper'

class CronTasks::ProductDashboard::AccountNamesUpdaterTest < ActiveSupport::TestCase

  def test_perform
    product_dashboard = mock
    product_dashboard.expects(:allowed_for_env).once.returns(true)
    product_dashboard.expects(:update).with(account_names: true).once
    ProductDashboard.expects(:new).once.returns(product_dashboard)
    CronTasks::ProductDashboard::AccountNamesUpdater.new.perform
  end

  def test_perform_when_not_allowed_for_env
    ProductDashboard.any_instance.expects(:update).never
    CronTasks::ProductDashboard::AccountNamesUpdater.new.perform
  end
end