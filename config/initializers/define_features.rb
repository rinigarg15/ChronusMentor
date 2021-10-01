ActionController::Base.send :include, FeatureManager

# Features that are available in the application.
module FeatureName
  ANSWERS                          = 'answers'
  ARTICLES                         = 'articles'
  SKYPE_INTERACTION                = 'skype_interation'
  STICKY_TOPIC                     = 'sticky_topic'
  SUBPROGRAM_CREATION              = 'subprogram_creation'
  CONNECTION_PROFILE               = 'connection_profile'
  PROFILE_COMPLETION_ALERT         = 'profile_completion_alert'
  CALENDAR                         = 'calendar'
  MENTORING_CONNECTION_MEETING     = 'mentoring_connection_meeting'
  MEMBER_TAGGING                   = 'member_tagging'
  OFFER_MENTORING                  = 'offer_mentoring'
  FORUMS                           = 'forums'
  RESOURCES                        = 'resources'
  FLAGGING                         = 'flagging'
  PROGRAM_EVENTS                   = 'program_events'
  BULK_MATCH                       = 'bulk_matching'
  ORGANIZATION_PROFILES            = 'organization_profiles'
  DATA_IMPORT                      = 'data_import'
  ENROLLMENT_PAGE                  = 'enrollment_page'
  COACHING_GOALS                   = 'coaching_goals'
  LINKEDIN_IMPORTS                 = 'linkedin_imports'
  LANGUAGE_SETTINGS                = 'language_settings'
  MODERATE_FORUMS                  = 'moderate_forums'
  MANAGER                          = 'manager'
  THREE_SIXTY                      = 'three_sixty'
  MENTORING_CONNECTIONS_V2         = 'mentoring_connections_v2'
  LOGGED_IN_PAGES                  = 'logged_in_pages'
  MENTORING_INSIGHTS               = 'mentoring_tips'
  CONTRACT_MANAGEMENT              = 'contract_management'
  PROGRAM_MANGAGEMENT_REPORT       = 'program_management_report'
  EXECUTIVE_SUMMARY_REPORT         = 'executive_summary_report'
  PROGRAM_OUTCOMES_REPORT          = 'program_outcomes_report'
  MEMBERSHIP_ELIGIBILITY_RULES     = 'membership_eligibility_rules'
  MENTOR_RECOMMENDATION            = 'mentor_recommendation'
  CAMPAIGN_MANAGEMENT              = 'campaign_management'
  SKIP_AND_FAVORITE_PROFILES       = 'skip_and_favorite_profiles'
  MENTOR_TO_MENTEE_MATCHING        = 'mentor_to_mentee_matching'
  MATCH_REPORT                     = 'match_report'
  # The below are organization level features and there are others too
  CUSTOMIZE_EMAILS                 = 'customize_emails'
  MOBILE_VIEW                      = 'mobile_view'
  COACH_RATING                     = 'coach_rating'
  CAREER_DEVELOPMENT               = 'career_development'
  USER_CSV_IMPORT                  = 'user_csv_import'
  CALENDAR_SYNC                    = 'calendar_sync'
  CALENDAR_SYNC_V2                 = 'calendar_sync_v2'
  GLOBAL_REPORTS_V3                = 'global_reports_v3' # tldr: Global reports V3, reports that are intended to be presented by org admin to their org executives
  SHARE_PROGRESS_REPORTS           = 'share_progress_reports'
  ORG_WIDE_CALENDAR_ACCESS         = 'organization_wide_calendar_access'
  ENHANCED_MEETING_SCHEDULER       = 'enhanced_meeting_scheduler'
  WORK_ON_BEHALF                   = 'work_on_behalf'
  EXPLICIT_USER_PREFERENCES        = 'explicit_user_preferences'
  POPULAR_CATEGORIES               = 'popular_categories'

  def self.all
    [
      ANSWERS, ARTICLES, SKYPE_INTERACTION, SUBPROGRAM_CREATION,
      CONNECTION_PROFILE, PROFILE_COMPLETION_ALERT, CALENDAR, MENTORING_CONNECTION_MEETING,
      MEMBER_TAGGING, OFFER_MENTORING,
      RESOURCES, GLOBAL_REPORTS_V3,
      FLAGGING, PROGRAM_EVENTS, STICKY_TOPIC, FORUMS,
      BULK_MATCH, ORGANIZATION_PROFILES, DATA_IMPORT, COACHING_GOALS, ENROLLMENT_PAGE,
      LINKEDIN_IMPORTS, LANGUAGE_SETTINGS, MODERATE_FORUMS, THREE_SIXTY, MENTORING_CONNECTIONS_V2, MANAGER,
      LOGGED_IN_PAGES, MENTORING_INSIGHTS, CAMPAIGN_MANAGEMENT, CUSTOMIZE_EMAILS, CONTRACT_MANAGEMENT,EXECUTIVE_SUMMARY_REPORT, PROGRAM_OUTCOMES_REPORT,
      MOBILE_VIEW, COACH_RATING, MEMBERSHIP_ELIGIBILITY_RULES, MENTOR_RECOMMENDATION, CAREER_DEVELOPMENT, USER_CSV_IMPORT, CALENDAR_SYNC,
      CALENDAR_SYNC_V2, SHARE_PROGRESS_REPORTS, ORG_WIDE_CALENDAR_ACCESS, SKIP_AND_FAVORITE_PROFILES, ENHANCED_MEETING_SCHEDULER,
      EXPLICIT_USER_PREFERENCES, WORK_ON_BEHALF, MENTOR_TO_MENTEE_MATCHING, POPULAR_CATEGORIES, MATCH_REPORT
    ]
  end

  def self.removed_as_feature_from_ui
    [
      OFFER_MENTORING, CALENDAR
    ] + tandem_features
  end

  def self.organization_level_features
    [
      CUSTOMIZE_EMAILS, MOBILE_VIEW, COACH_RATING, THREE_SIXTY, LANGUAGE_SETTINGS, SUBPROGRAM_CREATION, MANAGER, CAREER_DEVELOPMENT, GLOBAL_REPORTS_V3
    ]
  end

  def self.program_level_only
    [
      OFFER_MENTORING, CALENDAR
    ]
  end

  def self.super_user_features
    [
      SUBPROGRAM_CREATION, CONNECTION_PROFILE, CALENDAR, MENTORING_CONNECTION_MEETING, MEMBER_TAGGING, FORUMS,
      STICKY_TOPIC, BULK_MATCH, ORGANIZATION_PROFILES, DATA_IMPORT, COACHING_GOALS, GLOBAL_REPORTS_V3,
      ENROLLMENT_PAGE, LANGUAGE_SETTINGS, MODERATE_FORUMS, THREE_SIXTY, MENTORING_CONNECTIONS_V2, MANAGER,
      LOGGED_IN_PAGES, MENTORING_INSIGHTS, CUSTOMIZE_EMAILS, CONTRACT_MANAGEMENT, EXECUTIVE_SUMMARY_REPORT,
      PROGRAM_OUTCOMES_REPORT, MOBILE_VIEW, COACH_RATING, MEMBERSHIP_ELIGIBILITY_RULES, MENTOR_RECOMMENDATION,
      CAREER_DEVELOPMENT, CAMPAIGN_MANAGEMENT, USER_CSV_IMPORT, CALENDAR_SYNC, CALENDAR_SYNC_V2, SHARE_PROGRESS_REPORTS,
      ORG_WIDE_CALENDAR_ACCESS, SKIP_AND_FAVORITE_PROFILES, ENHANCED_MEETING_SCHEDULER,
      EXPLICIT_USER_PREFERENCES, WORK_ON_BEHALF, MENTOR_TO_MENTEE_MATCHING, POPULAR_CATEGORIES, MATCH_REPORT
    ]
  end

  def self.default_features
    [
      ANSWERS, ARTICLES, PROFILE_COMPLETION_ALERT, RESOURCES, FORUMS,
      MENTORING_CONNECTIONS_V2, FLAGGING, STICKY_TOPIC, ORGANIZATION_PROFILES, SKYPE_INTERACTION,
      PROGRAM_EVENTS, LINKEDIN_IMPORTS, MENTORING_INSIGHTS, EXECUTIVE_SUMMARY_REPORT, CAMPAIGN_MANAGEMENT, MOBILE_VIEW, CALENDAR_SYNC, SKIP_AND_FAVORITE_PROFILES, WORK_ON_BEHALF, EXPLICIT_USER_PREFERENCES
    ]
  end

  def self.default_basic_features
    [
      PROFILE_COMPLETION_ALERT, BULK_MATCH, RESOURCES, MOBILE_VIEW, CALENDAR_SYNC, WORK_ON_BEHALF
    ]
  end

  def self.default_demo_features
    [
      ARTICLES, BULK_MATCH, CONNECTION_PROFILE, ENROLLMENT_PAGE, FLAGGING, CALENDAR, STICKY_TOPIC, ORGANIZATION_PROFILES, LINKEDIN_IMPORTS, MEMBER_TAGGING, MENTORING_CONNECTION_MEETING, MENTORING_CONNECTIONS_V2, MENTORING_INSIGHTS, PROFILE_COMPLETION_ALERT, PROGRAM_EVENTS, ANSWERS, RESOURCES, SKYPE_INTERACTION, THREE_SIXTY, FORUMS, CAMPAIGN_MANAGEMENT, CALENDAR_SYNC, SKIP_AND_FAVORITE_PROFILES, WORK_ON_BEHALF, MENTOR_TO_MENTEE_MATCHING, EXPLICIT_USER_PREFERENCES, MATCH_REPORT
    ]
  end

  def self.dependent_features
    {
      MENTORING_CONNECTIONS_V2 => {
        enabled: [MENTORING_CONNECTION_MEETING],
        disabled: [COACHING_GOALS]
      },

      ORG_WIDE_CALENDAR_ACCESS => {
        enabled: [CALENDAR_SYNC_V2]
      }
    }
  end

  def self.tandem_features
    tandem_features_info.values.flatten.uniq
  end
  
  # tandem features : currently works based on some other feature in tandem and don't appear in UI, and in future will be rolled out as a separate feature
  # Enabling or disabling the 'hash key' feature, enables or disables all the features listed in the 'hash value' array
  def self.tandem_features_info
    {
      CALENDAR_SYNC_V2 => [ENHANCED_MEETING_SCHEDULER]
    }
  end

  def self.specific_dependent_features
    {
      project_based: {
        enabled: [CONNECTION_PROFILE, MENTORING_CONNECTIONS_V2],
        disabled: [BULK_MATCH, CALENDAR, OFFER_MENTORING]
      }
    }
  end

  def self.dependent_emails
    {
      CALENDAR_SYNC => {
        enabled: Meeting::CALENDAR_SYNC_NECESSARY_EMAILS,
        disabled: []
      }
    }
  end

  def self.list(feature_name, prog_or_org = nil, options = {})
    Titles.translate(feature_name, prog_or_org, options)
  end

  def self.ongoing_mentoring_related_features
    [CONNECTION_PROFILE, BULK_MATCH, COACHING_GOALS, OFFER_MENTORING, MENTORING_CONNECTION_MEETING, MENTORING_CONNECTIONS_V2, MENTORING_INSIGHTS, MENTOR_RECOMMENDATION]
  end

  module Titles
    def self.get_translate_hash(prog_or_org)
      {
        mentor_name_plural_uppercase: prog_or_org.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).try(:pluralized_term),
        program_term_upcase: prog_or_org.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term,
        mentoring_term_downcase: prog_or_org.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase,
        career_development_term_upcase: prog_or_org.term_for(CustomizedTerm::TermType::CAREER_DEVELOPMENT_TERM).term,
        mentoring_connection_name_upcase: prog_or_org.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term,
        meeting_term_uppercase: prog_or_org.term_for(CustomizedTerm::TermType::MEETING_TERM).term,
        mentor_name_uppercase: prog_or_org.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).try(:term),
        mentee_name_uppercase: prog_or_org.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).try(:term)
      }
    end

    def self.translate(key, prog_or_org, options = {})
      translate_hash = {default: ""}
      if options[:use_translate_hash]
        translate_hash.merge!(options[:use_translate_hash])
      else
        translate_hash.merge!(get_translate_hash(prog_or_org)) if prog_or_org
      end
      "features_list.#{key}.title".translate(translate_hash)
    end
  end

  module Descriptions

    DESCRIPTION_KEY_MAPPING = {
      FeatureName::LINKEDIN_IMPORTS => "description_v1"
    }

    def self.get_translate_hash(prog_or_org)
      {
        default: "",
        mentor_name: prog_or_org.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).try(:term_downcase),
        mentee_name: prog_or_org.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).try(:term_downcase),
        mentee_name_plural: prog_or_org.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).try(:pluralized_term_downcase),
        mentor_name_plural: prog_or_org.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).try(:pluralized_term_downcase),
        mentoring_connection_name: prog_or_org.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase,
        mentoring_connection_name_plural: prog_or_org.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase,
        program: prog_or_org.term_for(CustomizedTerm::TermType::PROGRAM_TERM).try(:term_downcase),
        mentoring_term_downcase: prog_or_org.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase,
        meeting_term_downcase: prog_or_org.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase
      }
    end

    def self.translate(key, prog_or_org, options = {})
      description_key = DESCRIPTION_KEY_MAPPING[key] || "description"
      translate_hash = options[:use_description_translate_hash] || get_translate_hash(prog_or_org)
      "features_list.#{key}.#{description_key}".translate(translate_hash)
    end
  end
