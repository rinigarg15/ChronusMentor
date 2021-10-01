class ConnectionDetailedReport < ConnectionReportCommon
  attr_accessor :positiveOutcomesGraphData, :completedConnectionGraphData, :ongoingConnectionsGraphData, :sectioneOneData, :prevRangeStartDateText, :prevRangeEndDateText
  include OutcomesReportUtils

  module Tab
    GROUPS = 'groups'
    USERS = 'users'
  end

  module Section
    ONE = 'one'
    TWO = 'two'
  end

  def initialize(program, date_range, options={})
    return if options[:skip_init]
    @options = options
    common_initialization(program, date_range, options[:enabled_status])
    self.prevRangeStartDateText = DateTime.localize(self.oldStartTime, format: :full_display_no_time)
    self.prevRangeEndDateText = DateTime.localize(self.oldEndTime, format: :full_display_no_time)
    read_from_cache(@options[:cache_key])
    @role = program.roles.find(@options[:role]) if @options[:role].present?
    @options[:section] == Section::ONE ? initilize_non_graph_data : initilize_graph_data
    remove_unnecessary_instance_variables
  end

  private

  def initilize_non_graph_data
    self.sectioneOneData = {
      overall: { connections: {}, users:{} },
      ongoing: { connections: {}, users:{} },
      completed: { connections: {}, users:{} },
      dropped: { connections: {}, users:{} },
      positive_outcomes: { connections: {}, users:{} }
    }
    initialize_groups_non_graph_data
    @role.present? ? initialize_role_users_non_graph_data : initialize_users_non_graph_data
  end

  def initilize_graph_data
    if @options[:tab] == Tab::GROUPS
      initialize_groups_graph_data
    elsif @options[:tab] == Tab::USERS
      @role.present? ? initialize_role_users_graph_data : initialize_users_graph_data
    end
  end

  def initialize_groups_graph_data
    set_ongoing_connections_groups_graph_data
    set_completed_connections_groups_graph_data
    set_positive_outcomes_groups_graph_data
  end

  def initialize_users_graph_data
    set_ongoing_connections_users_graph_data
    set_completed_connections_users_graph_data
    set_positive_outcomes_users_graph_data
  end

  def initialize_role_users_graph_data
    set_ongoing_connections_role_users_graph_data
    set_completed_connections_role_users_graph_data
    set_positive_outcomes_users_role_graph_data
  end

  def initialize_groups_non_graph_data
    completed_reason_ids = @program.group_closure_reasons.completed.pluck(:id)
    self.sectioneOneData[:overall][:connections][:count] = get_total_active_groups_count(self.startDate, self.endDate)
    self.sectioneOneData[:completed][:connections][:count] = get_total_completed_groups_data_between(self.startDate, self.endDate, completed_reason_ids).collect{|g| g["group_id"]}.uniq.count
    self.sectioneOneData[:dropped][:connections][:count] = get_total_dropped_groups_data_between(self.startDate, self.endDate, completed_reason_ids).collect{|g| g["group_id"]}.uniq.count
    self.sectioneOneData[:positive_outcomes][:connections][:count] = get_total_positive_outcome_groups_data_between(self.startDate, self.endDate).collect{|g| g["group_id"]}.uniq.count
    self.sectioneOneData[:ongoing][:connections][:count] = self.sectioneOneData[:overall][:connections][:count] - (self.sectioneOneData[:completed][:connections][:count] + self.sectioneOneData[:dropped][:connections][:count])
    if self.getOldData
      overall_old_count = get_total_active_groups_count(self.oldStartTime, self.oldEndTime)
      self.sectioneOneData[:overall][:connections][:change] = get_diff_in_percentage(overall_old_count, self.sectioneOneData[:overall][:connections][:count])

      completed_old_count = get_total_completed_groups_data_between(self.oldStartTime, self.oldEndTime, completed_reason_ids).collect{|g| g["group_id"]}.uniq.count
      self.sectioneOneData[:completed][:connections][:change] = get_diff_in_percentage(completed_old_count, self.sectioneOneData[:completed][:connections][:count])

      dropped_old_count = get_total_dropped_groups_data_between(self.oldStartTime, self.oldEndTime, completed_reason_ids).collect{|g| g["group_id"]}.uniq.count
      self.sectioneOneData[:dropped][:connections][:change] = get_diff_in_percentage(dropped_old_count, self.sectioneOneData[:dropped][:connections][:count])

      positive_outcomes_old_count = get_total_positive_outcome_groups_data_between(self.oldStartTime, self.oldEndTime).collect{|g| g["group_id"]}.uniq.count
      self.sectioneOneData[:positive_outcomes][:connections][:change] = get_diff_in_percentage(positive_outcomes_old_count, self.sectioneOneData[:positive_outcomes][:connections][:count])

      onging_old_count = overall_old_count - (completed_old_count + dropped_old_count)
      self.sectioneOneData[:ongoing][:connections][:change] = get_diff_in_percentage(onging_old_count, self.sectioneOneData[:ongoing][:connections][:count])
    end
  end

  def initialize_users_non_graph_data
    completed_reason_ids = @program.group_closure_reasons.completed.pluck(:id)
    self.sectioneOneData[:overall][:users][:count] = User.get_ids_of_connected_users_active_between(@program, self.startDate, self.endDate, ids: @userIds).size
    self.sectioneOneData[:ongoing][:users][:count] = get_total_active_groups_data_between(self.endDate).collect{|g| g["connection_membership_user_id"]}.uniq.count
    self.sectioneOneData[:completed][:users][:count] = get_total_completed_groups_data_between(self.startDate, self.endDate, completed_reason_ids).collect{|g| g["connection_membership_user_id"]}.uniq.count
    self.sectioneOneData[:dropped][:users][:count] = get_total_dropped_groups_data_between(self.startDate, self.endDate, completed_reason_ids).collect{|g| g["connection_membership_user_id"]}.uniq.count
    self.sectioneOneData[:positive_outcomes][:users][:count] = get_total_positive_outcome_groups_data_between(self.startDate, self.endDate).collect{|g| g["connection_membership_user_id"]}.uniq.count
    if self.getOldData
      overall_old_count = User.get_ids_of_connected_users_active_between(@program, self.oldStartTime, self.oldEndTime, ids: @userIds).size
      self.sectioneOneData[:overall][:users][:change] = get_diff_in_percentage(overall_old_count, self.sectioneOneData[:overall][:users][:count])

      onging_old_count = get_total_active_groups_data_between(self.oldEndTime).collect{|g| g["connection_membership_user_id"]}.uniq.count
      self.sectioneOneData[:ongoing][:users][:change] = get_diff_in_percentage(onging_old_count, self.sectioneOneData[:ongoing][:users][:count])

      completed_old_count = get_total_completed_groups_data_between(self.oldStartTime, self.oldEndTime, completed_reason_ids).collect{|g| g["connection_membership_user_id"]}.uniq.count
      self.sectioneOneData[:completed][:users][:change] = get_diff_in_percentage(completed_old_count, self.sectioneOneData[:completed][:users][:count])

      dropped_old_count = get_total_dropped_groups_data_between(self.oldStartTime, self.oldEndTime, completed_reason_ids).collect{|g| g["connection_membership_user_id"]}.uniq.count
      self.sectioneOneData[:dropped][:users][:change] = get_diff_in_percentage(dropped_old_count, self.sectioneOneData[:dropped][:users][:count])

      positive_outcomes_old_count = get_total_positive_outcome_groups_data_between(self.oldStartTime, self.oldEndTime).collect{|g| g["connection_membership_user_id"]}.uniq.count
      self.sectioneOneData[:positive_outcomes][:users][:change] = get_diff_in_percentage(positive_outcomes_old_count, self.sectioneOneData[:positive_outcomes][:users][:count])
    end
  end

  def initialize_role_users_non_graph_data
    completed_reason_ids = @program.group_closure_reasons.completed.pluck(:id)
    self.sectioneOneData[:overall][:users][:count] = User.get_ids_of_connected_users_active_between(@program, self.startDate, self.endDate, ids: @userIds, role: @role).size
    self.sectioneOneData[:ongoing][:users][:count] = get_total_active_groups_data_between(self.endDate).select{|g| g["connection_membership_role_id"] == @role.id}.collect{|g| g["connection_membership_user_id"]}.uniq.count
    self.sectioneOneData[:completed][:users][:count] = get_total_completed_groups_data_between(self.startDate, self.endDate, completed_reason_ids).select{|g| g["connection_membership_role_id"] == @role.id}.collect{|g| g["connection_membership_user_id"]}.uniq.count
    self.sectioneOneData[:dropped][:users][:count] = get_total_dropped_groups_data_between(self.startDate, self.endDate, completed_reason_ids).select{|g| g["connection_membership_role_id"] == @role.id}.collect{|g| g["connection_membership_user_id"]}.uniq.count
    self.sectioneOneData[:positive_outcomes][:users][:count] = get_total_positive_outcome_groups_data_between(self.startDate, self.endDate).select{|g| g["connection_membership_role_id"] == @role.id}.collect{|g| g["connection_membership_user_id"]}.uniq.count
    if self.getOldData
      overall_old_count = User.get_ids_of_connected_users_active_between(@program, self.oldStartTime, self.oldEndTime, ids: @userIds, role: @role).size
      self.sectioneOneData[:overall][:users][:change] = get_diff_in_percentage(overall_old_count, self.sectioneOneData[:overall][:users][:count])

      onging_old_count = get_total_active_groups_data_between(self.oldEndTime).select{|g| g["connection_membership_role_id"] == @role.id}.collect{|g| g["connection_membership_user_id"]}.uniq.count
      self.sectioneOneData[:ongoing][:users][:change] = get_diff_in_percentage(onging_old_count, self.sectioneOneData[:ongoing][:users][:count])

      completed_old_count = get_total_completed_groups_data_between(self.oldStartTime, self.oldEndTime, completed_reason_ids).select{|g| g["connection_membership_role_id"] == @role.id}.collect{|g| g["connection_membership_user_id"]}.uniq.count
      self.sectioneOneData[:completed][:users][:change] = get_diff_in_percentage(completed_old_count, self.sectioneOneData[:completed][:users][:count])

      dropped_old_count = get_total_dropped_groups_data_between(self.oldStartTime, self.oldEndTime, completed_reason_ids).select{|g| g["connection_membership_role_id"] == @role.id}.collect{|g| g["connection_membership_user_id"]}.uniq.count
      self.sectioneOneData[:dropped][:users][:change] = get_diff_in_percentage(dropped_old_count, self.sectioneOneData[:dropped][:users][:count])

      positive_outcomes_old_count = get_total_positive_outcome_groups_data_between(self.oldStartTime, self.oldEndTime).select{|g| g["connection_membership_role_id"] == @role.id}.collect{|g| g["connection_membership_user_id"]}.uniq.count
      self.sectioneOneData[:positive_outcomes][:users][:change] = get_diff_in_percentage(positive_outcomes_old_count, self.sectioneOneData[:positive_outcomes][:users][:count])
    end
  end

  def set_ongoing_connections_groups_graph_data
    self.ongoingConnectionsGraphData = [computed_graph_data_for_ongoing_connections]
  end

  def set_completed_connections_groups_graph_data
    completed_reason_ids = @program.group_closure_reasons.completed.pluck(:id)
    total_completed_groups = get_total_completed_groups_data_between(self.startDate, self.endDate, completed_reason_ids)
    self.completedConnectionGraphData = [get_group_data_for_graph_from_raw_data(total_completed_groups)]
  end

  def set_positive_outcomes_groups_graph_data
    total_closed_groups_with_positive_outcome = get_total_positive_outcome_groups_data_between(self.startDate, self.endDate)
    self.positiveOutcomesGraphData = [get_group_data_for_graph_from_raw_data(total_closed_groups_with_positive_outcome)]
  end

  def set_ongoing_connections_users_graph_data
    self.ongoingConnectionsGraphData = [computed_graph_data_for_users_of_ongoing_connections]
  end

  def set_completed_connections_users_graph_data
    completed_reason_ids = @program.group_closure_reasons.completed.pluck(:id)
    total_completed_groups = get_total_completed_groups_data_between(self.startDate, self.endDate, completed_reason_ids)
    self.completedConnectionGraphData = [get_users_data_for_graph_from_raw_data(total_completed_groups)]
  end

  def set_positive_outcomes_users_graph_data
    total_closed_groups_with_positive_outcome = get_total_positive_outcome_groups_data_between(self.startDate, self.endDate)
    self.positiveOutcomesGraphData = [get_users_data_for_graph_from_raw_data(total_closed_groups_with_positive_outcome)]
  end

  def set_ongoing_connections_role_users_graph_data
    self.ongoingConnectionsGraphData = [computed_graph_data_for_users_of_ongoing_connections_per_role(@role)]
  end

  def set_completed_connections_role_users_graph_data
    completed_reason_ids = @program.group_closure_reasons.completed.pluck(:id)
    total_completed_groups = get_total_completed_groups_data_between(self.startDate, self.endDate, completed_reason_ids)
    self.completedConnectionGraphData = [get_role_users_data_for_graph_from_raw_data(total_completed_groups)]
  end

  def set_positive_outcomes_users_role_graph_data
    total_closed_groups_with_positive_outcome = get_total_positive_outcome_groups_data_between(self.startDate, self.endDate)
    self.positiveOutcomesGraphData = [get_role_users_data_for_graph_from_raw_data(total_closed_groups_with_positive_outcome)]
  end

  def get_group_data_for_graph_from_raw_data(data)
    all_months_graph_data = all_months_graph_data_for_completed_groups(data)
    total_data = groups_data_for_completed_groups_graph_data(all_months_graph_data)
    computed_graph_data_for_completed_connections(total_data)
  end

  def get_users_data_for_graph_from_raw_data(data)
    all_months_graph_data = all_months_graph_data_for_completed_groups(data)
    total_data = users_data_for_completed_groups_graph_data(all_months_graph_data)
    computed_graph_data_for_users_of_completed_connections(total_data)
  end

  def get_role_users_data_for_graph_from_raw_data(data)
    all_months_graph_data = all_months_graph_data_for_completed_groups(data)
    total_data = role_users_data_for_completed_groups_graph_data(all_months_graph_data, @role)
    computed_graph_data_for_users_of_completed_connections_per_role(@role, total_data)
  end

  def remove_unnecessary_instance_variables
    remove_instance_variable(:@program)
    remove_instance_variable(:@userIds)
    remove_instance_variable(:@groupIds)
    remove_instance_variable(:@options)
  end
end