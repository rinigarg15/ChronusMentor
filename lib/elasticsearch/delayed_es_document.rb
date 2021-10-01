class DelayedEsDocument

  DUPLICATE_JOB_WAIT_TIME = 12.hours
  ID_SLICE_SIZE = 1000

  BULK_METHODS = [:bulk_update_es_documents, :bulk_delete_es_documents, :bulk_index_es_documents, :bulk_partial_update_es_documents]

  def self.delayed_index_es_document(class_name, id)
    delayed_indexing(class_name, id, :index_es_document)
  end

  def self.delayed_update_es_document(class_name, id)
    delayed_indexing(class_name, id, :update_es_document)
  end

  def self.delayed_bulk_update_es_documents(class_name, ids)
    delayed_indexing(class_name, ids, :bulk_update_es_documents)
  end

  def self.delayed_delete_es_document(class_name, id)
    delayed_indexing(class_name, id, :delete_es_document)
  end

  def self.delayed_bulk_delete_es_documents(class_name, id)
    delayed_indexing(class_name, id, :bulk_delete_es_documents)
  end

  def self.delayed_bulk_index_es_documents(class_name, id)
    delayed_indexing(class_name, id, :bulk_index_es_documents)
  end

  def self.delayed_bulk_partial_update_es_documents(class_name, id, partial_indices, includes_list = [])
    delayed_indexing(class_name, id, :bulk_partial_update_es_documents, partial_indices, includes_list)
  end

  def self.do_delta_indexing(klass, objects, column)
    if objects.is_a?(::ActiveRecord::Relation) || objects.is_a?(Array)
      ids = objects.collect(&column).uniq
      delayed_bulk_update_es_documents(klass, ids)
    else
      raise "objects must be an ActiveRecord Relation/Array, so that delta indexing for update_all/delete_all will be taken care."
    end
  end

  def self.arel_delta_indexer(klass, objects, action)
    if klass.respond_to?(:__elasticsearch__)
      ids = (objects || []).collect(&:id)
      case action
      when :update
        delayed_bulk_update_es_documents(klass, ids)
      when :delete
        delayed_bulk_delete_es_documents(klass, ids)
      end
    end
    klass.es_reindex(objects) if klass.respond_to? :es_reindex
  end

  ############################################################################################################################################################
  # Usage:
  # auto_reindex => compute the objects which needs to be indexed and create dj entries for the respective objects.
  # skip_dj_creation => Setting this true will skip the dj entries creation. This option can be useful when skip_es_delta_indexing is used
  #  inside Parallel block.
  ##############################################################################################################################################################
  def self.skip_es_delta_indexing(options = {}, &block)
    exception = nil
    begin
      @skip_es_delta_indexing = true
      @auto_reindex = !!options[:auto_reindex]
      @es_reindex_list = {}
      result = yield
    rescue => ex
      exception = ex
    ensure
      @skip_es_delta_indexing = false
      create_delayed_indexes_from_hash(@es_reindex_list) if @auto_reindex && !options[:skip_dj_creation]
      @auto_reindex = false
      # In auto_reindex case, if exception happened inside a transaction it will be rolled back or else we will reindex for objects which are persisted.
      raise exception if exception

      return result, @es_reindex_list
    end
  end

  def self.create_delayed_indexes_from_hash(es_reindex_list = {})
    es_reindex_list.each {|klass, ids| DelayedEsDocument.delayed_bulk_update_es_documents(klass, ids)}
  end

  private

  def self.is_model_reindexing?(klass)
    ElasticsearchReindexing.get_reindexing_model(ChronusElasticsearch.get_indexed_class(klass).name).present?
  end

  def self.es_index_present?(klass)
    ElasticsearchReindexing.exists_alias?(ChronusElasticsearch.get_indexed_class(klass).name)
  end

  def self.common_es_reindex(klass, id, method_name, partial_indices, includes_list)
    DJUtils.enqueue_unless_duplicates(queue: DjQueues::ES_DELTA).create_elasticsearch_indexer_job(klass, id, method_name, partial_indices, includes_list)
    DJUtils.enqueue_unless_duplicates(queue: DjQueues::AWS_ELASTICSEARCH_SERVICE).create_elasticsearch_indexer_job(klass, id, method_name, partial_indices, includes_list)
  end

  def self.is_skip_es_delta_indexing?(klass, id)
    return false unless @skip_es_delta_indexing
    return true unless @auto_reindex
    @es_reindex_list[klass] ||= []
    @es_reindex_list[klass] += Array(id)
    return true
  end

  def self.delayed_indexing(klass, id, method_name, partial_indices=nil, includes_list=[])
    return if id.blank? || is_skip_es_delta_indexing?(klass, id)

    if BULK_METHODS.include?(method_name)
      Array(id).uniq.each_slice(ID_SLICE_SIZE) { |sliced_ids| enqueue_es_djs(klass, sliced_ids, method_name, partial_indices, includes_list) }
    else
      enqueue_es_djs(klass, id, method_name, partial_indices, includes_list)
    end
  end

  def self.enqueue_es_djs(klass, id, method_name, partial_indices, includes_list)
    if es_index_present?(klass)
      common_es_reindex(klass, id, method_name, partial_indices, includes_list)
      if is_model_reindexing?(klass)
        DJUtils.enqueue_unless_duplicates(run_at: (Time.now + DUPLICATE_JOB_WAIT_TIME), queue: DjQueues::ES_DELTA).create_elasticsearch_indexer_job(klass, id, method_name, partial_indices, includes_list)
      end
    end
  end

end
