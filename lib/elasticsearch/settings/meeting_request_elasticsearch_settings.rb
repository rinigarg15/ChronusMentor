#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module MeetingRequestElasticsearchSettings
  REINDEX_VERSION = 2
  extend ActiveSupport::Concern

  included do
    include Searchable

    settings index: {max_result_window: QueryHelper::MAX_HITS} do
      mappings do
        indexes :id, type: 'integer'
        indexes :status, type: 'byte'
        indexes :program_id, type: 'integer'
        indexes :created_at, type: 'date'
        indexes :accepted_at, type: 'date'
        indexes :sender_id, enabled: false, type: "object"
        indexes :receiver_id, enabled: false, type: "object"
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
        only: [:id, :status, :program_id, :created_at, :accepted_at, :sender_id, :receiver_id]
      }
    end
  end
end