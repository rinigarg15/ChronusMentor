#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module ThreeSixtySurveyElasticsearchSettings
  REINDEX_VERSION = 1
  extend ActiveSupport::Concern

  included do
    include Searchable

    settings ElasticsearchConstants::SORTABLE_ANALYZER_SETTINGS.merge(index: { max_result_window: QueryHelper::MAX_HITS }) do      mappings do
        indexes :id, type: 'integer'
        indexes :created, type: 'date', null_value: '1900-01-01'
        indexes :title, type: 'text', analyzer: "sortable", fielddata: true
        indexes :state, type: 'keyword'
        indexes :organization_id, type: 'integer'
        indexes :program_id, type: 'integer'
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
        only: [:id, :title, :state, :organization_id, :program_id],
        methods: [:created]
      }
    end
  end
end
