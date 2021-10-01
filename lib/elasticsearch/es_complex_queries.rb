module EsComplexQueries
  def get_filtered_ids(es_options = {})
    es_query = build_es_query(es_options)
    common_chronus_elasticsearch_query_executor(es_query, get_options(es_options.merge(skip_includes: true)))
  end

  def get_filtered_objects(es_options = {})
    es_query = build_es_query(es_options)
    common_esearch_query_executor_collect_records(es_query, get_options(es_options))
  end

  def get_filtered_count(es_options = {})
    es_query = build_es_query(es_options)
    get_total_response_hits(es_query)
  end

  def get_filtered_source_columns(es_options = {})
    es_query = build_es_query(es_options)
    common_esearch_query_executor_extract_source(es_query, get_query_options(es_options))
  end

  private

  def get_must_terms(options)
    must_terms = QueryHelper::Filter.get_filter_conditions(options[:with] || [])
    must_terms << QueryHelper::Filter.get_match_phrase_query(options[:location_filter][:field], options[:location_filter][:address]) if options[:location_filter].present?
    must_terms << QueryHelper::Filter.get_geo_distance_query(options[:geo][:point], options[:geo][:distance], options[:geo][:field]) if options[:geo].present?
    return must_terms
  end

  def get_query_options(options)
    query_options = {}
    if options[:sort_order].present?
      query_options[:sort] = Array(options[:sort_field]).collect do |sort_field|
         {sort_field => options[:sort_order]}
      end
    end
    query_options[:includes] = options[:includes_list]
    query_options.merge!(page: options[:page] || 1, size: options[:per_page] || PER_PAGE) if options[:page] || options[:per_page]
    query_options.merge!(source: options[:source_columns])
    query_options.keep_if{ |_k,v| v.present? }
  end

  def build_es_query(es_options)
    search_queries = build_match_query(es_options)
    es_query = search_queries.present? ? QueryHelper::Filter.simple_bool_filter(search_queries, {}) : {bool: {}}
    es_query[:bool].merge!(filter: apply_filters(es_options))
    es_query
  end

  def get_options(es_options)
    options = {}
    options[:sort] = QueryHelper::Filter.get_sort_conditions(es_options[:sort]) if es_options[:sort]
    options.merge!(apply_pagination(es_options))
    options.merge!(includes: es_options[:includes_list]) unless es_options[:skip_includes]
    options
  end

  def apply_pagination(es_options)
    pagination_options = {}
    return {} if es_options[:skip_pagination].present?
    pagination_options[:size] = es_options[:per_page] || QueryHelper::MAX_HITS
    pagination_options[:page] = es_options[:page] || 1
    pagination_options
  end

  def apply_filters(es_options)
    range_formats = es_options.delete(:es_range_formats) || {}
    must_filters = QueryHelper::Filter.get_filter_conditions(es_options[:must_filters], range_formats)
    must_filters += QueryHelper::Filter.get_with_all_conditions(es_options[:with_all_filters])
    must_not_filters = QueryHelper::Filter.get_filter_conditions(es_options[:must_not_filters], range_formats)
    must_query = QueryHelper::Filter.simple_bool_filter(must_filters, must_not_filters)
    should_queries = get_should_queries(es_options[:should_filters], range_formats)
    should_not_queries = get_should_queries(es_options[:should_not_filters], range_formats)
    must_query[:bool][:must] += should_queries
    must_query[:bool][:must_not] += should_not_queries
    must_query
  end

  def get_should_queries(filters, range_formats = {})
    (filters || []).collect do |should_filter|
      filter_query = apply_should_filters(should_filter, range_formats)
      QueryHelper::Filter.simple_bool_should(filter_query)
    end
  end

  def apply_should_filters(filter_hash, range_formats)
    filter_hash.collect do |field, value|
      if field == :filters
        next if value.blank?
        value.collect do |item|
          must_queries = QueryHelper::Filter.get_filter_conditions(item[:must_filters] || [], range_formats)
          must_queries += QueryHelper::Filter.get_with_all_conditions(item[:with_all_filters])
          must_not_queries = QueryHelper::Filter.get_filter_conditions(item[:must_not_filters] || [], range_formats)
          QueryHelper::Filter.simple_bool_filter(must_queries, must_not_queries)
        end
      else
        QueryHelper::Filter.build_filter_query(field, value, range_formats)
      end
    end.flatten.compact
  end

  def build_match_query(es_options)
    return unless es_options[:search_conditions].present?
    if es_options[:search_conditions].is_a?(Array)
      should_match_queries = es_options[:search_conditions].collect do |search_hash|
                              get_match_query(search_hash)
                            end
      QueryHelper::Filter.simple_bool_should(should_match_queries.compact)
    else
      get_match_query(es_options[:search_conditions])
    end
  end

  def get_match_query(search_hash)
    return if search_hash.blank? || search_hash[:search_text].blank?
    search_text = QueryHelper::EsUtils.sanitize_es_query(search_hash[:search_text])
    if search_hash[:fields].count > 1
      QueryHelper::Filter.get_multi_match_query(search_hash[:fields], search_text, operator: search_hash[:operator])
    else
      QueryHelper::Filter.get_match_query(search_hash[:fields][0], search_text, operator:   search_hash[:operator])
    end
  end

end