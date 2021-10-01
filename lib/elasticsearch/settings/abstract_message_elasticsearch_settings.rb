#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module AbstractMessageElasticsearchSettings
  REINDEX_VERSION = 2
  extend ActiveSupport::Concern

  included do
    include Searchable

    settings ElasticsearchConstants::URL_ANALYZER_SETTINGS.merge(index: { max_result_window: QueryHelper::MAX_HITS }).deep_merge(ElasticsearchConstants::LANGUAGE_ANALYZER_SETTINGS) do
      mappings do
        indexes :id, type: 'integer'
        indexes :root_id, type: 'integer'
        indexes :subject, type: 'keyword', fields: { language_common: { type: 'text', analyzer: 'url_analyzer' }, language_en: { type: 'text', analyzer: 'chronus_english' }, language_fr: { type: 'text', analyzer: 'chronus_french' } }
        indexes :content, type: 'object', enabled: false
        # Few content were of the format "<a href="<a href=\"<LINK>\">"></a>" and html_strip filter wont strip these contents.
        indexes :html_stripped_content, type: 'text', index: false, fields: { language_common: { type: 'text', analyzer: 'url_analyzer' }, language_en: { type: 'text', analyzer: 'chronus_english' }, language_fr: { type: 'text', analyzer: 'chronus_french' } }
        indexes :created_at, type: 'date'
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
      {only: [:id, :root_id, :subject, :content, :created_at], methods: [:html_stripped_content]}
    end
  end
end