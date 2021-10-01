module SurveyAnswerElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper

    def get_es_survey_answers(options)
      query = get_query(options[:match_query])
      range_formats = options[:filter].delete(:es_range_formats)
      query[:bool].merge!({filter: QueryHelper::Filter.get_filter_conditions(options[:filter], range_formats || {})})

      common_esearch_query_executor_extract_source(query, {source: options[:source_columns], sort: options[:sort] || []})
    end

    private

    def get_query(match_query)
      return {bool: {}} if match_query.blank?
      match_queries = match_query.collect{|field, value| QueryHelper::Filter.get_multi_match_query(field, value) }
      QueryHelper::Filter.simple_bool_filter(match_queries, {})
    end
  end
end