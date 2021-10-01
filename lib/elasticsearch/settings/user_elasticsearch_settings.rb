#INCREMENT THE REINDEX_VERSION CONSTANT BY 1 IF REINDEXING NEEDS TO RUN FOR THIS INDEX
module UserElasticsearchSettings
  REINDEX_VERSION = 2
  extend ActiveSupport::Concern

  ES_PARTIAL_UPDATES = {
    profile_score: {
      index_fields: [:profile_score_sum],
      includes_list: [{roles: [:translations]}, {program: [role_questions: {profile_question: [:conditional_question_choices]}]}, {member: [{profile_answers: [profile_question: [question_choices: :translations]]}, :profile_picture]}]
    }
  }

  included do
    include Searchable
    INDEX_FIELDS = ['name_only', 'first_name', 'last_name', 'member.location_answer.location.full_address', 'profile_answer_text.language_*']

    settings ElasticsearchConstants::SORTABLE_ANALYZER_SETTINGS.deep_merge(ElasticsearchConstants::AUTOCOMPLETE_SETTINGS.merge(index: { max_result_window: QueryHelper::MAX_HITS })).deep_merge(ElasticsearchConstants::LANGUAGE_ANALYZER_SETTINGS).deep_merge(ElasticsearchConstants::ACCENT_SETTINGS) do
      mappings do
        indexes :id, type: 'integer'
        indexes :program_id, type: 'integer'
        indexes :state_transitions, type: 'nested' do
          indexes :id, type: 'integer'
          indexes :date_id, type: 'integer'
          indexes :from_state, type: 'keyword'
          indexes :to_state, type: 'keyword'
          indexes :from_roles
          indexes :to_roles
        end
        indexes :connection_membership_state_changes, type: 'nested' do
          indexes :id, type: 'integer'
          indexes :role_id, type: 'integer'
          indexes :date_id, type: 'integer'
          indexes :group_from_state, type: 'byte'
          indexes :group_to_state, type: 'byte'
          indexes :cm_from_state, type: 'byte'
          indexes :cm_to_state, type: 'byte'
          indexes :user_from_state, type: 'keyword'
          indexes :user_to_state, type: 'keyword'
        end

        indexes :name_only, type: 'text', analyzer: 'accent_analyzer', fields: { sort: { type: 'text', analyzer: 'sortable', fielddata: true }, autocomplete: { type: 'text', analyzer: 'autocomplete_index_analyzer', search_analyzer: 'autocomplete_search_analyzer' }, keyword: { type: 'text', analyzer: 'sortable' } }
        indexes :first_name, type: 'text', analyzer: 'accent_analyzer', fields: { sort: { type: 'text', analyzer: 'sortable', fielddata: true }, autocomplete: { type: 'text', analyzer: 'autocomplete_index_analyzer', search_analyzer: 'autocomplete_search_analyzer' }, keyword: { type: 'text', analyzer: 'sortable' } }
        indexes :last_name, type: 'text', analyzer: 'accent_analyzer', fields: { sort: { type: 'text', analyzer: 'sortable', fielddata: true }, autocomplete: { type: 'text', analyzer: 'autocomplete_index_analyzer', search_analyzer: 'autocomplete_search_analyzer' }, keyword: { type: 'text', analyzer: 'sortable' } }
        indexes :email, type: 'text', analyzer: 'standard', fields: { sort: { type: 'text', analyzer: 'sortable', fielddata: true }, keyword: { type: 'text', analyzer: 'sortable' } }
        indexes :created_at, type: 'date'
        indexes :last_seen_at, type: 'date'
        indexes :last_deactivated_at, type: 'date'
        indexes :creation_source, type: 'byte'
        indexes :state, type: 'keyword'
        indexes :mentoring_mode, type: 'integer'
        indexes :member_id, type: 'integer'
        indexes :can_accept_request, type: 'boolean'
        indexes :availability, type: 'integer'
        indexes :net_recommended_count, type: 'integer'
        indexes :active_mentee_connections_count, type: 'integer'
        indexes :total_mentee_connections_count, type: 'integer'
        indexes :active_user_connections_count, type: 'integer'
        indexes :total_user_connections_count, type: 'integer'
        indexes :closed_user_connections_count, type: 'integer'
        indexes :draft_connections_count, type: 'integer'
        indexes :last_closed_group_time, type: 'date'
        indexes :profile_answer_text, type: 'text', index: false, fields: { language_common: { type: 'text', analyzer: 'standard' }, language_en: { type: 'text', analyzer: 'chronus_english' }, language_fr: { type: 'text', analyzer: 'chronus_french' } }
        indexes :profile_answer_choices, type: 'text', analyzer: 'whitespace'
        indexes :role_name_string, type: 'text', analyzer: 'sortable', fielddata: true
        indexes :is_student, type: 'integer'
        indexes :is_mentor, type: 'integer'
        indexes :profile_score_sum, type: 'integer'
        indexes :roles do
          indexes :id, type: 'integer'
          indexes :name, type: 'keyword'
        end
        indexes :taggings do
          indexes :tag_id, type: 'integer'
        end
        indexes :user_stat do
          indexes :average_rating, type: 'float'
        end
        indexes :first_activity do
          indexes :created_at, type: 'date'
        end
        indexes :member do
          indexes :state, type: 'byte'
          indexes :organization_id, type: 'integer'
          indexes :terms_and_conditions_accepted, type: 'date'
          indexes :language_title, type: 'text', analyzer: 'sortable', fielddata: true
          indexes :member_language_id, type: 'integer'
          indexes :location_answer do
            indexes :location do
              indexes :point, type: 'geo_point'
              indexes :full_address, type: 'text'
              indexes :full_location, type: 'text'
            end
          end
        end
      end
    end

    def as_indexed_json(_options={})
      self.as_json(indexes)
    end

    def indexes
      {
        only: [:id, :program_id, :created_at, :last_status_update_at, :creation_source, :state, :mentoring_mode, :member_id, :last_seen_at, :last_deactivated_at],
        methods: [:name_only, :first_name, :last_name, :email, :active_mentee_connections_count, :total_mentee_connections_count, :active_user_connections_count, :total_user_connections_count, :closed_user_connections_count, :draft_connections_count, :last_closed_group_time, :profile_answer_text, :profile_answer_choices, :can_accept_request, :availability, :net_recommended_count, :role_name_string, :is_student, :is_mentor, :profile_score_sum],
        include:
          {
            state_transitions: {
              only: [:id, :date_id], methods: [:from_state, :to_state, :from_roles, :to_roles]
            },
            connection_membership_state_changes: {
              only: [:id, :date_id, :role_id], methods: [:group_from_state, :group_to_state, :cm_from_state, :cm_to_state, :user_from_state, :user_to_state]
            },
            roles: {
              only: [:id, :name],
            },
            taggings: {
             only: [:tag_id]
            },
            first_activity: {
              only: [:created_at]
            },
            user_stat: {
              only: [:average_rating]
            },
            member: {
              only: [:state, :organization_id, :terms_and_conditions_accepted],
              methods: [:language_title, :member_language_id],
              include:{
                location_answer: {only: [], include: {location: {only: [:full_address], methods: [:point, :full_location]}}}
              }
            }
          }
      }
    end

    def profile_answer_text
      role_ids = self.roles.collect(&:id)
      profile_question_ids = self.program.role_questions.select{|role_qn| role_qn.show_all? &&
        role_qn.role_id.in?(role_ids) }.collect(&:profile_question_id)
      self.member.profile_answers.select do |answer|
        answer.profile_question_id.in?(profile_question_ids)
      end.collect(&:answer_text).join(" ")
    end

    def profile_answer_choices
      self.member.profile_answers.select{|answer| ProfileQuestion::Type.choice_based_types.include?(answer.profile_question.question_type) }.map{|ans| ans.answer_choices.collect(&:question_choice_id)}.flatten.join(" ")
    end

    def profile_score_sum
      profile_score(eager_loaded: true).sum
    end

    def role_name_string
      set_role_names
      @role_names.sort.join("~")
    end

    def set_role_names
      @role_names ||= self.roles.collect(&:name)
    end

    def is_student
      set_role_names.include?(RoleConstants::STUDENT_NAME) ? 1 : 0
    end

    def is_mentor
      set_role_names.include?(RoleConstants::MENTOR_NAME) ? 1 : 0
    end

    def net_recommended_count
      recommendation_preferences.select { |recommendation_preference| recommendation_preference.mentor_recommendation.published? }.size
    end

    def availability
      availability = self.max_connections_limit.to_i - (active_mentor_connection_count + pending_mentor_offers_count)
      availability < 0 ? 0 : availability
    end

    def can_accept_request
      self.max_connections_limit.to_i > (active_mentor_connection_count + pending_mentor_offers_count + pending_mentor_requests_count)
    end

    def active_mentor_connection_count
      @active_mentor_connection_size ||= self.connection_memberships.select{|membership| membership.type == Connection::MentorMembership.name && membership.group.status != Group::Status::CLOSED}.collect(&:group).collect(&:student_memberships).flatten.compact.size
    end

    def set_active_connection_memberships
      @active_connection_memberships ||= self.connection_memberships.select{|membership| membership.group.status.in?([Group::Status::ACTIVE, Group::Status::INACTIVE])}
    end

    def set_closed_connection_memberships
      @closed_connection_memberships ||= self.connection_memberships.select{|membership| membership.group.status == Group::Status::CLOSED}
    end

    def active_mentee_connections_count
      set_active_connection_memberships
      @active_connection_memberships.select{|membership| membership.type == Connection::MenteeMembership.name}.size
    end

    def total_mentee_connections_count
      set_active_connection_memberships
      set_closed_connection_memberships
      (@active_connection_memberships + @closed_connection_memberships).select{|membership| membership.type == Connection::MenteeMembership.name}.size
    end

    def active_user_connections_count # active_groups_count
      set_active_connection_memberships
      @active_connection_memberships.size
    end

    def total_user_connections_count
      set_active_connection_memberships
      set_closed_connection_memberships
      @active_connection_memberships.size + @closed_connection_memberships.size
    end

    def closed_user_connections_count # closed_groups_count
      set_closed_connection_memberships
      @closed_connection_memberships.size
    end

    def draft_connections_count # drafted_groups_count
      self.connection_memberships.select{|membership| membership.group.status == Group::Status::DRAFTED}.size
    end

    def last_closed_group_time
      set_closed_connection_memberships
      @closed_connection_memberships.collect(&:group).collect(&:closed_at).compact.sort.last
    end

    def pending_mentor_offers_count
      @pending_mentor_offers_count_cache ||= self.sent_mentor_offers.select{|offer| offer.status == MentorOffer::Status::PENDING}.size
    end

    def pending_mentor_requests_count
      self.received_mentor_requests.select{|request| request.type == MentorRequest.name && request.status == AbstractRequest::Status::NOT_ANSWERED}.size
    end
  end
end
