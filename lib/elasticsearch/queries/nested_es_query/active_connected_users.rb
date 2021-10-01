# To find users who were *active(User::Status::ACTIVE)* and part of any *active(Group::Status::ACTIVE_CRITERIA)* connection
# as an *active(Connection::Membership::Status::ACTIVE)* member at any point during the timeframe(start_time..end_time)
class NestedEsQuery::ActiveConnectedUsers < NestedEsQuery::Base

  attr_accessor :role_query

  def initialize(program, start_time, end_time, options = {})
    super
    if options[:role].present?
      self.role_query = QueryHelper::Filter.get_term_query("connection_membership_state_changes.role_id", options[:role].id)
    end
  end

  private

  # Returns <Array> of user IDs
  # Users having atleast one state change in the timeframe, showing that the user
  # was active and an active participant of any active connection
  def get_hits
    User.common_chronus_elasticsearch_query_executor(
      QueryHelper::Filter.simple_bool_filter(
        [
          QueryHelper::Filter.get_term_query("id", self.filterable_ids),
          QueryHelper::Filter.get_nested_query("connection_membership_state_changes",
            QueryHelper::Filter.simple_bool_filter(
              [
                self.role_query,
                QueryHelper::Filter.get_range_query("connection_membership_state_changes.date_id", self.start_date_id..self.end_date_id),
                QueryHelper::Filter.get_term_query("connection_membership_state_changes.user_to_state", User::Status::ACTIVE),
                QueryHelper::Filter.get_term_query("connection_membership_state_changes.cm_to_state", Connection::Membership::Status::ACTIVE),
                QueryHelper::Filter.get_term_query("connection_membership_state_changes.group_to_state", Group::Status::ACTIVE_CRITERIA)
              ].compact,
            [])
          )
        ],
      [])
    )
  end

  # Returns <Hash> of format: { user_id => <number of matching state transitions> }
  # Number of times user had transitioned before start_time
  # Positive:
  # from not active or not an active participant of any active connection
  # to active and an active participant of any active connection

  # Negative:
  # from active and an active participant of any active connection
  # to not active or not an active participant of any active connection

  # Positive - Negative:
  # If the number of state transitions is >0 for a user, then we can conclude that the user
  # was active and an active participant of atleast one active connection at start_time
  def get_inner_hits_map(is_positive)
    from_to_order = is_positive ? ["to", "from"] : ["from", "to"]

    User.common_chronus_elasticsearch_nested_query_executor("connection_membership_state_changes",
      QueryHelper::Filter.simple_bool_filter(
        [
          QueryHelper::Filter.get_term_query("id", self.filterable_ids),
          QueryHelper::Filter.get_nested_query("connection_membership_state_changes",
            QueryHelper::Filter.simple_bool_filter(
              [
                self.role_query,
                QueryHelper::Filter.get_range_query("connection_membership_state_changes.date_id", lt: self.start_date_id),
                QueryHelper::Filter.get_term_query("connection_membership_state_changes.user_#{from_to_order[0]}_state", User::Status::ACTIVE),
                QueryHelper::Filter.get_term_query("connection_membership_state_changes.cm_#{from_to_order[0]}_state", Connection::Membership::Status::ACTIVE),
                QueryHelper::Filter.get_term_query("connection_membership_state_changes.group_#{from_to_order[0]}_state", Group::Status::ACTIVE_CRITERIA),
                QueryHelper::Filter.simple_bool_should(
                  [
                    QueryHelper::Filter.simple_bool_filter([], QueryHelper::Filter.get_term_query("connection_membership_state_changes.user_#{from_to_order[1]}_state", User::Status::ACTIVE)),
                    QueryHelper::Filter.simple_bool_filter([], QueryHelper::Filter.get_term_query("connection_membership_state_changes.cm_#{from_to_order[1]}_state", Connection::Membership::Status::ACTIVE)),
                    QueryHelper::Filter.simple_bool_filter([], QueryHelper::Filter.get_term_query("connection_membership_state_changes.group_#{from_to_order[1]}_state", Group::Status::ACTIVE_CRITERIA))
                  ]
                )
              ].compact,
            []),
          true)
        ],
      [])
    )
  end
end