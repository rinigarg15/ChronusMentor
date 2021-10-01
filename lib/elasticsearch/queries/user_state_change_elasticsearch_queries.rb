module UserStateChangeElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper
    def get_user_state_changes_per_day_for_active_users(program, user_ids, end_time=Time.now)
      get_user_state_changes_per_day_for_role_ids(program, user_ids, end_time, program.mentoring_role_ids)
    end

    # Query to get per role information
    def get_user_state_changes_per_day_per_role(program, user_ids, end_time=Time.now, role)
      get_user_state_changes_per_day_for_role_ids(program, user_ids, end_time, [role.id])
    end

    def get_active_connected_users_per_day_per_role(program, user_ids, end_time=Time.now, role)
      start_date_id, end_date_id, user_ids_filter = get_dates_and_user_ids(program, user_ids, end_time)
      role_id = role.id
      additions_per_day_filter = QueryHelper::Filter.simple_bool_should(get_active_connected_users_per_day_per_role_bool_filter("to_state", "connection_membership_to_roles", program, end_date_id, role_id))
      removals_per_day_filter = QueryHelper::Filter.simple_bool_should(get_active_connected_users_per_day_per_role_bool_filter("from_state", "connection_membership_from_roles", program, end_date_id, role_id))
      common_esearch_aggregation_query_executor(get_aggregations_filter(additions_per_day_filter, start_date_id, end_date_id), get_aggregations_filter(removals_per_day_filter, start_date_id, end_date_id), user_ids_filter)
    end

    def get_active_connected_users_per_day(program, user_ids, end_time=Time.now)
      start_date_id, end_date_id, user_ids_filter = get_dates_and_user_ids(program, user_ids, end_time)
      additions_per_day_filter = QueryHelper::Filter.simple_bool_should(get_active_connected_users_per_day_bool_filter("to_state", "connection_membership_to_roles", program, end_date_id))
      removals_per_day_filter = QueryHelper::Filter.simple_bool_should(get_active_connected_users_per_day_bool_filter("from_state", "connection_membership_from_roles", program, end_date_id))
      common_esearch_aggregation_query_executor(get_aggregations_filter(additions_per_day_filter, start_date_id, end_date_id), get_aggregations_filter(removals_per_day_filter, start_date_id, end_date_id), user_ids_filter)
    end

    private
    def get_user_state_changes_per_day_for_role_ids(program, user_ids, end_time=Time.now, role_ids)
      start_date_id, end_date_id, user_ids_filter = get_dates_and_user_ids(program, user_ids, end_time)
      additions_per_day_filter = QueryHelper::Filter.simple_bool_should(get_user_state_changes_per_day_for_role_ids_bool_filter("to_state", "to_roles", program, end_date_id, role_ids))
      removals_per_day_filter = QueryHelper::Filter.simple_bool_should(get_user_state_changes_per_day_for_role_ids_bool_filter("from_state", "from_roles", program, end_date_id, role_ids))
      common_esearch_aggregation_query_executor(get_aggregations_filter(additions_per_day_filter, start_date_id, end_date_id), get_aggregations_filter(removals_per_day_filter, start_date_id, end_date_id), user_ids_filter)
    end

    def get_dates_and_user_ids(program, user_ids, end_time=Time.now)
      start_date_id = program.created_at.utc.to_i/1.day.to_i
      end_date_id = end_time.utc.to_i/1.day.to_i
      end_date_id = start_date_id if end_date_id < start_date_id
      user_ids_filter = user_ids.nil? ? {} : {query: { bool: { filter: { terms: { user_id: user_ids}}}}}
      return start_date_id, end_date_id, user_ids_filter
    end

    def get_user_state_changes_per_day_for_role_ids_bool_filter(must_state, must_roles, program, end_date_id, role_ids)
      state_map = {"to_state" => "from_state", "from_state" => "to_state"}
      role_map = {"to_roles" => "from_roles", "from_roles" => "to_roles"}
      must_not_state = state_map[must_state]
      must_not_roles = role_map[must_roles]
      must_conditions = [get_program_term(program.id), get_status_term(must_state), {terms: {must_roles => role_ids}}, get_range(end_date_id)]
      common_user_state_change_query_filter(must_conditions, [{terms: {must_not_roles => role_ids}}], [get_status_term(must_not_state)])
    end

    def get_active_connected_users_per_day_per_role_bool_filter(must_state, must_conn_membership_roles, program, end_date_id, role_id)
      state_map = {"to_state" => "from_state", "from_state" => "to_state"}
      conn_membership_roles_map = {"connection_membership_to_roles" => "connection_membership_from_roles", "connection_membership_from_roles" => "connection_membership_to_roles"}
      must_not_state = state_map[must_state]
      must_not_conn_membership_roles = conn_membership_roles_map[must_conn_membership_roles]
      must_conditions = [get_status_term(must_state), {term: {must_conn_membership_roles => role_id}}, get_program_term(program.id), get_range(end_date_id)]
      common_user_state_change_query_filter(must_conditions, [get_status_term(must_not_state)], [{term: {must_not_conn_membership_roles => role_id}}])
    end

    def get_active_connected_users_per_day_bool_filter(must_state, must_conn_membership_roles, program, end_date_id)
      state_map = {"to_state" => "from_state", "from_state" => "to_state"}
      conn_membership_roles_map = {"connection_membership_to_roles" => "connection_membership_from_roles", "connection_membership_from_roles" => "connection_membership_to_roles"}
      must_not_state = state_map[must_state]
      must_not_conn_membership_roles = conn_membership_roles_map[must_conn_membership_roles]
      must_conditions = [get_status_term(must_state), get_program_term(program.id), get_range(end_date_id),  get_exists(must_conn_membership_roles)]
      common_user_state_change_query_filter(must_conditions, [get_status_term(must_not_state)], [get_exists(must_not_conn_membership_roles)])
    end

    def common_user_state_change_query_filter(must_conditions, must_not_condition1, must_not_condition2)
      [QueryHelper::Filter.simple_bool_filter(must_conditions, must_not_condition1),
      QueryHelper::Filter.simple_bool_filter(must_conditions, must_not_condition2)]
    end

    def get_program_term(program_id)
      {term: {"user.program_id" => program_id}}
    end

    def get_status_term(state_key)
      {terms: {state_key => ["#{User::Status::ACTIVE}"]}}
    end

    def get_range(end_date_id)
      {range: {date_id: {lte: end_date_id}}}
    end

    def get_exists(field)
      {exists: {field: field}}
    end

    def get_aggregations_filter(filter, start_date_id, end_date_id)
      {
        filter: filter,
        aggs: QueryHelper::Aggregation.date_aggregation(start_date_id, end_date_id)
      }
    end

  end
end