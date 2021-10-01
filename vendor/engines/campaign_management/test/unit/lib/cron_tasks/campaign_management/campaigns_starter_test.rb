require_relative './../../../../test_helper'

class CronTasks::CampaignManagement::CampaignsStarterTest < ActiveSupport::TestCase

  def test_perform
    CampaignManagement::CampaignProcessor.instance.expects(:start)
    CronTasks::CampaignManagement::CampaignsStarter.new.perform
  end
end