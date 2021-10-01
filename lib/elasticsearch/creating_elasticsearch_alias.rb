class CreatingElasticsearchAlias

  include ElasticsearchConstants

  def self.creating(models_list)
    ElasticsearchReindexing.start_deployment_check(models_list)
    ElasticsearchReindexing.configure_client_all_models
    puts "***Deployment ElasticSearch reindexing***"
    self.reindex_or_delete_rake(models_list, "eimport", "-v1")
    puts "***Deleting Old Elasticsearch Indexes***"
    self.reindex_or_delete_rake(models_list, "delete_indexes", "")
    self.create_alias(models_list)
    ElasticsearchReindexing.clear_deployment_check
    ElasticsearchReindexing.start_delayed_delta_indexes
  end

  def self.reindex_or_delete_rake(models_list, function_name, index_suffix)
    models_list.each do |model_name|
      self.reindex_or_delete_indexes_individually_rake(model_name, INDEX_INCLUDES_HASH[model_name], function_name, index_suffix)
    end
  end

  def self.reindex_or_delete_indexes_individually_rake(model_name, includes_list, function_name, index_suffix)
    index_name = ElasticsearchReindexing.get_index_alias_from_model(model_name)
    index_name += index_suffix unless function_name == "delete_indexes"
    model_name.constantize.includes(includes_list).send(function_name, :index_modified => index_name)
  end

  def self.create_alias(models_list)
    puts "***Creating Alias for indexes***"
    client = ElasticsearchReindexing.configure_client
    index_alias_list = ElasticsearchReindexing.flipping_indexes_list(models_list)
    index_alias_list.each do |index_alias_name|
      ElasticsearchReindexing.create_individual_alias(index_alias_name)
    end
  end
end
