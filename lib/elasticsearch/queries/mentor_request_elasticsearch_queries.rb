module MentorRequestElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper

    def get_filtered_mentor_requests(search_params = {}, filter_conditions = {}, skip_pagination = false, source_columns = [])
      query_options = get_es_query_options(search_params, filter_conditions, skip_pagination, source_columns)
      if source_columns.present?
        common_esearch_query_executor_extract_source(query_options.delete(:query), query_options)
      else
        common_esearch_query_executor_collect_records(query_options.delete(:query), query_options)
      end
    end

    def get_mentor_requests_search_count(search_params = {}, filter_conditions = {})
      query_options = get_es_query_options(search_params, filter_conditions, true)
      get_total_response_hits(query_options.delete(:query))
    end

    def get_filtered_mentor_request_ids(search_params = {}, filter_conditions = {})
      query = get_full_query_with_filter(search_params, filter_conditions, reverse_merge: true)
      common_chronus_elasticsearch_query_executor(query)
    end

    private

    def get_search_filters(search_params = {})
      list_field = search_params[:list] || 'active'

      search_filters = {
        status: AbstractRequest::Status::STRING_TO_STATE[list_field]
      }
      start_time, end_time = CommonFilterService.initialize_date_range_filter_params(search_params[:search_filters][:expiry_date])
      search_filters.merge!(created_at: start_time.beginning_of_day()..end_time.end_of_day()) if start_time.present? && end_time.present?
      search_filters
    end

    def build_search_query(search_params = {})
      search_queries = []
      search_queries << (QueryHelper::Filter.get_match_query("student.name_only", QueryHelper::EsUtils.sanitize_es_query(search_params[:search_filters][:sender]))) if search_params[:search_filters][:sender].present?
      search_queries << (QueryHelper::Filter.get_match_query("mentor.name_only", QueryHelper::EsUtils.sanitize_es_query(search_params[:search_filters][:receiver]))) if search_params[:search_filters][:receiver].present?
      search_queries
    end

    def get_full_query_with_filter(search_params, filter_conditions, options={})
      if search_params[:search_filters].present?
        search_queries = build_search_query(search_params)
        options[:reverse_merge] ? filter_conditions.reverse_merge!(get_search_filters(search_params)) : filter_conditions.merge!(get_search_filters(search_params))
      end

      es_query = search_queries.present? ? QueryHelper::Filter.simple_bool_filter(search_queries, {}) : { bool: {} }
      es_query[:bool].merge!(filter: QueryHelper::Filter.get_filter_conditions(filter_conditions)) if filter_conditions.present?
      es_query
    end

    def get_es_query_options(search_params = {}, filter_conditions = {}, skip_pagination = false, source_columns = [])
      query_options = {}
      query_options[:sort] = [{search_params[:sort_field] => search_params[:sort_order]}] if search_params[:sort_field].present? && search_params[:sort_order].present?
      query_options[:source] = source_columns if source_columns.present?
      query_options.merge!(page: search_params[:page], size: search_params[:per_page] || PER_PAGE) unless skip_pagination
      query_options[:query] = get_full_query_with_filter(search_params, filter_conditions)
      query_options
    end
  end
end