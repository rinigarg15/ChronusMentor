namespace :es_indexes do
  desc "Elasticsearch reindexing during deployment"
  # For Zero Downtime Deployment
  task :reindexing => :environment do
    if ENV['MODELS']
      models_list = ENV['MODELS'].split(",")
    else
      models_list = ChronusElasticsearch.models_with_es.collect(&:name)
    end
    force_reindex = (ENV['FORCE_REINDEX'] || "false").to_boolean
    ElasticsearchReindexing.reindexing(models_list, force_reindex)
  end

  # For Zero Downtime Deployment
  task :flipping_index => :environment do
    if ENV['MODELS']
      models_list = ENV['MODELS'].split(",")
    else
      models_list = ChronusElasticsearch.models_with_es.collect(&:name)
    end
    ElasticsearchReindexing.flipping_and_deleting_indexes(models_list)
  end

  # Creating es_indexes
  task :full_indexing => :environment do
    if ENV['MODELS']
      models_list = ENV['MODELS'].split(",")
    else
      models_list = ChronusElasticsearch.models_with_es.map { |x| x.name}
    end
    force_reindex = (ENV['FORCE_REINDEX'] || "false").to_boolean
    ElasticsearchReindexing.indexing_flipping_deleting(models_list, force_reindex)
  end

  task copy_indices: :environment do
    # What's the magic here?
    # We are copying mapping and settings from primary test es index and creating a new index for this test env.
    # Then we copy the data from primary index to the new index with reindex command.
    # We also update the alias of this env to properly point to the new index.
    # GOTCHA: While the primary test es index can have -v1 in their names, the secondary es indices will not have -v1 in their names
    process_index = ENV['TEST_ENV_NUMBER'].to_i
    return if process_index == 0 || !Rails.env.test?
    if ENV['MODELS']
      models_list = ENV['MODELS'].split(",")
    else
      models_list = ChronusElasticsearch.models_with_es.map { |x| x.name}
    end
    indexes_list = ElasticsearchReindexing.flipping_indexes_list(models_list)
    indexes_list.each do |index_name|
      index_alias_name = index_name[0..-(ENV['TEST_ENV_NUMBER'].size + 1)]
      index_name_modified = "#{index_alias_name}#{process_index}-v0"
      settings = ChronusElasticsearch.client.indices.get_settings(index: index_alias_name).values.first["settings"]["index"]
      settings.slice!("refresh_interval", "number_of_shards", "analysis", "max_result_window", "number_of_replicas")
      mapping = ChronusElasticsearch.client.indices.get_mapping(index: index_alias_name).values.first

      ["v0", "v1"].each { |v| ChronusElasticsearch.client.indices.delete(index: "#{index_name}-#{v}", ignore: 404) }
      ChronusElasticsearch.client.indices.create(index: index_name_modified,
        body: { "settings" => { "index" => settings } }.merge!(mapping.merge!("aliases" => { index_name => {} } )))
      ChronusElasticsearch.client.reindex(
        body: { source: { index: index_alias_name }, dest: { index: index_name_modified } } )
    end
  end

  # Example: bundle exec rake es_indexes:create_es_snapshot
  desc "Take manual snapshot of aws es domain"
  task create_es_snapshot: :environment do
    EsSnapshot.create
  end

  # Example: bundle exec rake es_indexes:restore_es_snapshot SNAPSHOT_NAME="snapshot-1"
  desc "Restore the snapshot from s3 to the es domain"
  task restore_es_snapshot: :environment do
    EsSnapshot.restore(ENV['SNAPSHOT_NAME'])
  end

  # Example: bundle exec rake es_indexes:check_es_snapshot_status SNAPSHOT_NAME="snapshot-1"
  desc "Check the status of the snapshot"
  task check_es_snapshot_status: :environment do
    puts EsSnapshot.check_status(ENV['SNAPSHOT_NAME'])
  end

  # bundle exec rake es_indexes:es_document_count_checker COUNT_ONLY=true FOR_DEPLOYMENT=true
  desc "Check if there any count mismatch betweeen model records and elasticsearch indexed documents"
  task :es_document_count_checker => :environment do
    start_time = Time.now

    if ENV['MODELS']
      models_list = ENV['MODELS'].split(",")
    else
      models_list = ChronusElasticsearch.models_with_es.collect(&:name)
    end
    models_with_index_name = {}
    models_list.each do |model_name|
      models_with_index_name[model_name] = model_name.constantize.index_name
    end
    options = {count_only: (ENV['COUNT_ONLY'] || 'false').to_boolean, for_deployment: (ENV['FOR_DEPLOYMENT'] || 'false').to_boolean}
    mismatched_models = EsDocumentCountChecker.check_and_fix_document_counts(models_with_index_name, options)
    puts "Es document count mismated models: #{mismatched_models}" if mismatched_models.any?
    puts "Time taken: #{Time.now - start_time}"
  end
end