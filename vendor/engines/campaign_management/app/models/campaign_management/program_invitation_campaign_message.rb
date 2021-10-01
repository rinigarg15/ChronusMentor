class CampaignManagement::ProgramInvitationCampaignMessage < CampaignManagement::AbstractCampaignMessage
  
  CAMPAIGN_MESSAGE_DURATION_MIN_IN_DAYS = 0
  CAMPAIGN_MESSAGE_DURATION_MAX_IN_DAYS = 30

  
  belongs_to :campaign,
             :foreign_key => "campaign_id",
             :class_name => "CampaignManagement::ProgramInvitationCampaign",
             :inverse_of => :campaign_messages

  has_many :jobs,
            :dependent => :destroy,
            :foreign_key => "campaign_message_id",
            :class_name => "CampaignManagement::ProgramInvitationCampaignMessageJob",
            :inverse_of => :campaign_message

  has_many :emails,
            :foreign_key => "campaign_message_id",
            :class_name => "CampaignManagement::CampaignEmail",
            :inverse_of => :campaign_message

  validates :campaign, presence: true
  validates :duration, :numericality => { :greater_than_or_equal_to => CAMPAIGN_MESSAGE_DURATION_MIN_IN_DAYS, :less_than_or_equal_to => CAMPAIGN_MESSAGE_DURATION_MAX_IN_DAYS}  

  def is_duration_editable?
    self != campaign.campaign_messages.first
  end

  def is_last_message?
    false
  end

  def create_jobs_for_eligible_statuses(update_time)
    # Creating jobs for the newly eligible statuses on duration update
    all_eligible_statuses = self.campaign.statuses.where("started_at >= ?", update_time - self.duration.days)
    all_eligible_invite_ids = all_eligible_statuses.pluck(:abstract_object_id)
    invite_ids_with_jobs = self.jobs.pluck(:abstract_object_id)
    invite_ids_with_mails_sent = self.emails.pluck(:abstract_object_id)
    invite_ids_to_be_handled = all_eligible_invite_ids - invite_ids_with_jobs - invite_ids_with_mails_sent
    statuses_to_be_handled = self.campaign.statuses.where(abstract_object_id: invite_ids_to_be_handled)

    if statuses_to_be_handled.present?
      params = []
      statuses_to_be_handled.each do |status|
        params << { abstract_object_id: status.abstract_object_id, run_at: status.started_at + duration.days }
      end
      create_jobs(params)
    end
  end
end