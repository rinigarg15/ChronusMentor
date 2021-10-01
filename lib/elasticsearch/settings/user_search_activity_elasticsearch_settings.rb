#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module UserSearchActivityElasticsearchSettings
  #REINDEX_VERSION = 1
  extend ActiveSupport::Concern

  included do
    include Searchable

    settings ElasticsearchConstants::WORD_CLOUD_ANALYZER_SETTINGS.merge!(index: { max_result_window: QueryHelper::MAX_HITS }) do
      mappings do
        indexes :id, type: 'integer'
        indexes :program_id, type: 'integer'
        indexes :user_id, type: 'integer'
        indexes :search_text, type: 'text', fielddata: true, analyzer: 'word_cloud_analyzer'
        indexes :created_at, type: 'date'
      end
    end

    def as_indexed_json(_options={})
      self.as_json(indexes)
    end


    def indexes
      {
        only: [:id, :program_id, :user_id, :search_text]
      }
    end
  end
end