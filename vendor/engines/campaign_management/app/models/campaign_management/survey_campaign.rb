class CampaignManagement::SurveyCampaign < CampaignManagement::AbstractCampaign
  SURVEY_CAMPAIGN_BUFFER_TIME = 12.hours

  belongs_to :survey, foreign_key: :ref_obj_id
  belongs_to :program

  has_many :campaign_messages,
    :dependent => :destroy,
    :foreign_key => "campaign_id",
    :class_name => "CampaignManagement::SurveyCampaignMessage",
    :inverse_of => :campaign

  has_many :statuses,
    :dependent => :destroy,
    :foreign_key => "campaign_id",
    :class_name => "CampaignManagement::SurveyCampaignStatus",
    :inverse_of => :campaign

  has_many :campaign_message_analyticss, :through => :campaign_messages
  has_many :jobs, :through => :campaign_messages
  has_many :email_templates, :through => :campaign_messages
  has_many :emails, :through => :campaign_messages

  validates :ref_obj_id, presence: true, :uniqueness => true

  before_create :set_enabled_at

  def campaign_email_tags
    tags = ChronusActionMailer::Base.mailer_attributes[:tags]
    email_tags = tags["#{survey.type.underscore}_campaign_tags".to_sym]
    email_tags.merge(tags[:global_tags]).merge(tags[:subprogram_tags])
  end

  def build_message(subject, source, duration)
    cm = self.campaign_messages.build(duration: duration)
    cm.build_email_template(subject: subject, source: source, program_id: program_id)
    cm.email_template.belongs_to_cm = true
  end

  def process!
    processed_tasks = statuses.select(:abstract_object_id, :started_at)
    processed_hash = processed_tasks.inject({}){|h, s| h[s.abstract_object_id]=s.started_at;h}
    overdue_tasks = abstract_objects_which_can_be_processed
    overdue_hash = overdue_tasks.inject({}){|h, t| h[t.id]=t.due_date_for_campaigns;h}
    
    # If a task is no longer overdue or if its due date is changed then clear its existing statuses and jobs
    ids_of_tasks_to_cleanup = processed_tasks.select{|status| status.started_at != overdue_hash[status.abstract_object_id]}.collect(&:abstract_object_id)

    # If a task is not processed or if its due date changed then we need to create statuses and jobs
    ids_of_tasks_to_be_processed = overdue_tasks.select{|task| task.due_date_for_campaigns != processed_hash[task.id]}.collect(&:id)

    cleanup_jobs_for_object_ids(ids_of_tasks_to_cleanup)
    create_survey_campaign_message_statusses_and_jobs(ids_of_tasks_to_be_processed.take(MAX_NEW_OBJECTS), overdue_hash)
  end

  def create_survey_campaign_message_statusses_and_jobs(new_object_ids, start_time_hash)
    new_object_ids.each do |object_id|
      statuses.create!(abstract_object_id: object_id, started_at: start_time_hash[object_id])
    end
    create_survey_campaign_message_jobs(new_object_ids, start_time_hash)
  end

  def create_survey_campaign_message_jobs(new_object_ids, start_time_hash)
    campaign_messages.old_messages.each do |campaign_message|
      params = []
      new_object_ids.each do |object_id|
        run_at = start_time_hash[object_id] + campaign_message.duration.days
        # Only create the job if run_at is greater than the current time (with some buffer)
        # We do it differently from other type of campaigns as the due_date can also move backwards
        # The buffer is included to handle 0 duration
        if run_at + SURVEY_CAMPAIGN_BUFFER_TIME > Time.now.utc
          params << {abstract_object_id: object_id, campaign_message_id: campaign_message.id, run_at: run_at}
        end
      end
      campaign_message.create_jobs(params)
    end
  end

  def for_engagement_survey?
    survey.engagement_survey?
  end

  def abstract_object_klass
    survey.engagement_survey? ? MentoringModel::Task : MemberMeeting
  end

  private

  def abstract_objects_which_can_be_processed
    for_engagement_survey? ? survey.assigned_overdue_tasks.select(:id, :due_date) : survey.member_meetings_past_end_time
  end

  def set_enabled_at
    self.enabled_at = Time.now
  end
end