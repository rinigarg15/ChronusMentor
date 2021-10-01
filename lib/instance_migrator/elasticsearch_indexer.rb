#InstanceMigrator::ElasticsearchIndexer.new("source_environment", "source_seed").reindex
module InstanceMigrator
  class ElasticsearchIndexer

    attr_accessor :source_environment, :source_seed

    def initialize(source_environment, source_seed)
      self.source_environment = source_environment
      self.source_seed = source_seed
    end

    def reindex
      models = ChronusElasticsearch.models_with_es
      import_options = {parallel_processing: true}
      models.each do |model|
        bulk_es_import(model, import_options)
      end
    end

    private
    def get_source_audit_key(id)
      "#{source_environment}_#{source_seed}_#{id}"
    end

    def bulk_es_import(model, import_options)
      import_options[:includes_list]  = ElasticsearchConstants::INDEX_INCLUDES_HASH[model.name] || []
      model.where("#{model.table_name}.source_audit_key LIKE '#{get_source_audit_key("%")}'").eimport(import_options)
    end
  end
end