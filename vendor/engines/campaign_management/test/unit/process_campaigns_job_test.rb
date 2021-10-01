require_relative './../test_helper'

class ProcessCampaignsJobTest < ActiveSupport::TestCase
  def test_perform
    process_job = CampaignManagement::ProcessCampaignsJob.new

    next_job = mock
    CampaignManagement::ProcessCampaignsJob.expects(:new).returns(next_job)
    Delayed::Job.expects(:enqueue)
    CampaignManagement::CampaignProcessor.any_instance.expects(:start)

    process_job.perform
  end
end
