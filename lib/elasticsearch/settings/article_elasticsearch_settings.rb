#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module ArticleElasticsearchSettings
  REINDEX_VERSION = 1
  extend ActiveSupport::Concern

  included do
    include Searchable
    INDEX_FIELDS = ['author.name_only', 'article_content.body.language_*', 'article_content.title.language_*', 'article_content.labels.name.language_*']

    settings ElasticsearchConstants::HTML_ANALYZER_SETTINGS.merge(index: { max_result_window: QueryHelper::MAX_HITS }).deep_merge(ElasticsearchConstants::STOPWORDS_ANALYZER_SETTINGS).deep_merge(ElasticsearchConstants::LANGUAGE_ANALYZER_SETTINGS) do
      mappings do
        indexes :id, type: 'integer'
        indexes :organization_id, type: 'integer'
        indexes :created_at, type: 'date'
        indexes :view_count, type: 'integer'
        indexes :helpful_count, type: 'integer'
        indexes :role_ids, type: 'integer'
        indexes :author do
          indexes :id, type: 'integer'
          indexes :name_only, type: 'text', analyzer: "standard"
        end
        indexes :publications do
          indexes :program_id, type: 'integer'
        end
        indexes :article_content do
          indexes :body, type: 'text', index: false, fields: { language_common: { type: 'text', analyzer: 'html_analyzer' }, language_en: { type: 'text', analyzer: 'chronus_english_html_analyzer' }, language_fr: { type: 'text', analyzer: 'chronus_french_html_analyzer' } }
          indexes :title, type: 'keyword', fields: { language_common: { type: 'text', analyzer: 'stopwords' }, language_en: { type: 'text', analyzer: 'chronus_english' }, language_fr: { type: 'text', analyzer: 'chronus_french' } }
          indexes :labels do
            indexes :id, type: 'integer'
            indexes :name, type: 'keyword', fields: { language_common: { type: 'text', analyzer: 'stopwords' }, language_en: { type: 'text', analyzer: 'chronus_english' }, language_fr: { type: 'text', analyzer: 'chronus_french' } }
          end
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
        only: [:id, :organization_id, :created_at, :view_count, :helpful_count ],
        methods: [:role_ids],
        include: {
          author: {only: [:id], methods: [:name_only]},
          publications: {only: [:program_id]},
          article_content: {only: [:body, :title], include: {labels: {only: [:id, :name] }}}
        }
      }
    end
  end
end