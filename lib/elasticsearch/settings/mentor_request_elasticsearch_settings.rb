#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module MentorRequestElasticsearchSettings
  REINDEX_VERSION = 1
  extend ActiveSupport::Concern

  included do
    include Searchable

    settings index: { max_result_window: QueryHelper::MAX_HITS } do
      mappings do
        indexes :id, type: 'integer'
        indexes :status, type: 'byte'
        indexes :program_id, type: 'integer'
        indexes :receiver_id, type: 'integer'
        indexes :sender_id, type: 'integer'
        indexes :created_at, type: 'date'
        indexes :student do
          indexes :id, type: 'integer'
          indexes :name_only, type: 'text', analyzer: 'standard'
        end
        indexes :mentor do
          indexes :id, type: 'integer'
          indexes :name_only, type: 'text', analyzer: 'standard'
        end
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
        only: [:id, :status, :program_id, :receiver_id, :sender_id, :created_at],
        include: {student: {only: [:id], methods: [:name_only]}, mentor: {only: [:id], methods: [:name_only]}}
      }
    end
  end
end