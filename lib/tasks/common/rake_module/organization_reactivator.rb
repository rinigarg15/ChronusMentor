module Common::RakeModule::OrganizationReactivator

  def self.fetch_jobs_and_notifications(organization)
    program_ids = organization.program_ids
    abstract_campaign_ids = CampaignManagement::AbstractCampaign.where(program_id: program_ids).pluck(:id)
    abstract_campaign_message_ids = CampaignManagement::AbstractCampaignMessage.where(campaign_id: abstract_campaign_ids).pluck(:id)
    abstract_campaign_message_jobs = CampaignManagement::AbstractCampaignMessageJob.where(campaign_message_id: abstract_campaign_message_ids)
    pending_notifications = PendingNotification.where(program_id: program_ids)
    [abstract_campaign_message_jobs, pending_notifications]
  end
end