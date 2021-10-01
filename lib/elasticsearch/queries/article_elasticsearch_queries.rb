module ArticleElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper

    def get_es_articles(search_content, options = {})
      es_query = build_query(search_content, options)
      es_query = apply_filter(es_query, options)
      common_esearch_query_executor_collect_records(es_query, get_query_options(options))
    end

    private
    def build_query(search_content, options)
      return get_boosted_search_query(search_content, options) if options[:fetch_related_articles].present?
      if search_content.present?
        search_query = QueryHelper::Filter.get_multi_match_query(["author.name_only", 'article_content.body.language_*', 'article_content.title.language_*', 'article_content.labels.name.language_*'], QueryHelper::EsUtils.sanitize_es_query(search_content), operator: "OR")
      end
      es_query = search_query.present? ? QueryHelper::Filter.simple_bool_filter(search_query, {}) : {bool: {}}
      es_query
    end

    def get_query_options(options)
      query_options = options.slice(:includes)
      unless options[:skip_pagination]
        query_options[:page] = options[:page]
        query_options[:size] = options[:per_page]
      end
      query_options[:sort] = QueryHelper::Filter.get_sort_conditions(options[:sort])
      query_options
    end

    def apply_filter(es_query, options)
      es_query[:bool].merge!({filter: QueryHelper::Filter.get_filter_conditions(options[:filter])})
      es_query
    end
  end
end