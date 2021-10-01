class ElasticsearchIndexerJob < Struct.new(:klass, :id, :method, :partial_indices, :includes_list)
  def perform
    return if ChronusElasticsearch.skip_es_index
    begin
      ChronusElasticsearch.reindex_list << klass if Rails.env.test?
      index_objects(klass, id, method, partial_indices, includes_list)
      JobLog.log_info "**#{method} for #{klass.name} with id #{id} SUCCESSFUL**"
    rescue => e
      JobLog.log_info "**#{method} for #{klass.name} with id #{id} FAILED with exception '#{e}'**"
      Airbrake.notify(e) unless [ActiveRecord::RecordNotFound, Elasticsearch::Transport::Transport::Errors::NotFound].include?(e.class)
    end
  end

  private

  def index_objects(klass, id, method, partial_indices, includes_list)
    case method
    when :delete_es_document
      invoke_delete_document(klass, id)
    when :bulk_update_es_documents
      bulk_update_es_documents(klass, id)
    when :bulk_delete_es_documents
      invoke_bulk_api(klass, build_body_for_bulk_delete(id))
    when :bulk_index_es_documents
      bulk_index_es_documents(klass, id)
    when :bulk_partial_update_es_documents
      bulk_update_es_documents(klass, id, partial_indices, includes_list)
    else
      index_or_delete_document(klass, id, method)
    end
  end

  def index_or_delete_document(klass, id, method)
    klass_with_scope = get_klass_with_scope(klass)
    obj = klass_with_scope.find_by(id: id)
    if obj.present?
      obj.send(method)
    else
      invoke_delete_document(klass, id, true)
    end
  end

  def bulk_update_es_documents(klass, id, partial_indices = nil, includes_list = [])
    objects = if partial_indices.present?
                bulk_partial_update_es_documents(klass, id, partial_indices, includes_list)
              else
                bulk_index_es_documents(klass, id)
              end
    ids_to_be_deleted = id - objects.collect(&:id)
    invoke_bulk_api(klass, build_body_for_bulk_delete(ids_to_be_deleted))
  end

  def bulk_partial_update_es_documents(klass, id, partial_indices, includes_list)
    klass_with_scope = get_klass_with_scope(klass)
    new_objects = klass_with_scope.where(id: id).includes(includes_list)
    invoke_bulk_api(klass, build_body_for_bulk_partial_update(new_objects, partial_indices))
    new_objects
  end

  def bulk_index_es_documents(klass, id)
    klass_with_scope = get_klass_with_scope(klass)
    new_objects = klass_with_scope.where(id: id).includes(ElasticsearchConstants::INDEX_INCLUDES_HASH[klass.to_s])
    invoke_bulk_api(klass, build_body_for_bulk_insert(new_objects))
    new_objects
  end

  def build_body_for_bulk_partial_update(new_objects, partial_indices)
    new_objects.collect do |new_object|
      {update: {_id: new_object.id, data: {doc: new_object.as_partial_indexed_json(partial_indices)}}}
    end
  end

  def build_body_for_bulk_insert(new_objects)
    new_objects.collect { |object| {index: {_id: object.id, data: object.as_indexed_json }}}
  end

  def build_body_for_bulk_delete(object_ids)
    object_ids.compact.collect { |id| {delete: {_id: id } } }
  end

  def invoke_bulk_api(klass, body)
    return unless body.present?
    Elasticsearch::Model.client.bulk index: klass.index_name, type: klass.document_type, body: body
  end

  def invoke_delete_document(klass, id, ignore_404 = false)
    client_hash = {index: klass.index_name, type: klass.document_type, id: id}
    client_hash.merge!(ignore: '404') if ignore_404.present?
    Elasticsearch::Model.client.delete client_hash
  end

  def get_klass_with_scope(klass)
    return klass unless klass.const_defined?("ES_SCOPE")
    klass.__send__(klass.const_get("ES_SCOPE"))
  end

end