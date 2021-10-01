class CampaignManagement::SurveyCampaignMessage < CampaignManagement::AbstractCampaignMessage
  CAMPAIGN_MESSAGE_DURATION_MIN_IN_DAYS = 0

  belongs_to :campaign,
             :foreign_key => "campaign_id",
             :class_name => "CampaignManagement::SurveyCampaign",
             :inverse_of => :campaign_messages

  has_many :jobs,
            :dependent => :destroy,
            :foreign_key => "campaign_message_id",
            :class_name => "CampaignManagement::SurveyCampaignMessageJob",
            :inverse_of => :campaign_message

  has_many :emails,
            :foreign_key => "campaign_message_id",
            :class_name => "CampaignManagement::CampaignEmail",
            :inverse_of => :campaign_message

  validates :campaign, presence: true
  validates :duration, :numericality => { :greater_than_or_equal_to => CAMPAIGN_MESSAGE_DURATION_MIN_IN_DAYS }

  def is_duration_editable?
    true
  end

  def is_last_message?
    false
  end

  def handle_schedule_update_for_survey_campaign(update_time)
    handle_existing_jobs
    create_jobs_for_eligible_statuses(update_time)
  end

  def handle_existing_jobs
    status_hash = campaign.statuses.select([:started_at, :abstract_object_id]).index_by(&:abstract_object_id)
    jobs.each do |job|
      new_run_at = status_hash[job.abstract_object_id].started_at + duration.days
      # Remove or update the job depending on the new run_at is in the past or the future
      if new_run_at + CampaignManagement::SurveyCampaign::SURVEY_CAMPAIGN_BUFFER_TIME > Time.now.utc
        job.run_at = new_run_at
        job.save!
      else
        job.destroy
      end
    end
  end

  def create_jobs_for_eligible_statuses(update_time)
    # Creating jobs for the newly eligible statuses on duration update
    all_task_ids = self.campaign.statuses.where("started_at >= ?", update_time - self.duration.days).pluck(:abstract_object_id)
    task_ids_with_jobs = self.jobs.pluck(:abstract_object_id)
    task_ids_with_mails_sent = self.emails.pluck(:abstract_object_id)
    task_ids_to_be_handled = all_task_ids - task_ids_with_jobs - task_ids_with_mails_sent
    statuses_to_be_handled = self.campaign.statuses.where(abstract_object_id: task_ids_to_be_handled)

    if statuses_to_be_handled.present?
      params = []
      statuses_to_be_handled.each do |status|
        params << { abstract_object_id: status.abstract_object_id, run_at: status.started_at + duration.days }
      end
      create_jobs(params)
    end
  end
end