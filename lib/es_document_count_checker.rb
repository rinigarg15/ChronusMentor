module EsDocumentCountChecker
  class << self
    SCROLL_LIMIT = "5m"
    BATCH_SIZE = 100
    PER_SCROLL_SIZE = 10000
    THRESOLD_PERCENT = 2.0
    THRESOLD_LIMIT = 1000
    DELTA_RECORDS_WINDOW = ->(model_name){ ElasticsearchDeploymentSettings.find_by(reindexing_model: model_name).try(:index_start_time) || 1.hour.ago.utc }

    THRESOLD = ->(model_count){ [THRESOLD_LIMIT, ((THRESOLD_PERCENT * model_count.to_f) / 100.0).ceil].min }

    def check_and_fix_document_counts(models_with_index_name, options = {})
      @mismatched_models = []

      models_with_index_name.each do |model_name, index_name|
        model = model_name.constantize
        scope = model.const_defined?("ES_SCOPE") && model.const_get("ES_SCOPE")
        @indexed_ids = []
        @record_ids = []
        if is_count_mismatch?(model, scope, index_name, options)
          # During deployment, we will fix the mismatch count only for new index and others fails with exception.
          fix_count_mismatch(model, scope, index_name, options)
          @mismatched_models << model_name unless is_new_index?(index_name, options)
        end
      end
      @mismatched_models
    end

    # Check if there is a count mismatch between elasticsearch and model records by checking the below cases
    # elasticsearch documents is not equal to db model records count
    # if there is any dj entries in queue for the model then include it in elasticsearch documents count and compare it with model records count.
    # if the mismatch exceeds thresold then raise exception. Thresold will be considered only for cron.

    def is_count_mismatch?(model, scope, index_name = model.index_name, options = {})
      refresh_es_index(index_name)
      model_records_count = get_model_with_scope(model, scope).count
      es_documents_count = (get_es_client.count index: index_name).try(:[], "count")
      is_mismatch = (es_documents_count != model_records_count)
      is_mismatch &&= check_mismatch_by_load_ids(model, scope, options)
      check_mismatch_untolerable!(model.name) if is_mismatch && !options[:for_deployment]
      return is_mismatch
    end

    def get_ids_from_djs(model)
      ApplicationEagerLoader.load # To load the descendants
      model_names = [model.name] + model.descendants.map(&:name)
      sql_query = ["index_es_document", "bulk_index_es_documents"].map do |method_name|
        model_names.map { |model_name| "handler LIKE '%#{model_name}%#{method_name}%'" }.join(" OR ")
      end.join(" OR ")

      handlers = Delayed::Job.where(queue: DjQueues::ES_DELTA).where(sql_query).pluck(:handler)
      handlers.map { |handler| YAML.load_dj(handler) }.map(&:id).flatten.uniq
    end

    def check_mismatch_untolerable!(model_name)
      es_documents_count = @indexed_ids.size
      model_records_count = @record_ids.size
      is_mismatch = ((es_documents_count + THRESOLD.call(model_records_count)) < model_records_count)
      if is_mismatch
        exception_message = "Elasticsearch Document count mismatch is found for #{model_name}: #{model_records_count - es_documents_count}"
        Airbrake.notify(exception_message)
        raise exception_message
      end
    end

    def check_mismatch_by_load_ids(model, scope, options = {})
      @indexed_ids = collect_indexed_ids(model)
      @record_ids = get_model_with_scope(model, scope).pluck(:id)
      @indexed_ids += get_ids_from_djs(model)
      is_mismatch = (@record_ids - @indexed_ids).any?
      # To prevent deployment failure if there is some documents din't get deleted.
      return is_mismatch if options[:for_deployment]
      is_mismatch ||= (@indexed_ids - @record_ids).any?
    end

    def fix_count_mismatch(model, scope, index_name, options = {})
      return if (!(is_new_index = is_new_index?(index_name, options)) && options[:count_only].present?)
      if !options[:for_deployment] && skip_index_checker?(model.name)
        puts "Skipping Elasticsearch Index checker for model #{model.name}"
        return
      end
      puts "Fixing count for #{model.name}"
      if is_new_index && options[:for_deployment]
        # For new indexes, records created during elasticsearch indexing won't create delta indexes.
        is_mismatch = check_mismatch_after_delta_exclusion(model, scope)
        return if is_mismatch
      end
      if (to_add = (@record_ids - @indexed_ids)).any?
        puts "Adding index for ids: #{to_add}"
        # es documents to be created
        create_or_delete_es_documents(model, to_add, :add)
      elsif (to_delete = (@indexed_ids - @record_ids)).any?
        puts "Removing index for ids: #{to_delete}"
        # es documents to be deleted
        create_or_delete_es_documents(model, to_delete, :delete)
      end
    end

    private

    def is_new_index?(index_name, options)
      (options[:new_index_list] || []).include?(index_name)
    end

    def check_mismatch_after_delta_exclusion(model, scope)
      model_name = ChronusElasticsearch.get_indexed_class(model).name
      if model.column_names.include?("created_at")
        delta_record_ids = get_model_with_scope(model, scope).where("#{model.table_name}.created_at > ?", DELTA_RECORDS_WINDOW.call(model_name)).pluck(:id)
      end
      is_mismatch = (@record_ids - @indexed_ids - (delta_record_ids || [])).any?
      if is_mismatch
        @mismatched_models << model_name
        return true
      end
      return false
    end

    def refresh_es_index(index_name)
      get_es_client.indices.refresh index: index_name
    end

    def collect_indexed_ids(model)
      indexed_ids = []
      response = get_es_client.search({index: model.index_name, type:  model.document_type, scroll: SCROLL_LIMIT, sort: ['_doc'], size: PER_SCROLL_SIZE, body: {} })
      indexed_ids += response['hits']['hits'].map{ |h| h["_id"].to_i }
      while response['hits']['hits'].any? do
        response = get_es_client.scroll({ scroll_id: response['_scroll_id'], scroll: SCROLL_LIMIT })
        indexed_ids += response['hits']['hits'].map{ |h| h["_id"].to_i }
      end
      indexed_ids
    end

    def get_es_client
      @es_client ||= Elasticsearch::Model.client
    end

    def get_model_with_scope(model, scope)
      (scope.present? ? model.__send__(scope) : model)
    end

    def create_or_delete_es_documents(model, ids, action)
      ids.each_slice(BATCH_SIZE) do |batch_ids|
        case action
        when :add
          batch_ids.each { |id| DelayedEsDocument.delayed_index_es_document(model, id)}
        when :delete
          batch_ids -= model.where(id: batch_ids).pluck(:id)
          DelayedEsDocument.delayed_bulk_delete_es_documents(model, batch_ids)
        end
      end
    end

    def skip_index_checker?(model_name)
      ElasticsearchReindexing.get_reindexing_model(model_name).present?
    end
  end
end