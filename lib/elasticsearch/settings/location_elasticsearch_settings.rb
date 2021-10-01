#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module LocationElasticsearchSettings
  REINDEX_VERSION = 1
  AUTOCOMPLETE_LIMIT= 15
  extend ActiveSupport::Concern

  included do
    include Searchable

    settings ElasticsearchConstants::AUTOCOMPLETE_SETTINGS do
      mappings do
        indexes :id, type: 'integer'
        indexes :full_address, type: 'text', analyzer: 'autocomplete_index_analyzer', search_analyzer: 'autocomplete_search_analyzer'
        indexes :full_address_db, type: 'object', enabled: false
        indexes :profile_answers_count, type: 'integer'
        indexes :full_country, type: 'text', analyzer: 'standard', fields: { keyword: {type: 'keyword'}}
        indexes :full_state, type: 'text', analyzer: 'standard', fields: { keyword: {type: 'keyword'}}
        indexes :full_city, type: 'text', analyzer: 'standard', fields: { keyword: {type: 'keyword'}}
      end
    end

    # To facilitate partially updating indexes, provide indexes as a separate method.
    def as_indexed_json(options={})
      self.as_json(indexes)
    end

    # indexes is a hash which can consists of keys :only, :methods, :include
    # always provide array to :only and :methods
    # always provide hash to :include
    def indexes
      {
        only: [:id, :profile_answers_count],
        methods: [:full_address, :full_address_db, :full_state, :full_country, :full_city]
      }
    end
  end
end