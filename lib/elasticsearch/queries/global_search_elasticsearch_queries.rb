class GlobalSearchElasticsearchQueries
  include QueryHelper

  DOCUMENT_TYPE_MODEL_MAPPING = {
    User.document_type => User,
    Article.document_type => Article,
    QaQuestion.document_type => QaQuestion,
    Group.document_type => Group,
    Resource.document_type => Resource,
    Topic.document_type => Topic
  }

  def search(search_content, options)
    options[:classes] = (options[:filter_view] == "topic") ? options[:classes].delete_if{|x| x != Topic} : options[:classes]
    if options[:classes].present?
      es_query = prepare_query(search_content, options)
      unpaginated_results = ChronusElasticsearch.client.search(index: options[:classes].collect(&:index_name), body: get_common_esearch_options(es_query, {}))["hits"]["hits"]
    end
    paginate_results((unpaginated_results || []), options)
  end

  def count(search_content, options)
    es_query = prepare_query(search_content, options)
    esearch_options = get_common_esearch_options(es_query, {}).except(:from, :size, :sort, :_source)
    ChronusElasticsearch.client.count(index: options[:classes].collect(&:index_name), body: esearch_options)["count"].to_i
  end

  private

  def prepare_query(search_content, options)
    fields_to_search = get_fields_to_search(options)
    es_query = build_query(search_content, fields_to_search)
    apply_filter(es_query, options)
  end

  def paginate_results(unpaginated_results, options)
    paginated_results = unpaginated_results.paginate(page: options[:page], per_page: options[:per_page])

    paginated_results.each do |result|
      klass = DOCUMENT_TYPE_MODEL_MAPPING[result["_type"]]
      result.merge!(active_record: klass.find(result["_id"].to_i))
    end

    return paginated_results
  end

  def build_query(search_content, fields_to_search)
    return {bool: {}} if search_content.blank? || fields_to_search.blank?
    search_query = QueryHelper::Filter.get_multi_match_query(fields_to_search, QueryHelper::EsUtils.sanitize_es_query(search_content), operator: "OR")
    QueryHelper::Filter.simple_bool_filter(search_query, {})
  end

  def apply_filter(es_query, options)
    filter = QueryHelper::Filter.simple_bool_filter(modify_filters(options[:with], options), {})
    es_query[:bool].merge!(filter: filter)
    return es_query
  end

  def modify_filters(must_filters, options = {})
    modified_must_filters = includes_resource_or_topic(options[:classes]) ? must_filters.reverse_merge(role_ids: []) : must_filters
    should_queries = modified_must_filters.collect{|field, value| get_should_query(field, value, options)}
    should_queries.collect{|query| QueryHelper::Filter.simple_bool_should(query) }
  end

  def get_should_query(field, value, options = {})
    # Add field names from different indices in the "fields" key
    # Add names of fields which do not exist in all the indices in the "not_exists_fields" key

    field_map = {program_id: {fields: [:program_id, 'publications.program_id', 'resource_publications.program_id'], not_exists_fields: []}, role_ids: {fields: ['roles.id', :role_ids, 'program.roles.id'], exists_fields: [] ,not_exists_fields: []}, group_status: {fields: [:group_status], not_exists_fields: [:group_status]}, state: {fields: [:state], not_exists_fields: [:state]}}
    
    mapping = field_map[field]
    mapping = get_mapping(options[:admin_view_check], mapping, field, value, options)

    queries = mapping[:fields].collect do |attribute|
      mapping_value = get_resource_for_role_ids(attribute, value, options)
      next if mapping_value.blank?
      QueryHelper::Filter.get_range_term_query(attribute, mapping_value , {}) 
    end
    queries.compact!
    
    mapping[:not_exists_fields].each do |non_existent_field|
      queries << QueryHelper::Filter.simple_bool_filter([], QueryHelper::Filter.get_exists_query(non_existent_field))
    end
    if mapping[:exists_fields].present?
      exists_queries = []
      mapping[:exists_fields].each do |existent_field|
        exists_queries << QueryHelper::Filter.simple_bool_filter( QueryHelper::Filter.get_exists_query(existent_field),[])
      end
      queries << QueryHelper::Filter.simple_bool_should(exists_queries)
    end  
    queries
  end

  def get_mapping(is_admin, mapping = {}, field, value, options)
    if field == :role_ids
      mapping = modify_mapping(mapping, options) if value.blank?  
      if !is_admin 
        mapping[:fields] << :resource_for_role_ids
        mapping[:fields] << :topic_role_ids
      else 
        mapping[:exists_fields] << 'resource_publications.program_id'
        mapping[:exists_fields] << :topic_role_ids
      end
    end
    mapping
  end

  def modify_mapping(mapping, options)
    if (options[:classes].include?(Article) || options[:classes].include?(Group))
      mapping[:exists_fields] << :role_ids 
    end
    if (options[:classes].include?(QaQuestion))
      mapping[:exists_fields] << 'program.roles.id'
    end
    mapping 
  end

  def get_fields_to_search(options)
    fields_to_search = options[:classes].collect{|klass| klass.const_get("INDEX_FIELDS")}.flatten.uniq
    fields_to_search -= ["author.name_only"] if options[:with][:role_ids].blank? && options[:classes].include?(Article)
    fields_to_search -= ["user.topic_author_name_only"] if options[:with][:role_ids].blank? && options[:classes].include?(Topic)
    return fields_to_search
  end

  def get_resource_for_role_ids(attribute, value, options = {})
    ((attribute == :resource_for_role_ids)||(attribute == :topic_role_ids)) ? (options[:current_user_role_ids].present? ? options[:current_user_role_ids] : [] ) : value
  end

  def includes_resource_or_topic(classes)
    classes.include?(Resource) || classes.include?(Topic)
  end

end