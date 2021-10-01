# == Schema Information
#
# Table name: admin_views
#
#  id            :integer          not null, primary key
#  title         :string(255)
#  program_id    :integer          not null
#  filter_params :text(16777215)
#  default_view  :integer
#  created_at    :datetime
#  updated_at    :datetime
#  description   :text(16777215)
#  type          :string(255)      default("AdminView")
#  favourite     :boolean          default(FALSE)
#  favourited_at :datetime
#  role_id       :integer
#

class AdminView < AbstractView
  include ChronusS3Utils
  include DateProfileFilter

  EDITABLE_DEFAULT_VIEWS = [AbstractView::DefaultType::ACCEPTED_BUT_NOT_JOINED, AbstractView::DefaultType::REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::NEVER_CONNECTED_MENTEES, AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES, AbstractView::DefaultType::USERS_WITH_LOW_PROFILE_SCORES, AbstractView::DefaultType::MENTORS_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::MENTEES_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::AVAILABLE_MENTORS]

  DEFAULT_VIEWS_FOR_MATCH_REPORT = [AbstractView::DefaultType::NEVER_CONNECTED_MENTEES, AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES, AbstractView::DefaultType::AVAILABLE_MENTORS]

  CSV_USER_SLICE_SIZE = 2500
  CSV_PROCESSES = 4

  MIN_LAST_X_DAYS_VALUE = 1
  BULK_LIMIT = 25

  OR_OPERATOR_KEY = '|'
  FILL_TMP_INVALID_MEMBER_STATE = "i"
  LOCATION_VALUES_SPLITTER = "|"
  LOCATION_SCOPE_SPLITTER = ", "
  LOCATION_SCOPE_CLARIFIER_BEGIN = "("
  LOCATION_SCOPE_CLARIFIER_END = ")"

  CONNECTION_STATUS_FILTER_MIN_VALUE = 0
  CONNECTION_STATUS_FILTER_MAX_VALUE = 10**9

  module SurveyAnswerStatus
    RESPONDED = 1
    NOT_RESPONDED = 0
  end

  module LocationScope
    CITY = 'city'
    STATE = 'state'
    COUNTRY = 'country'

    def self.valid_values
      [CITY, STATE, COUNTRY]
    end
  end

  module RolesStatusQuestions
    ACCEPTED_NOT_SIGNED_UP = 'accepted_not_signed_up_users'
    ADDED_NOT_SIGNED_UP = 'added_not_signed_up_users'
    SIGNED_UP = 'signed_up_users'
  end

  module MandatoryFilterOptions
    FILLED_ALL_MANDATORY_QUESTIONS = "filled_all_mandatory_questions"
    NOT_FILLED_ALL_MANDATORY_QUESTIONS = "not_filled_all_mandatory_questions"
    FILLED_ALL_QUESTIONS = "filled_all_questions"
    NOT_FILLED_ALL_QUESTIONS = "not_filled_all_questions"
  end

  module DraftConnectionStatus
    WITH_DRAFTS = 1
    WITHOUT_DRAFTS = 2
  end

  module MeetingRequestStatus
    RECEIVED = 1
    SENT = 2
    ACCEPTED = 3
    PENDING = 4
  end

  module UserState
    IGNORE_USER_STATUS = 0
    MEMBER_WITH_ACTIVE_USER = 1
    MEMBER_WITHOUT_ACTIVE_USER = 2
  end

  module RequestsStatus
    SENT_OR_RECEIVED = 1
    SENT_OR_RECEIVED_WITH_PENDING_ACTION = 2
    NOT_SENT_OR_RECEIVED = 3
    RECEIVED_WITH_REJECTED_ACTION = 4
    RECEIVED_WITH_CLOSED_ACTION = 5

    def self.default_requests_filters
      {
        "mentoring_requests" => {"mentees"=>"", "mentors"=>""},
        "meeting_requests" => {"mentees"=>"", "mentors"=>""}
      }
    end
  end

  module UserMeetingConnectionStatus
    NOT_CONNECTED = 1
    CONNECTED = 2
  end

  module MentorRecommendationFilter
    MENTEE_RECEIVED = 1
    MENTEE_NOT_RECEIVED = 2
  end

  module ConnectionStatusCategoryKey
    NEVER_CONNECTED = "never_connected"
    CURRENTLY_CONNECTED = "currently_connected"
    CURRENTLY_UNCONNECTED = "currently_unconnected"
    FIRST_TIME_CONNECTED = "first_time_connected"
    CONNECTED_CURRENTLY_OR_PAST = "connected_currently_or_past"
    ADVANCED_FILTERS = "advanced_filters"
  end

  module ConnectionStatusTypeKey
    ONGOING = "ongoing"
    CLOSED = "closed"
    ONGOING_OR_CLOSED = "ongoing_or_closed"
    DRAFTED = "drafted"
  end

  module ConnectionStatusOperatorKey
    LESS_THAN = "less_than"
    EQUALS_TO = "equals_to"
    GREATER_THAN = "greater_than"
  end

  module ProgramRoleStateFilterObjectKey
    INCLUDE = "include"
    EXCLUDE = "exclude"
    ALL_MEMBERS = "all_members"
    INCLUSION = "inclusion"
    PROGRAM = "program"
    STATE = "state"
    ROLE = "role"
  end

  module ProgramRoleStateFilterActions
    ALL_MEMBERS = 0
    ALL_ACTIVE_MEMBERS = 1
    ALL_INACTIVE_MEMBERS = 2
    ADVANCED = 3
  end

  module ConnectionStatusFilterObjectKey
    CATEGORY = "category"
    TYPE = "type"
    OPERATOR = "operator"
    COUNT_VALUE = "countvalue"
  end

  module TimelineQuestions
    LAST_LOGIN_DATE = 1
    JOIN_DATE = 2
    TNC_ACCEPTED_ON = 3
    SIGNED_UP_ON = 4
    LAST_DEACTIVATED_AT = 5

    NEVER_SEEN_VALUE = "never"

    RevereMap = {
      TimelineQuestions::LAST_LOGIN_DATE.to_s => :last_seen_at,
      TimelineQuestions::JOIN_DATE.to_s => :created_at,
      TimelineQuestions::TNC_ACCEPTED_ON.to_s => 'member.terms_and_conditions_accepted',
      TimelineQuestions::SIGNED_UP_ON.to_s => 'first_activity.created_at',
      TimelineQuestions::LAST_DEACTIVATED_AT.to_s => :last_deactivated_at
    }

    def self.all
      [LAST_LOGIN_DATE, JOIN_DATE, TNC_ACCEPTED_ON, SIGNED_UP_ON, LAST_DEACTIVATED_AT]
    end

    module Type
      NEVER = 1
      BEFORE = 2
      BEFORE_X_DAYS = 3
      AFTER = 4
      DATE_RANGE = 5
      IN_LAST_X_DAYS = 6

      def self.all
        [NEVER..IN_LAST_X_DAYS]
      end

      RANGE_FETCHER = {
        NEVER => :get_never_range,
        BEFORE => :get_before_range,
        BEFORE_X_DAYS => :get_older_than_range,
        AFTER => :get_after_range,
        DATE_RANGE => :get_date_range,
        IN_LAST_X_DAYS => :get_in_last_x_days_range
      }
    end

    STARTING_DATE = Time.new(1985)
    ENDING_DATE = Time.new(2500)
  end

  module ProfileQuestionDateType
    FILLED = "filled"
    NOT_FILLED = "not_filled"
    BEFORE = "before"
    AFTER = "after"
    DATE_RANGE = "date_range"
    IN_LAST = "in_last"
    IN_NEXT = "in_next"

    def self.mapping_to_compatible_types
      {
        FILLED => AdminViewsHelper::QuestionType::ANSWERED.to_s,
        NOT_FILLED => AdminViewsHelper::QuestionType::NOT_ANSWERED.to_s,
        DATE_RANGE => DateRangePresets::CUSTOM,
        IN_LAST => DateRangePresets::LAST_N_DAYS,
        IN_NEXT => DateRangePresets::NEXT_N_DAYS
      }
    end

    def self.get_mapping(key)
      mapping_to_compatible_types[key.to_s] || key.to_s
    end

    def self.get_reverse_mapping(value)
      mapping_to_compatible_types.invert[value.to_s] || value.to_s
    end
  end

  module AdvancedOptionsType
    LAST_X_DAYS = 1
    BEFORE = 2
    AFTER = 3
    EVER = 4

    RANGE_FETCHER = {
      LAST_X_DAYS => :get_in_last_x_days_range,
      BEFORE => :get_before_range,
      AFTER => :get_after_range,
      EVER => :get_ever_range
    }
  end

  module DefaultAdminView

    ROLE_TO_TYPE_MAP = {
      RoleConstants::MENTOR_NAME => AbstractView::DefaultType::MENTORS,
      RoleConstants::STUDENT_NAME => AbstractView::DefaultType::MENTEES,
      RoleConstants::TEACHER_NAME => AbstractView::DefaultType::TEACHERS,
      RoleConstants::EMPLOYEE_NAME => AbstractView::DefaultType::EMPLOYEES,
      RoleConstants::ADMIN_NAME => AbstractView::DefaultType::ALL_ADMINS
    }

    def self.mandatory_views(program)
      views = [params_wrapper("feature.admin_view.content.all_users".translate, {:roles_and_status => {role_filter_1: {type: :include, roles: program.get_role_names}}}, AbstractView::DefaultType::ALL_USERS)]
      program.roles.each do |role|
        if default_view_type = ROLE_TO_TYPE_MAP[role.name]
          views << params_wrapper("feature.admin_view.content.all_role".translate(:role => program.term_for(CustomizedTerm::TermType::ROLE_TERM, role.name).pluralized_term), {:roles_and_status => {role_filter_1: {type: :include, roles: ["#{role.name}"]}}}, default_view_type)
        end
      end
      views
    end

    def self.non_mandatory_views(organization)
      [
        params_wrapper("Never Signedup at #{organization.name}", {
          :roles_and_status => {
            :role_filter_1 => { type: :include, roles: RoleConstants::DEFAULT_ROLE_NAMES },
            :signup_state => {
              :accepted_not_signed_up_users => AdminView::RolesStatusQuestions::ACCEPTED_NOT_SIGNED_UP,
              :added_not_signed_up_users => AdminView::RolesStatusQuestions::ADDED_NOT_SIGNED_UP
            }
          }
        },
        AbstractView::DefaultType::NEVER_SIGNEDUP_USERS)
      ]
    end

    def self.params_wrapper(title, filter_params, default_view_type)
      { :title => title, :admin_view => filter_params, :default_view => default_view_type }
    end
  end

  module KendoNumericOperators
    EQUAL = 'eq'
    NOT_EQUAL = 'neq'
    GREATER_OR_EQUAL = 'gte'
    GREATER = 'gt'
    LESS_OR_EQUAL = 'lte'
    LESS = 'lt'
  end

  module DefaultViews
    extend AbstractView::DefaultViewsCommons

    ACCEPTED_BUT_NOT_JOINED = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.admin_view.accepted_not_signed_up_title".translate(program.management_report_related_custom_term_interpolations) },
        description: ->{ "feature.abstract_view.admin_view.accepted_not_signed_up_description".translate(program.management_report_related_custom_term_interpolations) },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>program.get_role_names}, "signup_state"=>{"accepted_not_signed_up_users"=>"#{AdminView::RolesStatusQuestions::ACCEPTED_NOT_SIGNED_UP}"}}, "connection_status"=>{"availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => ""}.merge(RequestsStatus.default_requests_filters), "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::ACCEPTED_BUT_NOT_JOINED }
      }
    }

    REGISTERED_BUT_NOT_ACTIVE = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.admin_view.registered_not_active_title".translate },
        description: ->{ "feature.abstract_view.admin_view.registered_not_active_description".translate },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>program.get_role_names}, "state"=>{"pending"=>"#{User::Status::PENDING}"}, "signup_state"=>{"signed_up_users"=>"#{AdminView::RolesStatusQuestions::SIGNED_UP}"}}, "connection_status"=>{"availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => ""}.merge(RequestsStatus.default_requests_filters), "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::REGISTERED_BUT_NOT_ACTIVE }
      }
    }

    NEVER_CONNECTED_MENTEES = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.admin_view.never_connected_mentees_title".translate(Mentees: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term) },
        description: ->{ "feature.abstract_view.admin_view.never_connected_mentees_description".translate(Mentees: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term) },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::STUDENT_NAME]}, "state"=> {"active" => User::Status::ACTIVE}}, "connection_status"=>{"status_filters"=>{"status_filter_1"=>{"category"=>ConnectionStatusCategoryKey::NEVER_CONNECTED}}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => ""}.merge(RequestsStatus.default_requests_filters), "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::NEVER_CONNECTED_MENTEES }
      }
    }

    NEVER_CONNECTED_MENTORS = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.admin_view.never_connected_mentors_title".translate(Mentors: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term) },
        description: ->{ "feature.abstract_view.admin_view.never_connected_mentors_description".translate(Mentors: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term) },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::MENTOR_NAME]}, "state"=> {"active" => User::Status::ACTIVE}}, "connection_status"=>{"status_filters"=>{"status_filter_1"=>{"category"=>ConnectionStatusCategoryKey::NEVER_CONNECTED}}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => ""}.merge(RequestsStatus.default_requests_filters), "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::NEVER_CONNECTED_MENTORS }
      }
    }

    CURRENTLY_NOT_CONNECTED_MENTEES = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.admin_view.currently_not_connected_mentees_title".translate(Mentees: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term) },
        description: ->{ "feature.abstract_view.admin_view.currently_not_connected_mentees_description".translate(Mentees: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term) },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::STUDENT_NAME]}, "state"=> {"active" => User::Status::ACTIVE}}, "connection_status"=>{"status_filters"=>{"status_filter_1"=>{"category"=>ConnectionStatusCategoryKey::CURRENTLY_UNCONNECTED}}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => ""}.merge(RequestsStatus.default_requests_filters), "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES }
      }
    }

    USERS_WITH_LOW_PROFILE_SCORES = Proc.new {|program|
      {
        enabled_for: [CareerDev::Portal, Program],
        title: ->{ "feature.abstract_view.admin_view.users_with_low_profile_scores_title".translate },
        description: ->{ "feature.abstract_view.admin_view.users_with_low_profile_scores_description".translate },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>program.get_role_names}, "state"=>{"active" => User::Status::ACTIVE}}, "connection_status"=>{"availability"=>{"operator"=>"", "value"=>""}, "last_closed_connection"=>{"type"=>"", "days"=>"", "date"=>"", "date_range"=>""}, "meetingconnection_status" => ""}.merge(RequestsStatus.default_requests_filters), "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"1", "value"=>"60"}}, "others"=>{"tags"=>""}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::USERS_WITH_LOW_PROFILE_SCORES }
      }
    }

    MENTORS_REGISTERED_BUT_NOT_ACTIVE = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.admin_view.registered_mentors_not_active_title".translate(Mentors: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term) },
        description: ->{ "feature.abstract_view.admin_view.registered_mentors_not_active_description".translate(Mentors: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term) },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::MENTOR_NAME]}, "state"=>{"pending"=>"#{User::Status::PENDING}"}, "signup_state"=>{"signed_up_users"=>"#{AdminView::RolesStatusQuestions::SIGNED_UP}"}}, "connection_status"=>{"availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => ""}.merge(RequestsStatus.default_requests_filters), "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::MENTORS_REGISTERED_BUT_NOT_ACTIVE }
      }
    }

    MENTEES_REGISTERED_BUT_NOT_ACTIVE = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.admin_view.registered_mentees_not_active_title".translate(Mentees: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term) },
        description: ->{ "feature.abstract_view.admin_view.registered_mentees_not_active_description".translate(Mentees: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term) },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::STUDENT_NAME]}, "state"=>{"pending"=>"#{User::Status::PENDING}"}, "signup_state"=>{"signed_up_users"=>"#{AdminView::RolesStatusQuestions::SIGNED_UP}"}}, "connection_status"=>{"availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => ""}.merge(RequestsStatus.default_requests_filters), "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::MENTEES_REGISTERED_BUT_NOT_ACTIVE }
      }
    }

    MENTORS_WITH_LOW_PROFILE_SCORES = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.admin_view.mentors_with_low_profile_scores_title".translate(Mentors: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term) },
        description: ->{ "feature.abstract_view.admin_view.mentors_with_low_profile_scores_description".translate(Mentors: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term) },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::MENTOR_NAME]}, "state"=>{"active" => User::Status::ACTIVE}}, "connection_status"=>{"availability"=>{"operator"=>"", "value"=>""}, "last_closed_connection"=>{"type"=>"", "days"=>"", "date"=>"", "date_range"=>""}, "meetingconnection_status" => ""}.merge(RequestsStatus.default_requests_filters), "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"1", "value"=>"80"}}, "others"=>{"tags"=>""}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::MENTORS_WITH_LOW_PROFILE_SCORES }
      }
    }

    MENTEES_WITH_LOW_PROFILE_SCORES = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.admin_view.mentees_with_low_profile_scores_title".translate(Mentees: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term) },
        description: ->{ "feature.abstract_view.admin_view.mentees_with_low_profile_scores_description".translate(Mentees: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term) },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::STUDENT_NAME]}, "state"=>{"active" => User::Status::ACTIVE}}, "connection_status"=>{"availability"=>{"operator"=>"", "value"=>""}, "last_closed_connection"=>{"type"=>"", "days"=>"", "date"=>"", "date_range"=>""}, "meetingconnection_status" => ""}.merge(RequestsStatus.default_requests_filters), "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"1", "value"=>"80"}}, "others"=>{"tags"=>""}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::MENTEES_WITH_LOW_PROFILE_SCORES }
      }
    }

    MENTORS_IN_DRAFTED_CONNECTIONS = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.admin_view.mentors_in_drafted_connections_title".translate(Mentors: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term, Connections: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term) },
        description: ->{ "feature.abstract_view.admin_view.mentors_in_drafted_connections_description".translate(Mentors: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term, connections: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase) },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::MENTOR_NAME]}, "state"=> {"active" => User::Status::ACTIVE, "pending" => User::Status::PENDING}}, "connection_status"=>{"status_filters"=>{"status_filter_1"=>{"category"=>ConnectionStatusCategoryKey::ADVANCED_FILTERS, "type"=>ConnectionStatusTypeKey::DRAFTED, "operator"=>ConnectionStatusOperatorKey::GREATER_THAN, "countvalue"=>0}}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => ""}.merge(RequestsStatus.default_requests_filters), "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::MENTORS_IN_DRAFTED_CONNECTIONS }
      }
    }

    MENTEES_IN_DRAFTED_CONNECTIONS = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.admin_view.mentees_in_drafted_connections_title".translate(Mentees: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term, Connections: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term) },
        description: ->{ "feature.abstract_view.admin_view.mentees_in_drafted_connections_description".translate(Mentees: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term, connections: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase) },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::STUDENT_NAME]}, "state"=> {"active" => User::Status::ACTIVE, "pending" => User::Status::PENDING}}, "connection_status"=>{"status_filters"=>{"status_filter_1"=>{"category"=>ConnectionStatusCategoryKey::ADVANCED_FILTERS, "type"=>ConnectionStatusTypeKey::DRAFTED, "operator"=>ConnectionStatusOperatorKey::GREATER_THAN, "countvalue"=>0}}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => ""}.merge(RequestsStatus.default_requests_filters), "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::MENTEES_IN_DRAFTED_CONNECTIONS }
      }
    }

    MENTORS_YET_TO_BE_DRAFTED = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.admin_view.mentors_yet_to_be_drafted_title".translate(Mentors: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term) },
        description: ->{ "feature.abstract_view.admin_view.mentors_yet_to_be_drafted_description".translate(Mentors: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term, connections: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase) },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::MENTOR_NAME]}, "state"=> {"active" => User::Status::ACTIVE, "pending" => User::Status::PENDING}}, "connection_status"=>{"status_filters"=>{"status_filter_1"=>{"category"=>ConnectionStatusCategoryKey::ADVANCED_FILTERS, "type"=>ConnectionStatusTypeKey::DRAFTED, "operator"=>ConnectionStatusOperatorKey::EQUALS_TO, "countvalue"=>0}, "status_filter_2"=>{"category"=>"", "type"=>ConnectionStatusTypeKey::ONGOING, "operator"=>ConnectionStatusOperatorKey::EQUALS_TO, "countvalue"=>0}}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => ""}.merge(RequestsStatus.default_requests_filters), "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::MENTORS_YET_TO_BE_DRAFTED }
      }
    }

    MENTEES_YET_TO_BE_DRAFTED = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.admin_view.mentees_yet_to_be_drafted_title".translate(Mentees: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term) },
        description: ->{ "feature.abstract_view.admin_view.mentees_yet_to_be_drafted_description".translate(Mentees: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term, connections: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase) },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::STUDENT_NAME]}, "state"=> {"active" => User::Status::ACTIVE, "pending" => User::Status::PENDING}}, "connection_status"=>{"status_filters"=>{"status_filter_1"=>{"category"=>ConnectionStatusCategoryKey::ADVANCED_FILTERS, "type"=>ConnectionStatusTypeKey::DRAFTED, "operator"=>ConnectionStatusOperatorKey::EQUALS_TO, "countvalue"=>0}, "status_filter_2"=>{"category"=>"", "type"=>ConnectionStatusTypeKey::ONGOING, "operator"=>ConnectionStatusOperatorKey::EQUALS_TO, "countvalue"=>0}}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => ""}.merge(RequestsStatus.default_requests_filters), "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::MENTEES_YET_TO_BE_DRAFTED }
      }
    }

    MENTORS_WITH_PENDING_MENTOR_REQUESTS = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.admin_view.mentors_with_pending_mentor_requests_title".translate(Mentors: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term, Mentoring: program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term) },
        description: ->{ "feature.abstract_view.admin_view.mentors_with_pending_mentor_requests_description".translate(Mentors: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term, mentoring: program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase) },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::MENTOR_NAME]}, "state"=> {"active" => User::Status::ACTIVE}}, "connection_status"=>{"mentoring_requests"=>{"mentors"=> RequestsStatus::SENT_OR_RECEIVED_WITH_PENDING_ACTION}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => "", "meeting_requests" => {"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::MENTORS_WITH_PENDING_MENTOR_REQUESTS }
      }
    }

    MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.admin_view.mentees_who_sent_request_but_not_connected_title".translate(Mentees: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term, Mentoring: program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term) },
        description: ->{ "feature.abstract_view.admin_view.mentees_who_sent_request_but_not_connected_description".translate(Mentees: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term, mentoring: program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase) },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::STUDENT_NAME]}, "state"=> {"active" => User::Status::ACTIVE}}, "connection_status"=>{"mentoring_requests"=>{"mentees"=> RequestsStatus::SENT_OR_RECEIVED}, "status_filters"=>{"status_filter_1"=>{"category"=>ConnectionStatusCategoryKey::NEVER_CONNECTED}}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => "", "meeting_requests" => {"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED }
      }
    }

    MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.admin_view.mentees_who_havent_sent_mentoring_request_title".translate(Mentees: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term, Mentoring: program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term) },
        description: ->{ "feature.abstract_view.admin_view.mentees_who_havent_sent_mentoring_request_description".translate(Mentees: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term, mentoring: program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase) },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::STUDENT_NAME]}, "state"=> {"active" => User::Status::ACTIVE}},"connection_status"=>{"mentoring_requests"=>{"mentees"=> RequestsStatus::NOT_SENT_OR_RECEIVED}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => "", "meeting_requests" => {"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST }
      }
    }

    AVAILABLE_MENTORS = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.admin_view.available_mentors_title".translate(Mentors: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term) },
        description: ->{ "feature.abstract_view.admin_view.available_mentors_description".translate(Mentors: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term, connections: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase) },
        filter_params: ->{ AbstractView.convert_to_yaml( {"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::MENTOR_NAME]}, "state"=> {"active" => User::Status::ACTIVE}}, "connection_status"=>{"availability"=>{"operator"=>AdminViewsHelper::QuestionType::HAS_GREATER_THAN.to_s, "value"=>"0"}, "meetingconnection_status" => "", "meeting_requests" => {"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} ) },
        default_view: -> { AbstractView::DefaultType::AVAILABLE_MENTORS }
      }
    }

    class << self
      def all
        [ACCEPTED_BUT_NOT_JOINED, NEVER_CONNECTED_MENTEES, CURRENTLY_NOT_CONNECTED_MENTEES, USERS_WITH_LOW_PROFILE_SCORES, MENTORS_REGISTERED_BUT_NOT_ACTIVE, MENTEES_REGISTERED_BUT_NOT_ACTIVE, MENTORS_WITH_LOW_PROFILE_SCORES, MENTEES_WITH_LOW_PROFILE_SCORES, MENTORS_IN_DRAFTED_CONNECTIONS, MENTEES_IN_DRAFTED_CONNECTIONS, MENTORS_YET_TO_BE_DRAFTED, MENTEES_YET_TO_BE_DRAFTED, NEVER_CONNECTED_MENTORS, MENTORS_WITH_PENDING_MENTOR_REQUESTS, MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED, MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST, AVAILABLE_MENTORS]
      end
    end
  end

  scope :favourites, -> { where(favourite: true) }
  has_many :admin_view_columns, -> {order "admin_view_columns.position asc, admin_view_columns.id asc"}, :dependent => :destroy
  has_many :diversity_reports, dependent: :destroy
  has_many :program_events
  has_many :resource_publications
  has_many :mentor_view_bulk_matches, class_name: "AbstractBulkMatch", foreign_key: "mentor_view_id"
  has_many :mentee_view_bulk_matches, class_name: "AbstractBulkMatch", foreign_key: "mentee_view_id"
  has_one :admin_view_user_cache, dependent: :destroy
  has_many :match_report_admin_views
  belongs_to :role

  attr_accessor :skip_observer
  validates :favourited_at, presence: true, if: ->(admin_view){ admin_view.favourite? }

  MAX_CONNECTIONS_UPPER_BOUND = 100
  ### Needed for Sphinx search limits ###
  MIN_LIMIT = 0
  MAX_LIMIT = 1000000
  DEFAULT_SORT_ORDER = "asc"
  DEFAULT_SORT_PARAM = "first_name"
  MEMBER_WITH_ONGOING_ENGAGEMENTS_FILTER_HSH = ActiveSupport::HashWithIndifferentAccess.new({"field" => AdminViewColumn::Columns::Key::ORG_LEVEL_ONGOING_ENGAGEMENTS, "operator" => AdminView::KendoNumericOperators::GREATER, "value" => 0})
  MEMBERS_IN_SPECIFIED_PROGRAMS = Proc.new { |program_ids|
    ActiveSupport::HashWithIndifferentAccess.new({"field" => AdminViewColumn::Columns::Key::PROGRAM_USER_ROLES, "operator" => AdminView::KendoNumericOperators::EQUAL, "value" => program_ids})
  }

  def self.add_tags(user_ids, tag_list)
    users = User.where(:id => user_ids)
    users.each do |user|
    tags_to_add = (tag_list.split(",") || []) - user.tag_list
      if tags_to_add.present?
        user.tag_list = (user.tag_list + tags_to_add).join(', ')
        user.save!
      end
    end
  end

  def self.remove_tags(user_ids, tag_list)
    users = User.where(id: user_ids)
    split_tag_list = tag_list.split(",")
    users.each do |user|
      user.tag_list = (user.tag_list - split_tag_list).join(', ')
      user.save!
    end
  end

  def report_to_stream(stream, user_or_member_ids, admin_view_columns, date_ranges = nil)
    columns = admin_view_columns.includes(:profile_question => :translations)

    # receive max possible values by column ids
    keys = columns.collect(&:column_key)
    options = get_options_for(keys)
    availability_slots_hash = options.delete(:availability_slots_hash)
    net_recommended_count_hash = options.delete(:net_recommended_count_hash)

    max_answer_count = get_max_answers(columns)

    column_titles = get_column_titles(columns, max_answer_count)
    stream << CSV::Row.new(column_titles, column_titles).to_s

    slice_size = [1 + user_or_member_ids.size / CSV_PROCESSES, CSV_USER_SLICE_SIZE].min
    has_slots_key = keys.include?(AdminViewColumn::Columns::Key::AVAILABLE_SLOTS)
    has_net_recommended_count_key = keys.include?(AdminViewColumn::Columns::Key::NET_RECOMMENDED_COUNT)
    has_roles_key = keys.include?(AdminViewColumn::Columns::Key::ROLES)
    has_program_user_roles_key = keys.include?(AdminViewColumn::Columns::Key::PROGRAM_USER_ROLES)
    has_last_closed_connection = keys.include?(AdminViewColumn::Columns::Key::LAST_CLOSED_GROUP_TIME)
    has_rating_key = keys.include?(AdminViewColumn::Columns::Key::RATING)
    has_meeting_request_keys = (keys & AdminViewColumn::Columns::Key.meeting_request_columns).present?
    has_mentoring_request_keys = (keys & AdminViewColumn::Columns::Key.mentoring_request_columns).present?
    has_mentoring_mode_key = keys.include?(AdminViewColumn::Columns::Key::MENTORING_MODE)

    if is_program_view?
      # adding Meeting Requests Counts into options
      handle_meeting_requests_count_for_csv(keys, program, date_ranges, options)
      # adding Mentoring Requests Counts into options
      handle_mentoring_requests_count_for_csv(keys, program, date_ranges, options)
    end

    options.merge!(organization: organization)

    user_or_member_ids_slices = user_or_member_ids.each_slice(slice_size).to_a
    user_or_member_ids_slices.each_slice(CSV_PROCESSES) do |slice|
      Parallel.each(slice, in_processes: CSV_PROCESSES) do |ids|
        # Reconnect DB for each fork (once per each)
        @reconnected ||= User.connection.reconnect!

        # collect users or members dependent of current view
        user_or_member_hashes = is_program_view? ? User.connection.select_all(users_scope.where(id: ids)): Member.connection.select_all(members_scope.where(id: ids))

        if is_program_view?
          # collect roles
          users_role_names = (has_slots_key || has_net_recommended_count_key || has_roles_key || has_rating_key || has_meeting_request_keys || has_mentoring_request_keys) ? users_with_role_names(ids) : {}
          options.merge!(users_role_names: users_role_names)

          # user rating
          users_rating = has_rating_key && program.coach_rating_enabled? ? users_with_rating(ids) : {}
          options.merge!(rating: users_rating)

          #mentoring mode
          users_mentoring_mode = has_mentoring_mode_key ? users_with_mentoring_mode(ids) : {}
          options.merge!(mentoring_mode: users_mentoring_mode)
        end

        if is_organization_view? && has_program_user_roles_key
          # collect program roles
          members_program_role_names = Member.members_with_role_names_and_deactivation_dates(ids, self.organization, only_suspended_status: true)
          options.merge!(members_program_role_names: members_program_role_names)
        end

        # profile answers
        member_ids = is_program_view? ? user_or_member_hashes.map { |user_hash| user_hash['member_id'] } : ids
        profile_answers_hash = Member.prepare_answer_hash(member_ids, admin_view_columns.custom.pluck(:profile_question_id))

        if is_program_view? && keys.include?(AdminViewColumn::Columns::Key::PROFILE_SCORE)
          profile_answers_hash[:users_with_score_hash] = Hash[get_users_with_profile_scores(ids).map{|user_profile| [user_profile.id.to_i, user_profile.profile_score_sum]}]
        end

        user_last_connection_time_hash = Hash[User.connection.execute(User.joins(:last_closed_group).where(id: ids).select("users.id, groups.closed_at").to_sql).to_a] if has_last_closed_connection
        # iterate users
        user_or_member_hashes.each do |user_or_member_hash|
          if is_program_view?
            user_id = user_or_member_hash['id']
            user_or_member_hash["last_closed_group_time"] = DateTime.localize(user_last_connection_time_hash[user_id]) || "" if has_last_closed_connection
            if users_role_names[user_id].present?
              options[:is_mentor] = users_role_names[user_id].include?(RoleConstants::MENTOR_NAME)
              options[:is_student] = users_role_names[user_id].include?(RoleConstants::STUDENT_NAME)
            end
            if options[:is_mentor]
              options[:slots_available] = [user_or_member_hash['max_connections_limit'] - availability_slots_hash[user_id].to_i, 0].max if has_slots_key
              options[:net_recommended_count] = net_recommended_count_hash[user_id] if has_net_recommended_count_key
            end
          end
          answers = get_answers_for(user_or_member_hash, columns, max_answer_count, profile_answers_hash, options.merge(use_scope: false))
          stream << CSV::Row.new(column_titles, answers).to_s
        end
      end
    end
  end

  def users_scope
    include_members_users_language_scope User.where(program_id: program).select(user_fields_for_csv).joins(:member).
        # join active_groups
        joins("LEFT JOIN connection_memberships ON connection_memberships.user_id=users.id").
        joins("LEFT JOIN groups ON groups.id=connection_memberships.group_id").
        group('users.id')
  end

  def members_scope
    include_members_users_language_scope Member.where(organization_id: organization).select(member_fields_for_csv).joins("LEFT JOIN users ON users.member_id=members.id").joins("LEFT JOIN connection_memberships ON connection_memberships.user_id=users.id").joins("LEFT JOIN groups ON groups.id=connection_memberships.group_id").group('members.id')
  end

  def user_fields_for_csv
    include_language_field_for_user_and_member [
      # user
      'users.id', 'users.member_id', 'users.max_connections_limit', 'users.state',
      'users.created_at', 'users.last_seen_at', 'users.last_deactivated_at',
      # member
      'members.terms_and_conditions_accepted', 'members.first_name', 'members.last_name', 'members.email',
      # active_groups
      "sum(case when groups.status NOT IN (#{Group::Status::NOT_ACTIVE_CRITERIA.join(',')}) then 1 else 0 end) as active_groups_count",
      "sum(case when groups.status IN (#{Group::Status::CLOSED}) then 1 else 0 end) as closed_groups_count",
      "sum(case when groups.status IN (#{Group::Status::DRAFTED}) then 1 else 0 end) as drafted_groups_count"
    ]
  end

  def member_fields_for_csv
    include_language_field_for_user_and_member [
      # member
      'members.id', 'members.terms_and_conditions_accepted', 'members.first_name', 'members.last_name',
      'members.email', 'members.state', 'members.last_suspended_at',
      # active_groups
      "sum(case when groups.status IN (#{Group::Status::ACTIVE_CRITERIA.join(',')}) then 1 else 0 end) as ongoing_engagements_count",
      "sum(case when groups.status IN (#{Group::Status::CLOSED}) then 1 else 0 end) as closed_engagements_count"
    ]
  end

  def create_default_columns
    self.get_default_columns.keys.each_with_index do |column_key, position|
      self.admin_view_columns.create!(:column_key => column_key, :position => position)
    end
  end

  def get_default_columns
    options = get_column_title_translation_keys
    if self.is_organization_view?
      AdminViewColumn::Columns::OrganizationDefaults.defaults
    elsif self.default_view == AbstractView::DefaultType::ALL_ADMINS
      AdminViewColumn::Columns::ProgramDefaults.admin_defaults
    else
     AdminViewColumn::Columns::ProgramDefaults.defaults(options)
    end
  end

  def get_columns_of_question_type(type)
    admin_view_columns.joins(:profile_question).where("profile_questions.question_type = ?", type).pluck(:id)
  end

  def languages_filter_enabled?
    organization.languages_filter_enabled?
  end

  def language_columns_exists?
    admin_view_columns.where(column_key: AdminViewColumn::Columns::Key::LANGUAGE).exists?
  end

  def save_admin_view_columns!(columns_array)
    admin_view_columns = self.admin_view_columns.dup.to_a
    module_obj = self.is_program_view? ? AdminViewColumn::Columns::ProgramDefaults : AdminViewColumn::Columns::OrganizationDefaults
    columns_array.each_with_index do |column_string, index|
      column_string = column_string.split(AdminViewColumn::COLUMN_SPLITTER).last
      column_object = AdminViewColumn.find_object(admin_view_columns, column_string, self)
      if column_object.present?
        column_object.update_attributes!(:position => index)
        admin_view_columns.delete(column_object)
      else
        attrs = module_obj.has?(column_string) ? {:column_key => column_string} : {:profile_question_id => column_string.to_i}
        attrs.merge!({column_sub_key: column_string.split(AdminViewColumn::ID_SUBKEY_JOINER)[1]}) if column_string.include?(AdminViewColumn::ID_SUBKEY_JOINER)
        column_object = AdminViewColumn.create!({:admin_view => self, :position => index}.merge(attrs))
      end
    end
    admin_view_columns.each{|column| column.destroy}
  end

  def generate_view(sort_param, sort_order, sort_needed = true, pagination_options = {}, dynamic_filter_params = {}, alert=nil, date_ranges = {}, other_options = {})
    options = {
      page: 1,
      per_page: ES_MAX_PER_PAGE,
      pagination_options: pagination_options,
      includes_list: self.admin_view_columns.include?(AdminViewColumn::Columns::Key::LAST_CLOSED_GROUP_TIME) ? [:last_closed_group] : []
    }
    options[:includes_list] << (self.is_program_view? ? {member: [member_language: :language]} : {member_language: :language}) if self.language_columns_exists?
    if self.is_program_view?
      generate_program_view(sort_param, sort_order, sort_needed, options, dynamic_filter_params, alert, date_ranges)
    else
      generate_organization_view(sort_param, sort_order, sort_needed, options, dynamic_filter_params)
    end
  end

  def refresh_user_ids_cache
    user_ids = self.generate_view("", "",false).to_a
    self.create_or_update_user_ids_cache(user_ids)
  end

  def create_or_update_user_ids_cache(user_ids)
    admin_view_user_cache = AdminViewUserCache.find_or_initialize_by(admin_view_id: self.id)
    admin_view_user_cache.last_cached_at = DateTime.now.utc
    admin_view_user_cache.user_ids = user_ids.join(",")
    admin_view_user_cache.save!
    admin_view_user_cache
  end

  def can_create_admin_view_user_cache?
    self.is_program_view? && self.admin_view_user_cache.nil?
  end

  def profile_question_text_method
    is_program_view? ? [:question_text_with_mandatory_mark, program.roles] : [:question_text]
  end

  def count(alert=nil, options = {})
    # This will fetch only ids
    generate_view(nil, nil, false, {count_only: true}, (options[:dynamic_filter_params] || {}), alert)
  end

  def fetch_all_users_or_members
    (self.is_program_view? ? User : Member).where(id: self.generate_view("", "", false))
  end

  def fetch_all_member_ids(options = {})
    ids = generate_view(nil, nil, false, {}, (options[:dynamic_filter_params] || {}))
    self.is_organization_view? ? ids : Member.member_ids_of_users(user_ids: ids)
  end

  def favourite_image_path
    self.favourite ? "fa fa-star" : "fa fa-star-o"
  end

  def set_favourite!
    self.favourite = true
    self.favourited_at = Time.now
    self.save!
  end

  def unset_favourite!
    self.favourite = false
    self.favourited_at = nil
    self.save!
  end

  def self.get_admin_views_ordered(admin_views)
    time_now = Time.now.to_i
    admin_views.sort_by { |admin_view| admin_view.favourite? ? time_now - admin_view.favourited_at.to_i : time_now + admin_view.created_at.to_i }
  end


  def generate_program_view(sort_param, sort_order, sort_needed, options, dynamic_filter_params, alert, date_ranges)
    with_options = {}
    with_all_options = {}
    without_options = {}
    should_options = []
    should_not_options = []
    pagination_options = options.delete(:pagination_options)

    filter_params = FilterUtils.process_filter_hash_for_alert(self, self.filter_params_hash, alert)

    with_user_ids = process_params!(filter_params, with_options, with_all_options, without_options, should_not_options, should_options)
    with_options.merge!(default_fields_filters(dynamic_filter_params))

    apply_language_filtering!(filter_params, with_options, 'member.')
    apply_role_filter!(dynamic_filter_params, with_options)

    es_order = get_es_search_order(sort_param)

    user_ids = filter_users(with_user_ids, filter_params, dynamic_filter_params)
    user_ids = sort_users_or_members(user_ids, sort_param, sort_order, User, date_ranges) if sort_needed && es_order.blank?

    options.merge!(must_filters: with_options.merge!(program_id: self.program.id, id: get_es_object_ids(user_ids)), with_all_filters: with_all_options, must_not_filters: without_options, should_filters: should_options, should_not_filters: should_not_options)
    return User.get_filtered_count(options.except(:page, :per_page)) if pagination_options && pagination_options[:count_only]
    ordered_objects(User, user_ids, {order: es_order, sort_order: sort_order, sort_param: sort_param}, options, pagination_options)
  end

  def generate_organization_view(sort_param, sort_order, sort_needed, options, dynamic_filter_params)
    with_options = {}
    pagination_options = options.delete(:pagination_options)
    filter_params = self.filter_params_hash

    apply_role_and_state_member_filtering!(filter_params, with_options)
    process_advanced_connection_status_filters!(filter_params[:member_status], with_options) if filter_params[:member_status].present?
    apply_language_filtering!(filter_params, with_options, '')
    options[:member_ids] = collect_members_based_on_program_roles_and_states(filter_params) unless filter_params[:program_role_state][:all_members].to_s.to_boolean
    member_ids = filter_members(options, filter_params, dynamic_filter_params)
    return member_ids if options[:only_profile_filters]

    defaults_filters = default_fields_filters(dynamic_filter_params)
    with_options.merge!(defaults_filters.except(:member_id))
    member_ids &= [defaults_filters[:member_id]] if defaults_filters[:member_id].present?

    es_order = get_es_search_order(sort_param)
    member_ids = sort_users_or_members(member_ids, sort_param, sort_order, Member, dynamic_filter_params) if sort_needed && es_order.blank?

    options.merge!(must_filters: with_options.merge({organization_id: self.organization.id, id: get_es_object_ids(member_ids)}))
    return Member.get_filtered_count(options.except(:page, :per_page)) if pagination_options && pagination_options[:count_only]
    ordered_objects(Member, member_ids, {order: es_order, sort_order: sort_order, sort_param: sort_param}, options, pagination_options)
  end

  def collect_members_based_on_program_roles_and_states(filter_params)
    must_options = {program_id: self.organization.program_ids}
    selected_members = get_selected_members(program_role_state_hash(filter_params), must_options)
    filter_params[:program_role_state][:inclusion] == ProgramRoleStateFilterObjectKey::INCLUDE ? selected_members : self.organization.members.pluck(:id) - selected_members
  end

  def program_role_state_hash(filter_params)
    filter_params[:program_role_state][:filter_conditions]
  end

  def get_selected_members(program_role_state_hash_param, must_options)
    selected_members = self.organization.members.pluck(:id)
    program_role_state_hash_param.values.each do |and_filter|
      should_options = []
      include_and_filter = true
      filter_hash_array = []
      and_filter.values.each do |or_filter|
        must_filters_hash = generate_program_role_state_es_filter(or_filter)
        must_filters_hash.present? ? (filter_hash_array << {must_filters: must_filters_hash}) : (include_and_filter = false)
      end
      should_options << {filters: filter_hash_array} if (filter_hash_array.present? && include_and_filter)
      options = {must_filters: must_options}
      options.merge!(should_filters: should_options) if should_options.present?
      selected_members &= User.where(id: User.get_filtered_ids(options)).pluck(:member_id)
    end
    selected_members
  end

  def generate_program_role_state_es_filter(or_filter)
    es_filter = {}
    es_filter[:state] = or_filter[:state] if or_filter[:state]&.delete_if(&:blank?).present?
    es_filter[:program_id] = or_filter[:program] if or_filter[:program]&.delete_if(&:blank?).present?
    es_filter["roles.name"] = or_filter[:role] if or_filter[:role]&.delete_if(&:blank?).present?
    es_filter
  end

  def apply_language_filtering!(filter_params, with_options, key_prefix)
    state_key = "#{key_prefix}state"
    language_id = "#{key_prefix}member_language_id"
    if filter_params[:language].present? && languages_filter_enabled?
      with_options[state_key] = apply_state_condition_value(with_options[state_key], Member::Status.all_except(Member::Status::DORMANT))
      with_options[language_id] = filter_params[:language].is_a?(Array) ? filter_params[:language].map(&:to_i) : filter_params[:language].to_i
    end
  end

  def get_included_roles_string(hsh = nil)
    (hsh || filter_params_hash[:roles_and_status] || {}).select{|key, val| key.match(/role_filter/) && val[:type].try(:to_sym) == :include }.map{|key, val| val[:roles]}.flatten.compact.uniq.join(",")
  end

  def process_role_status_params!(filter_params, with_options, with_all_options, should_not_options, should_options)
    process_role_params(filter_params, with_all_options, should_not_options)
    with_options.merge!({state: filter_params[:state].values}) if filter_params[:state].present?
    process_status_params(filter_params, should_options)
  end

  def process_connection_status_params!(filter_params, selected_roles, with_options, without_options)
    with_user_ids = self.program.users.pluck(:id)
    roles_array = selected_roles.split(",")

    if filter_params.present?

      if roles_array.include?(RoleConstants::MENTOR_NAME)
        if filter_params[:availability].present? && filter_params[:availability][:operator].present?
          range = if filter_params[:availability][:operator] == AdminViewsHelper::QuestionType::HAS_GREATER_THAN.to_s
            (filter_params[:availability][:value].to_i + 1)..MAX_CONNECTIONS_UPPER_BOUND
          else
            MIN_LIMIT..(filter_params[:availability][:value].to_i - 1)
          end
          with_options.merge!({availability: range})
        end

        ## If Admin requests for Mentors with Time-based mentoring mode, he should
        ## get mentors with Time-based mentoring mode as well as Session & Time-based mentoring mode.
        if self.is_program_view? && self.program.consider_mentoring_mode? && filter_params[:mentoring_model_preference].present?
          engagement_model_pref = filter_params[:mentoring_model_preference].to_i
          modes = []
          modes += User::MentoringMode.ongoing_sanctioned if User::MentoringMode.ongoing_sanctioned.include?(engagement_model_pref)
          modes += User::MentoringMode.one_time_sanctioned if User::MentoringMode.one_time_sanctioned.include?(engagement_model_pref)
          with_options.merge!(mentoring_mode: modes.flatten.uniq) if modes.present?
        end

        # Mentor Rating
        if filter_params.present? && filter_params[:rating].present? && filter_params[:rating][:operator].present? && self.program.coach_rating_enabled?
          delta = UserStat::Rating::DELTA
          min = UserStat::Rating::MIN_RATING
          max = UserStat::Rating::MAX_RATING

          case filter_params[:rating][:operator]
          when AdminViewsHelper::Rating::NOT_RATED
            without_options.merge!(exists_query: 'user_stat.average_rating')
          when AdminViewsHelper::Rating::LESS_THAN
            less_than = filter_params[:rating][:less_than].to_f
            with_options.merge!('user_stat.average_rating' => min..less_than-delta)
          when AdminViewsHelper::Rating::GREATER_THAN
            greater_than = filter_params[:rating][:greater_than].to_f
            with_options.merge!('user_stat.average_rating' => greater_than+delta..max)
          when AdminViewsHelper::Rating::EQUAL_TO
            equal_to = filter_params[:rating][:equal_to].to_f
            with_options.merge!('user_stat.average_rating' => equal_to..equal_to)
          end
        end
      end

      if roles_array.include?(RoleConstants::MENTOR_NAME) || roles_array.include?(RoleConstants::STUDENT_NAME)
        
        if filter_params[:status].present? && self.program.ongoing_mentoring_enabled?
          status = filter_params[:status]
          if status == UsersIndexFilters::Values::CONNECTED
            with_options.merge!(active_user_connections_count: (1..CONNECTION_STATUS_FILTER_MAX_VALUE))
          elsif status == UsersIndexFilters::Values::UNCONNECTED
            with_options.merge!(active_user_connections_count: CONNECTION_STATUS_FILTER_MIN_VALUE)
          elsif status == UsersIndexFilters::Values::NEVERCONNECTED
            with_options.merge!(total_user_connections_count: CONNECTION_STATUS_FILTER_MIN_VALUE)
          end
        end

        if filter_params[:draft_status].present? && self.program.ongoing_mentoring_enabled?
          draft_status = filter_params[:draft_status].to_i
          if draft_status == DraftConnectionStatus::WITH_DRAFTS
            with_options.merge!(draft_connections_count: (1..CONNECTION_STATUS_FILTER_MAX_VALUE))
          elsif draft_status == DraftConnectionStatus::WITHOUT_DRAFTS
            with_options.merge!(draft_connections_count: CONNECTION_STATUS_FILTER_MIN_VALUE)
          end
        end

        # Advanced Connection Status Filters
        process_advanced_connection_status_filters!(filter_params, with_options, self.program)

        if filter_params[:last_closed_connection].present? && filter_params[:last_closed_connection][:type].present? && self.program.ongoing_mentoring_enabled?
          value = case filter_params[:last_closed_connection][:type].to_i
            when TimelineQuestions::Type::BEFORE_X_DAYS
              filter_params[:last_closed_connection][:days]
            when TimelineQuestions::Type::AFTER, TimelineQuestions::Type::BEFORE
              filter_params[:last_closed_connection][:date]
            when TimelineQuestions::Type::DATE_RANGE
              filter_params[:last_closed_connection][:date_range]
          end
          with_options.merge!(last_closed_group_time: get_range(filter_params[:last_closed_connection][:type], value))
        end

        # Mentoring Requests
        without_user_ids = []

        if filter_params[:mentoring_requests].present? && self.is_program_view? && self.program.only_career_based_ongoing_mentoring_enabled?
          if filter_params[:mentoring_requests][:mentees].present? && roles_array.include?(RoleConstants::STUDENT_NAME) && (self.program.matching_by_mentee_and_admin? || self.program.matching_by_mentee_alone?)
            range = get_connection_status_range(filter_params, :mentoring_requests, :mentees)
            case filter_params[:mentoring_requests][:mentees].to_i
            when RequestsStatus::SENT_OR_RECEIVED
              sender_ids = MentorRequest.get_filtered_mentor_requests({}, {:program_id => self.program.id, :created_at => range}, true, ["sender_id"]).collect(&:sender_id)
              with_user_ids &= sender_ids
            when RequestsStatus::SENT_OR_RECEIVED_WITH_PENDING_ACTION
              sender_ids = MentorRequest.get_filtered_mentor_requests({}, {:program_id => self.program.id, :created_at => range, :status => AbstractRequest::Status::NOT_ANSWERED}, true, ["sender_id"]).collect(&:sender_id)
              with_user_ids &= sender_ids
            when RequestsStatus::NOT_SENT_OR_RECEIVED
              sender_ids = MentorRequest.get_filtered_mentor_requests({}, {:program_id => self.program.id, :created_at => range}, true, ["sender_id"]).collect(&:sender_id)
              without_user_ids |= sender_ids
            end
          end

          if filter_params[:mentoring_requests][:mentors].present? && roles_array.include?(RoleConstants::MENTOR_NAME) && self.program.matching_by_mentee_alone?
            range = get_connection_status_range(filter_params, :mentoring_requests, :mentors)
            case filter_params[:mentoring_requests][:mentors].to_i
            when RequestsStatus::SENT_OR_RECEIVED
              receiver_ids = MentorRequest.get_filtered_mentor_requests({}, {:program_id => self.program.id, :created_at => range}, true, ["receiver_id"]).collect(&:receiver_id)
              with_user_ids &= receiver_ids
            when RequestsStatus::SENT_OR_RECEIVED_WITH_PENDING_ACTION
              receiver_ids = MentorRequest.get_filtered_mentor_requests({}, {:program_id => self.program.id, :created_at => range, :status => AbstractRequest::Status::NOT_ANSWERED}, true, ["receiver_id"]).collect(&:receiver_id)
              with_user_ids &= receiver_ids
            when RequestsStatus::RECEIVED_WITH_REJECTED_ACTION
              receiver_ids = MentorRequest.get_filtered_mentor_requests({}, {:program_id => self.program.id, :created_at => range, :status => AbstractRequest::Status::REJECTED}, true, ["receiver_id"]).collect(&:receiver_id)
              with_user_ids &= receiver_ids
            when RequestsStatus::RECEIVED_WITH_CLOSED_ACTION
              receiver_ids = MentorRequest.get_filtered_mentor_requests({}, {:program_id => self.program.id, :created_at => range, :status => AbstractRequest::Status::CLOSED}, true, ["receiver_id"]).collect(&:receiver_id)
              with_user_ids &= receiver_ids
            when RequestsStatus::NOT_SENT_OR_RECEIVED
              receiver_ids = MentorRequest.get_filtered_mentor_requests({}, {:program_id => self.program.id, :created_at => range}, true, ["receiver_id"]).collect(&:receiver_id)
              without_user_ids |= receiver_ids
            end
          end
        end

        # Meeting Requests

        if filter_params[:meeting_requests].present? && self.is_program_view? && self.program.calendar_enabled?
          if filter_params[:meeting_requests][:mentees].present? && roles_array.include?(RoleConstants::STUDENT_NAME)
            range = get_connection_status_range(filter_params, :meeting_requests, :mentees)
            case filter_params[:meeting_requests][:mentees].to_i
            when RequestsStatus::SENT_OR_RECEIVED
              sender_ids = MeetingRequest.get_es_meeting_requests({program_id: self.program.id, created_at: range}, ["sender_id"]).collect(&:sender_id)
              with_user_ids &= sender_ids
            when RequestsStatus::SENT_OR_RECEIVED_WITH_PENDING_ACTION
              sender_ids = MeetingRequest.get_es_meeting_requests({program_id: self.program.id, created_at: range, status: AbstractRequest::Status::NOT_ANSWERED}, ["sender_id"]).collect(&:sender_id)
              with_user_ids &= sender_ids
            when RequestsStatus::NOT_SENT_OR_RECEIVED
              sender_ids = MeetingRequest.get_es_meeting_requests({program_id: self.program.id, created_at: range}, ["sender_id"]).collect(&:sender_id)
              without_user_ids |= sender_ids
            end
          end

          if filter_params[:meeting_requests][:mentors].present? && roles_array.include?(RoleConstants::MENTOR_NAME)
            range = get_connection_status_range(filter_params, :meeting_requests, :mentors)
            case filter_params[:meeting_requests][:mentors].to_i
            when RequestsStatus::SENT_OR_RECEIVED
              receiver_ids = MeetingRequest.get_es_meeting_requests({program_id: self.program.id, created_at: range}, ["receiver_id"]).collect(&:receiver_id)
              with_user_ids &= receiver_ids
            when RequestsStatus::SENT_OR_RECEIVED_WITH_PENDING_ACTION
              receiver_ids = MeetingRequest.get_es_meeting_requests({program_id: self.program.id, created_at: range, status: AbstractRequest::Status::NOT_ANSWERED}, ["receiver_id"]).collect(&:receiver_id)
              with_user_ids &= receiver_ids
            when RequestsStatus::RECEIVED_WITH_REJECTED_ACTION
              receiver_ids = MeetingRequest.get_es_meeting_requests({program_id: self.program.id, created_at: range, status: AbstractRequest::Status::REJECTED}, ["receiver_id"]).collect(&:receiver_id)
              with_user_ids &= receiver_ids
            when RequestsStatus::RECEIVED_WITH_CLOSED_ACTION
              receiver_ids = MeetingRequest.get_es_meeting_requests({program_id: self.program.id, created_at: range, status: AbstractRequest::Status::CLOSED}, ["receiver_id"]).collect(&:receiver_id)
              with_user_ids &= receiver_ids
            when RequestsStatus::NOT_SENT_OR_RECEIVED
              receiver_ids = MeetingRequest.get_es_meeting_requests({program_id: self.program.id, created_at: range}, ["receiver_id"]).collect(&:receiver_id)
              without_user_ids |= receiver_ids
            end
          end
        end

        # Meeting Connection Status

        if filter_params[:meetingconnection_status].present? && self.is_program_view? && self.program.calendar_enabled?
          range = get_connection_status_range(filter_params, :meetingconnection_status, :both)
          requests_in_range = MeetingRequest.get_es_meeting_requests({program_id: self.program.id, accepted_at: range, status: AbstractRequest::Status::ACCEPTED}, ["sender_id", "receiver_id"])
          case filter_params[:meetingconnection_status].to_i
          when UserMeetingConnectionStatus::CONNECTED
            with_user_ids &= (requests_in_range.collect(&:sender_id)|requests_in_range.collect(&:receiver_id))
          when UserMeetingConnectionStatus::NOT_CONNECTED
            without_user_ids |= (requests_in_range.collect(&:sender_id)|requests_in_range.collect(&:receiver_id))
          end
        end

        # Mentor Recommendation
        if filter_params[:mentor_recommendations].present? && filter_params[:mentor_recommendations][:mentees].present? && can_show_mentor_recommendation_filter?(roles_array)
          range = get_connection_status_range(filter_params, :mentor_recommendations, :mentees)
          requests_in_range = MentorRecommendation.get_filtered_source_columns({must_filters: {program_id: self.program.id, published_at: range, status: MentorRecommendation::Status::PUBLISHED}, source_columns: ["receiver_id"]})
          case filter_params[:mentor_recommendations][:mentees].to_i
          when MentorRecommendationFilter::MENTEE_RECEIVED
            with_user_ids &= requests_in_range.collect(&:receiver_id)
          when MentorRecommendationFilter::MENTEE_NOT_RECEIVED
            without_user_ids |= requests_in_range.collect(&:receiver_id)
          end
        end

        without_options.merge!(id: without_user_ids) if without_user_ids.size > 0
      end
    end

    return with_user_ids
  end

  def self.programs_type_hash
    {ConnectionStatusTypeKey::ONGOING => :active_user_connections_count, ConnectionStatusTypeKey::CLOSED =>:closed_user_connections_count, ConnectionStatusTypeKey::ONGOING_OR_CLOSED => :total_user_connections_count}
  end

  def self.organization_type_hash 
    {ConnectionStatusTypeKey::ONGOING => :ongoing_engagements_count, ConnectionStatusTypeKey::CLOSED => :closed_engagements_count, ConnectionStatusTypeKey::ONGOING_OR_CLOSED => :total_engagements_count}
  end

  def self.programs_category_hash
    {ConnectionStatusCategoryKey::NEVER_CONNECTED => :total_user_connections_count_max, ConnectionStatusCategoryKey::CURRENTLY_CONNECTED =>:active_user_connections_count_min, ConnectionStatusCategoryKey::CURRENTLY_UNCONNECTED => :active_user_connections_count_max, ConnectionStatusCategoryKey::FIRST_TIME_CONNECTED => [:closed_user_connections_count_max, :active_user_connections_count_min], ConnectionStatusCategoryKey::CONNECTED_CURRENTLY_OR_PAST => :total_user_connections_count_min}
  end

  def self.organization_category_hash 
    {ConnectionStatusCategoryKey::NEVER_CONNECTED => :total_engagements_count_max, ConnectionStatusCategoryKey::CURRENTLY_CONNECTED =>:ongoing_engagements_count_min, ConnectionStatusCategoryKey::CURRENTLY_UNCONNECTED => :ongoing_engagements_count_max, ConnectionStatusCategoryKey::FIRST_TIME_CONNECTED => [:closed_engagements_count_max, :ongoing_engagements_count_min], ConnectionStatusCategoryKey::CONNECTED_CURRENTLY_OR_PAST => :total_engagements_count_min}
  end

  def self.get_category_hash_key(category, program_lvl)
    program_lvl ? self.programs_category_hash[category] : self.organization_category_hash[category] 
  end 

  def self.get_type_hash_key(type, program_lvl)
    program_lvl ? self.programs_type_hash[type] : self.organization_type_hash[type] 
  end 

  def process_advanced_connection_status_filters!(filter_params, with_options, program=nil)
    return if program.present? && !program.ongoing_mentoring_enabled?

    filters = program.present? ? filter_params[:status_filters] : filter_params[:connection_status]
    if filters.present?
      es_indices = program.present? ? [:active_user_connections_count, :closed_user_connections_count, :total_user_connections_count, :draft_connections_count] : [:ongoing_engagements_count, :closed_engagements_count, :total_engagements_count]
      program_lvl = program.present?
      data_hsh = {}
      es_idx_to_key = ->(es_idx, min_or_max) { "#{es_idx}_#{min_or_max}".to_sym }
      es_indices.each do |idx|
        data_hsh[es_idx_to_key[idx, :min]] = CONNECTION_STATUS_FILTER_MIN_VALUE
        data_hsh[es_idx_to_key[idx, :max]] = CONNECTION_STATUS_FILTER_MAX_VALUE
      end
      (filters.try(:values) || []).each do |hsh|
        category_key = AdminView.get_category_hash_key(hsh[ConnectionStatusFilterObjectKey::CATEGORY], program_lvl)
        type_key = AdminView.get_type_hash_key(hsh[ConnectionStatusFilterObjectKey::TYPE], program_lvl)
        
        case hsh[ConnectionStatusFilterObjectKey::CATEGORY]
        when ConnectionStatusCategoryKey::NEVER_CONNECTED
          data_hsh[category_key] = 0 
        when ConnectionStatusCategoryKey::CURRENTLY_CONNECTED
          data_hsh[category_key] = 1
        when ConnectionStatusCategoryKey::CURRENTLY_UNCONNECTED
          data_hsh[category_key] = 0
        when ConnectionStatusCategoryKey::FIRST_TIME_CONNECTED
          data_hsh[category_key.first ] = 0
          data_hsh[category_key.second ] = 1
        when ConnectionStatusCategoryKey::CONNECTED_CURRENTLY_OR_PAST
          data_hsh[category_key] = 1
        when ConnectionStatusCategoryKey::ADVANCED_FILTERS, "" # pls note an value "" also should end up here which refer to advanced filters, it is default case from second entry in UI
          next if hsh[ConnectionStatusFilterObjectKey::COUNT_VALUE].blank? || hsh[ConnectionStatusFilterObjectKey::OPERATOR].blank? || hsh[ConnectionStatusFilterObjectKey::TYPE].blank?
          count_value = hsh[ConnectionStatusFilterObjectKey::COUNT_VALUE].to_i
          min_value, max_value = [CONNECTION_STATUS_FILTER_MIN_VALUE, CONNECTION_STATUS_FILTER_MAX_VALUE]
          case hsh[ConnectionStatusFilterObjectKey::OPERATOR]
          when ConnectionStatusOperatorKey::LESS_THAN
            max_value = count_value - 1
          when ConnectionStatusOperatorKey::EQUALS_TO
            min_value = max_value = count_value
          when ConnectionStatusOperatorKey::GREATER_THAN
            min_value = count_value + 1
          end

          es_idx = (hsh[ConnectionStatusFilterObjectKey::TYPE] == ConnectionStatusTypeKey::DRAFTED ? :draft_connections_count : type_key)
          min_key, max_key = [es_idx_to_key[es_idx, :min], es_idx_to_key[es_idx, :max]]
          data_hsh[min_key] = [min_value, data_hsh[min_key]].max
          data_hsh[max_key] = [max_value, data_hsh[max_key]].min
        end
      end
      with_options.merge!(es_indices.map{|idx| [idx, (data_hsh[es_idx_to_key[idx, :min]]..data_hsh[es_idx_to_key[idx, :max]])]}.to_h)
    end
  end

  def process_timeline_params!(filter_params, with_options, without_options)
    return if filter_params.blank?

    filter_params[:timeline_questions].each_pair do |timeline_key, questions|
      if TimelineQuestions.all.include?(questions[:question].to_i) && questions[:value].present?
        populate_options_for_timeline_params!(questions, with_options, without_options)
      end
    end
  end

  def populate_options_for_timeline_params!(questions, with_options, without_options)
    if TimelineQuestions::Type::NEVER == questions[:type].to_i
      without_options[:multi_exists_query] ||= []
      without_options[:multi_exists_query] << TimelineQuestions::RevereMap[questions[:question]]
    else
      and_merge!(with_options, TimelineQuestions::RevereMap[questions[:question]],
        get_range(questions[:type], questions[:value]), fill_nil_with: 0)
    end
  end

  def process_other_params!(filter_params, with_options)
    if filter_params.present? && filter_params[:tags].present?
      tag_names = filter_params[:tags].split(",")
      program_tags = self.program.all_users.tag_counts
      tag_ids = program_tags.where(name: tag_names).pluck(:id)
      with_options.merge!('taggings.tag_id' => get_es_object_ids(tag_ids))
    end
  end

  def apply_non_search_filters!(user_ids, profile_params)
    if profile_params.present?
      user_ids = compute_profile_scores(user_ids, profile_params[:score])
      user_ids = refine_profile_params(user_ids, profile_params[:questions]) if user_ids.present?
    end
    return user_ids
  end

  def apply_mandatory_profile_question_filter(user_ids, applied_mandatory_filter, options = {})
    return user_ids.compact if user_ids.compact.empty?

    conditional_type_questions_filter = options[:conditional_type_questions_filter].present?

    roles = program.roles.to_a
    # hash of roles : questions to be answered for the role
    questions_to_consider_for_role_id = questions_hash_to_be_answered_for_each_role(roles, applied_mandatory_filter, conditional_type_questions_filter)

    # hash of combinations of roles : questions to be answered for the combinations of roles
    questions_to_be_answered_for_combinations_of_role_ids = questions_hash_to_be_answered_for_combination_of_roles(roles, questions_to_consider_for_role_id)

    all_profile_question_ids_to_query = []

    if conditional_type_questions_filter
      parent_profile_question_ids, questions_to_answers_hsh, all_profile_question_ids_to_query = generate_questions_to_answers_hash(questions_to_consider_for_role_id)

      return [] if parent_profile_question_ids.empty?
    end

    # filtering users based on the preprocessing and query
    sql_query = generate_sql_query(user_ids, conditional_type_questions_filter, all_profile_question_ids_to_query)

    unless conditional_type_questions_filter
      selected_user_ids = users_answered_all_questions(sql_query, questions_to_be_answered_for_combinations_of_role_ids)
      selected_user_ids -= apply_mandatory_profile_question_filter(selected_user_ids, applied_mandatory_filter, {conditional_type_questions_filter: true })
      user_ids_based_on_filter_type(applied_mandatory_filter, user_ids, selected_user_ids)
    else
      users_answered_parent_questions_and_not_answered_visible_child_questions(sql_query, questions_to_be_answered_for_combinations_of_role_ids, questions_to_answers_hsh)
    end
  end

  def users_answered_parent_questions_and_not_answered_visible_child_questions(sql_query, questions_to_be_answered_for_role_ids, questions_to_answers_hsh)
    # code for selecting users who did answer parent question and did not answer visible child question
    selected_user_ids = []
    ActiveRecord::Base.connection.exec_query(sql_query).to_a.each do |row|
      questions_to_investigate = (questions_to_be_answered_for_role_ids[row["role_ids"].to_s] - row["answered_profile_question_ids"].to_s.split(","))
      all_answered = true
      unless questions_to_investigate.empty?
        answered_question_choices_ids = row["question_choice_ids"].to_s.split(",").map(&:to_i)
        questions_to_investigate.each do |conditional_question_id|
          if (answered_question_choices_ids & questions_to_answers_hsh[conditional_question_id.to_i]).present?
            all_answered = false
            break
          end
        end
      end
      selected_user_ids << row["user_id"] if !all_answered
    end
    selected_user_ids
  end

  def users_answered_all_questions(sql_query, questions_to_be_answered_for_role_ids)
    selected_user_ids = []
    ActiveRecord::Base.connection.exec_query(sql_query).to_a.each do |row|
      questions_to_investigate = (questions_to_be_answered_for_role_ids[row["role_ids"].to_s] - row["answered_profile_question_ids"].to_s.split(","))
      selected_user_ids << row["user_id"] if questions_to_investigate.empty?
    end
    selected_user_ids
  end

  def generate_questions_to_answers_hash(questions_to_consider_for_role_id)
    questions_to_answers_hsh = {}
    all_profile_question_ids_to_query = []
    all_conditional_question_ids = questions_to_consider_for_role_id.values.flatten.compact.uniq
    parent_profile_question_ids = ProfileQuestion.where(id: all_conditional_question_ids).pluck(:conditional_question_id).flatten.uniq.compact
    unless parent_profile_question_ids.empty?
      all_profile_question_ids_to_query = (all_conditional_question_ids + parent_profile_question_ids).flatten.uniq.compact
      questions_to_answers_hsh = ProfileQuestion.where(id: all_conditional_question_ids).includes(:conditional_match_choices).index_by(&:id).map{|k,v| [k, v.conditional_match_choices.map(&:question_choice_id)]}.to_h
    end
    [parent_profile_question_ids, questions_to_answers_hsh, all_profile_question_ids_to_query]
  end

  def questions_hash_to_be_answered_for_each_role(roles, applied_mandatory_filter, conditional_type_questions = false)
    questions_to_consider_for_role_id = {}
    roles.each do |role|
      selected_profile_question_ids = []
      selected_profile_questions = program.profile_questions_for([role.name], {default: false, skype: organization.skype_enabled?, view: true, edit: true}).to_a
      all_profile_question_ids = selected_profile_questions.map(&:id)
      all_profile_question_except_conditional_question_ids = selected_profile_questions.select{ |pq| pq.conditional_question_id.nil? }.map(&:id)
      conditional_profile_question_ids = all_profile_question_ids - all_profile_question_except_conditional_question_ids
      selected_profile_question_ids = conditional_type_questions ? conditional_profile_question_ids : all_profile_question_except_conditional_question_ids

      selected_profile_question_ids = RoleQuestion.where(profile_question_id: selected_profile_question_ids, role_id: role.id).required.pluck(:profile_question_id) if [MandatoryFilterOptions::FILLED_ALL_MANDATORY_QUESTIONS, MandatoryFilterOptions::NOT_FILLED_ALL_MANDATORY_QUESTIONS].include?(applied_mandatory_filter)
      questions_to_consider_for_role_id[role.id] = selected_profile_question_ids
    end
    questions_to_consider_for_role_id
  end

  def questions_hash_to_be_answered_for_combination_of_roles(roles, questions_to_consider_for_role_id)
    # collecting data about questions to be answered for combination of roles that could exist
    questions_to_be_answered_for_role_ids = {}
    number_of_roles = roles.size
    all_roles_selected_bitmask = 2**number_of_roles - 1
    0.upto(all_roles_selected_bitmask).each do |bitmask|
      role_ids_for_bm = []
      profile_question_ids_for_bm = []
      0.upto(number_of_roles-1).each do |position|
        if bitmask & (1<<position) != 0
          role = roles[position]
          role_ids_for_bm << role.id
          profile_question_ids_for_bm << questions_to_consider_for_role_id[role.id]
        end
      end
      questions_to_be_answered_for_role_ids[role_ids_for_bm.sort.join(",")] = profile_question_ids_for_bm.flatten.compact.uniq.map(&:to_s)
    end
    questions_to_be_answered_for_role_ids
  end

  def generate_sql_query(user_ids, conditional_type_questions, all_profile_question_ids_to_query = [])
    sql_query = "SELECT users.id as user_id"
    sql_query << ", GROUP_CONCAT(DISTINCT profile_answers.profile_question_id) AS answered_profile_question_ids"
    sql_query << ", GROUP_CONCAT(DISTINCT role_references.role_id ORDER BY role_references.role_id) AS role_ids"
    sql_query << ", GROUP_CONCAT(DISTINCT answer_choices.question_choice_id ORDER BY answer_choices.question_choice_id) AS question_choice_ids" if conditional_type_questions
    sql_query << " FROM users"
    sql_query << " LEFT JOIN members ON (members.id = users.member_id)"
    sql_query << " LEFT JOIN profile_answers ON (profile_answers.ref_obj_id = members.id AND profile_answers.ref_obj_type = '#{Member.name}')"
    sql_query << " LEFT JOIN answer_choices ON (answer_choices.ref_obj_id = profile_answers.id AND answer_choices.ref_obj_type = '#{ProfileAnswer.name}')" if conditional_type_questions
    sql_query << " LEFT JOIN role_references ON (role_references.ref_obj_id = users.id AND role_references.ref_obj_type = '#{User.name}')"
    sql_query << " WHERE users.id IN (#{user_ids.join(",")})"
    sql_query << " AND profile_answers.profile_question_id IN (#{all_profile_question_ids_to_query.join(",")})" if conditional_type_questions
    sql_query << " GROUP BY users.id"
    sql_query
  end

  def user_ids_based_on_filter_type(applied_mandatory_filter, user_ids, selected_user_ids)
    case applied_mandatory_filter
    when MandatoryFilterOptions::FILLED_ALL_MANDATORY_QUESTIONS, MandatoryFilterOptions::FILLED_ALL_QUESTIONS
      selected_user_ids
    when MandatoryFilterOptions::NOT_FILLED_ALL_MANDATORY_QUESTIONS, MandatoryFilterOptions::NOT_FILLED_ALL_QUESTIONS
      user_ids - selected_user_ids
    end
  end

  def apply_survey_filters!(user_ids, survey_params)
    if survey_params.present?
      user_ids = compute_user_survey_response_status(user_ids, survey_params[:user]) if user_ids.present? 
      user_ids = compute_user_survey_response_value(user_ids, survey_params[:survey_questions]) if user_ids.present? 
    end
    return user_ids
  end

  def sort_users_or_members(user_or_member_ids, sort_param, sort_order, klass, date_ranges = {})
    return [] if user_or_member_ids.blank?
    sort_order = ('desc' == sort_order) ? 'desc' : 'asc'

    if sort_param == AdminViewColumn::Columns::Key::PROFILE_SCORE
      return get_users_with_profile_scores(user_or_member_ids, {sort_field: "profile_score_sum", sort_order: sort_order}).collect(&:id).map(&:to_i)
    end

    users_or_members_scope = klass.where(id: user_or_member_ids)
    # if we need to sort by answer
    if sort_param =~ /^column(\d+)$/
      column_id = $1.to_i
      column = admin_view_columns.includes(:profile_question).find(column_id)
      profile_question = column.profile_question
      klass.sorted_by_answer(users_or_members_scope, profile_question, sort_order, location_scope: column.column_sub_key).collect(&:id)
    elsif sort_param == AdminViewColumn::Columns::Key::PROGRAM_USER_ROLES
      klass.sorted_by_program_roles(users_or_members_scope, sort_order).collect(&:id)
    elsif AdminViewColumn::Columns::Key.meeting_request_columns.include?(sort_param)
      sort_by_meeting_request_column(user_or_member_ids, sort_param, sort_order, date_ranges).collect(&:id)
    elsif AdminViewColumn::Columns::Key.mentoring_request_columns.include?(sort_param)
      sort_by_mentoring_request_column(user_or_member_ids, sort_param, sort_order, date_ranges).collect(&:id)
    elsif sort_param == AdminViewColumn::Columns::Key::MENTORING_MODE
      sorted_ids = users_or_members_scope.to_a.sort! { |a, b| a.mentoring_mode_option_text <=> b.mentoring_mode_option_text }.collect(&:id)
      return sorted_ids if sort_order == "asc"
      return sorted_ids.reverse!
    end
  end

  def sort_by_mentoring_request_column(user_ids, sort_param, sort_order, date_ranges)
    range_condition = get_mentor_requests_range_condition(date_ranges, sort_param)
    join_condition = case sort_param
    when AdminViewColumn::Columns::Key::MENTORING_REQUESTS_SENT
      "LEFT OUTER JOIN mentor_requests ON users.id = mentor_requests.sender_id AND mentor_requests.type = 'MentorRequest'"
    when AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED
      "LEFT OUTER JOIN mentor_requests ON users.id = mentor_requests.receiver_id AND mentor_requests.type = 'MentorRequest'"
    when AdminViewColumn::Columns::Key::MENTORING_REQUESTS_SENT_AND_PENDING
      "LEFT OUTER JOIN mentor_requests ON users.id = mentor_requests.sender_id AND mentor_requests.type = 'MentorRequest' AND mentor_requests.status = #{AbstractRequest::Status::NOT_ANSWERED}"
    when AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING
      "LEFT OUTER JOIN mentor_requests ON users.id = mentor_requests.receiver_id AND mentor_requests.type = 'MentorRequest' AND mentor_requests.status = #{AbstractRequest::Status::NOT_ANSWERED}"
    when AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_REJECTED
      "LEFT OUTER JOIN mentor_requests ON users.id = mentor_requests.receiver_id AND mentor_requests.type = 'MentorRequest' AND mentor_requests.status = #{AbstractRequest::Status::REJECTED}"
    when AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_CLOSED
      "LEFT OUTER JOIN mentor_requests ON users.id = mentor_requests.receiver_id AND mentor_requests.type = 'MentorRequest' AND mentor_requests.status = #{AbstractRequest::Status::CLOSED}"
    end
    join_condition += range_condition if range_condition.present?
    sorted_users = self.program.users.select("users.*, COUNT(mentor_requests.id) AS requests_count").where("users.id IN (?)", user_ids).joins(join_condition).group("users.id").order("requests_count #{sort_order}")
  end

  def sort_by_meeting_request_column(user_ids, sort_param, sort_order, date_ranges)
    range_condition = get_mentor_requests_range_condition(date_ranges, sort_param)
    join_condition = case sort_param
    when AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_V1
      "LEFT OUTER JOIN mentor_requests ON users.id = mentor_requests.sender_id AND mentor_requests.type = 'MeetingRequest'"
    when AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_V1
      "LEFT OUTER JOIN mentor_requests ON users.id = mentor_requests.receiver_id AND mentor_requests.type = 'MeetingRequest'"
    when AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_AND_ACCEPTED
      "LEFT OUTER JOIN mentor_requests ON users.id = mentor_requests.sender_id AND mentor_requests.type = 'MeetingRequest' AND mentor_requests.status = #{AbstractRequest::Status::ACCEPTED}"
    when AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED
      "LEFT OUTER JOIN mentor_requests ON users.id = mentor_requests.receiver_id AND mentor_requests.type = 'MeetingRequest' AND mentor_requests.status = #{AbstractRequest::Status::ACCEPTED}"
    when AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_AND_PENDING
      "LEFT OUTER JOIN mentor_requests ON users.id = mentor_requests.sender_id AND mentor_requests.type = 'MeetingRequest' AND mentor_requests.status = #{AbstractRequest::Status::NOT_ANSWERED}"
    when AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_PENDING
      "LEFT OUTER JOIN mentor_requests ON users.id = mentor_requests.receiver_id AND mentor_requests.type = 'MeetingRequest' AND mentor_requests.status = #{AbstractRequest::Status::NOT_ANSWERED}"
    when AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED
      "LEFT OUTER JOIN mentor_requests ON users.id = mentor_requests.receiver_id AND mentor_requests.type = 'MeetingRequest' AND mentor_requests.status = #{AbstractRequest::Status::REJECTED}"
    when AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED
      "LEFT OUTER JOIN mentor_requests ON users.id = mentor_requests.receiver_id AND mentor_requests.type = 'MeetingRequest' AND mentor_requests.status = #{AbstractRequest::Status::CLOSED}"
    end
    join_condition += range_condition if range_condition.present?

    sorted_users = self.program.users.select("users.*, COUNT(mentor_requests.id) AS requests_count").where("users.id IN (?)", user_ids).joins(join_condition).group("users.id").order("requests_count #{sort_order}")
  end

  def get_connection_status_range(filter_params, request_type, role_type)
    advanced_options = filter_params.try(:dig, :advanced_options, request_type, role_type) || { request_duration: AdminView::AdvancedOptionsType::EVER.to_s }

    get_advanced_options_range(advanced_options)
  end

  def editable?
    super || EDITABLE_DEFAULT_VIEWS.include?(default_view)
  end

  def default_view_for_match_report?
    DEFAULT_VIEWS_FOR_MATCH_REPORT.include?(default_view)
  end

  def deletable?
    self.editable? && !self.default_view_for_match_report?
  end

  def get_applied_filters
    hash_options = {}
    filter_params = self.filter_params_hash
    role_status_param = filter_params[:roles_and_status]
    role_status_param[:roles] = get_included_roles_string(filter_params[:roles_and_status])
    connection_status_param = filter_params[:connection_status]
    profile_param = filter_params[:profile]
    others_param = filter_params[:others]
    timeline_param = filter_params[:timeline]

    get_user_role(role_status_param, self.program, hash_options)
    get_user_status(role_status_param, hash_options)
    get_language_applied_filters(filter_params, hash_options)
    if connection_status_param.present?
      selected_roles = role_status_param[:roles].split(",")
      get_connection_status(connection_status_param[:status], hash_options) if selected_roles.include?(RoleConstants::MENTOR_NAME) || selected_roles.include?(RoleConstants::STUDENT_NAME)
      get_draft_connection_status(connection_status_param[:draft_status], hash_options) if (selected_roles.include?(RoleConstants::MENTOR_NAME) || selected_roles.include?(RoleConstants::STUDENT_NAME))
      get_connection_status_filters(connection_status_param[:status_filters], hash_options) if selected_roles.include?(RoleConstants::MENTOR_NAME) || selected_roles.include?(RoleConstants::STUDENT_NAME)
      get_mentor_availability(connection_status_param[:availability], hash_options) if selected_roles.include?(RoleConstants::MENTOR_NAME)
      get_meeting_requests_filters(connection_status_param, self.program, hash_options, selected_roles) if self.is_program_view? && self.program.calendar_enabled?
      get_mentoring_requests_filters(connection_status_param, self.program, hash_options, selected_roles) if self.program.ongoing_mentoring_enabled?
      get_meeting_connection_status_filter(connection_status_param, self.program, hash_options) if self.program.calendar_enabled? && (selected_roles.include?(RoleConstants::MENTOR_NAME) || selected_roles.include?(RoleConstants::STUDENT_NAME))
      get_mentor_recommendations_filter(connection_status_param, self.program, hash_options) if can_show_mentor_recommendation_filter?(selected_roles)
    end
    get_profile_completion_score(profile_param, hash_options)
    get_mandatory_filter_data(profile_param, hash_options)
    hash_options["feature.admin_view.label.tags".translate] = others_param[:tags] if others_param.present? && others_param[:tags].present?

    profile_filters = get_profile_applied_filters(profile_param[:questions]) if profile_param.present? && profile_param[:questions].present?
    hash_options["feature.admin_view.label.Profile".translate] = profile_filters if profile_filters.present?

    timeline_filters = get_timeline_applied_filters(timeline_param[:timeline_questions]) if timeline_param.present? && timeline_param[:timeline_questions].present?
    hash_options["feature.admin_view.label.Timeline".translate] = timeline_filters if timeline_filters.present?
    hash_options
  end

  def profile_questions_for_roles(options = {})
    questions = {}
    questions_for_admin = {}
    opts = {default: false, edit: true, skype: program.organization.skype_enabled?, dont_include_section: true, pq_translation_include: false}
    [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME].each do |role|
      questions[role] = program.profile_questions_for(role, opts)
      questions_for_admin[role] = program.profile_questions_for(role, opts.merge(fetch_all: true)) if options[:csv_score]
    end
    options[:csv_score] ? {:all => questions_for_admin, :editable_by_user => questions} : questions
  end

  def get_org_applied_filters(options = {})
    filter_params = self.filter_params_hash
    if filter_params[:program_role_state][:all_members].to_s.to_boolean
      {"feature.admin_view.content.status".translate => "feature.admin_view.content.any_status".translate}
    else
      {"feature.admin_view.label.show".translate => "feature.admin_view.show.atleast_one_active_track".translate(program: options[:program_customized_term])}
    end
  end

  def filter_names
    [:profile, :language] + (self.is_program_view? ? [:roles_and_status, :connection_status, :others, :timeline, :survey] : [:member_status, :program_role_state])
  end

  def convert_to_date(date_string, options = {})
    return date_string.to_time if options[:no_format].present?
    Date.strptime(date_string.strip, MeetingsHelper::DateRangeFormat.call).to_time
  end

  def is_part_of_bulk_match?
    return false unless self.is_program_view?
    self.program.bulk_matches.where("mentee_view_id = ? OR mentor_view_id = ?", self.id, self.id).present?
  end

  def get_user_ids_for_match_report
    admin_view_user_cache = self.admin_view_user_cache.presence || self.refresh_user_ids_cache
    admin_view_user_cache.get_admin_view_user_ids
  end

  def get_filters_and_users(options={})
    user_ids = self.get_user_ids_for_match_report if options[:src] == MatchReport::SettingsSrc::MATCH_REPORT
    return [self.get_applied_filters, user_ids || self.generate_view("", "",false)]
  end

  private

  def can_show_mentor_recommendation_filter?(roles = [], program = self.program)
    self.is_program_view? && program.mentor_recommendation_enabled? && program.only_career_based_ongoing_mentoring_enabled? && (program.matching_by_mentee_and_admin? || program.matching_by_mentee_alone?) && roles.include?(RoleConstants::STUDENT_NAME)
  end

  def get_mentor_requests_range_condition(date_ranges, sort_param)
    range = date_ranges.present? && date_ranges[sort_param].presence
    return unless range.present?
    " AND mentor_requests.created_at >= '#{range.first}' AND mentor_requests.created_at <= '#{range.last}'"
  end

  def process_params!(filter_params, with_options, with_all_options, without_options, should_not_options, should_options)
    process_role_status_params!(filter_params[:roles_and_status], with_options, with_all_options, should_not_options, should_options)
    with_user_ids = process_connection_status_params!(filter_params[:connection_status], get_included_roles_string(filter_params[:roles_and_status]), with_options, without_options)
    process_timeline_params!(filter_params[:timeline], with_options, without_options)
    process_other_params!(filter_params[:others], with_options)
    return with_user_ids
  end

  def filter_users(with_user_ids, filter_params, dynamic_filter_params)
    user_ids = apply_non_search_filters!(with_user_ids, filter_params[:profile])
    user_ids = apply_survey_filters!(user_ids, filter_params[:survey])
    user_ids = UserAndMemberFilterService.apply_profile_filtering(user_ids, dynamic_filter_params[:profile_field_filters], {is_program_view: true, program_id: self.program_id}) if dynamic_filter_params[:profile_field_filters].present?
    user_ids = apply_non_profile_filtering(user_ids, dynamic_filter_params[:non_profile_field_filters])
    user_ids = apply_mandatory_profile_question_filter(user_ids, filter_params[:profile][:mandatory_filter]) if filter_params[:profile].try(:[], :mandatory_filter).present?
    return user_ids
  end

  def filter_members(options, filter_params, dynamic_filter_params)
    member_ids = options[:member_ids] || self.organization.members.pluck(:id)
    member_ids = refine_profile_params(member_ids, filter_params[:profile].try(:[], :questions))
    return member_ids if options[:only_profile_filters]
    member_ids = UserAndMemberFilterService.apply_profile_filtering(member_ids, dynamic_filter_params[:profile_field_filters]) if dynamic_filter_params[:profile_field_filters].present?
    member_ids = apply_non_profile_filtering(member_ids, dynamic_filter_params[:non_profile_field_filters])
    return member_ids
  end

  def apply_role_and_state_member_filtering!(filter_params, with_options)
    state = filter_params[:member_status].present? ? filter_params[:member_status][:state] : filter_params[:state]
    with_options.merge!(state: apply_state_condition_value(with_options[:state], state.values)) if state.present?
  end

  def process_role_params(filter_params, with_all_options, should_not_options)
    exclude_role_ids = []
    filter_params.each do |role_filter_key, role_filter_val|
      next unless role_filter_key.match(/role_filter/)
      role_ids = self.program.get_roles(role_filter_val[:roles]).collect(&:id)
      next unless role_ids.present?
      if role_filter_val[:type].try(:to_sym) == :include
        (with_all_options["roles.id"] ||= []) << role_ids
      else
        exclude_role_ids << role_ids
      end
    end

    return unless exclude_role_ids.present?
    should_not_filter = exclude_role_ids.reduce(:product).collect do |role_ids|
      {with_all_filters: {'roles.id' => Array(role_ids).flatten}}
    end
    should_not_options << {filters: should_not_filter}
  end

  def process_status_params(filter_params, should_options)
    signup_state_sub_filters = filter_params[:signup_state]
    if signup_state_sub_filters.present?
      should_filter = []
      should_filter << {must_not_filters: {exists_query: :last_seen_at, creation_source: User::CreationSource::MEMBERSHIP_REQUEST_ACCEPTED}} if signup_state_sub_filters[:added_not_signed_up_users].present?
      should_filter << {must_not_filters: {exists_query: :last_seen_at}, must_filters: {creation_source: User::CreationSource::MEMBERSHIP_REQUEST_ACCEPTED}} if signup_state_sub_filters[:accepted_not_signed_up_users].present?
      should_filter << {must_filters: {exists_query: :last_seen_at}} if signup_state_sub_filters[:signed_up_users].present?
      should_options << {filters: should_filter} if should_filter.present?
    end
  end

  def get_es_object_ids(object_ids)
    object_ids.present? ? object_ids : [0]
  end

  def include_members_users_language_scope(arel)
    arel.joins("LEFT OUTER JOIN member_languages ON member_languages.member_id = members.id").joins("LEFT OUTER JOIN languages ON member_languages.language_id = languages.id")
  end

  def include_language_field_for_user_and_member(fields)
    fields + ["IF(members.state = #{Member::Status::DORMANT}, '#{AdminViewColumn::LANGUAGE_NOT_SET_DISPLAY}', IFNULL(languages.title, '#{Language.for_english.title}')) AS language"]
  end

  def ordered_objects(klass, sorted_ids, order_params, options, pagination_options)
    if order_params[:order].present?
      options.merge!(order_role_specific_option(order_params[:order], order_params[:sort_order], order_params[:sort_param]))
      if pagination_options.present?
        return klass.get_filtered_objects(options.merge!(pagination_options))
      else
        return klass.get_filtered_ids(options)
      end
    else
      users_or_ids = klass.get_filtered_ids(options)
      return users_or_ids unless pagination_options.present?
      ids_string = sorted_ids.join(',')
      return klass.where(id: users_or_ids).order(ids_string.present? ? "field(id,#{ids_string})" : "").paginate(pagination_options)
    end
  end

  def order_role_specific_option(es_order_field, sort_order, sort_param)
    order = Array(es_order_field).collect{|field| [field, sort_order]}
    if AdminViewColumn::Columns::Key.student_only.include?(sort_param)
      order.unshift([:is_student, sort_order]) # cause non student role has NA
    elsif AdminViewColumn::Columns::Key.mentor_only.include?(sort_param)
      order.unshift([:is_mentor, sort_order]) # cause non mentor role has NA
    end
    {sort: order.to_h}
  end

  def get_options_for(keys)
    options = {}
    options[:availability_slots_hash] = program.available_slots_by_user if keys.include?(AdminViewColumn::Columns::Key::AVAILABLE_SLOTS)
    options[:net_recommended_count_hash] = get_net_recommended_count_hash if keys.include?(AdminViewColumn::Columns::Key::NET_RECOMMENDED_COUNT)
    options
  end

  def get_net_recommended_count_hash
    User.get_filtered_users(nil, with: {id: program.users.pluck(:id)}, source_columns: [:id, :net_recommended_count]).map { |info| [info.id.to_i, info.net_recommended_count] }.to_h
  end

  def and_merge!(hsh, key, val, options = {})
    options.reverse_merge!({fill_nil_with: nil})
    if hsh.key?(key)
      unless hsh[key] == options[:fill_nil_with]
        hsh[key] = hsh[key] & val
        hsh[key] = options[:fill_nil_with] if hsh[key].nil?
      end
    else
      hsh.merge!({key => val})
    end
  end

  def get_max_answers(columns)
    max_answer_count = {}
    columns.each do |column|
      question = column.profile_question
      if question.present? && (question.education? || question.experience? || question.publication? || question.manager?)
        max_answer_count[column.id] =
          if question.education?
            Education.max_count_by_program(program, question.id)
          elsif question.experience?
            Experience.max_count_by_program(program, question.id)
          elsif question.publication?
            Publication.max_count_by_program(program, question.id)
          elsif question.manager?
            1
          end
      end
    end
    max_answer_count
  end

  def get_column_titles(columns, max_answer_count)
    columns.inject([]) do |res, column|
      question = column.profile_question
      max_answers = max_answer_count[column.id] || 1
      if column.is_default? || !(question.education? || question.experience? || question.publication? || question.manager?)
        res << column.get_title(get_column_title_translation_keys)
      else
        res += column.column_headers * max_answers
      end
    end
  end

  # In career dev portal, mentoring related customized terms won't be present so #try is used.
  def get_column_title_translation_keys
    {
      program_title: self.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).try(:pluralized_term),
      Meeting: self.program.term_for(CustomizedTerm::TermType::MEETING_TERM).try(:term),
      Mentoring_Connection: self.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).try(:term),
      Mentoring_Connections: self.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).try(:pluralized_term),
      Mentoring: self.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).try(:term),
      mentees: self.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).try(:pluralized_term_downcase)
    }
  end

  def get_answers_for(user_or_member, columns, max_answer_count, profile_answers_hash = {}, options ={})
    answers = []
    columns.each do |column|
      column_answer = column.get_answer(user_or_member, profile_answers_hash, options)
      if column_answer.is_a? Array
        answers += column_answer.flatten
        if max_answers = max_answer_count[column.id]
          answers += ((max_answers - column_answer.size) * column.columns_count).times.map { nil }
        end
      else
        answers << column_answer
      end
    end
    answers
  end

  def get_user_role(role_status_param, program, hash_options)
    role_filter_hash = RoleConstants.program_roles_mapping(program, capitalize: true)
    hash_options["display_string.Roles".translate] = role_filter_hash[role_status_param[:roles]] || RoleConstants.human_role_string(role_status_param[:roles].split(","), program: program, capitalize: true)
  end

  def get_language_applied_filters(filter_params, hash_options)
    if filter_params[AdminViewColumn::Columns::Key::LANGUAGE].present? && languages_filter_enabled?
      language_ids = filter_params[AdminViewColumn::Columns::Key::LANGUAGE].map(&:to_i)
      language_key = "feature.admin_view.label.language".translate
      language_values = language_ids.include?(0) ? [Language.for_english.title] : []
      language_values += Language.where(id: language_ids.reject(&:zero?)).pluck(:title)
      hash_options[language_key] = language_values
    end
  end

  def get_user_status(role_status_param, hash_options)
    if role_status_param[:state].present?
      hash_options["feature.admin_view.label.User_Status".translate] = get_translated_states(role_status_param)
    end
    signup_state_sub_filters = role_status_param[:signup_state]
    if signup_state_sub_filters.present? && (signup_state_sub_filters[:added_not_signed_up_users].present? || signup_state_sub_filters[:accepted_not_signed_up_users].present? || signup_state_sub_filters[:signed_up_users].present?)
      user_signup_status_key = "feature.admin_view.label.user_signup_status".translate
      hash_options[user_signup_status_key] = []
      hash_options[user_signup_status_key] << "feature.admin_view.content.added_not_signed_up_users".translate if signup_state_sub_filters[:added_not_signed_up_users].present?
      hash_options[user_signup_status_key] << "feature.admin_view.content.accepted_not_signed_up_users".translate if signup_state_sub_filters[:accepted_not_signed_up_users].present?
      hash_options[user_signup_status_key] << "feature.admin_view.content.signed_up_users_explain".translate if signup_state_sub_filters[:signed_up_users].present?
    end
  end

  def get_translated_states(role_status_param)
    status_hash = {"active" => "feature.admin_view.status.active".translate, "pending" => "feature.admin_view.status.unpublished".translate, "suspended" => "feature.admin_view.status.deactivated".translate
           }

    translated_states = []
    role_status_param[:state].values.each do |value|
      translated_states << status_hash[value]
    end
    translated_states.join(", ")
  end

  def get_connection_status(status_param, hash_options)
    if status_param.present?
      hash_options["feature.admin_view.label.Connection_Status_v1".translate(:Mentoring_Connection => program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term)] = get_connection_status_options.invert[status_param]
    end
  end

  def get_draft_connection_status(draft_connection_status_param, hash_options)
    if draft_connection_status_param.present?
      hash_options["feature.admin_view.label.draft_connection_status_v1".translate(:Mentoring_Connection => program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term)] = get_draft_status_options.invert[draft_connection_status_param.to_i]
    end
  end

  def get_connection_status_filters(status_filters_param, hash_options)
    if status_filters_param.present? && program.ongoing_mentoring_enabled?
      text_chunks = (status_filters_param.try(:values) || []).map do |hsh|
        str = case hsh[ConnectionStatusFilterObjectKey::CATEGORY]
        when ConnectionStatusCategoryKey::NEVER_CONNECTED
          "feature.admin_view.status.Never_connected".translate
        when ConnectionStatusCategoryKey::CURRENTLY_CONNECTED
          "feature.admin_view.status.Currently_connected".translate
        when ConnectionStatusCategoryKey::CURRENTLY_UNCONNECTED
          "feature.admin_view.status.Currently_not_connected".translate
        when ConnectionStatusCategoryKey::FIRST_TIME_CONNECTED
          "feature.admin_view.status.Currently_connected_for_first_time".translate
        when ConnectionStatusCategoryKey::CONNECTED_CURRENTLY_OR_PAST
          "feature.admin_view.status.Connected_currently_or_in_the_past".translate
        when ConnectionStatusCategoryKey::ADVANCED_FILTERS, "" # pls note an value "" also should end up here which refer to advanced filters, it is default case from second entry in UI
          if hsh[ConnectionStatusFilterObjectKey::COUNT_VALUE].present? && hsh[ConnectionStatusFilterObjectKey::OPERATOR].present? && hsh[ConnectionStatusFilterObjectKey::TYPE].present?
            part1 = case hsh[ConnectionStatusFilterObjectKey::TYPE]
            when ConnectionStatusTypeKey::ONGOING
              "feature.admin_view.status.Part_of_ongoing_connection".translate(connections: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase)
            when ConnectionStatusTypeKey::CLOSED
              "feature.admin_view.status.Part_of_closed_connection".translate(connections: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase)
            when ConnectionStatusTypeKey::ONGOING_OR_CLOSED
              "feature.admin_view.status.Part_of_ongoing_or_closed_connection".translate(connections: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase)
            when ConnectionStatusTypeKey::DRAFTED
              "feature.admin_view.status.Part_of_drafted_connection".translate(connections: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase)
            end
            part2 = case hsh[ConnectionStatusFilterObjectKey::OPERATOR]
            when ConnectionStatusOperatorKey::LESS_THAN
              "feature.admin_view.status.Less_than".translate
            when ConnectionStatusOperatorKey::EQUALS_TO
              "feature.admin_view.status.Equals_to".translate
            when ConnectionStatusOperatorKey::GREATER_THAN
              "feature.admin_view.status.Greater_than".translate
            end
            [part1, UnicodeUtils.downcase(part2.to_s), hsh[ConnectionStatusFilterObjectKey::COUNT_VALUE]].join(" ")
          end
        end
      end.select(&:present?)
      text_chunks.map!.with_index { |str, idx| idx == 0 ? str : UnicodeUtils.downcase(str.to_s) }
      hash_options["feature.admin_view.label.Connection_Status_v2".translate(mentoring_connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)] = to_sentence_sanitize(text_chunks) if text_chunks.present?
    end
  end

  def get_mentor_availability(availability_param, hash_options)
    if availability_param.present? && availability_param[:operator].present? && availability_param[:value].present?
      hash_options["feature.admin_view.label.mentor_availability".translate(:mentor => self.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term)] = "#{get_mentor_availability_options.invert[availability_param[:operator].to_i]} #{availability_param[:value]}"
    end
  end

  def get_meeting_requests_filters(connection_status_param, program, hash_options, selected_roles)
    meeting_requests_param = connection_status_param[:meeting_requests]
    meeting_requests_advanced_options = connection_status_param[:advanced_options].present? && connection_status_param[:advanced_options][:meeting_requests].presence
    if meeting_requests_param.present?
      meeting_term = program.term_for(CustomizedTerm::TermType::MEETING_TERM).term
      meeting_request_filters = []

      meeting_requests_param.reject!{|k| k == "mentees" && !selected_roles.include?(RoleConstants::STUDENT_NAME)}
      meeting_requests_param.reject!{|k| k == "mentors" && !selected_roles.include?(RoleConstants::MENTOR_NAME)}

      meeting_requests_param.each do |role_type, filter_option|
        if filter_option.present?
          meeting_request_filters << "#{get_meeting_request_status_options(meeting_term.downcase, role_type).invert[filter_option.to_i]} #{get_request_advanced_options(meeting_requests_advanced_options, role_type)}"
        end
      end

      hash_options["feature.admin_view.label.meeting_request_status".translate(:Meeting => meeting_term)] = meeting_request_filters if meeting_request_filters.present?
    end
  end

  def get_mentoring_requests_filters(connection_status_param, program, hash_options, selected_roles)
    mentoring_requests_param = connection_status_param[:mentoring_requests]
    mentoring_requests_advanced_options = connection_status_param[:advanced_options].present? && connection_status_param[:advanced_options][:mentoring_requests].presence
    if mentoring_requests_param.present?
      mentoring_term = program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term
      mentoring_request_filters = []

      mentoring_requests_param.reject!{|k| k == "mentees" && !selected_roles.include?(RoleConstants::STUDENT_NAME)}
      mentoring_requests_param.reject!{|k| k == "mentors" && !selected_roles.include?(RoleConstants::MENTOR_NAME)}

      mentoring_requests_param.each do |role_type, filter_option|
        if filter_option.present?
          mentoring_request_filters << "#{get_mentoring_request_status_options(mentoring_term.downcase, role_type).invert[filter_option.to_i]} #{get_request_advanced_options(mentoring_requests_advanced_options, role_type)}"
        end
      end

      hash_options["feature.admin_view.label.mentoring_request_status".translate(:Mentoring => mentoring_term)] = mentoring_request_filters if mentoring_request_filters.present?
    end
  end

  def get_meeting_connection_status_filter(connection_status_param, program, hash_options)
    meeting_connection_status = connection_status_param[:meetingconnection_status]
    meetingconnection_status_advanced_options = connection_status_param[:advanced_options].present? && connection_status_param[:advanced_options][:meetingconnection_status].presence
    if meeting_connection_status.present?
      meeting_term = program.term_for(CustomizedTerm::TermType::MEETING_TERM).term

      meeting_connection_status_filter = "#{get_meeting_connection_status_options(meeting_term.downcase).invert[meeting_connection_status.to_i]} #{get_request_advanced_options(meetingconnection_status_advanced_options, :both)}"

      hash_options["feature.admin_view.label.meeting_connection_status".translate] = meeting_connection_status_filter
    end
  end

  def get_mentor_recommendations_filter(connection_status_param, program, hash_options)
    mentor_recommendation = connection_status_param.try(:dig, :mentor_recommendations, :mentees)
    mentor_recommendation_advanced_options = connection_status_param.try(:dig, :advanced_options, :mentor_recommendations)
    if mentor_recommendation.present?
      mentor_term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME)
      mentor_recommendation_filter = "#{get_mentor_recommendation_options(mentor_term.term_downcase).invert[mentor_recommendation.to_i]} #{get_request_advanced_options(mentor_recommendation_advanced_options, :mentees)}"

      hash_options["feature.admin_view.label.mentor_recommendations_v1".translate(Mentor: mentor_term.term)] = mentor_recommendation_filter
    end
  end

  def get_profile_completion_score(profile_param, hash_options)
    if profile_param.present? && profile_param[:score].present? && profile_param[:score][:operator].present? && profile_param[:score][:value].present?
      hash_options["feature.admin_view.label.Profile_Completeness_Score".translate] = "#{get_profile_completion_score_options.invert[profile_param[:score][:operator].to_i]} #{profile_param[:score][:value]} %"
    end
  end

  def get_mandatory_filter_data(profile_param, hash_options)
    if profile_param.try(:[], :mandatory_filter).present?
      hash_options["feature.admin_view.select_option.users_who_have".translate] = case profile_param[:mandatory_filter]
      when MandatoryFilterOptions::FILLED_ALL_MANDATORY_QUESTIONS
        "feature.admin_view.select_option.answered_all_mandatory_questions".translate
      when MandatoryFilterOptions::FILLED_ALL_QUESTIONS
        "feature.admin_view.select_option.answered_all_questions".translate
      when MandatoryFilterOptions::NOT_FILLED_ALL_QUESTIONS
        "feature.admin_view.select_option.not_answered_all_question".translate
      when MandatoryFilterOptions::NOT_FILLED_ALL_MANDATORY_QUESTIONS
        "feature.admin_view.select_option.not_answered_all_mandatory_questions".translate
      else
        "display_string.n_a".translate
      end
    end
  end

  # TODO : the entire get filters applied logic need to be checked for its usage and
  # moved to appropriately places.
  def get_timeline_applied_filters(timeline_param)
    timeline_fields_array = []
    timeline_param.values.each do |timeline|
      if timeline[:question].present? && timeline[:type].present? && timeline[:value].present?
        type_int = timeline[:type].try(:to_i) || TimelineQuestions::Type::DATE_RANGE
        question_text = get_timeline_options.invert[timeline[:question].to_i]
        display_string_construct = "#{question_text}: "
        case type_int
        when TimelineQuestions::Type::NEVER
          display_string_construct += (->{"feature.admin_view.content.never".translate}.call)
        when TimelineQuestions::Type::BEFORE
          display_string_construct += "#{->{"feature.admin_view.content.before".translate}.call} #{timeline[:value]}"
        when TimelineQuestions::Type::BEFORE_X_DAYS
          display_string_construct += "#{->{"feature.admin_view.content.older_than".translate}.call} #{timeline[:value]} #{->{"display_string.days".translate}.call}"
        when TimelineQuestions::Type::AFTER
          display_string_construct += "#{->{"feature.admin_view.content.after".translate}.call} #{timeline[:value]}"
        when TimelineQuestions::Type::DATE_RANGE
          display_string_construct += timeline[:value]
        end
        timeline_fields_array << display_string_construct
      end
    end
    timeline_fields_array
  end

  def get_profile_applied_filters(profile_param)
    profile_fields_array = []
    profile_question_ids = profile_param.values.collect { |hsh| hsh[:question] }
    profile_question_id_question_map = self.organization.profile_questions.includes(question_choices: :translations).where(id: profile_question_ids).index_by(&:id)
    profile_param.values.each do |profile|
      profile_question = profile_question_id_question_map[profile[:question].to_i]
      if profile_question.present? && profile[:operator].present?
        value = if profile_question.location?
          # profile[:value] : "chennai, tamil nadu, India|San Jose, California, USA" => value : "chennai (tamil nadu, India), San Jose (California, USA)"
          # profile[:value] : "tamil nadu, India|California, USA" => value : "tamil nadu (India), California (USA)"
          # profile[:value] : "India|USA" => value : "India, USA"
          profile[:value].split(AdminView::LOCATION_VALUES_SPLITTER).map { |location| location.sub(AdminView::LOCATION_SCOPE_SPLITTER, " #{LOCATION_SCOPE_CLARIFIER_BEGIN}") }.map { |location| location + (location.include?(LOCATION_SCOPE_CLARIFIER_BEGIN) ? LOCATION_SCOPE_CLARIFIER_END : "") }.join(LOCATION_SCOPE_SPLITTER)
        elsif profile_question.choice_or_select_type? && profile[:operator].in?([AdminViewsHelper::QuestionType::WITH_VALUE.to_s, AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s, AdminViewsHelper::QuestionType::IN.to_s, AdminViewsHelper::QuestionType::NOT_IN.to_s])
          qc_ids = (profile[:choice] || "").split(COMMA_SEPARATOR).map(&:strip).map(&:to_i)
          profile_question.question_choices.select{|qc| qc.id.in?(qc_ids)}.collect(&:text).join_by_separator(ProfileAnswer::SEPERATOR)
        else
          profile[:value]
        end
        profile_fields_array << { question_text: profile_question.question_text, operator_text: get_profile_filter_options.invert[profile[:operator].to_i], value: value }
      end
    end
    return profile_fields_array
  end

  def refine_profile_params(user_or_member_ids, profile_questions_hash)
    return user_or_member_ids if profile_questions_hash.blank?
    filtered_user_or_member_ids = user_or_member_ids
    select_cond, program_cond = if self.is_program_view?
      ["SELECT users.id FROM users join members on users.member_id = members.id", "users.program_id = #{self.program_id} AND "]
    else
      ["SELECT members.id FROM members", ""]
    end
    program = self.is_program_view? ? self.program : nil
    profile_question_ids = profile_questions_hash.values.collect { |hsh| hsh[:question] }
    profile_question_id_question_map = self.organization.profile_questions.where(id: profile_question_ids).index_by(&:id)

    profile_questions_hash.each_pair do |question_key, answer_value|
      operator = answer_value[:operator]
      question_id = answer_value[:question].to_i
      value = answer_value[:value].to_s.downcase
      choice = answer_value[:choice].presence || "0"
      profile_question = profile_question_id_question_map[question_id]

      if profile_question.present? && operator.present?
        mem = ActiveRecord::Base.connection.quote(Member.name)
        profile_answer = ActiveRecord::Base.connection.quote(ProfileAnswer.name)
        ans = value.format_for_mysql_query(delimit_with_percent: true)
        users_or_member_ids_for_positive_operator =
          if operator.in? [AdminViewsHelper::QuestionType::WITH_VALUE.to_s, AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s]
            query = if profile_question.location?
              "#{select_cond}
                join profile_answers on (profile_answers.ref_obj_id = members.id AND profile_answers.ref_obj_type=#{mem})
                join profile_questions on profile_questions.id = profile_answers.profile_question_id
                WHERE (#{program_cond} profile_answers.location_id IN (#{UserProfileFilterService.get_locations_ids(value).join(',')}) AND
                profile_questions.id = #{question_id})"
            elsif profile_question.choice_or_select_type?
              "#{select_cond}
                JOIN profile_answers ON (profile_answers.ref_obj_id = members.id AND profile_answers.ref_obj_type=#{mem})
                JOIN answer_choices ON (answer_choices.ref_obj_id = profile_answers.id AND answer_choices.ref_obj_type=#{profile_answer})
                JOIN profile_questions ON profile_questions.id = profile_answers.profile_question_id AND profile_questions.question_type IN (#{ProfileQuestion::Type.choice_based_types.join(',')})
                WHERE (#{program_cond} answer_choices.question_choice_id IN (#{choice}) AND
                profile_questions.id = #{question_id})"
            else
              "#{select_cond}
                join profile_answers on (profile_answers.ref_obj_id = members.id AND profile_answers.ref_obj_type=#{mem})
                join profile_questions on profile_questions.id = profile_answers.profile_question_id
                WHERE (#{program_cond} profile_answers.answer_text like #{ans} AND
                profile_questions.id = #{question_id})"
            end
            ActiveRecord::Base.connection.select_values(query)
          elsif operator.in? [AdminViewsHelper::QuestionType::ANSWERED.to_s, AdminViewsHelper::QuestionType::NOT_ANSWERED.to_s]
            query = "#{select_cond}
              join profile_answers on (profile_answers.ref_obj_id = members.id AND profile_answers.ref_obj_type=#{mem})
              join profile_questions on profile_questions.id = profile_answers.profile_question_id
              WHERE (#{program_cond} profile_questions.id = #{question_id})"
            ActiveRecord::Base.connection.select_values(query)
          elsif operator.in? [AdminViewsHelper::QuestionType::IN.to_s, AdminViewsHelper::QuestionType::NOT_IN.to_s]
            filter_text = profile_question.choice_or_select_type? ? choice : value
            UserProfileFilterService.filter_based_on_question_type!(program, filtered_user_or_member_ids.dup, profile_question, filter_text.split(','), filter_for_members: self.is_organization_view?, perform_in_operation: true).to_a
          elsif operator.in?([AdminViewsHelper::QuestionType::MATCHES.to_s])
            UserProfileFilterService.filter_based_on_regex_match(program, filtered_user_or_member_ids.dup, profile_question, value.split(','), filter_for_members: self.is_organization_view?).to_a
          elsif operator == AdminViewsHelper::QuestionType::DATE_TYPE.to_s
            preset = ProfileQuestionDateType.get_mapping(answer_value["date_operator"])
            date_range = get_date_range_string_for_variable_days(answer_value["date_value"], answer_value["number_of_days"], preset)
            UserProfileFilterService.filter_based_on_question_type!(program, filtered_user_or_member_ids.dup, profile_question, date_range, filter_for_members: self.is_organization_view?).to_a
          end

        if operator.in? [AdminViewsHelper::QuestionType::WITH_VALUE.to_s, AdminViewsHelper::QuestionType::ANSWERED.to_s, AdminViewsHelper::QuestionType::IN.to_s, AdminViewsHelper::QuestionType::MATCHES.to_s, AdminViewsHelper::QuestionType::DATE_TYPE.to_s]
          filtered_user_or_member_ids &= users_or_member_ids_for_positive_operator
        elsif operator.in? [AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s, AdminViewsHelper::QuestionType::NOT_ANSWERED.to_s, AdminViewsHelper::QuestionType::NOT_IN.to_s]
          filtered_user_or_member_ids -= users_or_member_ids_for_positive_operator
        end
      end
    end
    return filtered_user_or_member_ids
  end

  def apply_state_condition_value(current_states, apply_states)
    if current_states.present?
      val = current_states.map(&:to_i) & apply_states.map(&:to_i)
      val = FILL_TMP_INVALID_MEMBER_STATE if val.blank?
      val
    else
      apply_states
    end
  end

  def apply_non_profile_filtering(user_or_member_ids, non_profile_field_filters)
    return user_or_member_ids if non_profile_field_filters.blank?
    users_or_members = []
    user_or_member_superset = user_or_member_ids
    with_options = {}
    without_options = {}
    es_range_formats = {}
    klass = self.is_program_view? ? User : Member

    non_profile_field_filters.group_by{|f| f["field"]}.each do |field, filter|
      value = filter[0]["value"]
      operator = filter[0]["operator"]
      common_params_for_update_options_for_non_profile_filtering = [operator, value, with_options, without_options]

      case field
      when AdminViewColumn::Columns::Key::PROFILE_SCORE
        users_or_members = user_or_member_superset & filter_profile_score(user_or_member_ids, operator, value)
        user_or_member_superset = users_or_members
      when AdminViewColumn::Columns::Key::STATE
        if klass == Member
          with_options[:state] = apply_state_condition_value(with_options[:state], value.split(ProfileQuestion::SEPERATOR))
        elsif klass == User
          with_options[:state] = value.split(ProfileQuestion::SEPERATOR)
        end
      when AdminViewColumn::Columns::Key::LANGUAGE
        state_key = ( klass == Member ? 'state' : 'member.state')
        language_id_key = ( klass == Member ? 'member_language_id' : 'member.member_language_id')
        with_options[state_key] = apply_state_condition_value(with_options[state_key], Member::Status.all_except(Member::Status::DORMANT))
        with_options[language_id_key] = value.split(',').map(&:to_i)
      when AdminViewColumn::Columns::Key::AVAILABLE_SLOTS
        update_options_for_non_profile_filtering!(:availability, *common_params_for_update_options_for_non_profile_filtering)
      when AdminViewColumn::Columns::Key::NET_RECOMMENDED_COUNT
        update_options_for_non_profile_filtering!(:net_recommended_count, *common_params_for_update_options_for_non_profile_filtering)
      when AdminViewColumn::Columns::Key::GROUPS
        update_options_for_non_profile_filtering!(:active_user_connections_count, *common_params_for_update_options_for_non_profile_filtering)
      when AdminViewColumn::Columns::Key::MENTORING_MODE
        value = value.split(ProfileQuestion::SEPERATOR)
        with_options[:mentoring_mode] = value
      when AdminViewColumn::Columns::Key::CLOSED_GROUPS
        update_options_for_non_profile_filtering!(:closed_user_connections_count, *common_params_for_update_options_for_non_profile_filtering)
      when AdminViewColumn::Columns::Key::DRAFTED_GROUPS
        update_options_for_non_profile_filtering!(:draft_connections_count, *common_params_for_update_options_for_non_profile_filtering)
      when AdminViewColumn::Columns::Key::ORG_LEVEL_ONGOING_ENGAGEMENTS
        update_options_for_non_profile_filtering!(:ongoing_engagements_count, *common_params_for_update_options_for_non_profile_filtering)
      when AdminViewColumn::Columns::Key::ORG_LEVEL_CLOSED_ENGAGEMENTS
        update_options_for_non_profile_filtering!(:closed_engagements_count, *common_params_for_update_options_for_non_profile_filtering)
      when AdminViewColumn::Columns::Key::CREATED_AT, AdminViewColumn::Columns::Key::LAST_SEEN_AT, AdminViewColumn::Columns::Key::TERMS_AND_CONDITIONS, AdminViewColumn::Columns::Key::LAST_DEACTIVATED_AT, AdminViewColumn::Columns::Key::LAST_SUSPENDED_AT
        start_time = value
        end_time = filter.count > 1 ? filter[1]["value"] : start_time
        key = field
        key = 'member.terms_and_conditions_accepted' if field == AdminViewColumn::Columns::Key::TERMS_AND_CONDITIONS

        es_date_range_format = ElasticsearchConstants::DATE_RANGE_FORMATS::DATE_WITH_TIME_AND_ZONE
        start_time = Time.zone.parse(DateTime.localize(Date.strptime(start_time.strip, "date.formats.date_range".translate).to_time, format: :full_date_full_time)).in_time_zone(TimezoneConstants::DEFAULT_TIMEZONE).strftime(ElasticsearchConstants::DATE_RANGE_FORMATS::FORMATS_HASH[es_date_range_format])
        end_time = Time.zone.parse(DateTime.localize(Date.strptime(end_time.strip, "date.formats.date_range".translate).to_time, format: :full_date_full_time)).end_of_day.in_time_zone(TimezoneConstants::DEFAULT_TIMEZONE).strftime(ElasticsearchConstants::DATE_RANGE_FORMATS::FORMATS_HASH[es_date_range_format])
        with_options[key] = start_time..end_time
        es_range_formats[key] = es_date_range_format
      when AdminViewColumn::Columns::Key::LAST_CLOSED_GROUP_TIME
        start_time = value
        end_time = filter.count > 1 ? filter[1]["value"] : start_time
        with_options[get_es_search_order(field)] = get_date_range([start_time,end_time].join('-'))
      when AdminViewColumn::Columns::Key::PROGRAM_USER_ROLES
        program_id_key = ( klass == Member ? 'users.program_id' : 'program_id')
        with_options[program_id_key] = value.split(ProfileQuestion::SEPERATOR).map(&:to_i)
      end
    end

    if (with_options.blank? && without_options.blank? && es_range_formats.blank?) || user_or_member_superset.empty?
      return user_or_member_superset
    end

    users_or_members = []
    user_or_member_superset.each_slice(QueryHelper::MAX_HITS) do |user_or_member_id_set|
      users_or_members += klass.get_filtered_ids(must_filters: {id: user_or_member_id_set}.merge(with_options), must_not_filters: without_options, es_range_formats: es_range_formats)
    end
    return users_or_members
  end

  def update_options_for_non_profile_filtering!(key, operator, value, with_options, without_options)
    search_value = es_search_condition(operator, value)
    if operator == KendoNumericOperators::NOT_EQUAL
      without_options[key] = search_value
    else
      with_options[key] = search_value
    end
  end

  def compute_profile_scores(user_ids, profile_score_params)
    if profile_score_params.present? && profile_score_params[:value].present?

      users_with_profile_scores = get_users_with_profile_scores(user_ids)

      if(profile_score_params[:operator] == AdminViewsHelper::QuestionType::HAS_GREATER_THAN.to_s)
        return users_with_profile_scores.select{|user| user.profile_score_sum > profile_score_params[:value].to_i}.collect(&:id).map(&:to_i)
      else
        return users_with_profile_scores.select{|user| user.profile_score_sum < profile_score_params[:value].to_i }.collect(&:id).map(&:to_i)
      end
    end
    user_ids
  end

  def get_users_with_profile_scores(user_ids, options = {})
    return user_ids if user_ids.empty?

    users_with_profile_scores = []
    user_ids.each_slice(QueryHelper::MAX_HITS) do |user_ids_set|
      users_with_profile_scores += User.get_filtered_users(nil, {with: {id: user_ids_set}, source_columns: ["id", "profile_score_sum"]}.merge(options))
    end
    users_with_profile_scores
  end

  def compute_user_survey_response_status(user_ids, survey_user_params)
    filtered_user_ids = []
    user_ids_superset = user_ids
    survey_id = survey_user_params[:survey_id]
    users_response_status = survey_user_params[:users_status]
    if survey_id.present? && users_response_status.present? && Survey.exists?(survey_id.to_i)
      survey_id = survey_id.to_i
      all_user_ids = SurveyAnswer.where(:survey_id => survey_id).pluck(:user_id).uniq
      filtered_user_ids = (users_response_status == AdminView::SurveyAnswerStatus::RESPONDED.to_s) ? (user_ids_superset & all_user_ids) : (user_ids_superset - all_user_ids)
    else
      filtered_user_ids =  user_ids_superset
    end
    return filtered_user_ids
  end

  def compute_user_survey_response_value(user_ids, survey_questions_hash)
    filtered_user_ids = SurveyQuestionFilterServiceForAdminViews.new(survey_questions_hash, user_ids).filtered_user_ids 
  end

  def get_never_range(value)
    (Time.new(0)..Time.new(0))
  end

  def get_before_range(value)
    (TimelineQuestions::STARTING_DATE)..convert_to_date(value)
  end

  def get_older_than_range(value)
    (TimelineQuestions::STARTING_DATE)..((Date.today - value.to_i.days + 1.day).to_time)
  end

  def get_after_range(value)
    (convert_to_date(value) + 1.day)..(TimelineQuestions::ENDING_DATE)
  end

  def get_date_range(value)
    date = value.split("-")
    if date.present? && date.size < 2
      convert_to_date(date[0])..(convert_to_date(date[0]) + 1.day)
    elsif date.size == 2
      convert_to_date(date[0])..(convert_to_date(date[1]) + 1.day)
    end
  end

  def get_range(type, value)
    send(AdminView::TimelineQuestions::Type::RANGE_FETCHER[type.to_i], value)
  end

  def get_advanced_options_range(advanced_options)
    type, value = get_request_type_and_value(advanced_options)
    send(AdminView::AdvancedOptionsType::RANGE_FETCHER[type.to_i], value)
  end

  def get_request_type_and_value(params)
    type = params[:request_duration]
    value = (type.to_i != AdminView::AdvancedOptionsType::EVER) ? params[type] : ""
    type = AdminView::AdvancedOptionsType::EVER unless value.present?
    return type, value
  end

  def get_ever_range(value)
    (TimelineQuestions::STARTING_DATE)..(TimelineQuestions::ENDING_DATE)
  end

  def get_in_last_x_days_range(value)
    ((Date.today - value.to_i.days).to_time)..(TimelineQuestions::ENDING_DATE)
  end

  def get_es_search_order(sort_param)
    default_keys = AdminViewColumn::Columns::Key
    case sort_param
    when default_keys::MEMBER_ID
      return (self.is_program_view? ? "member_id" : "id")
    when default_keys::FIRST_NAME
      return "name_only.sort"
    when default_keys::LAST_NAME
      return ["last_name.sort", "first_name.sort"]
    when default_keys::EMAIL
      return "email.sort"
    when default_keys::CREATED_AT
      return "created_at"
    when default_keys::LAST_DEACTIVATED_AT
      return "last_deactivated_at"
    when default_keys::LAST_SUSPENDED_AT
      return "last_suspended_at"
    when default_keys::LAST_SEEN_AT
      return "last_seen_at"
    when default_keys::TERMS_AND_CONDITIONS
      return 'member.terms_and_conditions_accepted'
    when default_keys::GROUPS
      return "active_user_connections_count"
    when default_keys::CLOSED_GROUPS
      return "closed_user_connections_count"
    when default_keys::DRAFTED_GROUPS
      return "draft_connections_count"
    when default_keys::STATE
      return "state"
    when default_keys::ROLES
      return "role_name_string"
    when default_keys::AVAILABLE_SLOTS
      return "availability"
    when default_keys::NET_RECOMMENDED_COUNT
      return "net_recommended_count"
    when default_keys::LAST_CLOSED_GROUP_TIME
      return "last_closed_group_time"
    when default_keys::RATING
      return "user_stat.average_rating"
    when default_keys::LANGUAGE
      return (self.is_program_view? ? "member.language_title" : "language_title")
    when default_keys::ORG_LEVEL_ONGOING_ENGAGEMENTS
      return "ongoing_engagements_count"
    when default_keys::ORG_LEVEL_CLOSED_ENGAGEMENTS
      return "closed_engagements_count"
    end
  end

  def includes_list(columns)
    column_keys = columns.collect(&:column_key)
    include_array = []
    include_array << :active_groups if column_keys.include?(AdminViewColumn::Columns::Key::GROUPS)
    include_array << :closed_groups if column_keys.include?(AdminViewColumn::Columns::Key::CLOSED_GROUPS)
    include_array << :drafted_groups if column_keys.include?(AdminViewColumn::Columns::Key::DRAFTED_GROUPS)
    include_array << :roles if column_keys.include?(AdminViewColumn::Columns::Key::ROLES) || column_keys.include?(AdminViewColumn::Columns::Key::PROFILE_SCORE) || column_keys.include?(AdminViewColumn::Columns::Key::AVAILABLE_SLOTS)
    members_includes = [{ :organization => { :customized_terms => :translations } }]


    profile_questions = columns.custom.collect(&:profile_question)
    if profile_questions.any?
      profile_answers_includes = []
      profile_answers_includes << :educations if profile_questions.any?(&:education?)
      profile_answers_includes << :experiences if profile_questions.any?(&:experience?)
      profile_answers_includes << :publications if profile_questions.any?(&:publication?)
      profile_answers_includes << :answer_choices if profile_questions.any?(&:choice_or_select_type?)
      members_includes << { :profile_answers => profile_answers_includes }
    end

    include_array << { member: members_includes }
    include_array
  end

  ####################################################################
  #Methods to get filter options
  ####################################################################

  def get_connection_status_options
    {
      "common_text.prompt_text.Select".translate => "",
      "app_constant.admin_view.connection_status.Never_connected".translate => UsersIndexFilters::Values::NEVERCONNECTED,
      "app_constant.admin_view.connection_status.Currently_connected".translate => UsersIndexFilters::Values::CONNECTED,
      "app_constant.admin_view.connection_status.Currently_not_connected".translate => UsersIndexFilters::Values::UNCONNECTED
    }
  end

  def get_draft_status_options
    {
      "common_text.prompt_text.Select".translate => "",
      "app_constant.admin_view.draft_status.with_draft_connections".translate => AdminView::DraftConnectionStatus::WITH_DRAFTS,
      "app_constant.admin_view.draft_status.without_draft_connections".translate => AdminView::DraftConnectionStatus::WITHOUT_DRAFTS
    }
  end

  def get_mentor_availability_options
    {
      "common_text.prompt_text.Select".translate => "",
      "app_constant.admin_view.mentor_availability.slots_less_than".translate => AdminViewsHelper::QuestionType::HAS_LESS_THAN,
      "app_constant.admin_view.mentor_availability.slots_greater_than".translate => AdminViewsHelper::QuestionType::HAS_GREATER_THAN
    }
  end

  def get_request_advanced_options(advanced_options, role_type)
    applied_option = advanced_options.present? && advanced_options[role_type].presence
    if applied_option.present? && applied_option[applied_option[:request_duration]].present?
      case applied_option[:request_duration].to_i
      when AdminView::AdvancedOptionsType::LAST_X_DAYS
        "feature.admin_view.action.in_last".translate + applied_option[applied_option[:request_duration]] + "feature.admin_view.action.days".translate
      when AdminView::AdvancedOptionsType::AFTER
        "feature.admin_view.action.after".translate + applied_option[applied_option[:request_duration]]
      when AdminView::AdvancedOptionsType::BEFORE
        "feature.admin_view.action.before".translate + applied_option[applied_option[:request_duration]]
      end
    end
  end

  def get_meeting_request_status_options(meeting_term, role_type)
    if role_type == "mentees"
      {
        "common_text.prompt_text.Select".translate => "",
        "feature.admin_view.meeting_request.mentee.sent".translate(:meeting => meeting_term) => AdminView::RequestsStatus::SENT_OR_RECEIVED,
        "feature.admin_view.meeting_request.mentee.pending_action".translate(:meeting => meeting_term) => AdminView::RequestsStatus::SENT_OR_RECEIVED_WITH_PENDING_ACTION,
        "feature.admin_view.meeting_request.mentee.not_sent".translate(:meeting => meeting_term) => AdminView::RequestsStatus::NOT_SENT_OR_RECEIVED
      }
    else
      {
        "common_text.prompt_text.Select".translate => "",
        "feature.admin_view.meeting_request.mentor.received".translate(:meeting => meeting_term) => AdminView::RequestsStatus::SENT_OR_RECEIVED,
        "feature.admin_view.meeting_request.mentor.pending_action".translate(:meeting => meeting_term) => AdminView::RequestsStatus::SENT_OR_RECEIVED_WITH_PENDING_ACTION,
        "feature.admin_view.meeting_request.mentor.not_received".translate(:meeting => meeting_term) => AdminView::RequestsStatus::NOT_SENT_OR_RECEIVED,
        "feature.admin_view.meeting_request.mentor.rejected_action_v2".translate(:meeting => meeting_term) => AdminView::RequestsStatus::RECEIVED_WITH_REJECTED_ACTION,
        "feature.admin_view.meeting_request.mentor.closed_action_v2".translate(:meeting => meeting_term) => AdminView::RequestsStatus::RECEIVED_WITH_CLOSED_ACTION
      }
    end
  end

  def get_meeting_connection_status_options(meeting_term)
    {
      "common_text.prompt_text.Select".translate => "",
      "feature.admin_view.meeting_connection_status.not_connected".translate(:meeting => meeting_term) => AdminView::UserMeetingConnectionStatus::NOT_CONNECTED,
      "feature.admin_view.meeting_connection_status.connected".translate(:meeting => meeting_term) => AdminView::UserMeetingConnectionStatus::CONNECTED
    }
  end

  def get_mentor_recommendation_options(mentor_term)
    {
      "common_text.prompt_text.Select".translate => "",
      "feature.admin_view.mentor_recommendation.received_recommendations".translate(mentor: mentor_term) => AdminView::MentorRecommendationFilter::MENTEE_RECEIVED,
      "feature.admin_view.mentor_recommendation.not_received_recommendations".translate(mentor: mentor_term) => AdminView::MentorRecommendationFilter::MENTEE_NOT_RECEIVED
    }
  end

  def get_mentoring_request_status_options(mentoring_term, role_type)
    if role_type == "mentees"
      {
        "common_text.prompt_text.Select".translate => "",
        "feature.admin_view.mentoring_request.mentee.sent".translate(:mentoring => mentoring_term) => AdminView::RequestsStatus::SENT_OR_RECEIVED,
        "feature.admin_view.mentoring_request.mentee.pending_action".translate(:mentoring => mentoring_term) => AdminView::RequestsStatus::SENT_OR_RECEIVED_WITH_PENDING_ACTION,
        "feature.admin_view.mentoring_request.mentee.not_sent".translate(:mentoring => mentoring_term) => AdminView::RequestsStatus::NOT_SENT_OR_RECEIVED
      }
    else
      {
        "common_text.prompt_text.Select".translate => "",
        "feature.admin_view.mentoring_request.mentor.received".translate(:mentoring => mentoring_term) => AdminView::RequestsStatus::SENT_OR_RECEIVED,
        "feature.admin_view.mentoring_request.mentor.pending_action".translate(:mentoring => mentoring_term) => AdminView::RequestsStatus::SENT_OR_RECEIVED_WITH_PENDING_ACTION,
        "feature.admin_view.mentoring_request.mentor.not_received".translate(:mentoring => mentoring_term) => AdminView::RequestsStatus::NOT_SENT_OR_RECEIVED,
        "feature.admin_view.mentoring_request.mentor.rejected_action_v2".translate(:mentoring => mentoring_term) => AdminView::RequestsStatus::RECEIVED_WITH_REJECTED_ACTION,
        "feature.admin_view.mentoring_request.mentor.closed_action_v2".translate(:mentoring => mentoring_term) => AdminView::RequestsStatus::RECEIVED_WITH_CLOSED_ACTION
      }
    end
  end

  def get_profile_completion_score_options
    {
      "common_text.prompt_text.Select".translate => "",
      "app_constant.admin_view.profile_completion_score.Less_than".translate => AdminViewsHelper::QuestionType::HAS_LESS_THAN,
      "app_constant.admin_view.profile_completion_score.Greater_than".translate => AdminViewsHelper::QuestionType::HAS_GREATER_THAN
    }
  end

  def get_timeline_options
    {
      "common_text.prompt_text.Select".translate => "",
      "app_constant.admin_view.timeline.Join_date".translate => AdminView::TimelineQuestions::JOIN_DATE,
      "app_constant.admin_view.timeline.Last_login_date".translate => AdminView::TimelineQuestions::LAST_LOGIN_DATE,
      "app_constant.admin_view.timeline.terms_and_conditions".translate => AdminView::TimelineQuestions::TNC_ACCEPTED_ON,
      "app_constant.admin_view.timeline.last_deactivated_at_v1".translate => AdminView::TimelineQuestions::LAST_DEACTIVATED_AT
     }
  end

  def get_profile_filter_options
    {
      "common_text.prompt_text.Select".translate => "",
      "app_constant.admin_view.profile_filter.Contains".translate => AdminViewsHelper::QuestionType::WITH_VALUE,
      "app_constant.admin_view.profile_filter.Answered_v1".translate => AdminViewsHelper::QuestionType::ANSWERED,
      "app_constant.admin_view.profile_filter.Not_Answered_v1".translate => AdminViewsHelper::QuestionType::NOT_ANSWERED,
      "feature.admin_view.select_option.Not_Contains".translate => AdminViewsHelper::QuestionType::NOT_WITH_VALUE,
      "feature.admin_view.select_option.In_v1".translate => AdminViewsHelper::QuestionType::IN,
      "feature.admin_view.select_option.Not_in_v1".translate => AdminViewsHelper::QuestionType::NOT_IN,
      "feature.admin_view.select_option.Matches".translate => AdminViewsHelper::QuestionType::MATCHES
    }
  end

  def users_with_mentoring_mode(user_ids)
    result = {}
    self.program.users.where(:id => user_ids).each do |user|
      result[user.id] = user.mentoring_mode_option_text
    end
    result
  end

  def self.get_first_admin_view(ref_obj, program_id)
    if ref_obj.is_a?(CampaignManagement::AbstractCampaign)
      trigger_params = ref_obj.trigger_params
      return "" if !trigger_params || !trigger_params[1] || trigger_params[1].empty?
      admin_view_id = trigger_params[1][0].to_i
      AdminView.find_by(id: admin_view_id)
    elsif ref_obj.is_a?(Resource)
      ref_obj.resource_publications.find_by(program_id: program_id).admin_view
    end
  end

  def users_with_rating(user_ids)
    users_rating = User.connection.select_all(User.select('users.id, user_stats.average_rating as rating').joins("LEFT JOIN user_stats ON user_stats.user_id=users.id").where(program_id: program, id: user_ids).group('users.id'))
    users_rating.inject({}) do |result, user_rating|
      user_id, rating = user_rating['id'], user_rating['rating']
      result[user_id] = rating
      result
    end
  end

  def users_with_role_names(user_ids)
    roles_scope = RoleReference.joins(:role).select(['ref_obj_id as user_id', :name]).
      where(roles: { program_id: program }).where(ref_obj_id: user_ids, ref_obj_type: User.name)
    users_roles = RoleReference.connection.select_all(roles_scope)
    users_roles.inject({}) do |result, user_role|
      user_id, role_name = user_role['user_id'], user_role['name']
      result[user_id] ||= []
      result[user_id] << role_name
	  result[user_id] = result[user_id].sort
      result
    end
  end

  def apply_date_range_for_scope(scope, date_range_hash)
    return scope unless date_range_hash.present?

    date_range = (convert_to_date(date_range_hash[:start_time], no_format: true)..convert_to_date(date_range_hash[:end_time], no_format: true))
    scope.created_in_date_range(date_range)
  end

  def handle_meeting_requests_count_for_csv(keys, program, date_ranges, options = {})
    has_received_meeting_request_keys = (keys & AdminViewColumn::Columns::Key.received_meeting_request_columns).any?

    if has_received_meeting_request_keys
      received_scope = program.meeting_requests.select("receiver_id, status, created_at")
      if keys.include?(AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_V1)
        date_range_hash = date_ranges.present? && date_ranges[AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_V1].presence
        received_requests = apply_date_range_for_scope(received_scope, date_range_hash)
        options.merge!(received_meeting_requests: received_requests.group(:receiver_id).size)
      end
      if keys.include?(AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_PENDING)
        date_range_hash = date_ranges.present? && date_ranges[AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_PENDING].presence
        pending_received_requests = apply_date_range_for_scope(received_scope.active, date_range_hash)
        options.merge!(pending_received_meeting_requests: pending_received_requests.group(:receiver_id).size)
      end
      if keys.include?(AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED)
        date_range_hash = date_ranges.present? && date_ranges[AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED].presence
        accepted_requests = apply_date_range_for_scope(received_scope.accepted, date_range_hash)
        options.merge!(accepted_received_meeting_requests: accepted_requests.group(:receiver_id).size)
      end
      if keys.include?(AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED)
        date_range_hash = date_ranges.present? && date_ranges[AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED].presence
        rejected_requests = apply_date_range_for_scope(received_scope.rejected, date_range_hash)
        options.merge!(rejected_received_meeting_requests: rejected_requests.group(:receiver_id).size)
      end
      if keys.include?(AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED)
        date_range_hash = date_ranges.present? && date_ranges[AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED].presence
        closed_requests = apply_date_range_for_scope(received_scope.closed, date_range_hash)
        options.merge!(closed_received_meeting_requests: closed_requests.group(:receiver_id).size)
      end
    end

    has_sent_meeting_request_keys = (keys & AdminViewColumn::Columns::Key.sent_meeting_request_columns).any?

    if has_sent_meeting_request_keys
      sent_scope = program.meeting_requests.select("sender_id, status, created_at")
      if keys.include?(AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_V1)
        date_range_hash = date_ranges.present? && date_ranges[AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_V1].presence
        sent_requests = apply_date_range_for_scope(sent_scope, date_range_hash)
        options.merge!(sent_meeting_requests: sent_requests.group(:sender_id).size)
      end
      if keys.include?(AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_AND_PENDING)
        date_range_hash = date_ranges.present? && date_ranges[AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_AND_PENDING].presence
        pending_sent_requests = apply_date_range_for_scope(sent_scope.active, date_range_hash)
        options.merge!(pending_sent_meeting_requests: pending_sent_requests.group(:sender_id).size)
      end
      if keys.include?(AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_AND_ACCEPTED)
        date_range_hash = date_ranges.present? && date_ranges[AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_AND_ACCEPTED].presence
        accepted_requests = apply_date_range_for_scope(sent_scope.accepted, date_range_hash)
        options.merge!(accepted_sent_meeting_requests: accepted_requests.group(:sender_id).size)
      end
    end
  end

  def handle_mentoring_requests_count_for_csv(keys, program, date_ranges, options = {})
    has_received_mentoring_request_keys = (keys & AdminViewColumn::Columns::Key.received_mentoring_request_columns).any?
    if has_received_mentoring_request_keys
      received_scope = program.mentor_requests.select("receiver_id, status, created_at")
      if keys.include?(AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED)
        date_range_hash = date_ranges.present? && date_ranges[AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED].presence
        received_requests = apply_date_range_for_scope(received_scope, date_range_hash)
        options.merge!(received_mentoring_requests: received_requests.group(:receiver_id).size)
      end
      if keys.include?(AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING)
        date_range_hash = date_ranges.present? && date_ranges[AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING].presence
        pending_received_requests = apply_date_range_for_scope(received_scope.active, date_range_hash)
        options.merge!(pending_received_mentoring_requests: pending_received_requests.group(:receiver_id).size)
      end
      if keys.include?(AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_REJECTED)
        date_range_hash = date_ranges.present? && date_ranges[AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_REJECTED].presence
        rejected_received_requests = apply_date_range_for_scope(received_scope.rejected, date_range_hash)
        options.merge!(rejected_received_mentoring_requests: rejected_received_requests.group(:receiver_id).size)
      end
      if keys.include?(AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_CLOSED)
        date_range_hash = date_ranges.present? && date_ranges[AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_CLOSED].presence
        closed_received_requests = apply_date_range_for_scope(received_scope.closed, date_range_hash)
        options.merge!(closed_received_mentoring_requests: closed_received_requests.group(:receiver_id).size)
      end
    end

    has_sent_mentoring_request_keys = (keys & AdminViewColumn::Columns::Key.sent_mentoring_request_columns).any?

    if has_sent_mentoring_request_keys
      sent_scope = program.mentor_requests.select("sender_id, status, created_at")
      if keys.include?(AdminViewColumn::Columns::Key::MENTORING_REQUESTS_SENT)
        date_range_hash = date_ranges.present? && date_ranges[AdminViewColumn::Columns::Key::MENTORING_REQUESTS_SENT].presence
        sent_requests = apply_date_range_for_scope(sent_scope, date_range_hash)
        options.merge!(sent_mentoring_requests: sent_requests.group(:sender_id).size)
      end
      if keys.include?(AdminViewColumn::Columns::Key::MENTORING_REQUESTS_SENT_AND_PENDING)
        date_range_hash = date_ranges.present? && date_ranges[AdminViewColumn::Columns::Key::MENTORING_REQUESTS_SENT_AND_PENDING].presence
        pending_sent_requests = apply_date_range_for_scope(sent_scope.active, date_range_hash)
        options.merge!(pending_sent_mentoring_requests: pending_sent_requests.group(:sender_id).size)
      end
    end
  end

  def apply_role_filter!(dynamic_filter_params, with_options)
    return unless dynamic_filter_params[:role_names].present?
    role_ids = self.program.get_roles(dynamic_filter_params[:role_names]).collect(&:id)
    with_options.merge!('roles.id' => role_ids) if role_ids.present?
  end

  def default_fields_filters(dynamic_filter_params)
    return {} if dynamic_filter_params.blank?
    member_id = dynamic_filter_params[:member_id].presence.try(:to_i) || ""
    first_name = dynamic_filter_params[:first_name].presence.try(:downcase) || ""
    last_name = dynamic_filter_params[:last_name].presence.try(:downcase) || ""
    email = dynamic_filter_params[:email].presence.try(:downcase) || ""
    { member_id: member_id, 'first_name.keyword' => first_name, 'last_name.keyword' => last_name, 'email.keyword' => email }.keep_if{ |_k,v| v.present? }
  end

  def es_search_condition(operator, value)
    value = value.to_i
    case operator
    when KendoNumericOperators::EQUAL then value
    when KendoNumericOperators::NOT_EQUAL then value
    when KendoNumericOperators::GREATER_OR_EQUAL then value..MAX_LIMIT
    when KendoNumericOperators::GREATER then (value + 1)..MAX_LIMIT
    when KendoNumericOperators::LESS_OR_EQUAL then 0..value
    when KendoNumericOperators::LESS then 0..(value - 1)
    end
  end

  def filter_profile_score(user_ids, operator, value)
    value = value.to_i
    all_users = get_users_with_profile_scores(user_ids)
    all_users.select do |user|
      case operator
      when KendoNumericOperators::EQUAL then user.profile_score_sum == value
      when KendoNumericOperators::NOT_EQUAL then user.profile_score_sum != value
      when KendoNumericOperators::GREATER_OR_EQUAL then user.profile_score_sum >= value
      when KendoNumericOperators::GREATER then user.profile_score_sum > value
      when KendoNumericOperators::LESS_OR_EQUAL then user.profile_score_sum <= value
      when KendoNumericOperators::LESS then user.profile_score_sum < value
      end
    end.map(&:id).map(&:to_i)
  end

end
