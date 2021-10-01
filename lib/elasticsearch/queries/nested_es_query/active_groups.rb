# To find groups which were active at any point during the timeframe(start_time..end_time)
class NestedEsQuery::ActiveGroups < NestedEsQuery::Base

  def initialize(program, start_time, end_time, options = {})
    self.filterable_ids = options[:ids].nil? ? program.group_ids : options[:ids]
    super
  end

  private

  # Returns <Array> of group IDs
  # Groups having atleast one state change in the timeframe, showing that the group was active
  def get_hits
    Group.common_chronus_elasticsearch_query_executor(
      QueryHelper::Filter.simple_bool_filter(
        [
          QueryHelper::Filter.get_term_query("id", self.filterable_ids),
          QueryHelper::Filter.get_nested_query("state_changes",
            QueryHelper::Filter.simple_bool_filter(
              [
                QueryHelper::Filter.get_range_query("state_changes.date_id", self.start_date_id..self.end_date_id),
                QueryHelper::Filter.get_term_query("state_changes.to_state", Group::Status::ACTIVE_CRITERIA)
              ],
            [])
          )
        ],
      [])
    )
  end

  # Returns <Hash> of format: { group_id => <number of matching state changes> }
  # Number of times group had transitioned before start_time
  # Positive: from not active to active
  # Negative: from active to not active
  # Positive - Negative:
  # If the number of state changes is >0 for a group, then we can conclude that the group
  # was active at start_time
  def get_inner_hits_map(is_positive)
    from_to_order = is_positive ? ["to", "from"] : ["from", "to"]

    Group.common_chronus_elasticsearch_nested_query_executor("state_changes",
      QueryHelper::Filter.simple_bool_filter(
        [
          QueryHelper::Filter.get_term_query("id", self.filterable_ids),
          QueryHelper::Filter.get_nested_query("state_changes",
            QueryHelper::Filter.simple_bool_filter(
              [
                QueryHelper::Filter.get_range_query("state_changes.date_id", lt: self.start_date_id),
                QueryHelper::Filter.get_term_query("state_changes.#{from_to_order[0]}_state", Group::Status::ACTIVE_CRITERIA)
              ],
              [
                QueryHelper::Filter.get_term_query("state_changes.#{from_to_order[1]}_state", Group::Status::ACTIVE_CRITERIA)
              ]
            ),
          true)
        ],
      [])
    )
  end
end