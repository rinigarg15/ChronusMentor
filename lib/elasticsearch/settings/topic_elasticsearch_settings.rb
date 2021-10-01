#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module TopicElasticsearchSettings
  #REINDEX_VERSION = 1
  extend ActiveSupport::Concern

  included do
    include Searchable
    INDEX_FIELDS = ['title.language_*', 'body.language_*', 'user.topic_author_name_only', 'published_posts.body.language_*']

    settings ElasticsearchConstants::HTML_ANALYZER_SETTINGS.merge(index: { max_result_window: QueryHelper::MAX_HITS } ).deep_merge(ElasticsearchConstants::STOPWORDS_ANALYZER_SETTINGS).deep_merge(ElasticsearchConstants::LANGUAGE_ANALYZER_SETTINGS) do
      mappings do
        indexes :id, type: 'integer'
        indexes :program_id, type: 'integer'
        indexes :topic_role_ids, type: 'integer'
        indexes :title, type: 'text', index: false, fields: { language_common: { type: 'text', analyzer: 'stopwords' }, language_en: { type: 'text', analyzer: 'chronus_english' }, language_fr: { type: 'text', analyzer: 'chronus_french' } }
        indexes :body, type: 'text', index: false, fields: { language_common: { type: 'text', analyzer: 'html_analyzer' }, language_en: { type: 'text', analyzer: 'chronus_english_html_analyzer' }, language_fr: { type: 'text', analyzer: 'chronus_french_html_analyzer' } }
        indexes :user do
          indexes :id, type: 'integer'
          indexes :topic_author_name_only, type: 'text', analyzer: 'standard'
        end
        indexes :published_posts do
          indexes :id, type: 'integer'
          indexes :body, type: 'text', index: false, fields: { language_common: { type: 'text', analyzer: 'stopwords' }, language_en: { type: 'text', analyzer: 'chronus_english' }, language_fr: { type: 'text', analyzer: 'chronus_french' } }
        end
      end
    end

    # To facilitate partially updating indexes, provide indexes as a separate method.
    def as_indexed_json(options={})
      self.as_json(indexes)
    end


    def indexes
      {
        only: [:id, :title, :body],
        methods: [:program_id, :topic_role_ids],
        include: {
          user: { only: [:id], methods: [:topic_author_name_only] },
          published_posts: { only: [:id, :body] }
        }
      }
    end
  end
end