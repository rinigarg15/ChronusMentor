require_relative './../../../../test_helper'

class CronTasks::CampaignManagement::JobsProcessorTest < ActiveSupport::TestCase

  def test_perform
    CampaignManagement::CampaignMessageJobProcessor.expects(:process)
    CronTasks::CampaignManagement::JobsProcessor.new.perform
  end
end