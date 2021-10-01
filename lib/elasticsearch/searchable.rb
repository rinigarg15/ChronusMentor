module Searchable
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model
    index_name "#{ElasticsearchReindexing.get_valid_index_name(self.name)}-#{ES_INDEX_SUFFIX}"

    after_create :zdt_delayed_index_es_document
    after_update :zdt_delayed_update_es_document
    after_destroy :zdt_delayed_delete_es_document
  end

  module ClassMethods

    def esearch(options)
      self.__elasticsearch__.search(options)
    end

    def ecount(options)
      # Elasticsearch::Model::Proxy doesn't provide an interface for 'count'.
      # So we're using Elasticsearch::Model.client instead of self.__elasticsearch__
      Elasticsearch::Model.client.count(index: self.index_name, body: options)
    end

    def bulk_es_index(options = {})
      if(options[:force])
        self.__elasticsearch__.create_index!(index: options[:index], force: true)
      end
      named_scope = options.delete(:scope)
      scope = named_scope ? self.__send__(named_scope) : self
      ids = scope.order(:id).pluck(:id)
      model_name = ChronusElasticsearch.get_indexed_class(self).name
      currently_indexing_model = ElasticsearchDeploymentSettings.find_by(reindexing_model: model_name)
      currently_indexing_model.update_attributes!(index_start_time: Time.now.utc) if currently_indexing_model.present?
      return if ids.empty?
      processes = (Class.new.extend(Parallel::ProcessorCount).processor_count)/2
      ranges = []
      ids.each_slice((ids.size.to_f/processes).ceil).to_a.each {|r| ranges << [r.first, r.last]}
      Parallel.each(ranges, in_processes: processes) do |range|
        begin
          client = ElasticsearchReindexing.configure_client
          scope.includes(options[:includes_list]).where("#{self.table_name}.id >= ? AND #{self.table_name}.id <= ?", range.first, range.last).find_in_batches(batch_size: APP_CONFIG[:parallel_processing_batch_size].to_i) do |batch|
            client.bulk({
              index: options[:index],
              type: self.__elasticsearch__.document_type,
              body: prepare_records_for_indexing(batch)
            })
          end
        rescue Exception => ex
          Airbrake.notify(ex)
          raise ex
        end
      end
    end

    def eimport(options={})
      import_options = {}
      import_options[:force] = options[:force].nil? ? true : options[:force]
      self.settings(self.settings.to_hash.deep_merge!(index: { number_of_shards: 1, refresh_interval: '1ms' })) if Rails.env.test?
      if options[:index_modified]
        import_options[:index] = options[:index_modified]
      else
        import_options[:index] = ElasticsearchReindexing.get_index_from_model(self.name)
        import_options[:force] = false
      end
      import_options[:scope] = self.const_get("ES_SCOPE") if self.const_defined?("ES_SCOPE")
      if options[:parallel_processing].present?
        self.settings(self.settings.to_hash.deep_merge(index: { refresh_interval: -1 }))
        self.bulk_es_index(import_options.merge(includes_list: options[:includes_list]))
        reset_refresh_interval(import_options[:index])
      else
        self.__elasticsearch__.import(import_options)
      end
    end

    def delete_indexes(options={})
      if options[:index_modified]
        index_name_modified = options[:index_modified]
      else
        index_name_modified = ElasticsearchReindexing.get_index_from_model(self.name)
      end
      self.__elasticsearch__.delete_index!(:index => index_name_modified)
    end

    def force_create_ex_index(options={})
      index_alias_name = ElasticsearchReindexing.get_index_alias_from_model(self.name)
      index_name_modified = index_alias_name + "-v1"
      if options[:index_modified]
        index_name_modified = options[:index_modified]
      end
      self.settings(self.settings.to_hash.deep_merge!(index: { number_of_shards: 1, refresh_interval: '1ms'})) if Rails.env.test?
      self.__elasticsearch__.create_index!(:index => index_name_modified, :force => true)
      ElasticsearchReindexing.create_individual_alias(index_alias_name, :index_name => index_name_modified)
    end

    def refresh_es_index
      index_name_modified = ElasticsearchReindexing.get_index_from_model(self.name)
      self.__elasticsearch__.refresh_index!(:index => index_name_modified)
    end

    #To be used when fetching large data so that logs wont be created and response
    #hash wont be converted into an object
    def chronus_elasticsearch(options)
      ChronusElasticsearch.client.search(index: self.index_name, body: options)
    end


    private

    def reset_refresh_interval(index_name)
      client = ElasticsearchReindexing.configure_client
      client.indices.put_settings index: index_name, body: {index: {refresh_interval: ElasticsearchConstants::DEFAULT_REFRESH_INTERVAL } }
    end


    def prepare_records_for_indexing(records)
      records.map do |record|
        { index: { _id: record.id, data: record.as_indexed_json } }
      end
    end
  end

  def index_es_document
    self.__elasticsearch__.index_document
  end

  def update_es_document
    self.__elasticsearch__.update_document
  end

  def delete_es_document
    self.__elasticsearch__.delete_document
  end

  def zdt_delayed_index_es_document(class_name = self.class)
    DelayedEsDocument.delayed_index_es_document(class_name, self.id)
  end

  def zdt_delayed_update_es_document(class_name = self.class)
    DelayedEsDocument.delayed_update_es_document(class_name, self.id)
  end

  def zdt_delayed_delete_es_document(class_name = self.class)
    DelayedEsDocument.delayed_delete_es_document(class_name, self.id)
  end

  def as_partial_indexed_json(fields)
    partial_hash = {}
    fields = fields.map(&:to_sym)
    partial_hash[:only] = ((indexes[:only] || []) & fields)
    partial_hash[:methods] = ((indexes[:methods] || []) & fields)
    partial_hash[:include] = (indexes[:include] || {}).select{|key, _| key.in?(fields)}
    self.as_json(partial_hash)
  end

end
