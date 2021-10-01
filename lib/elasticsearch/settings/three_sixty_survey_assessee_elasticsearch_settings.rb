#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module ThreeSixtySurveyAssesseeElasticsearchSettings
  REINDEX_VERSION = 1
  extend ActiveSupport::Concern

  included do
    include Searchable

    settings ElasticsearchConstants::SORTABLE_ANALYZER_SETTINGS.merge(index: { max_result_window: QueryHelper::MAX_HITS }) do
      mappings do
        indexes :id, type: 'integer'
        indexes :expires, type: 'date', null_value: '1900-01-01'
        indexes :issued, type: 'date', null_value: '1900-01-01'
        indexes :program_id, type: 'integer'
        indexes :organization_id, type: 'integer'
        indexes :title, type: 'text', analyzer: "sortable", fielddata: true
        indexes :state, type: 'keyword'
        indexes :participant, type: 'text', analyzer: "sortable", fielddata: true
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
        only: [:id],
        methods: [:expires, :issued, :program_id, :organization_id, :title, :state, :participant]
      }
    end
  end
end