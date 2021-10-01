class ChronusElasticsearch
  class << self
    attr_accessor :client, :skip_es_index, :reindex_list

    def models_with_es
      ApplicationEagerLoader.load
      all_models = ActiveRecord::Base.descendants
      models_with_es = []

      all_models.each do |klass|
        models_with_es << get_indexed_class(klass) if klass.respond_to?(:__elasticsearch__)
      end
      return models_with_es.uniq
    end

    def create_all_indexes
      models_list = models_with_es.collect(&:name)
      ElasticsearchReindexing.indexing_flipping_deleting(models_list)
    end

    def get_indexed_class(klass)
      (klass.base_class.respond_to?(:__elasticsearch__) ? klass.base_class : klass)
    end
  end
end