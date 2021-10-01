require_relative './../../../../test_helper'

class CronTasks::CampaignManagement::AnalyticsSynchronizerTest < ActiveSupport::TestCase

  def test_perform
    CampaignManagement::CampaignAnalyticsSynchronizer.instance.expects(:sync).once
    CronTasks::CampaignManagement::AnalyticsSynchronizer.new.perform
  end
end