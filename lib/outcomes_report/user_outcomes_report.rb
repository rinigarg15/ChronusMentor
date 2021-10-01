class UserOutcomesReport
  include OutcomesReportUtils

  module MembershipSectionElementId
    PREFIX = "membership_"

    def self.for_role(role)
      "#{PREFIX}#{role.name}"
    end
  end

  attr_accessor :programId, :nMentoringRoles, :startDate, :endDate, :startDayIndex, :totalCount, :overallChange, :rolewiseSummary, :graphData, :startDateForGraph, :prevWindowValid, :roleGraphColorMapping, :userState, :enabledStatusMapping, :intervalInDays, :newRoleStateUsersCache
  attr_reader :userIds, :mentoringRoles

  def initialize(program, date_range, options = {})
    data_side = options[:data_side] || ""
    cache_key = options[:cache_key]
    process_date_params(date_range)
    @userIds = cache_key.present? ? Rails.cache.read(cache_key + "_users") : nil
    @mentoringRoles = program.roles.for_mentoring.includes(:translations, customized_term: :translations)
    self.programId = program.id
    self.nMentoringRoles = @mentoringRoles.length

    initialize_non_graph_data(program, options) if data_side.in? [OutcomesReportUtils::DataType::NON_GRAPH_DATA, OutcomesReportUtils::DataType::ALL_DATA]
    initialize_graph_data(program, options) if data_side.in? [OutcomesReportUtils::DataType::GRAPH_DATA, OutcomesReportUtils::DataType::ALL_DATA]
  end

  def remove_unnecessary_instance_variables
    remove_instance_variable(:@userIds)
    remove_instance_variable(:@mentoringRoles)
  end

  private

  def initialize_non_graph_data(program, options)
    fetch_user_state = options[:fetch_user_state]
    self.newRoleStateUsersCache = {}

    if options[:include_rolewise_summary] || options[:only_rolewise_summary]
      self.rolewiseSummary = compute_rolewise_summary(program, fetch_user_state)
      return if options[:only_rolewise_summary]
    end

    self.intervalInDays = (self.endDate.utc.beginning_of_day.to_i - self.startDate.utc.beginning_of_day.to_i) / 1.day + 1
    self.totalCount = User.get_ids_of_users_active_between(program, self.startDate, self.endDate, ids: @userIds).size
    self.overallChange = get_overall_change(program)
    self.userState = {
      new_users: User.get_ids_of_new_active_users(program, self.startDate, self.endDate, ids: @userIds, cache_source: self).size,
      suspended_users: User.get_ids_of_new_suspended_users(program, self.startDate, self.endDate, ids: @userIds, cache_source: self).size
    } if fetch_user_state
  end

  def initialize_graph_data(program, options)
  # default enabled status is of the form "111" where the leading 1 is for users graph, and the number of remaining 1's depends on the number of mentoring roles
    enabled_status = options[:enabled_status] || Array.new(self.nMentoringRoles + 1, 1).join("")

    self.startDayIndex = (self.startDate.utc.beginning_of_day.to_i - program.created_at.utc.beginning_of_day.to_i) / 1.day
    self.startDayIndex = 0 if self.startDayIndex < 0
    self.roleGraphColorMapping = GraphColor.get_role_graph_color_mapping(@mentoringRoles)
    self.enabledStatusMapping = GraphEnabledStatus.get_enabled_status_mapping(@mentoringRoles, enabled_status, false)
    self.graphData = computed_graph_data(program)
    self.startDateForGraph = self.startDate.to_i * 1000
  end

  def computed_graph_data(program)
    total_user_data = UserStateChange.get_user_state_changes_per_day_for_active_users(program, @userIds, self.endDate)
    graph_data = [ {
      name: "feature.outcomes_report.title.registered_users".translate,
      data: get_aggregated_data(total_user_data)[self.startDayIndex..-1],
      color: GraphColor::USERS,
      visibility: self.enabledStatusMapping[:users]
    } ]

    @mentoringRoles.each do |role|
      graph_data << {
        name: "feature.outcomes_report.title.registered_roles".translate(role: role.customized_term.pluralized_term),
        data: get_aggregated_data(UserStateChange.get_user_state_changes_per_day_per_role(program, @userIds, self.endDate, role))[self.startDayIndex..-1],
        color: self.roleGraphColorMapping[role.id],
        visibility: self.enabledStatusMapping[role.id]
      }
    end
    graph_data
  end

  def compute_rolewise_summary(program, fetch_user_state)
    @mentoringRoles.map do |role|
      query_params = [program, self.startDate, self.endDate, role_ids: [role.id], ids: @userIds]
      current_count = User.get_ids_of_users_active_between(*query_params).size
      old_count = get_rolewise_change(program, role)
      change = (old_count.nil? || old_count.zero?) ? nil : ((((current_count - old_count).to_f)/old_count)*100).round(2)

      if fetch_user_state
        query_params[-1].merge!(cache_source: self)

        {
          name: role.customized_term.pluralized_term,
          count: current_count,
          change: change,
          new_roles: User.get_ids_of_new_active_users(*query_params).size,
          suspended_roles: User.get_ids_of_new_suspended_users(*query_params).size
        }
      else
        {
          id: MembershipSectionElementId.for_role(role),
          name: role.customized_term.pluralized_term,
          count: current_count,
          change: change
        }
      end
    end
  end

  def get_overall_change(program)
    days_span = (self.endDate.utc.beginning_of_day.to_i - self.startDate.utc.beginning_of_day.to_i) / 1.day
    old_end_time = self.startDate - 1.day
    old_start_time = self.startDate - (days_span + 1).days
    self.prevWindowValid = (old_start_time.to_i >= program.created_at.utc.beginning_of_day.to_i)
    old_count = (program.created_at.utc > old_start_time.utc) ? nil : User.get_ids_of_users_active_between(program, old_start_time, old_end_time, ids: @userIds).size
    return nil if old_count.nil? || old_count.zero?

    ((((self.totalCount - old_count).to_f) / old_count) * 100).round(2)
  end

  def get_rolewise_change(program, role)
    days_span = (self.endDate.utc.beginning_of_day.to_i - self.startDate.utc.beginning_of_day.to_i) / 1.day
    old_end_time = self.startDate - 1.day
    old_start_time = self.startDate - (days_span + 1).days
    return nil if program.created_at.utc > old_start_time.utc

    User.get_ids_of_users_active_between(program, old_start_time, old_end_time, role_ids: [role.id], ids: @userIds).size
  end
end