#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module MentorRecommendationElasticsearchSettings
  REINDEX_VERSION = 1
  extend ActiveSupport::Concern

  included do
    include Searchable

    settings index: {max_result_window: QueryHelper::MAX_HITS} do
      mappings do
        indexes :id, type: 'integer'
        indexes :status, type: 'byte'
        indexes :program_id, type: 'integer'
        indexes :created_at, type: 'date'
        indexes :published_at, type: 'date'
        indexes :receiver_id, enabled: false, type: "object"
      end
    end

    # To facilitate partially updating indexes, provide indexes as a separate method.
    def as_indexed_json(_options = {})
      self.as_json(indexes)
    end

    # indexes is a hash which can consists of keys :only, :methods, :include
    # always provide array to :only and :methods
    # always provide hash to :include
    def indexes
      {
        only: [:id, :status, :program_id, :created_at, :published_at, :receiver_id]
      }
    end
  end
end