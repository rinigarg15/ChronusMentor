class CampaignManagement::UserCampaignMessage < CampaignManagement::AbstractCampaignMessage

  CAMPAIGN_MESSAGE_DURATION_MIN_IN_DAYS = 0

  belongs_to :campaign,
             :foreign_key => "campaign_id",
             :class_name => "CampaignManagement::UserCampaign",
             :inverse_of => :campaign_messages

  has_many :jobs,
            :dependent => :destroy,
            :foreign_key => "campaign_message_id",
            :class_name => "CampaignManagement::UserCampaignMessageJob",
            :inverse_of => :campaign_message

  validates :campaign, presence: true
  validate :validate_sender
  
  has_many :emails,
            :foreign_key => "campaign_message_id",
            :class_name => "AdminMessage",
            :inverse_of => :campaign_message

  validates :duration, :numericality => { :greater_than_or_equal_to => CAMPAIGN_MESSAGE_DURATION_MIN_IN_DAYS}

  after_destroy :stop_campaign_if_no_campaign_messages
  after_save :mark_campaign_active_if_needed

  def is_duration_editable?
    true
  end

  def create_jobs_for_eligible_statuses(update_time)
    # Creating jobs for the newly eligible statuses on duration update
    program = self.campaign.program
    all_eligible_statuses = self.campaign.statuses.where("started_at >= ?", update_time - self.duration.days)
    all_eligible_user_ids = all_eligible_statuses.pluck(:abstract_object_id)
    all_eligible_member_ids = program.users.where(id: all_eligible_user_ids).pluck(:member_id)
    member_ids_with_jobs = program.users.where(id: self.jobs.pluck(:abstract_object_id)).pluck(:member_id)
    member_ids_with_mails_sent = self.emails.select("abstract_message_receivers.member_id AS receiver_id").joins(:message_receivers).collect(&:receiver_id)
    member_ids_to_be_handled = all_eligible_member_ids - member_ids_with_jobs - member_ids_with_mails_sent
    user_ids_to_be_handled = program.users.where(member_id: member_ids_to_be_handled).pluck(:id)
    statuses_to_be_handled = self.campaign.statuses.where(abstract_object_id: user_ids_to_be_handled)

    if statuses_to_be_handled.present?
      params = []
      statuses_to_be_handled.each do |status|
        params << { abstract_object_id: status.abstract_object_id, run_at: status.started_at + duration.days }
      end
      create_jobs(params)
    end
  end

  def is_last_message?
    campaign.campaign_messages.size == 1
  end

  private

  def validate_sender
    program = self.try(:campaign).try(:program)
    return unless program
    options = campaign_message_from_options(program)
    self.errors.add(:sender_id, "feature.campaigns.errors.sender_invalid_selection".translate) unless (options.map{ |r| r[1] }.include?(self.sender_id.to_i) || self.sender_id.nil?)
  end

  def stop_campaign_if_no_campaign_messages
    unless campaign._marked_for_destroy_
      if campaign.active? && campaign.reload.campaign_messages.empty?
        campaign.stop!
      end
    end
  end

  def mark_campaign_active_if_needed
    if campaign.drafted? && mark_campaign_active
      campaign.activate!
    end
  end
end