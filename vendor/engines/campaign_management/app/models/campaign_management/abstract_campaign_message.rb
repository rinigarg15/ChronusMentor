class CampaignManagement::AbstractCampaignMessage < ActiveRecord::Base
  include AppConstantsHelper
  include CampaignManagement::CampaignsHelper
  self.table_name = "cm_campaign_messages"

  belongs_to :sender, class_name: "User"

  MASS_UPDATE_ATTRIBUTES = {
    create: [:duration],
    update: [:duration],
    mailer_template: {create: [:subject, :source], update: [:subject, :source]}
  }

  module TYPE
    USER = "CampaignManagement::UserCampaignMessage"
    PROGRAMINVITATION = "CampaignManagement::ProgramInvitationCampaignMessage"
    SURVEY = "CampaignManagement::SurveyCampaignMessage"

    def self.all
      [USER, PROGRAMINVITATION, SURVEY]
    end
  end

  # Storing the analytic summary at the campaign message level as the below format
  # {
  #   :201401 => {
  #     Type::OPENED => 4, 
  #     Type::CLICKED => 6, 
  #     Type::SPAMMED => 7
  #   },
  # :201402 => {
  #     Type::OPENED => 12, 
  #     Type::CLICKED => 45, 
  #     Type::SPAMMED => 34
  #   },    
  # }
  # These numbers get updated whenever there is an email event from webhook

  has_one :email_template, foreign_key: "campaign_message_id", dependent: :destroy, class_name: "Mailer::Template"

  has_many :campaign_message_analyticss,
            :dependent => :destroy,
            :foreign_key => "campaign_message_id",
            :class_name => "CampaignManagement::CampaignMessageAnalytics",
            :inverse_of => :campaign_message

  has_many :emails,
            :foreign_key => "campaign_message_id",
            :class_name => "CampaignManagement::CampaignEmail",
            :inverse_of => :campaign_message

  validates :duration, :presence => true
  validates_presence_of :email_template
  validates :type, inclusion: { :in => TYPE.all }, presence: true

  scope :newly_created_messages,  -> { where(user_jobs_created: false) }
  scope :old_messages,   -> { where(user_jobs_created: true) }

  attr_accessor :source, :subject, :skip_observer, :mark_campaign_active
  accepts_nested_attributes_for :email_template

  def self.reset_sender_id_for(user_id)
    where(sender_id: user_id).update_all(sender_id: nil)
  end

  def self.get_analytics_summary_key(time)
    Time.at(time).strftime("%Y%m")
  end

  # Pass the tags as strings. This will replace {{tag}} inside the template body and subject with %recipient.tag%
  def replace_mustache_with_mailgun_delimiters(user_variables)
    template = self.email_template
    subject = Rinku.auto_link(template.subject)
    body = Rinku.auto_link(template.source) + "{{widget_styles}}"
    replacement_hash = Hash[user_variables.map{|key| ["{{#{key}}}", "%recipient.#{key}%"]}]
    subject.gsub!(/{{.*?}}/, replacement_hash)
    body.gsub!(/{{.*?}}/, replacement_hash)
    return subject, body
  end

  def mail_sender_name
    program = campaign.program
    message_sender = render_campaign_message_sender(sender_id, program)
    if message_sender != program.name
      "feature.email.content.sender_via_program_html".translate(:sender_name => message_sender, :program => program.name) 
    else
      program.name
    end
  end

  def handle_schedule_update(update_time)
    if campaign.is_survey_campaign?
      handle_schedule_update_for_survey_campaign(update_time)
    else
      self.update_jobs_timing
      self.create_jobs_for_eligible_statuses(update_time)
    end
  end

  def update_jobs_timing
    status_hash = campaign.statuses.select([:started_at, :abstract_object_id]).group_by(&:abstract_object_id)
    jobs.each do |job|
      job.run_at = status_hash[job.abstract_object_id].first.started_at + duration.days
      job.save!
    end
  end

  def event_rate(event_type)
    total_sent = emails.count 
    event_rate = 0
    if total_sent > 0
      event_count = campaign_message_analyticss.where(event_type: event_type).sum(:event_count)
      event_rate = ( event_count * 1.0 ) / total_sent
    end
    event_rate
  end

  def create_jobs(params)
    jobs.create!(params)
  end

  def create_jobs_for_newly_created_campaign_message(start_time)
    params = []
    campaign.statuses.where("started_at>=?", start_time - duration.days).each do |stat|
      params << {abstract_object_id: stat.abstract_object_id, run_at: stat.started_at + duration.days}
    end
    create_jobs(params)
    self.user_jobs_created = true
    self.save!
  end

end