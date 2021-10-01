#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module GroupStateChangeElasticsearchSettings
  REINDEX_VERSION = 1
  extend ActiveSupport::Concern

  included do
    include Searchable

    settings do
      mappings do
        indexes :id, type: 'integer'
        indexes :group_id, type: 'integer'
        indexes :date_id, type: 'integer'
        indexes :from_state, type: 'byte'
        indexes :to_state, type: 'byte'
        indexes :group do
          indexes :program_id, type: 'integer'
        end
      end
    end

    # To facilitate partially updating indexes, provide indexes as a separate method.
    def as_indexed_json(options={})
      # Not adding callback on group as program_id is not going to be updated
      self.as_json(indexes)
    end

    # indexes is a hash which can consists of keys :only, :methods, :include
    # always provide array to :only and :methods
    # always provide hash to :include
    def indexes
      {include: { group: { only: [:program_id]}}}
    end
  end
end