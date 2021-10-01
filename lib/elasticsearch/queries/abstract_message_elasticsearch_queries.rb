module AbstractMessageElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper

    def get_filtered_messages_from_es(search_content, message_ids)
      es_query = build_query(search_content, message_ids)
      aggs = build_aggregations
      common_esearch_query_executor_with_aggregations(es_query, aggs, size: 0)
    end

    private

    def build_query(search_content, message_ids)
      search_query = QueryHelper::Filter.get_multi_match_query(["subject.language_*", "html_stripped_content.language_*"], QueryHelper::EsUtils.sanitize_es_query_for_url_analyzer(search_content)) if search_content.present?
      es_query = search_query.present? ? QueryHelper::Filter.simple_bool_filter(search_query, {}) : {bool: {}}
      es_query[:bool].merge!({filter: QueryHelper::Filter.get_term_query("id", message_ids)})
      es_query
    end

    def build_aggregations
      {
        group_by_root_id: {
          terms: {
            field: "root_id",
            size: QueryHelper::MAX_HITS,
            order: [
              {"maximum_created_at": ElasticsearchConstants::SortOrder::DESC },
              {"max_score": ElasticsearchConstants::SortOrder::DESC}
            ]
          },
          aggs: {
            maximum_created_at: {
              max: {
                field: "created_at"
              }
            },
            max_score: {
              max: {
                script: {
                  lang: "painless",
                  inline: "_score"
                }
              }
            }
          }
        }
      }
    end
  end
end