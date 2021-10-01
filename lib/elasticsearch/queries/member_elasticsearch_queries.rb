module MemberElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper
    include EsComplexQueries

    def get_filtered_members(search_query, options = {})
      must_not_terms = QueryHelper::Filter.get_filter_conditions(options[:without] || [])
      es_query = get_search_query(search_query, options[:match_fields])
      es_query[:bool].merge!({filter: QueryHelper::Filter.simple_bool_filter(get_must_terms(options), must_not_terms)})
      query_options = get_query_options(options)
      if options[:source_columns].present? && options[:source_columns] == [:id]
        common_chronus_elasticsearch_query_executor(es_query, query_options)
      elsif options[:source_columns].present?
        common_esearch_query_executor_extract_source(es_query, query_options)
      else
        common_esearch_query_executor_collect_records(es_query, query_options)
      end
    end

    private

    def get_search_query(search_query, match_fields)
      if search_query.present? && match_fields.present?
        QueryHelper::Filter.simple_bool_filter(QueryHelper::Filter.get_multi_match_query(match_fields, search_query), {})
      else
        {bool: {}}
      end    
    end
  end
end