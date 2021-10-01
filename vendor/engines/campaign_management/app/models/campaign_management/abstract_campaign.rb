class CampaignManagement::AbstractCampaign < ActiveRecord::Base
  self.table_name = "cm_campaigns"
  module STATE
    ACTIVE     = 0
    STOPPED    = 1
    DRAFTED    = 2

    def self.all
      constants.collect{|c| const_get(c)}
    end

  end
  
  module TYPE
    USER = "CampaignManagement::UserCampaign"
    PROGRAMINVITATION = "CampaignManagement::ProgramInvitationCampaign"
    SURVEY = "CampaignManagement::SurveyCampaign"

    def self.all
      [USER, PROGRAMINVITATION, SURVEY]
    end
  end
  
  MAX_NEW_OBJECTS = 2500

  before_destroy :cleanup_campaign_jobs
  before_destroy :cleanup_campaign_statuses

  validates :title, :type, presence: true
  validates :type, inclusion: { :in => TYPE.all }

  translates :title

  DEFAULT_TIMEFRAME_FOR_ANALYTICS = 6 # in months

  attr_accessor :skip_observer, :_marked_for_destroy_

  serialize :trigger_params

  # scopes
  def self.active
    where(state: STATE::ACTIVE)
  end

  def self.stopped
    where(state: STATE::STOPPED)
  end

  def self.drafted
    where(state: STATE::DRAFTED)
  end

  def active?
    self.state == STATE::ACTIVE
  end

  def stopped?
    self.state == STATE::STOPPED
  end

  def drafted?
    self.state == STATE::DRAFTED
  end

  def is_user_campaign?
    type == TYPE::USER
  end

  def is_program_campaign?
    type == TYPE::PROGRAMINVITATION
  end

  def is_survey_campaign?
    type == TYPE::SURVEY
  end

  def calculate_overall_analytics
    overall_analytics = Hash.new {0}
    
    campaign_message_analyticss.each do |analytic|
      overall_analytics[analytic.event_type] += analytic.event_count
    end
    
    return overall_analytics
  end

    # Returns the overall event counts and event counts grouped by months
  def calculate_monthly_aggregated_analytics(analytics_summary_keys)
    # Create the monthly aggregated hash
    monthly_aggregated_analytics = Hash.new
    analytics_summary_keys.each do |key|
      monthly_aggregated_analytics[key] = Hash.new {0}
    end
    campaign_message_analytics_entries = campaign_message_analyticss.where(:year_month => analytics_summary_keys)

    campaign_message_analytics_entries.each do |analytic|
      monthly_aggregated_analytics[analytic.year_month][analytic.event_type] += analytic.event_count
    end

    return monthly_aggregated_analytics
  end

  def get_abstract_view_ids(abstract_view)
    @abstract_view_ids_cache ||= {}
    @abstract_view_ids_cache[abstract_view.id] ||= abstract_view.generate_view("", "", false).to_a
  end

  def create_campaign_message_jobs(new_object_ids, start_time)
    new_object_ids.each do |object_id|
      statuses.create!(abstract_object_id: object_id, started_at: start_time)
    end
    campaign_messages.old_messages.each do |campaign_message|
      params = []
      new_object_ids.each do |object_id|
        params << {abstract_object_id: object_id, campaign_message_id: campaign_message.id, run_at: start_time + campaign_message.duration.days}
      end
      campaign_message.create_jobs(params)
    end
    
  end 

  def cleanup_jobs_for_object_ids(ids_to_delete)
    campaign_message_ids = campaign_messages.pluck(:id)
    # Delete the corresponding UserCampaignMessageJobs
    CampaignManagement::AbstractCampaignMessageJob.where(campaign_message_id: campaign_message_ids, abstract_object_id: ids_to_delete).delete_all

    statuses.reload
    # Delete the corresponding entries of AbstractCampaignStatus
    statuses.where(abstract_object_id: ids_to_delete).delete_all
  end

  def get_supported_tags_and_widgets
    return self.campaign_email_tags.keys.collect(&:to_s), []
  end

  def get_analytics_details(params = {})
    overall_analytics = calculate_overall_analytics
    analytic_stats = get_analytics_stats(params)

    # total_sent_count shouldnt respect the time filter passed!
    total_sent_count = self.valid_emails.count
    if total_sent_count > 0
      click_rate = (overall_analytics[CampaignManagement::EmailEventLog::Type::CLICKED] * 1.0/ total_sent_count) * 100
      open_rate = (overall_analytics[CampaignManagement::EmailEventLog::Type::OPENED] * 1.0/ total_sent_count) * 100
    else
      click_rate = 0
      open_rate  = 0
    end

    analytic_stats.merge!(:total_sent_count => total_sent_count)
    analytic_stats.merge!(:click_rate => (click_rate).round(1))
    analytic_stats.merge!(:open_rate => (open_rate).round(1))

    return overall_analytics, analytic_stats
  end

  private

  def cleanup_campaign_jobs
    destroy_jobs!
  end

  def cleanup_campaign_statuses
    statuses.delete_all
  end

  def destroy_jobs!
    CampaignManagement::AbstractCampaignMessageJob.where(campaign_message_id: campaign_message_ids).delete_all
  end

  def get_analytics_keys(params)
    # We are not posting any of these params from the frontend
    analytics_for_months = params[:months].try(:to_i) || DEFAULT_TIMEFRAME_FOR_ANALYTICS
    ending_time = Time.parse(params[:end_time].try(:to_s) || Time.now.to_s ) 

    expected_start_time  = (ending_time - (analytics_for_months-1).months)
    valid_start_time = (self.enabled_at && expected_start_time < self.enabled_at) ? self.enabled_at : expected_start_time
    starting_time = params[:start_time] || valid_start_time

    # Get the number of months between start and end points
    graph_points = (ending_time.year * 12 + ending_time.month) - (starting_time.year * 12 + starting_time.month)
    analytics_info = []
    (0..graph_points).each do |month_index|
      time = Time.at(starting_time + month_index.month)
      analytics_info << {
        campaign_message_analytics_key: CampaignManagement::AbstractCampaignMessage.get_analytics_summary_key(time),
        exact_time: time
      }
    end

    return starting_time, ending_time, analytics_info
  end

  def get_analytics_stats(params)
    analytic_stats = {}
    starting_time, ending_time, analytics_info = get_analytics_keys(params)

    analytic_year_month_keys = analytics_info.map{|h| h[:campaign_message_analytics_key]}
    monthly_aggregated_analytics = calculate_monthly_aggregated_analytics(analytic_year_month_keys)

    analytic_stats[:month_numbers] = analytics_info.map{|h| h[:exact_time].month}
    analytic_stats[:starting_time] = starting_time
    analytic_stats[:ending_time]   = ending_time
    
    analytic_stats[:sent]       = []
    analytic_stats[:delivered]  = []
    analytic_stats[:clicked]    = []
    analytic_stats[:opened]     = []

    monthly_aggregated_analytics.values_at(*analytic_year_month_keys).each do |events_hash|
      analytic_stats[:delivered] << events_hash[CampaignManagement::EmailEventLog::Type::DELIVERED]
      analytic_stats[:clicked]   << events_hash[CampaignManagement::EmailEventLog::Type::CLICKED]
      analytic_stats[:opened]    << events_hash[CampaignManagement::EmailEventLog::Type::OPENED]
    end

    analytics_info.each do |h|
      time = h[:exact_time]
      analytic_stats[:sent] << valid_emails.where(:created_at => (time.at_beginning_of_month..time.at_end_of_month)).count
    end

    return analytic_stats
  end

end
