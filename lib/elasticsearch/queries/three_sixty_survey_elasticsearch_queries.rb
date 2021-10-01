# Used for both ThreeSixty::Survey and ThreeSixty::SurveyAssessee models. Please be careful while modifying this file
module ThreeSixtySurveyElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper

    def get_es_results(options = {})
      query_options = get_es_query_options(options[:search_params], options[:filter], options[:skip_pagination])
      common_esearch_query_executor_collect_records(query_options.delete(:query), query_options.merge!({includes: options[:includes_list]}))
    end

    private

    def get_es_query_options(search_params = {}, filter_conditions = {}, skip_pagination = false)
      query_options = {}
      query_options[:sort] = [{search_params[:sort_field] => search_params[:sort_order]}] if search_params[:sort_field].present? && search_params[:sort_order].present?
      query_options[:source] = false

      query_options.merge!(page: search_params[:page], size: search_params[:per_page] || PER_PAGE) unless skip_pagination

      es_query = { bool: {} }
      es_query[:bool].merge!(filter: QueryHelper::Filter.get_filter_conditions(filter_conditions))
      query_options[:query] = es_query
      query_options
    end

  end
end