#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module SurveyAnswerElasticsearchSettings
  REINDEX_VERSION = 2
  extend ActiveSupport::Concern

  included do
    include Searchable

    settings ElasticsearchConstants::SORTABLE_ANALYZER_SETTINGS.merge(index: { max_result_window: QueryHelper::MAX_HITS }).deep_merge(ElasticsearchConstants::STOPWORDS_ANALYZER_SETTINGS).deep_merge(ElasticsearchConstants::LANGUAGE_ANALYZER_SETTINGS) do
      mappings do
        indexes :id, type: 'integer'
        indexes :answer_text, type: 'text', index: false, fields: { language_common: { type: 'text', analyzer: 'stopwords' }, language_en: { type: 'text', analyzer: 'chronus_english' }, language_fr: { type: 'text', analyzer: 'chronus_french' } }
        indexes :answer_text_sortable, type: 'text', analyzer: "sortable", fielddata: true # https://www.elastic.co/guide/en/elasticsearch/reference/5.1/search-request-sort.html#_memory_considerations https://www.elastic.co/guide/en/elasticsearch/reference/current/fielddata.html#_fielddata_is_disabled_on_literal_text_literal_fields_by_default
        indexes :last_answered_at, type: 'date'
        indexes :common_question_id, type: 'integer'
        indexes :user_id, type: 'integer'
        indexes :group_id, type: 'integer'
        indexes :survey_id, type: 'integer'
        indexes :member_meeting_id, type: 'integer'
        indexes :response_id, type: 'integer'
        indexes :is_draft, type: 'boolean'
        indexes :connection_membership_role_id, type: 'integer'
        indexes :connection_membership_role_name_string, type: 'text', analyzer: 'sortable', fielddata: true
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
        only: [:id, :answer_text, :last_answered_at, :common_question_id, :user_id, :group_id, :survey_id, :member_meeting_id, :response_id, :is_draft, :connection_membership_role_id],
        methods: [:answer_text_sortable, :connection_membership_role_name_string]
      }
    end

    def connection_membership_role_name_string
      self.role.customized_term.term if self.role.present?
    end
  end
end
