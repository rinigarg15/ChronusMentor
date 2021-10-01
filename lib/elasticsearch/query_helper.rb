module QueryHelper
  MAX_HITS = 1000000
  DEFAULT_NESTED_SCORE_MODE = "none"

  module Aggregation
    def self.date_aggregation(start_date_id, end_date_id)
      {date_aggregation:
        {histogram:
          {field: "date_id",
          interval: 1,
          keyed: true,
          min_doc_count: 0,
          extended_bounds: {min: start_date_id,
                            max: end_date_id
                           }
          }
        }
      }
    end
  end

  module Filter
    def self.simple_bool_filter(must, must_not)
      bool_hsh = {}
      bool_hsh[:must] = must.presence || []
      bool_hsh[:must_not] = must_not.presence || []

      { bool: bool_hsh }
    end

    def self.simple_bool_should(should)
      { bool: { should: should } }
    end

    def self.get_filter_conditions(conditions, range_formats = {})
      (conditions || {}).collect do |field, value|
        build_filter_query(field, value, range_formats)
      end.flatten
    end

    def self.build_filter_query(field, value, range_formats)
      if value.is_a?(Range) || value.is_a?(Hash)
        get_range_query(field, value, range_formats)
      elsif field == :exists_query
        get_exists_query(value)
      elsif field == :multi_exists_query
        get_multi_exists_query(value)
      else
        get_term_query(field, value)
      end
    end

    def self.get_range_term_query(field, value, range_formats = {})
      if value.is_a?(Range)
        get_range_query(field, value, range_formats)
      else
        get_term_query(field, value)
      end
    end

    def self.get_with_all_conditions(conditions)
      (conditions || []).collect do |field, values|
        values.collect do |value|
          get_range_term_query(field, value)
        end
      end.flatten
    end

    def self.get_sort_conditions(sort_fields_with_order)
      (sort_fields_with_order || {}).collect do |field, order|
        next if field.blank?
        if field.to_s == "_score"
          {field => order}
        else
          {field => {order: order, missing: get_missing_order(order)}}
        end
      end.compact
    end

    def self.get_match_query(field, value, options = {})
      default_options = {operator: (options[:operator].presence || "AND")}
      default_options[:boost] = options[:boost] if options[:boost].present?
      {
        match: {
          field => {
            query: value
          }.merge(default_options)
        }
      }
    end

    def self.get_multi_match_query(fields, value, options = {})
      default_options = {operator: (options[:operator] || "AND")}
      default_options[:type] = options[:type] if options[:type].present?
      {
        multi_match: {
          query: value,
          fields: fields
        }.merge(default_options)
      }
    end

    def self.get_range_query(field, value, range_formats = {})
      range_options = {}
      range_options[:format] = range_formats[field] if range_formats && range_formats[field].present?
      range = {}
      if value.is_a?(Range)
        range[:gte] = value.begin unless value.begin == Float::INFINITY
        range[:lte] = value.end unless value.end == Float::INFINITY
      elsif value.is_a?(Hash)
        range.merge!(value)
      end
      { range: { field => range.merge(range_options)} }
    end

    def self.get_term_query(field, value)
      keyword = value.is_a?(Array) ? :terms : :term
      return {
        keyword => {
          field => value
        }
      }
    end

    def self.get_constant_score_query(query, options = {})
      default_options = {}
      default_options[:boost] = options[:boost] if options[:boost]
      {
        constant_score: {
          filter: query
        }.merge(default_options)
      }
    end

    def self.get_match_phrase_prefix_query(field, value, options = {})
      default_options = {slop: (options[:slop] || 0)}
      {
        match_phrase_prefix: {
          field => {
            query: value
          }.merge(default_options)
        }
      }
    end

    def self.get_match_phrase_query(field, value, options = {})
      default_options = {slop: (options[:slop] || 0)}
      {
        match_phrase: {
          field => {
            query: value
          }.merge(default_options)
        }
      }
    end

    def self.get_geo_distance_query(point, distance, field_name)
      {
        geo_distance: {
          distance: distance,
          field_name => {
            lon: point[0],
            lat: point[1]
          }
        }
      }
    end

    def self.get_exists_query(field)
     {
       exists: {
        field: field
       }
     }
    end

    def self.get_multi_exists_query(fields)
      Array(fields).collect do |field|
        get_exists_query(field)
      end
    end

    def self.get_nested_query(path, query, include_inner_hits = false)
      options = {
        path: path,
        score_mode: DEFAULT_NESTED_SCORE_MODE,
        query: query
      }
      options.merge!(inner_hits: { size: 0 } ) if include_inner_hits
      { nested: options }
    end

    def self.get_missing_order(sort_order)
      return "_last" if sort_order == "desc"
      return "_first"
    end
  end

  def get_boosted_search_query(search_query, options = {})
    search_queries = []
    options[:fields].each do |field|
      match_query = QueryHelper::Filter.get_multi_match_query(field, QueryHelper::EsUtils.sanitize_es_query(search_query), operator: "OR")
      search_queries << QueryHelper::Filter.get_constant_score_query(match_query, boost: options[:boost_hash][field])
    end
    must_not = options[:must_not_filter].present? ? QueryHelper::Filter.get_filter_conditions(options[:must_not_filter]) : {}
    search_queries.present? ? QueryHelper::Filter.simple_bool_filter(QueryHelper::Filter.simple_bool_should(search_queries), must_not) : options[:must_not_filter].present? ? {bool: { must_not: must_not}} : {bool: {}}
  end

  def common_chronus_elasticsearch_query_executor(query, default_options = {})
    default_options[:source] = false
    self.chronus_elasticsearch(get_common_esearch_options(query, default_options))['hits']['hits'].map{ |h| h["_id"].to_i }
  end

  def common_esearch_query_executor_extract_source(query, default_options = {})
    common_esearch_query_executor(query, default_options).results
  end

  def common_esearch_query_executor_collect_records(query, default_options = {})
    includes_list = default_options.delete(:includes) || []
    common_esearch_query_executor(query, default_options).records(includes: includes_list)
  end

  def common_esearch_query_executor(query, default_options = {})
    self.esearch(get_common_esearch_options(query, default_options))
  end

  def common_esearch_query_executor_with_aggregations(query, aggs, default_options = {})
    options = get_common_esearch_options(query, default_options).merge!(aggs: aggs)
    options.delete(:from)
    self.esearch(options)
  end

  def common_chronus_elasticsearch_nested_query_executor(path, query, default_options = {})
    results = self.chronus_elasticsearch(get_common_esearch_options(query, default_options))['hits']['hits']
    results.inject({}) do |inner_hits_map, result|
      inner_hits_map[result['_id'].to_i] = result['inner_hits'][path]['hits']['total']
      inner_hits_map
    end
  end

  def get_common_esearch_options(query, default_options = {})
    options = { size: MAX_HITS, source: false, sort: [] }.merge!(default_options)
    {
      query: query,
      from: page_to_from(options.delete(:page), options[:size]),
      size: options[:size].to_i,
      sort: options[:sort],
      _source: options[:source]
    }
  end

  def page_to_from(page, per_page)
    return 0 if page.blank?
    return (page.to_i - 1) * per_page.to_i
  end

  def get_total_response_hits(query)
    self.ecount({
      query: query
    })["count"]
  end

  def common_esearch_aggregation_query_executor(additions_per_day, removals_per_day, filter_hash={}, size=0)
    self.esearch(
      filter_hash.merge!(
      {
        aggs:
        {
          additions_per_day: additions_per_day,
          removals_per_day: removals_per_day
        },
        size: size
      })
    )
  end

  module EsUtils
    def self.sanitize_es_query(str)
      # Escape special characters
      escaped_characters = Regexp.escape('\\+-&|!(){}[]^~*?:\/')
      str.gsub(/([#{escaped_characters}])/, '\\\\\1')
    end

    #special query sanitizer for url analyzer. hyphen in the url_analyzer will be treated as underscore so hyphen need not to be sanitized.
    def self.sanitize_es_query_for_url_analyzer(str)
      # Escape special characters
      escaped_characters = Regexp.escape('\\+&|!(){}[]^~*?:\/')
      str.gsub(/([#{escaped_characters}])/, '\\\\\1')
    end
  end
end