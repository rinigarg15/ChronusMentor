#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module QaQuestionElasticsearchSettings
  REINDEX_VERSION = 1
  extend ActiveSupport::Concern

  included do
    include Searchable
    INDEX_FIELDS = ['user.name_only', 'qa_answers.user.name_only', 'summary.language_*', 'description.language_*', 'qa_answers.content.language_*']

    settings ElasticsearchConstants::STOPWORDS_ANALYZER_SETTINGS.merge!(index: { max_result_window: QueryHelper::MAX_HITS }).deep_merge(ElasticsearchConstants::LANGUAGE_ANALYZER_SETTINGS) do
      mappings do
        indexes :id, type: 'integer'
        indexes :program_id, type: 'integer'
        indexes :summary, type: 'text', index: false, fields: { language_common: { type: 'text', analyzer: 'stopwords' }, language_en: { type: 'text', analyzer: 'chronus_english' }, language_fr: { type: 'text', analyzer: 'chronus_french' } }
        indexes :description, type: 'text', index: false, fields: { language_common: { type: 'text', analyzer: 'stopwords' },language_en: { type: 'text', analyzer: 'chronus_english' }, language_fr: { type: 'text', analyzer: 'chronus_french' } }
        indexes :views, type: 'integer'
        indexes :user do
          indexes :name_only, type: 'text', analyzer: 'standard' # questioner
        end
        indexes :qa_answers do
          indexes :content, type: 'text', index: false, fields: { language_common: { type: 'text', analyzer: 'stopwords' },language_en: { type: 'text', analyzer: 'chronus_english' }, language_fr: { type: 'text', analyzer: 'chronus_french' } }
          indexes :user do
            indexes :name_only, type: 'text', analyzer: 'standard' # answerer
          end
        end
        indexes :program do
          indexes :parent_id, type: 'integer' # No reindexing needed in program_observer since parent_id will never change.
          indexes :roles do
            indexes :id, type: 'integer'
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
        only: [:id, :program_id, :summary, :description, :views],
        include: {
          user: {only: [], methods: [:name_only]},
          qa_answers: {only: [:content], include: {user: {only: [], methods: [:name_only]}}},
          program: {only: [:parent_id], include: {roles: {only: [:id]}}}
        }
      }
    end
  end
end