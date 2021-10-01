module UserSearchActivityElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper

    def get_search_keywords(conditions)
      query = {bool: {filter: QueryHelper::Filter.get_filter_conditions(conditions)}}
      aggs = build_aggregation
      get_search_keywords_from_aggregated_data(common_esearch_query_executor_with_aggregations(query, aggs, {}))
    end

    private

    def build_aggregation
      {
        search_text_aggregation: {
          terms: {
            field: "search_text",
            size: MatchReport::MenteeActions::TOP_SEARCH_KEYWORDS_LIMIT,
            order: { "_count": ElasticsearchConstants::SortOrder::DESC }
          }
        }
      }
    end

    def get_search_keywords_from_aggregated_data(data)
      data.response.aggregations.search_text_aggregation.buckets.map{|bucket| {keyword: bucket[:key], count: bucket[:doc_count]}}
    end

  end
end