# CM_TODO this is self-recurring job. We need to determine how to call it first time.
class CampaignManagement::ProcessCampaignsJob
  DELAY = 6.hours

  def perform
    job = CampaignManagement::ProcessCampaignsJob.new
    Delayed::Job.enqueue(job, run_at: Time.now + DELAY)
    CampaignManagement::CampaignProcessor.instance.start
  end
end
