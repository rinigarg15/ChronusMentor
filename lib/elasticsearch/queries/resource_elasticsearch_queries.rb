module ResourceElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper

    def get_es_resources(search_content, options = {})
      es_query = build_query(search_content, options)
      es_query = apply_filter(es_query, options)
      common_esearch_query_executor_collect_records(es_query, get_query_options(options))
    end

    private
    
    def build_query(search_content, _options)
      if search_content.present?
        search_query = QueryHelper::Filter.get_multi_match_query(['title.language_*', 'content.language_*', 'title.sort'], QueryHelper::EsUtils.sanitize_es_query(search_content), operator: "OR")
      end
      es_query = search_query.present? ? QueryHelper::Filter.simple_bool_filter(search_query, {}) : {bool: {}}
      es_query
    end

    def get_query_options(options)
      query_options = options.slice(:includes)
      query_options[:page] = options[:page]
      query_options[:size] = options[:per_page]
      query_options[:sort] = QueryHelper::Filter.get_sort_conditions(options[:sort])
      query_options
    end

    def apply_filter(es_query, options)
      es_query[:bool].merge!({filter: QueryHelper::Filter.get_filter_conditions(options[:filter])})
      is_admin = options[:admin_view_check]
      if is_admin
        filter_query = QueryHelper::Filter.get_exists_query('resource_publications.program_id')
      else
        filter_query = QueryHelper::Filter.get_range_term_query(:resource_for_role_ids, options[:current_user_role_ids], {})
      end
      es_query[:bool][:filter] << (QueryHelper::Filter.simple_bool_filter(filter_query, []))
      es_query
    end
  end
end