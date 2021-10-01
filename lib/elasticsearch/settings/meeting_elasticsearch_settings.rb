#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module MeetingElasticsearchSettings
  REINDEX_VERSION = 1
  extend ActiveSupport::Concern

  included do
    include Searchable

    settings ElasticsearchConstants::AUTOCOMPLETE_SETTINGS.merge!(index: {max_result_window: QueryHelper::MAX_HITS}) do
      mappings do
        indexes :id, type: 'integer'
        indexes :topic, type: 'text'
        indexes :not_cancelled, type: 'boolean'
        indexes :program_id, type: 'integer'
        indexes :active, type: 'boolean'
        indexes :attendees do
          indexes :id, type: 'integer'
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
        only: [:id, :topic, :program_id, :active],
        methods: [:not_cancelled],
        include: {attendees: {only: [:id], methods: [:name_only]}}
      }
    end
  end
end