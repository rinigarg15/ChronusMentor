module ProjectRequestElasticsearchQueries
  extend ActiveSupport::Concern

  module ClassMethods
    include QueryHelper

    def get_filtered_project_requests(filter_params = {}, options = {})
      query_options = {}
      query_options.merge!(page: filter_params[:page], size: filter_params[:per_page] || PER_PAGE) unless options[:skip_pagination]
      query_options.merge!(source: options[:source_columns]) if options[:source_columns].present?
      query_options.merge!(sort: [{"id" => ElasticsearchConstants::SortOrder::ASC}])
      es_query = build_query(filter_params, options)
      if options[:source_columns].present?
        common_esearch_query_executor_extract_source(es_query, query_options)
      else
        query_options[:includes] = [group: [{memberships: [user: :member]}, :active_project_requests, :membership_settings]]
        common_esearch_query_executor_collect_records(es_query, query_options)
      end
    end

    def get_project_requests_search_count(filter_params = {}, options = {})
      es_query = build_query(filter_params, options)
      get_total_response_hits(es_query)
    end

    def get_project_request_ids(filter_params = {}, options = {})
      es_query = build_query(filter_params, options)
      sort = [{"id" => "asc"}]
      common_chronus_elasticsearch_query_executor(es_query, {sort: sort})
    end

    private

    def build_query(filter_params, options)
      search_queries = get_match_query(filter_params)
      filter_conditions = get_filters(filter_params, options)
      es_query = search_queries.present? ? QueryHelper::Filter.simple_bool_filter(search_queries, {}) : { bool: {} }
      es_query[:bool].merge!(filter: QueryHelper::Filter.get_filter_conditions(filter_conditions)) if filter_conditions.present?
      es_query
    end

    def get_match_query(search_params)
      search_queries = []
      search_queries << (QueryHelper::Filter.get_match_query("sender.name_only", QueryHelper::EsUtils.sanitize_es_query(search_params[:requestor]))) if search_params[:requestor].present?
      search_queries << (QueryHelper::Filter.get_match_query("group.name", QueryHelper::EsUtils.sanitize_es_query(search_params[:project]))) if search_params[:project].present?
      search_queries
    end

    def get_filters(filter_params, options)
      cur_prog = options[:program]
      filter_conditions = {program_id: cur_prog.id}
      unless options[:skip_status].present?
        string_status = filter_params[:status] || AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::NOT_ANSWERED]
        status = AbstractRequest::Status::STRING_TO_STATE[string_status]
        scope = AbstractRequest::Status::STATUS_TO_SCOPE[status]
        ids = cur_prog.project_requests.send(scope).pluck(:id).presence || [0]
        filter_conditions.merge!(status: status, id: ids)
      end

      filter_conditions.merge!(created_at: filter_params[:start_time].beginning_of_day()..filter_params[:end_time].end_of_day()) if filter_params[:start_time].present? && filter_params[:end_time].present?
      filter_conditions.merge!(sender_id: options[:sender_id]) if options[:sender_id].present?
      filter_conditions.merge!(group_id: options[:group_ids]) if options[:group_ids].present?
      filter_conditions
    end
  end
end