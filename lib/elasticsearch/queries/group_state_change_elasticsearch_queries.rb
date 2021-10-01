module GroupStateChangeElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper
    def get_group_state_changes_per_day(program, group_ids, end_time=Time.now, state=Group::Status::ACTIVE_CRITERIA)
      # response.aggregations.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
      start_date_id = program.created_at.utc.to_i/1.day.to_i
      end_date_id = end_time.utc.to_i/1.day.to_i
      end_date_id = start_date_id if end_date_id < start_date_id
      group_ids_filter = group_ids.nil? ? {} : {query: { bool: { filter: { terms: { group_id: group_ids}}}}}
      additions_per_day = get_get_group_state_changes_per_day_aggregation("to_state", start_date_id, end_date_id, state, program)
      removals_per_day = get_get_group_state_changes_per_day_aggregation("from_state", start_date_id, end_date_id, state, program)
      common_esearch_aggregation_query_executor(additions_per_day, removals_per_day, group_ids_filter, 0)
    end

    private
    def get_get_group_state_changes_per_day_aggregation(must_state, start_date_id, end_date_id, state, program)
      state_map = {"to_state" => "from_state", "from_state" => "to_state"}
      must_not_state = state_map[must_state]
      {
        filter: QueryHelper::Filter.simple_bool_filter([{terms: {must_state => state}}, {term: {"group.program_id" => program.id}}, {range: {date_id: {lte: end_date_id}}}], [{terms: {must_not_state => state}}]),
        aggs: QueryHelper::Aggregation.date_aggregation(start_date_id, end_date_id)
      }
    end
  end
end