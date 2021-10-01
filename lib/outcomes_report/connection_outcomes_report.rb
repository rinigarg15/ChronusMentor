class ConnectionOutcomesReport < ConnectionReportCommon

  module MatchingSectionElementId
    PREFIX = "matching_"

    def self.for_role(role)
      "#{PREFIX}#{role.name}"
    end
  end

  module OngoingSectionElementId
    PREFIX = "ongoing_"

    def self.for_role(role)
      "#{PREFIX}#{role.name}"
    end
  end

  module PositiveOutcomesSectionElementId
    PREFIX = "positive_outcomes_"

    def self.for_role(role)
      "#{PREFIX}#{role.name}"
    end
  end

  include OutcomesReportUtils
  POSITIVE_OUTCOMES = "positive_outcomes"

  def initialize(program, date_range, options={})
    status = options[:status] || ""
    type = options[:type] || ""
    data_side = options[:data_side] || OutcomesReportUtils::DataType::ALL_DATA
    common_initialization(program, date_range, options[:enabled_status])
    read_from_cache(options[:cache_key])
    self.forStatus = status.present? ? status : Group::Status::ACTIVE

    if type == ConnectionOutcomesReport::POSITIVE_OUTCOMES
      initialize_for_positive_connection
    elsif status.blank? || status == Group::Status::ACTIVE
      initialize_for_active_connection(status, data_side)
    else
      initialize_for_completed_connection(status)
    end
  end

  def remove_unnecessary_instance_variables
    remove_instance_variable(:@program)
    remove_instance_variable(:@userIds)
    remove_instance_variable(:@groupIds)
  end

  private

  def initialize_for_active_connection(status, data_side)
    if data_side == OutcomesReportUtils::DataType::NON_GRAPH_DATA || data_side == OutcomesReportUtils::DataType::ALL_DATA
      self.totalCount = get_total_active_groups_count(self.startDate, self.endDate)
      self.overallChange = get_overall_active_groups_change
      self.userSummary = compute_user_summary
      self.rolewiseSummary = compute_rolewise_summary
    end
    if data_side == OutcomesReportUtils::DataType::GRAPH_DATA || data_side == OutcomesReportUtils::DataType::ALL_DATA
      self.graphData = computed_graph_data
    end
  end

  def initialize_for_completed_connection(status)
    completed_reason_ids = @program.group_closure_reasons.completed.pluck(:id)
    total_completed_groups, self.totalCount = compute_total_complete_groups(self.startDate, self.endDate, completed_reason_ids)
    old_total_completed_groups, old_total_count = compute_total_complete_groups(self.oldStartTime, self.oldEndTime, completed_reason_ids) if self.getOldData 
    self.userSummary = compute_user_summary_for_completed_connection(total_completed_groups, old_total_completed_groups)
    self.rolewiseSummary = compute_rolewise_summary_for_completed_connection(total_completed_groups, old_total_completed_groups)
    self.overallChange = compute_overall_change(old_total_count)
    self.graphData = compute_graph_data_for_completed_connection(total_completed_groups)
  end

  def initialize_for_positive_connection
    total_closed_groups_with_positive_outcome = get_total_positive_outcome_groups_data_between(self.startDate, self.endDate)
    
    if self.getOldData
      old_total_closed_groups_with_positive_outcome = get_total_positive_outcome_groups_data_between(self.oldStartTime, self.oldEndTime)
      old_total_closed_groups_with_positive_outcome_count = old_total_closed_groups_with_positive_outcome.collect{|g| g["group_id"]}.uniq.count

      old_total_closed_groups = get_total_closed_groups_data_between(self.oldStartTime, self.oldEndTime)
      old_total_closed_groups_count = old_total_closed_groups.collect{|g| g["group_id"]}.uniq.count
    end

    completed_reason_ids = @program.group_closure_reasons.completed.pluck(:id)
    completed_user_ids = get_total_completed_groups_data_between(self.startDate, self.endDate, completed_reason_ids).collect{|g| g["connection_membership_user_id"]}.uniq

    self.totalCount = total_closed_groups_with_positive_outcome.collect{|g| g["group_id"]}.uniq.count
    self.overallChange = compute_overall_change(old_total_closed_groups_with_positive_outcome_count)

    self.userSummary = compute_user_summary_for_completed_connection(total_closed_groups_with_positive_outcome, old_total_closed_groups_with_positive_outcome)
    self.rolewiseSummary = compute_rolewise_summary_for_completed_connection(total_closed_groups_with_positive_outcome, old_total_closed_groups_with_positive_outcome, true)
    self.responseRate, self.marginError = get_positive_outcomes_survey_response_rate_and_error_rate(completed_user_ids)
    self.graphData = compute_graph_data_for_completed_connection(total_closed_groups_with_positive_outcome)
  end

  def compute_rolewise_summary_for_completed_connection(total_completed_groups, old_total_completed_groups, for_positive_outcomes=false)
    rolewiseSummary = []
    @mentoring_roles.each do |role|
      total_role_memberships = total_completed_groups.select{|g| g["connection_membership_role_id"] == role.id}
      old_total_role_memberships = (self.getOldData ? old_total_completed_groups.select{|g| g["connection_membership_role_id"] == role.id} : nil)
      count = total_role_memberships.present? ? total_role_memberships.collect{|g| g["connection_membership_user_id"]}.uniq.count : 0
      old_count = old_total_role_memberships.present? ? old_total_role_memberships.collect{|g| g["connection_membership_user_id"]}.uniq.count : 0
      change = get_diff_in_percentage(old_count, count)
      id = for_positive_outcomes ? ConnectionOutcomesReport::PositiveOutcomesSectionElementId.for_role(role) : ConnectionOutcomesReport::OngoingSectionElementId.for_role(role)
      rolewiseSummary << {id: id, name: role.customized_term.pluralized_term, count: count, change: change}
    end
    return rolewiseSummary
  end

  def compute_overall_change(old_total_count)    
    return get_diff_in_percentage(old_total_count, self.totalCount) if self.getOldData
  end

  def compute_graph_data_for_completed_connection(total_completed_groups)
    all_months_graph_data = all_months_graph_data_for_completed_groups(total_completed_groups)
    total_data = groups_data_for_completed_groups_graph_data(all_months_graph_data)
    total_user_data = users_data_for_completed_groups_graph_data(all_months_graph_data)
    role_graph_data_mapping = {}
    @mentoring_roles.each do |role|
      role_graph_data_mapping.merge!({ role.id => role_users_data_for_completed_groups_graph_data(all_months_graph_data, role)})
    end

    graph_data = []
    graph_data << computed_graph_data_for_users_of_completed_connections(total_user_data)
    @mentoring_roles.each do |role|
      graph_data << computed_graph_data_for_users_of_completed_connections_per_role(role, role_graph_data_mapping[role.id])
    end
    graph_data << computed_graph_data_for_completed_connections(total_data)
    return graph_data
  end

  def computed_graph_data
    graph_data = []
    graph_data << computed_graph_data_for_users_of_ongoing_connections
    @mentoring_roles.each do |role|
      graph_data <<  computed_graph_data_for_users_of_ongoing_connections_per_role(role)
    end
    graph_data << computed_graph_data_for_ongoing_connections
    graph_data
  end

  def compute_rolewise_summary
    rolewiseSummary = []
    @mentoring_roles.each do |role|
      rolewiseSummary << compute_user_summary(role: role)
    end
    rolewiseSummary
  end
end
