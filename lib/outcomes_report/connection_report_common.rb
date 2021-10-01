class ConnectionReportCommon < OutcomesReportCommon
  attr_accessor :forStatus
  attr_reader :userIds

  include OutcomesReportUtils

  def get_satisfaction_stats_for_groups_between(start_date, end_date, options = {})
    surveys = Survey.where(program_id: options[:program_ids])
    positive_user_ids = get_total_positive_outcome_data_between(surveys, scoped_survey_response_time: true, start_date: start_date, end_date: end_date)
    survey_ids_with_positive_outcome = surveys.of_engagement_type.joins(:survey_questions_with_matrix_rating_questions).where("common_questions.positive_outcome_options IS NOT NULL").pluck(:id)
    {
      positive: positive_user_ids.size,
      total: SurveyAnswer.where(survey_id: survey_ids_with_positive_outcome).where("common_answers.last_answered_at >= ? AND common_answers.last_answered_at <= ?", start_date, end_date).count("distinct user_id")
    }
  end

  private

  def get_total_active_groups_data_between(end_date)
    query = @program.groups
    query = query.where("groups.id IN (?)", @groupIds) unless @groupIds.nil?
    query = query.where("groups.published_at <= ? AND (groups.closed_at IS NULL OR groups.closed_at > ?)", end_date.utc.end_of_day, end_date.utc.end_of_day).joins(:memberships).select("groups.id as group_id, groups.closed_at as group_closed_at, connection_memberships.role_id as connection_membership_role_id, connection_memberships.user_id as connection_membership_user_id")
    query = query.where("connection_memberships.user_id IN (?)", @userIds) unless @userIds.nil?
    return ActiveRecord::Base.connection.exec_query(query.to_sql).to_hash
  end

  def get_total_completed_groups_data_between(start_date, end_date, completed_reason_ids)
    query = @program.groups
    query = query.where("groups.id IN (?)", @groupIds) unless @groupIds.nil?
    query = query.where("groups.closure_reason_id IN (?)", completed_reason_ids).with_published_at.closed_between(start_date.utc.beginning_of_day, end_date.utc.end_of_day).joins(:memberships).select("groups.id as group_id, groups.closed_at as group_closed_at, connection_memberships.role_id as connection_membership_role_id, connection_memberships.user_id as connection_membership_user_id")
    query = query.where("connection_memberships.user_id IN (?)", @userIds) unless @userIds.nil?
    return ActiveRecord::Base.connection.exec_query(query.to_sql).to_hash
  end

  def get_total_dropped_groups_data_between(start_date, end_date, completed_reason_ids)
    query = @program.groups
    query = query.where("groups.id IN (?)", @groupIds) unless @groupIds.nil?
    query = query.where("groups.closure_reason_id NOT IN (?)", completed_reason_ids).with_published_at.closed_between(start_date.utc.beginning_of_day, end_date.utc.end_of_day).joins(:memberships).select("groups.id as group_id, groups.closed_at as group_closed_at, connection_memberships.role_id as connection_membership_role_id, connection_memberships.user_id as connection_membership_user_id")
    query = query.where("connection_memberships.user_id IN (?)", @userIds) unless @userIds.nil?
    return ActiveRecord::Base.connection.exec_query(query.to_sql).to_hash
  end

  def get_total_closed_groups_data_between(start_date, end_date)
    query = @program.groups
    query = query.where("groups.id IN (?)", @groupIds) unless @groupIds.nil?
    query = query.with_published_at.closed_between(start_date.utc.beginning_of_day, end_date.utc.end_of_day).joins(:memberships).select("groups.id as group_id, date(groups.closed_at) as group_closed_at, connection_memberships.role_id as connection_membership_role_id, connection_memberships.user_id as connection_membership_user_id") 
    query = query.where("connection_memberships.user_id IN (?)", @userIds) unless @userIds.nil?
    return ActiveRecord::Base.connection.exec_query(query.to_sql).to_hash
  end

  # In the given users the percentage of users that attempted atleast one 
  # survey which has a question with positive outcomes configured
  def get_positive_outcomes_survey_response_rate_and_error_rate(completed_user_ids)
    positive_outcome_survey_ids = SurveyQuestion.where(survey_id: @program.surveys.of_engagement_type.pluck(:id)).positive_outcome_configured.pluck(:survey_id).uniq
    survey_responded_completed_group_user_ids = SurveyAnswer.where(survey_id: positive_outcome_survey_ids).where(user_id: completed_user_ids).pluck(:user_id).uniq
    response_rate = Survey.calculate_response_rate(survey_responded_completed_group_user_ids.size, completed_user_ids.size) || 0
    error_rate = Survey.percentage_error(survey_responded_completed_group_user_ids.size, completed_user_ids.size) || 0
    return [response_rate, error_rate]
  end

  def get_total_positive_outcome_groups_data_between(start_date, end_date)
    query = @program.groups
    query = query.where("groups.id IN (?)", @groupIds) unless @groupIds.nil?
    group_ids = query.closed.with_published_at.closed_between(start_date.utc.beginning_of_day, end_date.utc.end_of_day).pluck(:id)
    group_ids = group_ids & @program.surveys.of_engagement_type.joins(survey_questions_with_matrix_rating_questions: [survey_answers: :answer_choices]).where("common_answers.group_id is not NULL and FIND_IN_SET(answer_choices.question_choice_id, common_questions.positive_outcome_options) > 0").pluck("DISTINCT group_id")
    user_ids = get_total_positive_outcome_data_between(@program.surveys, scoped_group_ids: group_ids)
    user_ids = user_ids & @userIds unless @userIds.nil?
    positive_outcome_groups_query = Group.where(id: group_ids).joins(:memberships).select("groups.id as group_id, groups.closed_at as group_closed_at, connection_memberships.role_id as connection_membership_role_id, connection_memberships.user_id as connection_membership_user_id")
    positive_outcome_groups_query = positive_outcome_groups_query.where("connection_memberships.user_id IN (?)", user_ids)
    return positive_outcome_groups_query
  end

  def get_total_positive_outcome_data_between(surveys, options = {})
    query_chain = surveys.of_engagement_type.joins(survey_questions_with_matrix_rating_questions: [survey_answers: :answer_choices]).where("FIND_IN_SET(answer_choices.question_choice_id, common_questions.positive_outcome_options) > 0")
    query_chain = query_chain.where("common_answers.group_id IN (?)", options[:scoped_group_ids]) if options[:scoped_group_ids]
    query_chain = query_chain.where("common_answers.last_answered_at >= ? AND common_answers.last_answered_at < ?", options[:start_date], options[:end_date]) if options[:scoped_survey_response_time]
    query_chain.pluck("DISTINCT user_id")
  end

  def read_from_cache(cache_key)
    @userIds = cache_key.present? ? Rails.cache.read(cache_key+"_users") : nil
    @groupIds = cache_key.present? ? Rails.cache.read(cache_key+"_groups") : nil
  end

  def compute_user_summary(options = {})
    role = options[:role]
    title = role.present? ? role.customized_term.pluralized_term : "feature.outcomes_report.title.users".translate
    total_users = User.get_ids_of_connected_users_active_between(@program, self.startDate, self.endDate, ids: @userIds, role: role).size
    if self.getOldData
      old_total_users = User.get_ids_of_connected_users_active_between(@program, self.oldStartTime, self.oldEndTime, ids: @userIds, role: role).size
      change = get_diff_in_percentage(old_total_users, total_users)
    end
    hsh = role.present? ? { id: ConnectionOutcomesReport::MatchingSectionElementId.for_role(role) } : {}
    return hsh.merge!(name: title, count: total_users, change: change)
  end

  def computed_graph_data_for_ongoing_connections
    total_connection_data = GroupStateChange.get_group_state_changes_per_day(@program, @groupIds, self.endDate)
    {name: "#{@program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term}", data: get_aggregated_data(total_connection_data)[self.startDayIndex..-1], color: GraphColor::CONNECTIONS, visibility: self.enabledStatusMapping[:total_connections_or_meetings]}
  end

  def computed_graph_data_for_users_of_ongoing_connections
    {name: "feature.outcomes_report.title.users".translate, data: get_aggregated_data(UserStateChange.get_active_connected_users_per_day(program, @userIds, self.endDate))[self.startDayIndex..-1], color: GraphColor::USERS, visibility: self.enabledStatusMapping[:users]}
  end

  def computed_graph_data_for_users_of_ongoing_connections_per_role(role)
    {name: "#{role.customized_term.pluralized_term}", data: get_aggregated_data(UserStateChange.get_active_connected_users_per_day_per_role(program, @userIds, self.endDate, role))[self.startDayIndex..-1], color: roleGraphColorMapping[role.id], visibility: self.enabledStatusMapping[role.id]}
  end

  def computed_graph_data_for_completed_connections(total_data)
    {name: "#{@program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term}", data: total_data, color: GraphColor::CONNECTIONS, visibility: self.enabledStatusMapping[:total_connections_or_meetings]}
  end

  def computed_graph_data_for_users_of_completed_connections(total_user_data)
    {name: "feature.outcomes_report.title.users".translate, data: total_user_data, color: GraphColor::USERS, visibility: self.enabledStatusMapping[:users]}
  end

  def computed_graph_data_for_users_of_completed_connections_per_role(role, role_user_data)
    {name: "#{role.customized_term.pluralized_term}", data: role_user_data, color: self.roleGraphColorMapping[role.id], visibility: self.enabledStatusMapping[role.id]}
  end

  def compute_user_summary_for_completed_connection(total_completed_groups, old_total_completed_groups)
    total_memberships_count = total_completed_groups.collect{|g| g["connection_membership_user_id"]}.uniq.count
    old_total_memberships_count = (self.getOldData ? old_total_completed_groups.collect{|g| g["connection_membership_user_id"]}.uniq.count : 0)
    total_change = get_diff_in_percentage(old_total_memberships_count, total_memberships_count)
    userSummary = {name: "feature.outcomes_report.title.users".translate, count: total_memberships_count, change: total_change}
  end

  def all_months_graph_data_for_completed_groups(total_completed_groups)
    graph_data = {}
    total_completed_groups.each do |total_completed_group|
      keyy = total_completed_group["group_closed_at"].utc.at_beginning_of_month.to_i*1000
      graph_data[keyy].present? ? (graph_data[keyy] << total_completed_group) : (graph_data.merge!({keyy => [total_completed_group]}))
    end
    graph_data
  end

  def get_graph_data_for_completed_groups(all_months_graph_data, method, role=nil)
    data = []
    end_month_index = (self.endDate.utc.at_beginning_of_month.to_i)*1000
    month_index = (self.startDate.utc.at_beginning_of_month.to_i)*1000
    next_month = self.startDate.at_beginning_of_month
    params = [all_months_graph_data]
    params << role if role.present?

    while (month_index <= end_month_index)
      data << method.call(*(params+[month_index]))
      next_month += 1.month
      month_index = (next_month.at_beginning_of_month.to_i)*1000
    end
    return data
  end

  def groups_data_for_completed_groups_graph_data(all_months_graph_data)
    get_graph_data_for_completed_groups(all_months_graph_data, method(:groups_data_for_completed_groups_graph_data_method))
  end

  def groups_data_for_completed_groups_graph_data_method(all_months_graph_data, month_index)
    months_data = all_months_graph_data[month_index]
    months_data.nil? ? [month_index, 0] : [month_index, months_data.collect{|g| g["group_id"]}.uniq.count]
  end

  def users_data_for_completed_groups_graph_data(all_months_graph_data)
    get_graph_data_for_completed_groups(all_months_graph_data, method(:users_data_for_completed_groups_graph_data_method))
  end

  def users_data_for_completed_groups_graph_data_method(all_months_graph_data, month_index)
    months_data = all_months_graph_data[month_index]
    months_data.nil? ? [month_index, 0] : [month_index, months_data.collect{|g| g["connection_membership_user_id"]}.uniq.count]
  end

  def role_users_data_for_completed_groups_graph_data(all_months_graph_data, role)
    get_graph_data_for_completed_groups(all_months_graph_data, method(:role_users_data_for_completed_groups_graph_data_method), role)
  end

  def role_users_data_for_completed_groups_graph_data_method(all_months_graph_data, role, month_index)
    months_data = all_months_graph_data[month_index]
    role_data = months_data.select{|g| g["connection_membership_role_id"] == role.id} if months_data.present?
    role_data.present? ? [month_index, role_data.collect{|g| g["connection_membership_user_id"]}.uniq.count] : [month_index, 0]
  end

  def get_total_active_groups_count(start_date, end_date)
    Group.get_ids_of_groups_active_between(@program, start_date, end_date, ids: @groupIds).size
  end

  def get_old_active_groups_count
    get_total_active_groups_count(self.oldStartTime, self.oldEndTime)
  end

  def get_overall_active_groups_change
    old_count = self.getOldData ? get_old_active_groups_count : nil
    return get_diff_in_percentage(old_count, self.totalCount)
  end

  def compute_total_complete_groups(start_time, end_time, completed_reason_ids)
    total_completed_groups = get_total_completed_groups_data_between(start_time, end_time, completed_reason_ids)
    total_count = total_completed_groups.collect{|g| g["group_id"]}.uniq.count
    return total_completed_groups, total_count
  end
end