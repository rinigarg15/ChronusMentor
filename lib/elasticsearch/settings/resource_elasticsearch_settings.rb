#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module ResourceElasticsearchSettings
  REINDEX_VERSION = 2
  extend ActiveSupport::Concern

  included do
    include Searchable
    INDEX_FIELDS = ['title.language_*', 'content.language_*']

    settings ElasticsearchConstants::SORTABLE_ANALYZER_SETTINGS.deep_merge(ElasticsearchConstants::HTML_ANALYZER_SETTINGS.merge(index: { max_result_window: QueryHelper::MAX_HITS } ).deep_merge(ElasticsearchConstants::STOPWORDS_ANALYZER_SETTINGS).deep_merge(ElasticsearchConstants::LANGUAGE_ANALYZER_SETTINGS)) do
      mappings do
        indexes :id, type: 'integer'
        indexes :title, type: 'text', index: false, fields: { sort: { type: 'text', analyzer: 'sortable', fielddata: true }, language_common: { type: 'text', analyzer: 'stopwords' }, language_en: { type: 'text', analyzer: 'chronus_english'}, language_fr: { type: 'text', analyzer: 'chronus_french' } }
        indexes :content, type: 'text', index: false, fields: { language_common: { type: 'text', analyzer: 'html_analyzer' }, language_en: { type: 'text', analyzer: 'chronus_english_html_analyzer' }, language_fr: { type: 'text', analyzer: 'chronus_french_html_analyzer' } }
        indexes :resource_for_role_ids, type: 'integer'
        indexes :resource_publications do
          indexes :program_id, type: 'integer'
        end
      end
    end

    # To facilitate partially updating indexes, provide indexes as a separate method.
    def as_indexed_json(options={})
      self.as_json(indexes)
    end

    def indexes
      {
        only: [:id, :title, :content],
        methods: [:resource_for_role_ids],
        include: {
          resource_publications: { only: [:program_id] },
        }
      }
    end
  end
end