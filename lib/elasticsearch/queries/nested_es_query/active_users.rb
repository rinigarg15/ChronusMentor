# To find users who were active with the specified role(s) at any point during the timeframe(start_time..end_time)
class NestedEsQuery::ActiveUsers < NestedEsQuery::Base

  attr_accessor :role_ids, :user_status

  def initialize(program, start_time, end_time, options = {})
    super
    self.role_ids = options[:role_ids].presence || program.mentoring_role_ids
    self.user_status =
      if options[:include_unpublished]
        [User::Status::ACTIVE, User::Status::PENDING]
      else
        User::Status::ACTIVE
      end
  end

  private

  # Returns <Array> of user IDs
  # Users having atleast one state transition in the timeframe, showing that the user
  # was active and had atleast one of the specified role(s)
  def get_hits
    User.common_chronus_elasticsearch_query_executor(
      QueryHelper::Filter.simple_bool_filter(
        [
          QueryHelper::Filter.get_term_query("id", self.filterable_ids),
          QueryHelper::Filter.get_nested_query("state_transitions",
            QueryHelper::Filter.simple_bool_filter(
              [
                QueryHelper::Filter.get_range_query("state_transitions.date_id", self.start_date_id..self.end_date_id),
                QueryHelper::Filter.get_term_query("state_transitions.to_state", self.user_status),
                QueryHelper::Filter.get_term_query("state_transitions.to_roles", self.role_ids)
              ],
            [])
          )
        ],
      [])
    )
  end

  # Returns <Hash> of format: { user_id => <number of matching state changes> }
  # Number of times user had transitioned before start_time
  # Positive:
  # from not active or not having atleast one of the specified role(s)
  # to active with atleast one of the specified role(s)

  # Negative:
  # from active with atleast one of the specified role(s)
  # to not active or not having atleast one of the specified role(s)

  # Positive - Negative:
  # If the number of state changes is >0 for a user, then we can conclude that the user
  # was active and had one of the specified role(s) at start_time
  def get_inner_hits_map(is_positive)
    from_to_order = is_positive ? ["to", "from"] : ["from", "to"]

    User.common_chronus_elasticsearch_nested_query_executor("state_transitions",
      QueryHelper::Filter.simple_bool_filter(
        [
          QueryHelper::Filter.get_term_query("id", self.filterable_ids),
          QueryHelper::Filter.get_nested_query("state_transitions",
            QueryHelper::Filter.simple_bool_filter(
              [
                QueryHelper::Filter.get_range_query("state_transitions.date_id", lt: self.start_date_id),
                QueryHelper::Filter.get_term_query("state_transitions.#{from_to_order[0]}_state", self.user_status),
                QueryHelper::Filter.get_term_query("state_transitions.#{from_to_order[0]}_roles", self.role_ids),
                QueryHelper::Filter.simple_bool_should(
                  [
                    QueryHelper::Filter.simple_bool_filter([], QueryHelper::Filter.get_term_query("state_transitions.#{from_to_order[1]}_state", self.user_status)),
                    QueryHelper::Filter.simple_bool_filter([], QueryHelper::Filter.get_term_query("state_transitions.#{from_to_order[1]}_roles", self.role_ids))
                  ]
                )
              ],
            []),
          true)
        ],
      [])
    )
  end
end