#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module MemberElasticsearchSettings
  REINDEX_VERSION = 2
  extend ActiveSupport::Concern

  included do
    include Searchable

    FIELD_MAPPING = {
      "name" => "name_only",
      "role_ids" => "users.role_references.role_id"
    }

    settings ElasticsearchConstants::SORTABLE_ANALYZER_SETTINGS.deep_merge(ElasticsearchConstants::AUTOCOMPLETE_SETTINGS.merge(index: { max_result_window: QueryHelper::MAX_HITS })) do
      mappings do
        indexes :id, type: 'integer'
        indexes :name_only, type: 'text', analyzer: 'standard', fields: { sort: { type: 'text', analyzer: 'sortable', fielddata: true }, autocomplete: { type: 'text', analyzer: 'autocomplete_index_analyzer', search_analyzer: 'autocomplete_search_analyzer' }, keyword: { type: 'text', analyzer: 'sortable' } }
        indexes :first_name, type: 'text', analyzer: 'standard', fields: { sort: { type: 'text', analyzer: 'sortable', fielddata: true }, autocomplete: { type: 'text', analyzer: 'autocomplete_index_analyzer', search_analyzer: 'autocomplete_search_analyzer' }, keyword: { type: 'text', analyzer: 'sortable' } }
        indexes :last_name, type: 'text', analyzer: 'standard', fields: { sort: { type: 'text', analyzer: 'sortable', fielddata: true }, autocomplete: { type: 'text', analyzer: 'autocomplete_index_analyzer', search_analyzer: 'autocomplete_search_analyzer' }, keyword: { type: 'text', analyzer: 'sortable' } }
        indexes :email, type: 'text', analyzer: 'standard', fields: { sort: { type: 'text', analyzer: 'sortable', fielddata: true }, autocomplete: { type: 'text', analyzer: 'autocomplete_index_analyzer', search_analyzer: 'autocomplete_search_analyzer' }, keyword: { type: 'text', analyzer: 'sortable' } }
        indexes :state, type: 'byte'
        indexes :created_at, type: 'date'
        indexes :organization_id, type: 'integer'
        indexes :language_title, type: 'text', analyzer: 'sortable', fielddata: true
        indexes :member_language_id, type: 'integer'
        indexes :last_suspended_at, type: 'date'
        indexes :location_answer do
          indexes :location do
            indexes :point, type: 'geo_point'
            indexes :full_address, type: 'text'
          end
        end
        indexes :users do
          indexes :id, type: 'integer'
          indexes :program_id, type: 'integer'
          indexes :role_references do
            indexes :role_id, type: 'integer'
          end
        end
        indexes :ongoing_engagements_count, type: 'integer'
        indexes :closed_engagements_count, type: 'integer'
        indexes :total_engagements_count, type: 'integer'
      end
    end

    # To facilitate partially updating indexes, provide indexes as a separate method.
    def as_indexed_json(_options={})
      self.as_json(indexes)
    end

    # indexes is a hash which can consists of keys :only, :methods, :include
    # always provide array to :only and :methods
    # always provide hash to :include
    def indexes
      {
        only: [:id, :first_name, :last_name, :email, :state, :created_at, :organization_id],
        methods: [:language_title, :name_only, :member_language_id, :ongoing_engagements_count, :closed_engagements_count, :total_engagements_count, :last_suspended_at],
        include: {
          location_answer: {only: [], include: {location: {only: [:full_address], methods: [:point]}}},
          users: {only: [:id, :program_id], include: {role_references: {only: [:role_id]}}},
          member_language: {only: [:language_id]}
        }
      }
    end

    def self.get_field_mapping(field_name)
      FIELD_MAPPING[field_name] || field_name
    end
  end
end