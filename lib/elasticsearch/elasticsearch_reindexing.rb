class ElasticsearchReindexing
  include ElasticsearchConstants

  def self.indexing_flipping_deleting(models_list, force_reindex = false)
    self.reindexing(models_list, force_reindex)
    self.flipping_and_deleting_indexes(models_list)
  end

  def self.get_valid_index_name(model_name)
    model_name.underscore.tr("/", "_")
  end

  def self.reindexing(models_list, force_reindex = false)
    self.clear_deployment_check(models_list) if force_reindex.present?
    self.start_deployment_check(models_list)
    self.reindexing_models(models_list)
  end

  def self.flipping_and_deleting_indexes(models_list)
    self.verify_es_document_count!(models_list)
    self.flip_indexes(models_list)
    self.clear_deployment_check(models_list)
    self.start_delayed_delta_indexes
    self.delete_old_indexes(models_list)
  end

  def self.verify_es_document_count!(model_lists)
    puts "***Verifying elasticsearch document counts***"
    populate_models_with_index_name_and_new_index_list(model_lists)
    mismatched_models = EsDocumentCountChecker.check_and_fix_document_counts(@models_with_index_name, count_only: true, for_deployment: true, new_index_list: @new_index_list)
    if mismatched_models.present?
      exception_message = "Elasticsearch document count mismatched models: #{mismatched_models}"
      Airbrake.notify(exception_message)
      raise exception_message
    end
  end

  def self.start_deployment_check(model_lists)
    reindexing_models = current_indexing_models(model_lists)
    raise "Reindexing for #{reindexing_models.join(COMMON_SEPARATOR)} are already in progress" if reindexing_models.any?
    model_lists.each do |model_name|
      ElasticsearchDeploymentSettings.create!(reindexing_model: model_name)
    end
  end

  def self.clear_deployment_check(model_lists)
    reindexing_models = current_indexing_models(model_lists)
    return if reindexing_models.empty?
    ElasticsearchDeploymentSettings.where(:reindexing_model.in => reindexing_models).destroy_all
  end

  def self.current_indexing_models(model_lists)
    (ElasticsearchDeploymentSettings.pluck(:reindexing_model) & model_lists)
  end

  def self.get_reindexing_model(model_name)
    ElasticsearchDeploymentSettings.find_by(reindexing_model: model_name)
  end

  def self.reindexing_models(model_lists)
    puts "***Deployment ElasticSearch reindexing***"
    @models_with_index_name = {}
    @new_index_list = []
    self.reindex_or_delete(model_lists, "eimport")
  end

  def self.configure_client_all_models
    Elasticsearch::Model.client = self.configure_client
  end

  def self.configure_client
    if Rails.env.test? || Rails.env.development?
      Elasticsearch::Client.new log: false, hosts: [ES_HOST_OPTIONS]
    else
      Elasticsearch::Client.new log: false, url: AWS_ES_OPTIONS[:url] do |f|
        f.request :aws_signers_v4,
          credentials: Aws::InstanceProfileCredentials.new,
          service_name: 'es',
          region: AWS_ES_OPTIONS[:es_region]
      end
    end
  end

  def self.reindex_or_delete(model_lists, function_name)
    self.configure_client_all_models
    model_lists.each do |model_name|
      self.reindex_or_delete_indexes_individually(model_name, INDEX_INCLUDES_HASH[model_name], function_name)
    end
  end

  def self.reindex_or_delete_indexes_individually(model_name, includes_list = [], function_name)
    if self.is_existing_index?(model_name)
      index_alias_name = self.get_index_alias_from_model(model_name)
      index_name_hash = self.get_old_and_new_indexname(index_alias_name)
      index_name = index_name_hash["new_index"]
      if (function_name == "eimport")
        @models_with_index_name[model_name] = index_name
        model_name.constantize.send(function_name, :index_modified => index_name, parallel_processing: true, includes_list: includes_list)
      elsif self.get_list_of_indexes.include? index_name
        model_name.constantize.send(function_name, :index_modified => index_name)
      end
    else
      self.create_index_and_alias(model_name, includes_list, function_name)
    end
  end

  def self.create_index_and_alias(model_name, includes_list = [], function_name)
    index_alias_name = self.get_index_alias_from_model(model_name)
    index_name = index_alias_name + "-v1"
    @models_with_index_name[model_name] = index_name
    @new_index_list << index_name
    model_name.constantize.send(function_name, :index_modified => index_name, parallel_processing: true, includes_list: includes_list)
    self.create_individual_alias(index_alias_name)
  end

  def self.get_index_alias_from_model(model_name)
    self.get_valid_index_name(model_name)+"-"+"#{ES_INDEX_SUFFIX}"
  end

  def self.flip_indexes(model_lists)
    puts "***flipping indexes***"
    indexes_list = self.flipping_indexes_list(model_lists)
    indexes_list.each do |index_name|
      index_name_hash = self.get_old_and_new_indexname(index_name)
      if self.get_list_of_indexes.include? index_name_hash["new_index"]
        self.atomic_update_alias(index_name_hash["old_index"], index_name_hash["new_index"], index_name)
      end
    end
  end

  def self.get_old_and_new_indexname(index_name)
    indexes_details = self.get_index_alias_details(index_name)
    if indexes_details[index_name + "-v0"]
      old_index = index_name + "-v0"
      new_index = index_name + "-v1"
    else
      old_index = index_name + "-v1"
      new_index = index_name + "-v0"
    end
    { "old_index" => old_index, "new_index" => new_index}
  end

  def self.get_index_alias_details(index_alias_name)
    client = self.configure_client
    client.indices.get_alias name: index_alias_name
  end

  def self.get_index_from_alias(index_alias_name)
    self.get_index_alias_details(index_alias_name).keys[0]
  end

  def self.get_index_from_model(model_name)
    self.get_index_alias_details(self.get_index_alias_from_model(model_name)).keys[0]
  end

  def self.exists_alias?(model_name)
    client = self.configure_client
    client.indices.exists_alias? name: self.get_index_alias_from_model(model_name)
  end

  def self.start_delayed_delta_indexes
    puts "***Start delayed_job for new index***"
    list_delta_jobs = self.get_delta_delayed_jobs
    list_delta_jobs.each do |d_job|
      d_job.run_at = d_job.run_at - DelayedEsDocument::DUPLICATE_JOB_WAIT_TIME
      d_job.save!
    end
  end

  def self.delete_old_indexes(model_lists)
    puts "***Deleting Old Elasticsearch Indexes***"
    self.reindex_or_delete(model_lists, "delete_indexes")
  end

  # Gives complete lists of indexes running 
  def self.get_list_of_indexes
    client = self.configure_client
    client.indices.get_mapping.keys
  end

  # Gives complete list of model with indexes running
  def self.get_index_list
    models_list = self.get_list_of_indexes.map { |x| x[0...-3]}
    models_list.uniq
  end

  def self.is_existing_index?(model_name)
    index_name = self.get_index_alias_from_model(model_name)
    self.get_index_list.include?(index_name)
  end

  def self.get_delta_delayed_jobs
    Delayed::Job.where(queue: DjQueues::ES_DELTA).order(:run_at)
  end

  def self.flipping_indexes_list(model_lists)
    self.valid_indexes_hash(model_lists).values
  end

  def self.valid_indexes_hash(model_lists)
    model_lists.inject({}) do |hsh, model_name|
      hsh[model_name] = self.get_valid_index_name(model_name) + "-" + "#{ES_INDEX_SUFFIX}"
      hsh
    end
  end

  def self.atomic_update_alias(old_index, new_index, alias_name)
    client = self.configure_client
    client.indices.update_aliases body: {
      actions: [
        { remove: { index: old_index, alias: alias_name} },
        { add:    { index: new_index, alias: alias_name } }
      ]
    }
  end

  def self.create_individual_alias(index_alias_name, options={})
    client = self.configure_client
    index_name = index_alias_name + "-v1"
    if options[:index_name] 
      index_name = options[:index_name]
    end
    client.indices.update_aliases body: {
      actions: [
        { add: { index: index_name, alias: index_alias_name } }
      ]
    }
  end

  def self.populate_models_with_index_name_and_new_index_list(model_lists)
    @models_with_index_name ||= {}
    @new_index_list ||= []
    return if @models_with_index_name.present?

    reindexing_models = self.current_indexing_models(model_lists)
    self.valid_indexes_hash(model_lists).each do |model_name, index_name|
      self.set_index_for_model_and_new_index(model_name, index_name, reindexing_models)
    end
  end

  def self.set_index_for_model_and_new_index(model_name, index_name, reindexing_models)
    return unless reindexing_models.include?(model_name)

    current_indexes_list = self.get_list_of_indexes
    index_name_hash = self.get_old_and_new_indexname(index_name)
    new_index_name, is_new_index = self.get_model_index_and_new_index(current_indexes_list, index_name_hash)
    @models_with_index_name[model_name] = new_index_name
    @new_index_list << new_index_name if is_new_index
  end

  def self.get_model_index_and_new_index(current_indexes_list, index_name_hash)
    if current_indexes_list.include?(index_name_hash["new_index"])
      [index_name_hash["new_index"], !current_indexes_list.include?(index_name_hash["old_index"])]
    elsif current_indexes_list.include?(index_name_hash["old_index"])
      # If new index is not available in the available list of indexes and old index is the only index present for the model and it is currently reindexing then old index is the new index.
      [index_name_hash["old_index"], true]
    end
  end
end
