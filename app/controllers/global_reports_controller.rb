class GlobalReportsController < ApplicationController
  include GlobalReportsControllerCommon

  before_action :login_required_in_organization
  skip_before_action :login_required_in_program, :require_program
  
  allow exec: :can_access_global_reports?

  def index
    @diversity_reports = @current_organization.diversity_reports
    @overall_impact_date_range = overall_impact_date_range({})
  end

  def overall_impact
    overall_impact_hash = {}
    @filters = params[:filters]&.permit(:date_range) || {}
    flags_hash = format_flags_hash(params.permit(:users_participated, :connections_created, :engagements_created, :satisfaction_rate))
    @overall_impact_date_range = overall_impact_date_range(@filters)
    update_rollup_for_overall_impact!(overall_impact_hash, flags_hash, @overall_impact_date_range.values)
    @overall_impact_hash = overall_impact_hash.presence
  end

  def overall_impact_survey_satisfaction_configurations
    @positive_outcome_surveys_by_program = positive_outcome_surveys_by_program
  end

  def edit_overall_impact_survey_satisfaction_configuration
    @survey_satisfaction_program = @current_organization.programs.find(params[:program_id])
  end

  def update_overall_impact_survey_satisfaction_configuration
    @survey_satisfaction_program = @current_organization.programs.find(params[:program_id])
    state = params[:reconsider].to_s.to_boolean ? true : (params[:ignore].to_s.to_boolean ? false : nil)
    @survey_satisfaction_program.update_attribute(:include_surveys_for_satisfaction_rate, state)
    @survey_satisfaction_configuration_hash = survey_satisfaction_hash_for_program(@survey_satisfaction_program)
  end

  private

  def overall_impact_date_range(filter_params)
    from, to = ReportsFilterService.get_report_date_range(filter_params, ReportsFilterService.program_created_date(@current_organization))
    {
      from: from.beginning_of_day,
      to: to.end_of_day
    }
  end

  def previous_time_period(current_period)
    previous_period = ReportsFilterService.get_previous_time_period(current_period[:from].to_date, current_period[:to].to_date, @current_organization)
    return nil if previous_period.first.nil?
    {
      from: previous_period.first.beginning_of_day,
      to: previous_period.second.end_of_day
    }
  end

  def update_rollup_for_overall_impact!(result_hash, flags_hash, date_range)
    date_range_hash = get_date_range_hash(date_range)
    users_participated_for_overall_impact!(date_range_hash, result_hash) if flags_hash[:users_participated]
    connections_created_for_overall_impact!(date_range_hash, result_hash) if flags_hash[:connections_created]
    engagement_created_for_overall_impact!(date_range_hash, result_hash)  if flags_hash[:engagements_created]
    satisfaction_rate_for_overall_impact!(date_range_hash, result_hash) if flags_hash[:satisfaction_rate]
  end

  def users_participated_for_overall_impact!(date_range_hash, result_hash)
    set_date_range_hash!(result_hash, date_range_hash)
    result_hash[:users_participated] = date_range_hash.collect { |key, value| [key, @current_organization.users_with_published_profiles_in_date_range_for_organization(value).size]}.to_h
  end

  def connections_created_for_overall_impact!(date_range_hash, result_hash)
    set_date_range_hash!(result_hash, date_range_hash)
    meetings_scope = Meeting.non_group_meetings.in_programs(current_organization_program_ids).accepted_meetings
    result_hash[:connections_created] = date_range_hash.collect { |key, value| [key, meetings_scope.between_time(value).count + @current_organization.connections_in_date_range_for_organization(value).size]}.to_h
  end

  def engagement_created_for_overall_impact!(date_range_hash, result_hash)
    set_date_range_hash!(result_hash, date_range_hash)
    result_hash[:engagements_created] = {
      messages: date_range_hash.collect { |key, value| [key, messages_for_overall_impact(value)]}.to_h,
      meetings: date_range_hash.collect { |key, value| [key, meetings_for_overall_impact(value)]}.to_h,
      posts: date_range_hash.collect { |key, value| [key, posts_for_overall_impact(value)]}.to_h
    }
  end

  def satisfaction_rate_for_overall_impact!(date_range_hash, result_hash)
    set_date_range_hash!(result_hash, date_range_hash)
    result_hash[:positive_outcomes_not_configured] = positive_outcome_surveys_by_program.all? {|_key, value| value[:surveys].empty? }
    calculate_satisfaction_rate_for_overall_impact!(date_range_hash, result_hash) unless result_hash[:positive_outcomes_not_configured]
  end

  def calculate_satisfaction_rate_for_overall_impact!(date_range_hash, result_hash)
    programs = @current_organization.programs.includes(:enabled_db_features, :disabled_db_features, organization: :enabled_db_features).where(include_surveys_for_satisfaction_rate: [nil, true]).select(&:program_outcomes_report_enabled?)
    one_time_program_ids = programs.select(&:only_one_time_mentoring_enabled?).pluck(:id)
    satisfaction_rate_hash_for_groups = satisfaction_rate_for_groups(date_range_hash, programs.pluck(:id) - one_time_program_ids)
    satisfaction_rate_hash_for_meetings = satisfaction_rate_for_meetings(date_range_hash, one_time_program_ids)
    result_hash[:satisfaction_rate] = date_range_hash.collect { |key, _value| [key, calculate_satisfaction_rate(group: satisfaction_rate_hash_for_groups[key], meeting: satisfaction_rate_hash_for_meetings[key])]}.to_h
  end

  def satisfaction_rate_for_groups(date_range_hash, program_ids)
    date_range_hash.collect { |key, value| [key, ConnectionDetailedReport.new(nil, nil, {skip_init: true}).get_satisfaction_stats_for_groups_between(value.first, value.last, program_ids: program_ids)]}.to_h
  end

  def satisfaction_rate_for_meetings(date_range_hash, program_ids)
    date_range_hash.collect { |key, value| [key, MeetingOutcomesReport.new(nil, skip_init: true).get_satisfaction_stats_for_meetings_between(value.first, value.last, program_ids: program_ids)]}.to_h
  end

  def calculate_satisfaction_rate(satisfaction_rate_hash)
    positive = satisfaction_rate_hash[:group][:positive] + satisfaction_rate_hash[:meeting][:positive]
    total = satisfaction_rate_hash[:group][:total] + satisfaction_rate_hash[:meeting][:total]
    safe_percentage(positive, total)
  end

  def messages_for_overall_impact(date_range)
    arel_chains = [Scrap.where(program_id: current_organization_program_ids), Message.where(program_id: @current_organization.id)]
    created_at_between_count(arel_chains, date_range)
  end

  def posts_for_overall_impact(date_range)
    forum_ids = Forum.where(program_id: current_organization_program_ids).where.not(group_id: nil).pluck(:id)
    topics = Topic.where(forum_id: forum_ids)
    arel_chains = [topics, Post.where(topic_id: topics.ids).published]
    created_at_between_count(arel_chains, date_range)
  end

  def meetings_for_overall_impact(date_range)
    meetings = Meeting.in_programs(current_organization_program_ids).accepted_meetings
    Meeting.recurrent_meetings(meetings, get_merged_list: true, get_occurrences_between_time: true, start_time: date_range.first, end_time: date_range.last)
  end

  def mentoring_time_for_overall_impact(meetings)
    (Meeting.hours(meetings) * 60).to_i
  end

  def survey_satisfaction_hash_for_program(program)
    program_outcomes_feature_enabled = program.program_outcomes_report_enabled?
    surveys = (!program_outcomes_feature_enabled || program.ignored_survey_satisfaction_configuration?) ? [] : program.get_positive_outcome_surveys
    {program_name: program.name, surveys: surveys, config: program.include_surveys_for_satisfaction_rate, program_outcomes_feature_enabled: program_outcomes_feature_enabled}
  end

  def format_flags_hash(flags_hash)
    flags_hash.each do |key, value|
      flags_hash[key] = value.to_s.to_boolean
    end
    flags_hash
  end

  def safe_percentage(numerator, denominator)
    result = numerator.fdiv(denominator)
    return 0 if result.nan?
    return 100 if (result.infinite? == 1)
    (result * 100).round
  end

  def get_date_range_hash(date_range)
    date_range_hash = {current: date_range}
    previous_time_period = previous_time_period(@overall_impact_date_range)
    date_range_hash[:previous] = previous_time_period.values unless previous_time_period.nil?
    date_range_hash
  end

  def positive_outcome_surveys_by_program
    @current_organization.programs.includes(:translations, :enabled_db_features, :disabled_db_features, organization: :enabled_db_features).collect { |program| [program.id, survey_satisfaction_hash_for_program(program)] }.to_h
  end

  def created_at_between_count(arel_chains, date_range)
    arel_chains.inject(0) {|sum, arel_chain| sum + arel_chain.where('created_at BETWEEN ? AND ?', date_range.first, date_range.second).count}
  end

  def set_date_range_hash!(result_hash, date_range_hash)
    result_hash[:date_range_hash] = date_range_hash
  end

  def current_organization_program_ids
    @__current_organization_program_ids ||= @current_organization.program_ids
  end
end