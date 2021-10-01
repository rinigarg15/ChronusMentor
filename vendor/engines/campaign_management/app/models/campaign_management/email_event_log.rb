class CampaignManagement::EmailEventLog < ActiveRecord::Base
  self.table_name = "cm_email_event_logs"

  PERMANENT_FAILURE = "permanent"

  module Type
    OPENED      = 0
    CLICKED     = 1
    DELIVERED   = 2
    DROPPED     = 3
    BOUNCED     = 4
    SPAMMED     = 5
    FAILED      = 6

    def self.all
      (OPENED..FAILED)
    end
  end

  # TODO: Find if this is the proper approach
  module MessageType
    ADMIN_MESSAGE = "AbstractMessage"
    PROGRAM_INVITATION_MESSAGE = "CampaignManagement::CampaignEmail"

    ALL = [ADMIN_MESSAGE, PROGRAM_INVITATION_MESSAGE]
  end

  belongs_to :message, :polymorphic => true

  validates :event_type, :timestamp, :message_id, :message_type, presence: true
  validates :event_type, inclusion: { :in => Type::OPENED..Type::FAILED}

  # TODO: Find if this is the correct approach or not
  validates :message_type, inclusion: { :in => MessageType::ALL}
  validates_uniqueness_of :event_type, :scope => [:timestamp, :message_id, :message_type]

  def self.store_campaign_event_data(params, mailgun_domain = "")
    email_event_type         = mailgun_events_hash[params['event']]
    message_id, message_type, from_campaign = get_campaign_email_id_and_type(params['user-variables'])
    message_id = get_valid_message_id(mailgun_domain, message_id, message_type, from_campaign)
    return if message_id.blank?
    event_log = CampaignManagement::EmailEventLog.new(:event_type => email_event_type, :message_id => message_id, :message_type => message_type, :timestamp => Time.at(params["timestamp"].to_f))
    event_log.params = params["url"] if (email_event_type == Type::CLICKED && params["url"])
    # Dont store temporary failures
    return if (email_event_type == Type::FAILED) && (params['severity'] != PERMANENT_FAILURE)
    event_log.save
  end

  def self.get_campaign_email_id_and_type(params)
    if params['campaign']
      campaign_params_hash = params['campaign'].is_a?(Hash) ? params['campaign'] : JSON(params['campaign'])
      return campaign_params_hash['message_id'].to_i, campaign_params_hash['message_type'], true
    else
      return params["admin_message_id"], MessageType::ADMIN_MESSAGE, false
    end
  end


  def update_analytics_summary_of_campaign_message
    # There can be cases where campaign message is deleted. Test being covered as part of test_deleteing_campaign_message_should_not_delete_the_corresponding_admin_message
    campaign_message = message.campaign_message
    return unless campaign_message
    return if any_similar_event_exists_already?
    return if message_older_than_campaign_enabled_at?(message)
    key = CampaignManagement::AbstractCampaignMessage.get_analytics_summary_key(message.created_at)
    CampaignManagement::CampaignMessageAnalytics.add_to_campaign_message_analytics(campaign_message, key, event_type)
  end

  # Mailgun does not track 'open' event when the images are disabled in email clients. Refer https://documentation.mailgun.com/user_manual.html#tracking-opens
  # Hence making sure that there exists an 'open' event when 'clicked' event is present.
  def handle_clicked_event
    message.event_logs.find_or_create_by(event_type: Type::OPENED) do |new_email_event_log|
      new_email_event_log.timestamp = timestamp - 1.second
    end
  end

  private

  def self.get_valid_message_id(mailgun_domain, message_id, message_type, from_campaign = false)
    # Only for the migrated environments we need to look for the mapping mailgun domain.
    source_environment = INVERTED_MAILGUN_DOMAIN_ENVIRONMENT_MAP[mailgun_domain] if mailgun_domain != MAILGUN_DOMAIN
    if source_environment.blank?
      valid_id = if from_campaign && message_type == MessageType::ADMIN_MESSAGE
                  message_type.constantize.where(id: message_id).where.not(campaign_message_id: nil).pluck(:id)[0]
                else
                  message_type.constantize.where(id: message_id).pluck(:id)[0]
                end
      return valid_id if valid_id.present?
      # If program is moved as a standalone organization within same server, then mailgun domain will be same but message id will be changed.
      source_environment = Rails.env.to_s
    end
    message_type.constantize.where("source_audit_key LIKE '#{source_environment}_%_#{message_id}'").pluck(:id)[0]
  end

  def self.mailgun_events_hash
    {
      ChronusMentorMailgun::Event::OPENED => Type::OPENED,
      ChronusMentorMailgun::Event::CLICKED => Type::CLICKED,
      ChronusMentorMailgun::Event::DELIVERED => Type::DELIVERED,
      ChronusMentorMailgun::Event::DROPPED => Type::DROPPED,
      ChronusMentorMailgun::Event::BOUNCED => Type::BOUNCED,
      ChronusMentorMailgun::Event::SPAMMED => Type::SPAMMED,
      ChronusMentorMailgun::Event::FAILED => Type::FAILED,
    }
  end

  def any_similar_event_exists_already?
    CampaignManagement::EmailEventLog.where(:message_id => message_id, :message_type => message_type, :event_type => event_type).count > 1
  end

  def message_older_than_campaign_enabled_at?(message)
    # So that we do not capture old message events for the re-enabled campaigns
    message.campaign_message.is_a?(CampaignManagement::UserCampaignMessage) && message.created_at < message.campaign_message.campaign.enabled_at
  end

end
