# To find users who weren't in specified state or didn't have the specified role(s) at start_time
# but transition to the specified state with the specified role(s) at end_time
class NestedEsQuery::NewRoleStateUsers < NestedEsQuery::Base

  attr_accessor :role_ids, :user_status, :include_new_role_users, :cache_source

  # include_new_role_users: Users who didn't have the specified role(s) at start_time
  # but have the specified role(s) at end_time
  def initialize(program, start_time, end_time, options = {})
    super
    self.role_ids = options[:role_ids].presence || program.mentoring_role_ids
    self.user_status = options[:user_status].presence || User::Status::ACTIVE
    self.include_new_role_users = options[:include_new_role_users]
    self.cache_source = options[:cache_source]
  end

  def get_filtered_ids
    positive_hits_maps = get_positive_hits_from_inner_hits_maps
    filtered_ids = (positive_hits_maps[:roles_count] & positive_hits_maps[:state_count]) - (positive_hits_maps[:before_roles_count] & positive_hits_maps[:before_state_count])
    if self.include_new_role_users
      filtered_ids += (positive_hits_maps[:roles_count] - positive_hits_maps[:before_roles_count])
    end
    filtered_ids.uniq
  end

  private

  # before_roles_count: IDs of users who have any of the specified role(s) at start_time
  # roles_count: IDs of users who have any of the specified role(s) at end_time
  # before_state_count: IDs of users who are in the specified state at start_time
  # state_count: IDs of users who are in the specified state at end_time
  def get_positive_hits_from_inner_hits_maps
    [:roles, :state].inject({}) do |positive_hits_maps, roles_or_state|
      cache_key = get_cache_key(roles_or_state)

      if cache_lookup(cache_key).blank?
        cumulative_maps = get_cumulative_inner_hits_maps(roles_or_state)
        hits_maps = {
          "before_#{roles_or_state}_count".to_sym => filter_positive_inner_hits(cumulative_maps[0]),
          "#{roles_or_state}_count".to_sym => cumulate_and_filter_positive_inner_hits(*cumulative_maps, :sum)
        }
        write_to_cache(cache_key, hits_maps)
      end
      positive_hits_maps.merge!(hits_maps.presence || cache_lookup(cache_key))
    end
  end

  # Returns <Array> of format: [<Hash>, <Hash>]
  # <Hash> format: { user_id: <number_of_positive_inner_hits> - <number_of_negative_inner_hits> }
  def get_cumulative_inner_hits_maps(roles_or_state)
    [
      { lt: self.start_date_id },
      self.start_date_id..self.end_date_id
    ].map do |range_filter|
      positive_inner_hits_map = get_inner_hits_map(true, roles_or_state, range_filter)
      negative_inner_hits_map = get_inner_hits_map(false, roles_or_state, range_filter)
      cumulate_inner_hits_maps(positive_inner_hits_map, negative_inner_hits_map)
    end
  end

  # Returns <Hash> of format: { user_id => <number of matching state transitions> }
  def get_inner_hits_map(is_positive, roles_or_state, range_filter)
    return {} if self.filterable_ids.blank?

    filter_names, filter_value = get_roles_or_state_filter(is_positive, roles_or_state)
    User.common_chronus_elasticsearch_nested_query_executor("state_transitions",
      QueryHelper::Filter.simple_bool_filter(
        [
          QueryHelper::Filter.get_term_query("id", self.filterable_ids),
          QueryHelper::Filter.get_nested_query("state_transitions",
            QueryHelper::Filter.simple_bool_filter(
              [
                QueryHelper::Filter.get_range_query("state_transitions.date_id", range_filter),
                QueryHelper::Filter.get_term_query("state_transitions.#{filter_names[0]}", filter_value)
              ],
              [
                QueryHelper::Filter.get_term_query("state_transitions.#{filter_names[1]}", filter_value)
              ]
            ),
          true)
        ],
      [])
    )
  end

  def get_roles_or_state_filter(is_positive, roles_or_state)
    filter_names = ["from_#{roles_or_state}", "to_#{roles_or_state}"]
    filter_names.reverse! if is_positive
    [filter_names, get_filter_value(roles_or_state)]
  end

  def get_filter_value(roles_or_state)
    (roles_or_state == :roles) ? self.role_ids : self.user_status
  end

  def cache_lookup(key)
    return unless is_caching_enabled?
    self.cache_source.newRoleStateUsersCache[key]
  end

  def write_to_cache(key, value)
    return unless is_caching_enabled?
    self.cache_source.newRoleStateUsersCache[key] = value
  end

  def is_caching_enabled?
    self.cache_source.present? && self.cache_source.respond_to?(:newRoleStateUsersCache)
  end

  def get_cache_key(roles_or_state)
    (Array(get_filter_value(roles_or_state)) + [self.start_date_id, self.end_date_id]).join(UNDERSCORE_SEPARATOR)
  end
end