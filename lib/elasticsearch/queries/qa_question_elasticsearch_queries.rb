module QaQuestionElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper

    QueryBoost = {
      "summary.language_*" => 1.0,
      "description.language_*" => 0.75,
      "qa_answers.content.language_*" => 0.70,
      "user.name_only" => 0.25, # questioner
      "qa_answers.user.name_only" => 0.25 # answerer
    }

    def get_qa_questions_matching_query(query, options = {})
      full_query = get_full_query(query, options)
      query_options = get_query_options(options)
      common_esearch_query_executor_collect_records(full_query, query_options)
    end

    private

    def get_full_query(query, options)
      match_query = get_match_query(query)
      must = QueryHelper::Filter.get_filter_conditions(options[:with]) if options[:with]
      must_not = QueryHelper::Filter.get_filter_conditions(options[:without]) if options[:without]
      return QueryHelper::Filter.simple_bool_filter([must, match_query].compact, must_not)
    end

    def get_match_query(query)
      fields_queries = QueryBoost.collect do |field, boost| 
        match_query = QueryHelper::Filter.get_multi_match_query(field, query, { operator: "OR"})
        QueryHelper::Filter.get_constant_score_query(match_query, boost: boost)
      end
      QueryHelper::Filter.simple_bool_should(fields_queries)
    end

    def get_query_options(options = {})
      query_options = {}
      query_options.merge!(page: options[:page], size: options[:per_page] || PER_PAGE) if options[:page].present?
      query_options[:includes] = options[:includes_list] if options[:includes_list]
      query_options[:sort] = [{options[:sort_field] => options[:sort_order]}, "_score" => "desc"] if options[:sort_field].present? && options[:sort_order].present?
      return query_options
    end
  end
end