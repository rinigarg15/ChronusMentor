class CampaignManagement::UserCampaign < CampaignManagement::AbstractCampaign

  include CampaignManagement::AbstractCampaignState

  MASS_UPDATE_ATTRIBUTES = {
    create: [:title],
    update: [:title],
    clone: [:title]
  }

  belongs_to :program

  before_destroy :set_marked_for_destroy

  has_many :campaign_messages,
    :dependent => :destroy,
    :foreign_key => "campaign_id",
    :class_name => "CampaignManagement::UserCampaignMessage",
    :inverse_of => :campaign

  has_many :statuses,
    :dependent => :destroy,
    :foreign_key => "campaign_id",
    :class_name => "CampaignManagement::UserCampaignStatus",
    :inverse_of => :campaign

  has_many :campaign_message_analyticss, :through => :campaign_messages
  has_many :email_templates, :through => :campaign_messages
  has_many :emails, :through => :campaign_messages
  has_many :jobs, :through => :campaign_messages

  validates :program, :trigger_params, presence: true

  attr_accessor :for_cloning

  CAMPAIGN_EMAILS = "Campaign Emails"

  def self.clone(parent, options={})
    campaign = parent.program.user_campaigns.new(title: options[:title], trigger_params: options[:trigger_params], state: options[:state])
    parent.campaign_messages.includes(:email_template).each do |parent_cm|
      campaign.build_message_from(parent_cm)
    end
    campaign.save!
    return campaign
  end

  def all_admin_view_ids
    trigger_params.values.inject([]) { |res, x| res += x }.uniq
  end

  def all_admin_views
    self.program.admin_views.where(id: all_admin_view_ids)
  end

  def get_first_admin_view_name
    get_first_admin_view.title
  end

  def campaign_email_tags
    all_tags = ChronusActionMailer::Base.mailer_attributes[:tags][:campaign_tags]
    if program.ongoing_mentoring_enabled?
      all_tags = all_tags.merge(ChronusActionMailer::Base.mailer_attributes[:tags][:mentoring_connection_tags])
    end
    if program.matching_by_mentee_alone? && program.ongoing_mentoring_enabled?
      all_tags = all_tags.merge(ChronusActionMailer::Base.mailer_attributes[:tags][:mentor_request_campaign_tags])
      all_tags = all_tags.merge(ChronusActionMailer::Base.mailer_attributes[:tags][:recommended_mentors_tag])
    end
    if program.calendar_enabled?
      all_tags = all_tags.merge(ChronusActionMailer::Base.mailer_attributes[:tags][:meeting_request_campaign_tags])
      all_tags = all_tags.merge(ChronusActionMailer::Base.mailer_attributes[:tags][:recommended_mentors_tag])
    end
    all_tags
  end

  def self.get_campaign_emails_title
    "feature.campaign.campaign_emails.user_campaign_emails".translate
  end

  def valid_emails
    emails.created_after(enabled_at)
  end

  def build_message_from(parent_cm)
    cm = self.campaign_messages.build(sender_id: parent_cm.sender_id, duration: parent_cm.duration)
    cm.build_email_template(parent_cm.email_template.attributes.slice("subject", "source", "program_id"))
    cm.email_template.belongs_to_cm = true
  end

  # Cleans up jobs and statuses for users who are no longer a part of the view
  # Creates statuses and jobs for new users who became a part of the view
  # Creates statuses and jobs for newly created campaigns
  def process!(skip_observer = false)
    return unless active?
    self.skip_observer = skip_observer
    start_time = Time.zone.now
    existing_object_ids = statuses.pluck(:abstract_object_id)
    ids_to_delete = existing_object_ids - get_current_object_ids
    new_object_ids = get_current_object_ids - existing_object_ids
    
    cleanup_jobs_for_object_ids(ids_to_delete)
    create_campaign_message_jobs(new_object_ids.take(MAX_NEW_OBJECTS), start_time)
    fix_inconsistencies(start_time)
  end

  # trigger_params has following structure now:
  # {
  #   1: [1, 2], # [1, 2] - admin-view ids
  #   2: [3]     # [3] - admin-view ids
  # }
  # this will be processed as ([AdminView-1] | [AdminView-2]) & [AdminView-3]
  def get_current_object_ids
    if @object_ids.nil?
      groups = trigger_params.map do |key, abstract_view_ids|
        aggregate_object_ids(program.abstract_views.where(id: abstract_view_ids))
      end
      @object_ids = aggregate_object_ids_by_groups(groups)
    end
    @object_ids
  end

  # This function will be useful: 
  # When new campaign message is added for an active campaign.
  def fix_inconsistencies(start_time)
    statuses.reload
    campaign_messages.newly_created_messages.each do |campaign_message|
      campaign_message.create_jobs_for_newly_created_campaign_message(start_time)
    end
  end

  def aggregate_object_ids(abstract_views)
    res = abstract_views.inject([]) do |ids, abstract_view|
      ids |= get_abstract_view_ids(abstract_view)
    end
  end

  def aggregate_object_ids_by_groups(groups)
    array = []
    array += groups.first unless groups.empty?
    groups.inject(array) do |ids, group|
      ids &= group
    end
  end

  def set_marked_for_destroy
    self._marked_for_destroy_ = true
  end

end