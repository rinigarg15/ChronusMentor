module Report::Customization
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def get_translated_report_category_name(title)
      "feature.reports.header.#{title}".translate
    end

    def get_translated_report_category_description(title)
      Proc.new{ |program| "feature.reports.content.description.#{title}".translate(program.return_custom_term_hash) }
    end

    def get_translated_report_subcategory_name(title)
      Proc.new{ |program| "feature.reports.content.subcategory.#{title}".translate(program.return_custom_term_hash) }
    end
  end

  module SubCategory
    ENROLLMENT = "enrollment"
    MATCHING = "matching"
    POST_MATCHING = "post_matching"
    MEETING_SURVEYS = "meeting_surveys"
    ENGAGEMENT_SURVEYS = "engagement_surveys"
    PROGRAM_OUTCOMES = "program_outcomes"
    PROGRAM_SURVEYS = "program_surveys"
    GROUP_SURVEY_OUTCOME = "group_survey_outcome"
    MEETING_SURVEY_OUTCOME = "meeting_survey_outcome"
    UTILITY = "utility"
    USER_VIEW = "user_view"
  end

  module Category
    HEALTH = 1
    OUTCOME = 2
    USER = 3

    def self.all
      (HEALTH..USER)
    end

    NAMES = {
      HEALTH => "health",
      OUTCOME => "outcome",
      USER => "user"
    }

    ICONS = {
      HEALTH => "fa fa-medkit",
      OUTCOME => "fa fa-line-chart",
      USER => "fa fa-user"
    }

    SubCategoryMap = {
      HEALTH => [SubCategory::ENROLLMENT, SubCategory::MATCHING, SubCategory::POST_MATCHING, SubCategory::MEETING_SURVEYS, SubCategory::ENGAGEMENT_SURVEYS],
      OUTCOME => [SubCategory::PROGRAM_OUTCOMES, SubCategory::PROGRAM_SURVEYS, SubCategory::GROUP_SURVEY_OUTCOME, SubCategory::MEETING_SURVEY_OUTCOME],
      USER => [SubCategory::UTILITY, SubCategory::USER_VIEW]
    }
  end

  module ReportItem
    # Health related
    MEMBERSHIP_REQUESTS = "membership_requests"
    INVITATION = "invitation"
    MENTOR_REQUESTS = "mentor_requests"
    MENTOR_OFFERS = "mentor_offers"
    MEETING_REQUESTS = "meeting_requests"
    MENTORING_CONNECTION_ACTIVITY = "mentoring_connection_activity"
    ACTIVITY_REPORT_DESCRIPTION = "activity_report_description"
    ENGAGEMENT_SURVEY = "engagement_survey"
    MENTORING_CALENDAR = "mentoring_calendar"
    CONTRACT_MANAGEMENT = "contract_management"
    MEETING_CALENDAR = "meeting_calendar"
    MEETING_SURVEY = "meeting_survey"
    MATCH_REPORT = "match_report"

    # Outcome related (ENGAGEMENT_SURVEY, MEETING_SURVEY will be presend in both Health and Outcome categories)
    PROGRAM_OUTCOMES = "program_outcomes"
    PROGRAM_SURVEY = "program_survey"

    # User related
    USER_VIEWS = "user_views"
    DEMOGRAPHIC = "demographic"

    REPORTS_CONFIG = {
      MEMBERSHIP_REQUESTS => {
        title: Proc.new { "manage_strings.program.Administration.General.Membership_Requests".translate },
        description: Proc.new { |program| "feature.reports.content.description.membership_requests_v1".translate(program.return_custom_term_hash) },
        category: Category::HEALTH,
        program_condition: Proc.new { |program| program.allow_join_now? },
        user_condition: Proc.new { |user| user.can_approve_membership_request? },
        path: Proc.new { |default_params| Rails.application.routes.url_helpers.membership_requests_path(default_params) },
        icon: "fa-user-plus",
        position: Proc.new { 1 },
        subcategory: Proc.new { SubCategory::ENROLLMENT }
      },

      INVITATION => {
        title: Proc.new { "manage_strings.program.Administration.Connection.invitations".translate },
        description: Proc.new { |program| "feature.reports.content.description.invitations_v1".translate(program.return_custom_term_hash) },
        category: Category::HEALTH,
        program_condition: Proc.new { |program| program.program_invitations.any? },
        path: Proc.new { |default_params| Rails.application.routes.url_helpers.program_invitations_path(default_params) },
        icon: "fa-envelope-open",
        position: Proc.new { 2 },
        subcategory: Proc.new { SubCategory::ENROLLMENT }
      },

      MENTOR_REQUESTS => {
        title: Proc.new { |program| "manage_strings.program.Administration.Connection.Mentor_Requests_v1".translate(Mentoring: program.return_custom_term_hash[:_Mentoring]) },
        description: Proc.new { |program| get_mentor_requests_description(program) },
        category: Category::HEALTH,
        user_condition: Proc.new { |user| user.can_manage_mentor_requests? },
        program_condition: Proc.new { |program| program.ongoing_mentoring_enabled? },
        path: Proc.new { |default_params| Rails.application.routes.url_helpers.manage_mentor_requests_path(default_params) },
        icon: "fa-user-plus",
        position: Proc.new { 5 },
        subcategory: Proc.new { SubCategory::MATCHING }
      },

      MENTOR_OFFERS => {
        title: Proc.new { |program| "manage_strings.program.Administration.Connection.Mentor_Offers".translate(Mentoring: program.return_custom_term_hash[:_Mentoring]) },
        description: Proc.new { |program| "feature.reports.content.description.mentor_offers".translate(program.return_custom_term_hash) },
        category: Category::HEALTH,
        program_condition: Proc.new { |program| program.ongoing_mentoring_enabled? && program.mentor_offer_enabled? && program.mentor_offer_needs_acceptance? },
        path: Proc.new { |default_params| Rails.application.routes.url_helpers.manage_mentor_offers_path(default_params) },
        icon: "fa-user-plus",
        position: Proc.new { 6 },
        subcategory: Proc.new { SubCategory::MATCHING }
      },

      MEETING_REQUESTS => {
        title: Proc.new { |program| "manage_strings.program.Administration.Connection.Meeting_Requests_v1".translate(Meeting: program.return_custom_term_hash[:_Meeting]) },
        description: Proc.new { |program| "feature.reports.content.description.meeting_requests".translate(program.return_custom_term_hash) },
        category: Category::HEALTH,
        program_condition: Proc.new { |program| program.calendar_enabled? },
        path: Proc.new { |default_params| Rails.application.routes.url_helpers.manage_meeting_requests_path(default_params) },
        icon: "fa-calendar-plus-o",
        position: Proc.new { 4 },
        subcategory: Proc.new { SubCategory::MATCHING }
      },

      MENTORING_CONNECTION_ACTIVITY => {
        title: Proc.new { |program| "feature.reports.header.mentoring_connections_report".translate(program.return_custom_term_hash) },
        description: Proc.new { |program| "feature.reports.content.mentoring_connections_report_description_v1".translate(program.return_custom_term_hash) },
        category: Category::HEALTH,
        program_condition: Proc.new { |program| program.ongoing_mentoring_enabled? },
        user_condition: Proc.new { |user| user.can_manage_connections? },
        path: Proc.new { |default_params| Rails.application.routes.url_helpers.groups_path(default_params) },
        position: Proc.new { 8 },
        subcategory: Proc.new { SubCategory::POST_MATCHING }
      },

      ACTIVITY_REPORT_DESCRIPTION => {
        title: Proc.new { |program| "feature.reports.header.mentoring_connection_activity_report".translate(Mentoring_Connection: program.return_custom_term_hash[:_Mentoring_Connection]) },
        description: Proc.new { |program| "feature.reports.content.mentoring_connection_activity_report_description_v1".translate(program.return_custom_term_hash) },
        category: Category::HEALTH,
        program_condition: Proc.new { |program| program.show_groups_report? },
        path: Proc.new { |default_params| Rails.application.routes.url_helpers.groups_report_path(default_params) },
        position: Proc.new { 9 },
        subcategory: Proc.new { SubCategory::POST_MATCHING }
      },

      ENGAGEMENT_SURVEY => {
        title: Proc.new { |survey| survey.name.term_titleize },
        description: Proc.new { |survey| "feature.reports.content.survey_report_description".translate(count: survey.total_responses) },
        category: [Category::HEALTH, Category::OUTCOME],
        collection: Proc.new { |program| Survey.by_type(program)[EngagementSurvey.name] },
        path: Proc.new { |survey, default_params| Rails.application.routes.url_helpers.report_survey_path(survey, default_params) },
        survey: true,
        icon: "fa-users",
        position: Proc.new { |category| { Category::HEALTH => 13, Category::OUTCOME => 4 }[category] },
        subcategory: Proc.new { |category| { Category::HEALTH => SubCategory::ENGAGEMENT_SURVEYS, Category::OUTCOME => SubCategory::GROUP_SURVEY_OUTCOME }[category] },
        object_condition: Proc.new { |survey| survey.total_responses > 0 }
      },

      MENTORING_CALENDAR => {
        title: Proc.new { |program| "feature.reports.header.mentoring_calendar_report_v1".translate(Mentoring: program.return_custom_term_hash[:_Mentoring]) },
        description: Proc.new { |program| "feature.reports.content.mentoring_report_description_v2".translate(program.return_custom_term_hash) },
        category: Category::HEALTH,
        user_condition: Proc.new { |user| user.can_manage_mentoring_sessions? },
        program_condition: Proc.new { |program| program.mentoring_connection_meeting_enabled? && program.ongoing_mentoring_enabled? },
        path: Proc.new { |default_params| Rails.application.routes.url_helpers.mentoring_sessions_path(default_params) },
        position: Proc.new { 10 },
        subcategory: Proc.new { SubCategory::POST_MATCHING }
      },

      CONTRACT_MANAGEMENT => {
        title: Proc.new { |program| "feature.reports.header.contract_management_report".translate(Mentor: program.return_custom_term_hash[:_Mentor]) },
        description: Proc.new { |program| "feature.reports.content.contract_management_report_description".translate(mentor: program.return_custom_term_hash[:_mentor], program: program.return_custom_term_hash[:_program], mentoring_connections: program.return_custom_term_hash[:_mentoring_connections]) },
        category: Category::HEALTH,
        program_condition: Proc.new { |program| program.contract_management_enabled? },
        path: Proc.new { |default_params| Rails.application.routes.url_helpers.group_checkins_path(default_params) },
        position: Proc.new { 11 },
        subcategory: Proc.new { SubCategory::POST_MATCHING }
      },

      MEETING_CALENDAR => {
        title: Proc.new { |program| "feature.reports.header.meeting_calendar_report_v1".translate(Meeting: program.return_custom_term_hash[:_Meeting]) },
        description: Proc.new { |program| "feature.reports.content.meeting_report_description".translate(mentoring: program.return_custom_term_hash[:_mentoring]) },
        category: Category::HEALTH,
        user_condition: Proc.new { |user| user.can_manage_mentoring_sessions? },
        program_condition: Proc.new { |program| program.calendar_enabled? },
        path: Proc.new { |default_params| Rails.application.routes.url_helpers.calendar_sessions_path(default_params) },
        position: Proc.new { 7 },
        subcategory: Proc.new { SubCategory::POST_MATCHING }
      },

      MEETING_SURVEY => {
        title: Proc.new { |survey| survey.name.term_titleize },
        description: Proc.new { |survey| "feature.reports.content.survey_report_description".translate(count: survey.total_responses) },
        category: [Category::HEALTH, Category::OUTCOME],
        collection: Proc.new { |program| Survey.by_type(program)[MeetingFeedbackSurvey.name] },
        path: Proc.new { |survey, default_params| Rails.application.routes.url_helpers.report_survey_path(survey, default_params) },
        survey: true,
        icon: "fa-users",
        position: Proc.new { |category| { Category::HEALTH => 12, Category::OUTCOME => 3 }[category] },
        subcategory: Proc.new { |category| { Category::HEALTH => SubCategory::MEETING_SURVEYS, Category::OUTCOME => SubCategory::MEETING_SURVEY_OUTCOME }[category] },
        object_condition: Proc.new { |survey| survey.total_responses > 0 }
      },

      MATCH_REPORT => {
        title: Proc.new { "feature.match_report.header.match_report".translate },
        description: Proc.new {|program| "feature.match_report.content.report_description".translate(program: program.return_custom_term_hash[:_program], mentee: program.return_custom_term_hash[:_mentee])},
        category: Category::HEALTH,
        user_condition: Proc.new { |user| user.can_view_match_report? },
        position: Proc.new { 3 },
        path: Proc.new { |default_params| Rails.application.routes.url_helpers.match_reports_path(default_params.merge(src: EngagementIndex::Src::MatchReport::REPORT_LISTING)) },
        icon: "fa-handshake-o",
        subcategory: Proc.new { SubCategory::MATCHING }
      },

      PROGRAM_OUTCOMES => {
        title: Proc.new { |program| "feature.reports.header.program_outcomes_report".translate(Program: program.return_custom_term_hash[:_Program]) },
        description: Proc.new { |program| "feature.reports.content.program_outcomes_report_description".translate(program: program.return_custom_term_hash[:_program]) },
        category: Category::OUTCOME,
        program_condition: Proc.new { |program| program.program_outcomes_report_enabled? },
        path: Proc.new { |default_params| Rails.application.routes.url_helpers.outcomes_report_path(default_params) },
        position: Proc.new { 1 },
        subcategory: Proc.new { SubCategory::PROGRAM_OUTCOMES }
      },

      PROGRAM_SURVEY => {
        title: Proc.new { |survey| survey.name.term_titleize },
        description: Proc.new { |survey| "feature.reports.content.survey_report_description".translate(count: survey.total_responses) },
        category: Category::OUTCOME,
        collection: Proc.new { |program| Survey.by_type(program)[ProgramSurvey.name] },
        path: Proc.new { |survey, default_params| Rails.application.routes.url_helpers.report_survey_path(survey, default_params) },
        survey: true,
        icon: "fa-users",
        position: Proc.new { 2 },
        subcategory: Proc.new { SubCategory::PROGRAM_SURVEYS },
        object_condition: Proc.new { |survey| survey.total_responses > 0 }
      },

      DEMOGRAPHIC => {
        title: Proc.new { "feature.reports.header.demographic_report_v1".translate },
        description: Proc.new { |program| "feature.reports.content.demographic_report_description".translate(program: program.return_custom_term_hash[:_program]) },
        category: Category::USER,
        path: Proc.new { |default_params| Rails.application.routes.url_helpers.demographic_report_path(default_params) },
        position: Proc.new { 1 },
        subcategory: Proc.new { SubCategory::UTILITY }
      },

      USER_VIEWS => {
        title: Proc.new { |admin_view| admin_view.title },
        description: Proc.new { |admin_view| admin_view.description },
        category: Category::USER,
        collection: Proc.new { |program| program.admin_views.defaults_first },
        path: Proc.new { |admin_view, default_params| Rails.application.routes.url_helpers.admin_view_path(admin_view, default_params) },
        icon: "fa-user-circle",
        position: Proc.new { 2 },
        subcategory: Proc.new { SubCategory::USER_VIEW }
      }
    }

    def self.evaluate_conditions(reports, options = {})
      reports_config = REPORTS_CONFIG.slice(*reports.keys)
      reports_config.select do |_key, configs|
        valid = true
        valid &&= configs[:program_condition].call(options[:program]) if configs[:program_condition].present?
        valid &&= configs[:user_condition].call(options[:user]) if configs[:user_condition].present?
        valid &&= configs[:collection].call(options[:program]).present? if configs[:collection].present?
        valid
      end
    end

    def self.get_valid_report_attributes(category, program, user)
      configs = REPORTS_CONFIG.select { |_key, attributes| Array(attributes[:category]).include?(category) }
      reports_attribute_list = ReportItem.evaluate_conditions(configs, program: program, user: user).values
      reports_attribute_list.sort_by! { |report_attribute| report_attribute[:position].call(category) }
    end

    def self.get_mentor_requests_description(program)
      custom_term_hash = program.return_custom_term_hash
      owner = program.matching_by_mentee_and_admin? ? custom_term_hash[:_admins] : custom_term_hash[:_mentors]
      "feature.reports.content.description.mentor_requests_v1".translate(custom_term_hash.merge(owner: owner))
    end
  end
end