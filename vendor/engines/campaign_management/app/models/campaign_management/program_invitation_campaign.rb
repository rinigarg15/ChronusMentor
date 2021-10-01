class CampaignManagement::ProgramInvitationCampaign < CampaignManagement::AbstractCampaign
  has_paper_trail on: [:update], class_name: 'ChronusVersion'
  belongs_to :program

  has_many :campaign_messages,
    :dependent => :destroy,
    :foreign_key => "campaign_id",
    :class_name => "CampaignManagement::ProgramInvitationCampaignMessage",
    :inverse_of => :campaign

  has_many :statuses,
    :dependent => :destroy,
    :foreign_key => "campaign_id",
    :class_name => "CampaignManagement::ProgramInvitationCampaignStatus",
    :inverse_of => :campaign

  has_many :campaign_message_analyticss, :through => :campaign_messages
  has_many :jobs, :through => :campaign_messages
  has_many :email_templates, :through => :campaign_messages
  has_many :emails, :through => :campaign_messages
  has_many :job_logs, as: :loggable_object

  validates :program_id, presence: true, :uniqueness => true

  CAMPAIGN_EMAILS = "Invitation Emails"

  before_create :set_enabled_at

  def set_enabled_at
    self.enabled_at = Time.now
  end
  
  def campaign_email_tags
    ChronusActionMailer::Base.mailer_attributes[:tags][:program_invitation_campaign_tags]
  end

  def self.get_campaign_emails_title
    "feature.campaign.campaign_emails.program_invitation_campaign_emails".translate
  end

  def start_program_invitation_campaign(program_invitation)
    create_campaign_message_jobs([program_invitation.id], program_invitation.sent_on)
  end

# Will either be an array with a single Id or an array with one plus ids
  def stop_program_invitation_campaign(program_invitation_ids)
    cleanup_jobs_for_object_ids(program_invitation_ids)
  end

  def start_program_invitation_campaign_and_send_first_campaign_message(program_invitation)
    start_program_invitation_campaign(program_invitation)
    first_campaign_message_job = program_invitation.get_first_job
    CampaignManagement::CampaignMessageJobProcessor.bulk_send_campaign_messages(first_campaign_message_job, skip_parallel_processing: true)
  end

  def valid_emails
    emails
  end

  def version_number
    versions.size + 1
  end

end