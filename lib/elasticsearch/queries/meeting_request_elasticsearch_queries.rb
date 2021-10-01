module MeetingRequestElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper

    def get_es_meeting_requests(conditions, source_columns)
      query = {bool: {filter: QueryHelper::Filter.get_filter_conditions(conditions)}}

      common_esearch_query_executor_extract_source(query, {source: source_columns})
    end
  end
end