end

# Add definition for all the features.
ActionController::Base.class_eval do
  add_feature(FeatureName::ANSWERS, [:qa_answers]) # qa_questions handled inside controller authorize method
  add_feature(FeatureName::ARTICLES, [:comments]) # articles handled inside controller authorize method
  add_feature(FeatureName::CONNECTION_PROFILE, ["connection/questions"])
  add_feature(FeatureName::CALENDAR, [:mentoring_slots, :meeting_requests], [{:controller => "users", :action => "mentoring_calendar"},{:controller => "reports", :action => "mentor_engagement_report"}])
  add_feature(FeatureName::MENTORING_CONNECTION_MEETING, [])
  add_feature(FeatureName::MEMBER_TAGGING, [], [{:controller => "users", :action => "update_tags"}])
  add_feature(FeatureName::OFFER_MENTORING, [:mentor_offers])
  ## This handled separately at the controller.
  # add_feature(FeatureName::RESOURCES, [:resources])
  add_feature(FeatureName::FLAGGING, [:flags])
  add_feature(FeatureName::PROGRAM_EVENTS, [:program_events])
  add_feature(FeatureName::STICKY_TOPIC, [], [{controller: 'topics', action: 'set_sticky_position'}])
  add_feature(FeatureName::MENTOR_RECOMMENDATION, [:bulk_recommendations])
  add_feature(FeatureName::ORGANIZATION_PROFILES, [], [{controller: 'members', action: 'index'}])
  add_feature(FeatureName::DATA_IMPORT, [:data_imports])
  add_feature(FeatureName::COACHING_GOALS, [:coaching_goals, :coaching_goal_activities])
  add_feature(FeatureName::LINKEDIN_IMPORTS, [:linkedin_import])
  add_feature(FeatureName::LANGUAGE_SETTINGS, [:language_settings, :translations])
  add_feature(FeatureName::MODERATE_FORUMS, [], [{controller: "posts", action: "moderatable_posts"}])
  add_feature(FeatureName::THREE_SIXTY, ["three_sixty/competencies", "three_sixty/questions", "three_sixty/surveys", "three_sixty/survey_competencies", "three_sixty/survey_questions", "three_sixty/survey_assessees", "three_sixty/survey_reviewers", "three_sixty/reviewer_groups"], [{:controller => "organizations", :action => "update_three_sixty_settings"}])
  add_feature(FeatureName::MENTORING_CONNECTIONS_V2, [:mentoring_models, :"mentoring_model/task_templates", :"mentoring_model/goal_templates", :"mentoring_model/milestone_templates", :"mentoring_model/goals", :"mentoring_model/tasks", :"mentoring_model/milestones"])
  add_feature(FeatureName::MENTORING_INSIGHTS, [:mentoring_tips])
  add_feature(FeatureName::CONTRACT_MANAGEMENT, [:group_checkins])
  add_feature(FeatureName::EXECUTIVE_SUMMARY_REPORT, [], [{controller: "reports", action: "executive_summary"}])
  add_feature(FeatureName::PROGRAM_OUTCOMES_REPORT, [:outcomes_report], [{controller: 'reports', action: 'outcomes_report'}])
  add_feature(FeatureName::COACH_RATING, ["feedback/responses"], [:controller => "users", :action => "reviews"])
  add_feature(FeatureName::CAREER_DEVELOPMENT, ["career_dev/portals"])
  add_feature(FeatureName::CAMPAIGN_MANAGEMENT, ["campaign_management/user_campaigns"])
  add_feature(FeatureName::USER_CSV_IMPORT, [:csv_imports])
  add_feature(FeatureName::SKIP_AND_FAVORITE_PROFILES, [:favorites, :ignores])
  add_feature(FeatureName::WORK_ON_BEHALF, [], [{:controller => "users", :action => "work_on_behalf"}, {:controller => "users", :action => "exit_wob"} ])
end
