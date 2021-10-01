# == Schema Information
#
# Table name: programs
#
#  id                                                :integer          not null, primary key
#  name                                              :string(255)
#  description                                       :text(65535)
#  created_at                                        :datetime
#  updated_at                                        :datetime
#  user_id                                           :integer
#  allow_one_to_many_mentoring                       :boolean
#  mentoring_period                                  :integer
#  analytics_script                                  :text(65535)
#  agreement                                         :text(4294967295)
#  sort_users_by                                     :integer          default(0)
#  default_max_connections_limit                     :integer          default(5)
#  min_preferred_mentors                             :integer          default(0)
#  max_connections_for_mentee                        :integer
#  theme_id                                          :integer
#  allow_mentoring_requests                          :boolean          default(TRUE)
#  allow_mentoring_requests_message                  :text(65535)
#  inactivity_tracking_period                        :integer          default(2592000)
#  mentor_request_style                              :integer          default(2)
#  footer_code                                       :text(65535)
#  type                                              :string(255)      not null
#  parent_id                                         :integer
#  root                                              :string(255)
#  programs_count                                    :integer
#  logout_path                                       :string(255)
#  active                                            :boolean          default(TRUE)
#  ssl_only                                          :boolean          default(FALSE)
#  privacy_policy                                    :text(65535)
#  mentor_offer_needs_acceptance                     :boolean          default(TRUE)
#  base_program_id                                   :integer
#  subscription_type                                 :integer          default(1)
#  allow_users_to_leave_connection                   :boolean
#  allow_to_change_connection_expiry_date            :boolean          default(FALSE)
#  allow_mentee_withdraw_mentor_request              :boolean          default(FALSE)
#  published                                         :boolean          default(TRUE)
#  max_pending_requests_for_mentee                   :integer
#  fluid_layout                                      :boolean          default(TRUE)
#  cannot_edit_admin_task_owner                      :boolean          default(TRUE)
#  account_name                                      :string(255)
#  allow_private_journals                            :boolean          default(TRUE)
#  allow_connection_feedback                         :boolean          default(TRUE)
#  allow_preference_mentor_request                   :boolean          default(TRUE)
#  show_multiple_role_option                         :boolean          default(FALSE)
#  can_update_root                                   :boolean          default(FALSE), not null
#  email_from_address                                :string(255)
#  allow_users_to_mark_connection_public             :boolean          default(FALSE)
#  prevent_manager_matching                          :boolean          default(FALSE)
#  allow_non_match_connection                        :boolean          default(FALSE)
#  zero_match_score_message                          :text(65535)
#  manager_matching_level                            :integer          default(1)
#  engagement_type                                   :integer
#  connection_limit_permission                       :integer          default(3)
#  hybrid_templates_enabled                          :boolean          default(FALSE)
#  program_type                                      :string(255)
#  number_of_licenses                                :integer
#  needs_meeting_request_reminder                    :boolean          default(FALSE)
#  meeting_request_reminder_duration                 :integer          default(3)
#  needs_mentoring_request_reminder                  :boolean          default(FALSE)
#  mentoring_request_reminder_duration               :integer          default(3)
#  programs_listing_visibility                       :integer          default(0)
#  mentor_request_expiration_days                    :integer
#  needs_project_request_reminder                    :boolean          default(FALSE)
#  project_request_reminder_duration                 :integer          default(3)
#  show_text_type_answers_per_reviewer_category      :boolean          default(TRUE)
#  position                                          :integer
#  meeting_request_auto_expiration_days              :integer
#  auto_terminate_reason_id                          :integer
#  active_mobile_theme                               :integer
#  admin_access_to_mentoring_area                    :integer          default(0)
#  allow_mentoring_mode_change                       :integer          default(0)
#  ssl_certificate_available                         :boolean          default(FALSE)
#  creation_way                                      :integer
#  prevent_past_mentor_matching                      :boolean          default(FALSE)
#  email_theme_override                              :string(255)
#  white_label                                       :boolean          default(FALSE)
#  favicon_link                                      :text(65535)
#  display_custom_terms_only                         :boolean          default(FALSE)
#  zendesk_support_portal                            :boolean          default(FALSE)
#  rollout_enabled                                   :boolean          default(FALSE)
#  audit_user_communication                          :boolean          default(FALSE)
#  processing_weekly_digest                          :boolean          default(FALSE)
#  allow_user_to_send_message_outside_mentoring_area :boolean          default(TRUE)
#  allow_end_users_to_see_match_scores               :boolean          default(TRUE)
#  allow_track_admins_to_access_all_users            :boolean          default(FALSE)
#  browser_warning                                   :text(65535)
#

class AbstractProgram < ActiveRecord::Base
  self.table_name = 'programs'

  # XXX Remove below code
  include ActionView::Helpers::DateHelper
  include AuthorizationManager::ProgramExtensions
  include TranslationsService

  #-----------------------------------------------------------------------------
  # ASSOCIATIONS
  #-----------------------------------------------------------------------------
  belongs_to  :active_theme,  :foreign_key => "theme_id", :class_name => "Theme"

  has_many :sections,      -> {order 'position'}, :foreign_key => "program_id", :dependent => :destroy
  has_many :roles,         :foreign_key => 'program_id', :dependent => :destroy
  has_many :pages,         -> {order 'position'}, :foreign_key => 'program_id', :dependent => :destroy
  has_many :themes,         :foreign_key => 'program_id', :dependent => :destroy
  has_many :mailer_templates, :foreign_key => 'program_id', :dependent => :destroy, :class_name => "Mailer::Template"
  has_many :mailer_widgets,   :foreign_key => 'program_id', :dependent => :destroy, :class_name => "Mailer::Widget"
  has_many :organization_features, :dependent => :destroy, :foreign_key => "organization_id"
  # The below feature associations will return features based on the direct db constraints present, and not
  # based on the actual organization/ program heirarchy which we use for the enabled and disabled features
  has_many :enabled_db_features, -> { where(organization_features: { enabled: true } ) }, source: :feature, through: :organization_features
  has_many :disabled_db_features,  -> { where(organization_features: { enabled: false } ) }, source: :feature, through: :organization_features

  has_many :customized_terms, :as => :ref_obj, :dependent => :destroy

  has_many :resources, :foreign_key => 'program_id', :dependent => :destroy

  has_many :admin_messages,  :foreign_key => 'program_id', :dependent  => :destroy
  has_many :admin_message_receivers, :through => :admin_messages, :source => :message_receivers
  has_many :abstract_views, dependent: :destroy, foreign_key: :program_id
  has_many :report_alerts, through: :abstract_views, source: :alerts
  has_many :ab_tests, dependent: :destroy, :foreign_key => 'program_id', :class_name => 'ProgramAbTest'
  has_many :actioned_rollout_emails, :class_name => "RolloutEmail", :as => :ref_obj, :dependent => :destroy

  has_many :user_csv_imports, :foreign_key => "program_id", :dependent => :destroy

  has_many :translation_imports, :foreign_key => "program_id", :dependent => :destroy

  has_one :default_section, -> { where(default_field: true) }, class_name: 'Section', foreign_key: 'program_id'
  has_one :program_asset, :foreign_key => "program_id", :dependent => :destroy

  translates :name, :description, :allow_mentoring_requests_message, :agreement, :privacy_policy, :browser_warning, :zero_match_score_message, fallbacks_for_empty_translations: true

  delegate :banner,
           :banner=,
           :logo,
           :logo=,
           :mobile_logo,
           :mobile_logo=,
           :to => :program_asset

  # ----------------------------------------------------------------------------
  # INSTANCE METHODS
  # ----------------------------------------------------------------------------

  # Fetches all users having one among the primitive roles
  #
  # Program#users is used only for *scoping* lookup of users to the program,
  # like <code>@program.users.find(params[:id])</code>. Only the persona
  # specific has_ associations are used otherwise.
  # users returns [admins + mentors + mentees]
  def users
    self.all_users
  end

  def get_role_names
    self.roles.collect(&:name)
  end

  #
  # Creates the default roles for the program by loading from role contants
  #
  def create_default_roles
    RoleConstants::DEFAULT_ROLE_NAMES.each do |role_name|
      get_role(role_name) || create_role(role_name)
    end
  end

  def build_default_roles
    RoleConstants::DEFAULT_ROLE_NAMES.each do |role_name|
      get_role(role_name) || build_role(role_name)
    end
  end

  def create_role(role_name)
    permissions = Permission.where(name: RoleConstants::DEFAULT_ROLE_PERMISSIONS[role_name])
    # Create role with the permissions and default join settings
    self.roles.create!(construct_options(role_name, permissions))
  end

  def build_role(role_name)
    permissions = Permission.where(name: RoleConstants::DEFAULT_ROLE_PERMISSIONS[role_name])
    # Build role with the permissions and default join settings
    roles.build(construct_options(role_name, permissions))
  end

  #
  # Returns whether this question is comparable with +other_program+
  # for similarity and matching.
  #
  def comparable_with?(other_program)
    case [self.class, other_program.class]
    # Both are program or organization level questions. True if both are same.
    when [Program, Program], [Organization, Organization]
      self == other_program

    # True if this program is under the other_program organization
    when [Program, Organization]
      self.organization == other_program

    # True if the other_program is under this organization.
    when [Organization, Program]
      self == other_program.organization
    end
  end

  def does_logo_exist?
    self.program_asset.present? && self.logo.exists?
  end

  def logo_url
    @abstract_program_logo_hash ||= {}
    return @abstract_program_logo_hash[self.id] if @abstract_program_logo_hash.has_key?(self.id)

    logo_locale = self.does_logo_exist? ? I18n.locale : I18n.default_locale
    GlobalizationUtils.run_in_locale(logo_locale) do
      @abstract_program_logo_hash[self.id] = self.does_logo_exist? ? self.logo.url : nil
    end
    @abstract_program_logo_hash[self.id]
  end

  def does_banner_exist?
    self.program_asset.present? && self.banner.exists?
  end

  def banner_url
    @abstract_program_banner_hash ||= {}
    return @abstract_program_banner_hash[self.id] if @abstract_program_banner_hash.has_key?(self.id)

    banner_locale = self.does_banner_exist? ? I18n.locale : I18n.default_locale
    GlobalizationUtils.run_in_locale(banner_locale) do
      @abstract_program_banner_hash[self.id] = self.does_banner_exist? ? self.banner.url : nil
    end
    @abstract_program_banner_hash[self.id]
  end

  def logo_or_banner_url(asset_priority = [:logo, :banner], with_type = false)
    asset_url, asset_type = [nil, nil]

    asset_priority.each do |type|
      asset_method = "#{type}_url"
      if self.send(asset_method).present?
        asset_url, asset_type = [self.send(asset_method), type]
        break
      end
    end
    with_type ? [asset_url, asset_type] : asset_url
  end

  def can_render_mobile_logo?
    self.program_asset.present? && self.mobile_logo.exists?
  end

  def mobile_logo_url
    self.program_asset.present? && self.mobile_logo.exists? ? self.mobile_logo.url : nil
  end

  def set_fluid_layout(true_or_false)
    self.update_attribute(:fluid_layout, true_or_false)
  end

  #-----------------------------------------------------------------------------
  # --- ADMIN MESSAGES - sent and received by admin
  #-----------------------------------------------------------------------------

  def admin_messages_unread_count
    self.admin_message_receivers.received.unread.size
  end

  # Since a message can exist without message receivers, we are doing Left Outer Join + message_receivers.message_id IS NULL
  def sent_admin_message_ids
    admin_messages.select("DISTINCT messages.id").
      joins("LEFT OUTER JOIN abstract_message_receivers ON abstract_message_receivers.message_id = messages.id").
      where("abstract_message_receivers.message_id IS NULL OR
        abstract_message_receivers.email IS NOT NULL OR
        abstract_message_receivers.member_id IS NOT NULL")
  end

  def received_admin_message_ids
    admin_messages.select("DISTINCT messages.id").
      joins(:message_receivers).
      where('abstract_message_receivers.email' => nil).
      where('abstract_message_receivers.member_id' => nil).
      where('abstract_message_receivers.status!=?', AbstractMessageReceiver::Status::DELETED)
  end

  #-----------------------------------------------------------------------------
  # --- THEMES
  #-----------------------------------------------------------------------------

  #
  # Returns the first active theme of this program
  #
  def private_themes
    Theme.available_themes(self)
  end

  #
  # Assigns the default theme to this organization.
  #
  def assign_default_theme
    theme = Theme.global.default.first
    self.activate_theme(theme)
  end
  #
  # Sets the given theme as the active theme for the program.
  #
  def activate_theme(new_theme)
    self.active_theme = new_theme
    self.save!
  end

  #-----------------------------------------------------------------------------
  # --- ROLE QUESTIONS UPDATE
  #-----------------------------------------------------------------------------

  #
  # Returns the last updated_at timestamp of role questions for the user_role
  #
  def role_questions_last_update_timestamp(role)
    role_q = self.role_questions_for(role)
    return role_q.sort_by(&:updated_at).last.try(:updated_at).to_i
  end

  def roles_without_admin_role
    self.roles.non_administrative
  end

  def role_names_without_admin_role
    roles_without_admin_role.collect(&:name)
  end

  #-----------------------------------------------------------------------------
  # --- PROFILE COMPLETION
  #-----------------------------------------------------------------------------

  #
  # Returns the last updated_at timestamp of questions for the user Returns nil
  # if the user is an admin
  #
  #TODO #CareerDev - Hardcoded Role #ProfileQuestions
  def profile_questions_last_update_timestamp(user)
    if user.is_mentor?
      mentor_questions_last_update_timestamp
    elsif user.is_student?
      student_questions_last_update_timestamp
    end
  end

  #
  # Returns the last updated_at timestamp for mentor questions.
  # Returns 0 if there are no questions
  #
  def mentor_questions_last_update_timestamp
    mentor_prof_q = self.profile_questions_for([RoleConstants::MENTOR_NAME], {:default => false, :skype => self.organization.skype_enabled?, pq_translation_include: false})
    mentor_prof_q.sort_by(&:updated_at).last.try(:updated_at).to_i
  end

  #
  # Returns the last updated_at timestamp for student questions Returns 0 if
  # there are no questions
  #
  def student_questions_last_update_timestamp
    student_prof_q = self.profile_questions_for([RoleConstants::STUDENT_NAME], {:default => false, :skype => self.organization.skype_enabled?, pq_translation_include: false })
    student_prof_q.sort_by(&:updated_at).last.try(:updated_at).to_i
  end

  #-----------------------------------------------------------------------------
  # --- FEATURES
  #-----------------------------------------------------------------------------

  def enable_feature(feature_name, should_enable = true)
    is_enabled = self.has_feature?(feature_name)

    # If the enabled state does not match <i>should_enable</i>, either create or
    # change the status as required.
    if is_enabled != should_enable
      enable_disable_feature(feature_name, should_enable)
    end
  end

  def enable_disable_feature(feature_name, should_enable)
    feature = Feature.find_by(name: feature_name)
    org_feature = self.organization_features.find_by(feature_id: feature.id)
    create_update_feature_record(should_enable, feature, org_feature)

    # these association have to be explicitly reloaded that the enabled_features & disabled_features methods work
    self.enabled_db_features.reload
    self.disabled_db_features.reload
  end

  def create_update_feature_record(status, feature, org_feature_record = nil)
    if org_feature_record.nil?
      self.organization_features.create!(:organization_id => self.id, :feature => feature, :enabled => status)
    else
      org_feature_record.update_attributes!(:enabled => status)
    end
    (FeatureName.tandem_features_info[feature.name] || []).each do |tandem_feature_name|
      tandem_feature = Feature.find_by(name: tandem_feature_name)
      create_update_feature_record(status, tandem_feature, organization_features.find_by(feature_id: tandem_feature.id))
    end
  end

  def removed_as_feature_from_ui
    return FeatureName.removed_as_feature_from_ui
  end

  def permanently_disabled_features
    return []
  end

  #-----------------------------------------------------------------------------
  # --- MISCELLANEOUS
  #-----------------------------------------------------------------------------

  def has_feature?(feature_name)
    self.enabled_features.include?(feature_name)
  end

  def mentoring_insights_enabled?
    self.has_feature?(FeatureName::MENTORING_INSIGHTS)
  end

  # Returns if skype interactionis enabled for the program
  def skype_enabled?
    self.has_feature?(FeatureName::SKYPE_INTERACTION)
  end

  def subprogram_creation_enabled?
    self.has_feature?(FeatureName::SUBPROGRAM_CREATION)
  end

  def career_development_enabled?
    self.has_feature?(FeatureName::CAREER_DEVELOPMENT)
  end

  def connection_profiles_enabled?
    self.has_feature?(FeatureName::CONNECTION_PROFILE)
  end

  def profile_completion_alert_enabled?
    self.has_feature?(FeatureName::PROFILE_COMPLETION_ALERT)
  end

  def calendar_enabled?
    self.has_feature?(FeatureName::CALENDAR)
  end

  def calendar_sync_v2_enabled?
    self.has_feature?(FeatureName::CALENDAR_SYNC_V2)
  end

  def organization_wide_calendar_access_enabled?
    self.has_feature?(FeatureName::ORG_WIDE_CALENDAR_ACCESS)
  end

  def calendar_sync_v2_for_member_applicable?
    calendar_sync_v2_enabled? && !organization_wide_calendar_access_enabled?
  end

  def global_reports_v3_applicable?(options = {})
    return false unless org_profiles_enabled?
    member = options[:member] || options[:user]&.member
    return true if options[:accessing_as_super_admin] || member&.mentoradmin?
    return has_feature?(FeatureName::GLOBAL_REPORTS_V3) if member&.admin?
  end

  def enhanced_meeting_scheduler_enabled?
    self.has_feature?(FeatureName::ENHANCED_MEETING_SCHEDULER)
  end

  def mentoring_connection_meeting_enabled?
    self.has_feature?(FeatureName::MENTORING_CONNECTION_MEETING)
  end

  def mentor_offer_enabled?
    self.has_feature?(FeatureName::OFFER_MENTORING)
  end

  def resources_enabled?
    self.has_feature?(FeatureName::RESOURCES)
  end

  def flagging_enabled?
    self.has_feature?(FeatureName::FLAGGING)
  end

  def moderation_enabled?
    self.has_feature?(FeatureName::MODERATE_FORUMS)
  end

  def program_events_enabled?
    self.has_feature?(FeatureName::PROGRAM_EVENTS)
  end

  def sticky_topics_enabled?
    self.has_feature?(FeatureName::STICKY_TOPIC)
  end

  def org_profiles_enabled?
    self.has_feature?(FeatureName::ORGANIZATION_PROFILES)
  end

  def articles_enabled?
    self.has_feature?(FeatureName::ARTICLES)
  end

  def qa_enabled?
    self.has_feature?(FeatureName::ANSWERS)
  end

  def forums_enabled?
    self.has_feature?(FeatureName::FORUMS)
  end

  def bulk_match_enabled?
    self.has_feature?(FeatureName::BULK_MATCH)
  end

  def data_import_enabled?
    self.has_feature?(FeatureName::DATA_IMPORT)
  end

  def enrollment_page_enabled?
    self.has_feature?(FeatureName::ENROLLMENT_PAGE)
  end

  def coaching_goals_enabled?
    self.has_feature?(FeatureName::COACHING_GOALS)
  end

  def linkedin_imports_feature_enabled?
    obj = self.is_a?(Program) ? self.organization : self
    self.has_feature?(FeatureName::LINKEDIN_IMPORTS) && obj.linkedin_imports_allowed?
  end

  def language_settings_enabled?
    self.has_feature?(FeatureName::LANGUAGE_SETTINGS)
  end

  def manager_enabled?
    self.has_feature?(FeatureName::MANAGER)
  end

  def three_sixty_tool_enabled?
    self.has_feature?(FeatureName::THREE_SIXTY)
  end

  def mentoring_connections_v2_enabled?
    self.has_feature?(FeatureName::MENTORING_CONNECTIONS_V2)
  end

  def logged_in_pages_enabled?
    self.has_feature?(FeatureName::LOGGED_IN_PAGES)
  end

  def customize_emails_enabled?
    self.has_feature?(FeatureName::CUSTOMIZE_EMAILS)
  end

  def contract_management_enabled?
    self.has_feature?(FeatureName::CONTRACT_MANAGEMENT)
  end

  def membership_eligibility_rules_enabled?
    self.has_feature?(FeatureName::MEMBERSHIP_ELIGIBILITY_RULES)
  end

  def executive_summary_report_enabled?
    self.has_feature?(FeatureName::EXECUTIVE_SUMMARY_REPORT)
  end

  def program_outcomes_report_enabled?
    self.has_feature?(FeatureName::PROGRAM_OUTCOMES_REPORT)
  end

  def mobile_view_enabled?
    self.has_feature?(FeatureName::MOBILE_VIEW)
  end

  def mentor_recommendation_enabled?
    self.has_feature?(FeatureName::MENTOR_RECOMMENDATION)
  end

  def coach_rating_enabled?
    self.has_feature?(FeatureName::COACH_RATING)
  end

  def campaign_management_enabled?
    self.has_feature?(FeatureName::CAMPAIGN_MANAGEMENT)
  end

  def skip_and_favorite_profiles_enabled?
    self.has_feature?(FeatureName::SKIP_AND_FAVORITE_PROFILES) && self.is_a?(Program) && self.matching_by_mentee_alone? && self.find_role(RoleConstants::STUDENT_NAME).has_permission_name?("view_mentors")
  end

  def user_csv_import_enabled?
    self.has_feature?(FeatureName::USER_CSV_IMPORT)
  end

  def calendar_sync_enabled?
    self.has_feature?(FeatureName::CALENDAR_SYNC)
  end

  def share_progress_reports_enabled?
    self.has_feature?(FeatureName::SHARE_PROGRESS_REPORTS)
  end

  def mentor_to_mentee_matching_enabled?
    self.has_feature?(FeatureName::MENTOR_TO_MENTEE_MATCHING)
  end

  def match_report_enabled?
    self.has_feature?(FeatureName::MATCH_REPORT)
  end
  
  def explicit_user_preferences_enabled?
    @explicit_user_preferences_enabled ||= (self.has_feature?(FeatureName::EXPLICIT_USER_PREFERENCES) && self.is_a?(Program) && self.career_based_self_match_or_only_flash? && self.find_role(RoleConstants::STUDENT_NAME).has_permission_name?("view_mentors") && self.get_valid_role_questions_for_explicit_preferences.present?)
  end

  #-----------------------------------------------------------------------------
  # --- USED FOR NOTIFICATION ABOUT NEW ACTIVITIES IN THE PROGRAM
  #-----------------------------------------------------------------------------

  def new_mentors(created_after = WEEKLY_UPDATE_PERIOD.ago)
    self.mentor_users.active.recent(created_after)
  end

  def new_students_count(created_after = WEEKLY_UPDATE_PERIOD.ago)
    self.student_users.active.recent(created_after).count
  end

  def new_articles(created_after = WEEKLY_UPDATE_PERIOD.ago)
    return [] unless self.articles_enabled?
    self.articles.published.recent(created_after).includes(:author => {:users => :roles})
  end

  def new_qa_questions(created_after = WEEKLY_UPDATE_PERIOD.ago)
    return [] unless self.qa_enabled?
    self.qa_questions.where("created_at > ?", created_after)
  end

  def invoke_feature_dependancy_offer_mentoring(enabled)
    self.roles.where(name: RoleConstants::MENTOR_NAME).each do |r|
      enabled ? r.add_permission("offer_mentoring") : r.remove_permission("offer_mentoring")
    end
  end

  def is_meetings_enabled_for_calendar_or_groups?
    self.calendar_enabled? || self.mentoring_connection_meeting_enabled?
  end

  def get_accessible_meetings_list(meetings_list)
    meetings_list = meetings_list
    if self.calendar_enabled? && self.mentoring_connection_meeting_enabled?
      meetings = meetings_list.of_program(self)
    elsif self.mentoring_connection_meeting_enabled?
      meetings = meetings_list.group_meetings.of_program(self)
    else
      meetings = meetings_list.non_group_meetings.of_program(self)
    end
  end

  #Returns a CustomizedTerm object, for a program/organization, given the term_type
  #Exception: If customized term is called for a role_name at organization level, it returns a String#Object
  #If ADMIN_TERM is called at organization level, it returns customized_term for ADMIN_TERM at organization level
  #If PROGRAM_TERM is called at program level, it returns the program term at Organization level
  def term_for(term_type, role_name = nil)
    return self.customized_terms.find_by(term_type: CustomizedTerm::TermType::ADMIN_TERM) if (self.is_a?(Organization) && ((term_type == CustomizedTerm::TermType::ADMIN_TERM ) || (term_type == CustomizedTerm::TermType::ROLE_TERM && role_name == RoleConstants::ADMIN_NAME)))

    if term_type == CustomizedTerm::TermType::ROLE_TERM
      #TODO #CareerDev - Hardcoded Role Check #Translations
      return roles.find_by(name: role_name).try(:customized_term) if self.is_a?(Program)
      mapped_role_name = RoleConstants::ROLE_DISPLAY_NAME_MAPPING[role_name]
      return mapped_role_name.present? ? mapped_role_name.capitalize : role_name.capitalize
    end

    if term_type == CustomizedTerm::TermType::PROGRAM_TERM || term_type == CustomizedTerm::TermType::CAREER_DEVELOPMENT_TERM
      scope = self.is_a?(Program) ? self.organization : self
      return scope.customized_terms.find_by(term_type: term_type)
    end

    return customized_terms.find_by(term_type: term_type)
  end

  def get_terms_for_view
    terms_to_fetch = self.is_a?(Program) ? CustomizedTerm::TermType::PROGRAM_LEVEL_TERMS : CustomizedTerm::TermType::ORGANIZATION_LEVEL_TERMS
    cached_custom_terms = self.customized_terms.includes(:translations)
    customized_terms = []
    terms_to_fetch.each do |term_type|
      if term_type == CustomizedTerm::TermType::ROLE_TERM
        self.roles.non_administrative.includes(customized_term: :translations).each do |role|
          customized_terms << role.customized_term
        end
      elsif !CustomizedTerm::TermType::CAREER_DEVELOPMENT_TERMS.include?(term_type) || self.career_development_enabled?
        customized_terms << cached_custom_terms.find{|term| term.term_type == term_type}
      end
    end
    customized_terms += self.programs.ordered.first.get_terms_for_view if (self.is_a?(Organization) && self.standalone?)
    customized_terms
  end

  def get_report_alerts_to_notify
    self.report_alerts.select(&:can_notify_alert?)
  end

  def enable_ab_test(experiment_name, enable=true)
    experiment = self.ab_tests.where(test: experiment_name).first_or_initialize
    experiment.enabled = enable
    experiment.save!
  end

  def return_custom_term(string)
    self.instance_variable_get('@'+ string)
  end

  def return_custom_term_hash
    @term_hash ||= {}
    if @term_hash.keys.blank?
      TranslationsService::initialize_custom_terms(self, self)
      AbstractProgram.translated_methods.each do |key|
        @term_hash[key] = self.return_custom_term(key.to_s)
      end
    end
    @term_hash
  end

  def return_custom_term_hash_with_third_role
    return_custom_term_hash.merge(third_role_hash)
  end

  def third_role_hash
    third_role = self.is_a?(Program) ? self.roles.find_by(name: RoleConstants::TEACHER_NAME) : nil
    third_role_term = third_role.try(:customized_term)
    hash = {}
    hash[:_Third_Role] = third_role_term.try(:term)||Proc.new{"feature.custom_terms.teacher".translate}.call
    hash[:_third_role] = third_role_term.try(:term_downcase)||Proc.new{"feature.custom_terms.downcase.teacher".translate}.call
    hash[:_Third_Roles] = third_role_term.try(:pluralized_term)||Proc.new{"feature.custom_terms.pluralize.teacher".translate}.call
    hash[:_a_Third_Role] = third_role_term.try(:articleized_term)||Proc.new{"feature.custom_terms.articalize.teacher".translate}.call
    hash[:_a_third_role] = third_role_term.try(:articleized_term_downcase)||Proc.new{"feature.custom_terms.articalize_downcase.teacher".translate}.call
    hash[:_third_roles] = third_role_term.try(:pluralized_term_downcase)||Proc.new{"feature.custom_terms.pluralize_downcase.teacher".translate}.call
    return hash
  end

  def theme_vars
    return self.active_theme ? self.active_theme.vars : {}
  end

  def disable_selected_mails_for_new_program_by_default
    mails_to_disable = Program::MAILS_TO_DISABLE_BY_DEFAULT.mail_classes_at_program_level
    mails_to_disable -= Meeting::CALENDAR_SYNC_NECESSARY_EMAILS if self.calendar_sync_enabled?
    mails_to_disable.each do |mail_class|
      Mailer::Template.create!(uid: mail_class.mailer_attributes[:uid], program_id: self.id, enabled: false)
    end
  end

  def translation_settings_sub_categories
    tabs = [ProgramsController::SettingsTabs::GENERAL , ProgramsController::SettingsTabs::TERMINOLOGY]
    if self.is_a?(Program)
      tabs += [ProgramsController::SettingsTabs::MEMBERSHIP]
      tabs += [ProgramsController::SettingsTabs::CONNECTION] if self.mentoring_connections_v2_enabled?
      tabs += [ProgramsController::SettingsTabs::MATCHING] if self.matching_enabled?
    end
    tab_objs = []
    tabs.each do |tab|
      tab_objs << {id: tab, heading: ProgramsController::SettingsTabs.get_label(tab, :Mentoring_Connection => self.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term)}
    end
    tab_objs
  end

  def reset_non_campaign_mails_content
    Mailer::Template.reset_content_for(self.mailer_templates.non_campaign_mails)
  end

  def reset_coppied_mails_content
    Mailer::Template.reset_content_for(self.mailer_templates.non_campaign_mails.both_copied)
    self.mailer_templates.non_campaign_mails.update_all(copied_content: nil)
  end

  def mailer_template_enable_or_disable(mailer_klass, enable_or_disable_value)
    mailer_template = mailer_templates.find_or_initialize_by(uid: mailer_klass.mailer_attributes[:uid])
    mailer_template.update_attributes!(enabled: enable_or_disable_value.present?)
  end

  def reset_mails_content_and_update_rollout(options={})
    options[:only_copied_content] ? self.reset_coppied_mails_content : self.reset_non_campaign_mails_content
    action_type = options[:only_copied_content] ? RolloutEmail::ActionType::UPDATE_ALL_NON_CUSTOMIZED : RolloutEmail::ActionType::UPDATE_ALL
    self.actioned_rollout_emails.create!(action_type: action_type)
  end

  def campaign_feature_non_editable?
    ((self.is_a?(Program) && self.user_campaigns.active.present?) || (self.is_a?(Organization) && self.programs_with_active_user_campaigns_present?))
  end

  def profile_questions_for_user_csv_import(role_names = nil)
    role_names ||= self.roles.pluck(:name) if self.is_a?(Program)
    pqs = self.is_a?(Program) ? self.profile_questions_for(role_names, {:default => false, :fetch_all => true}).to_a : self.profile_questions.to_a
    pqs.reject!{|pq| pq.file_type? || pq.education? || pq.manager? || pq.experience? || pq.publication?}
    return pqs
  end

  def previous_user_csv_import_info_hash
    prev_import = self.user_csv_imports.order("id DESC").offset(1).first
    return prev_import ? prev_import.info_hash : {}
  end

  #-----------------------------------------------------------------------------
  # PRODUCT DASHBOARD METHODS - START
  #-----------------------------------------------------------------------------

  def ytd_time_objects
    end_time = Time.now.utc
    [end_time.beginning_of_year, end_time]
  end

  def get_program_ids_ary
    self.is_a?(Organization) ? self.programs.pluck(:id) : [id]
  end

  def completed_connections_ytd_query
    program_ids = get_program_ids_ary
    query = Group.where(program_id: program_ids).where("groups.closure_reason_id IN (?)", GroupClosureReason.completed.where(program_id: program_ids).pluck(:id))
    query.with_published_at.closed_between(*ytd_time_objects)
  end

  def completed_connections_ytd_count
    completed_connections_ytd_query.pluck(:id).compact.uniq.size
  end

  def get_positive_outcome_groups_ytd_query
    program_ids = get_program_ids_ary
    group_ids = Group.where(program_id: program_ids).closed.with_published_at.closed_between(*ytd_time_objects).pluck(:id)
    group_ids = Survey.where(program_id: program_ids).of_engagement_type.joins(survey_questions_with_matrix_rating_questions: [survey_answers: :answer_choices]).where("common_answers.group_id IN (?) and FIND_IN_SET(answer_choices.question_choice_id, common_questions.positive_outcome_options) > 0", group_ids).pluck("DISTINCT group_id")
    Group.where(id: group_ids).joins(:memberships).select("groups.id as group_id, connection_memberships.user_id as connection_membership_user_id")
  end

  def successful_completed_connections_ytd_count(options = {})
    @__positive_completed_connections_data = nil if options[:invalidate_cache]
    @__positive_completed_connections_data ||= ActiveRecord::Base.connection.exec_query(get_positive_outcome_groups_ytd_query.to_sql).to_hash
    @__positive_completed_connections_data.map{ |hsh| hsh["group_id"] }.compact.uniq.size
  end

  def get_flash_meeting_requested_ytd_count
    program_ids = get_program_ids_ary
    Meeting.unscoped.where(program_id: program_ids).non_group_meetings.mentee_created_meeting.where("created_at > ? AND created_at < ?", *ytd_time_objects).count
  end

  def get_flash_meeting_accepted_ytd_count
    program_ids = get_program_ids_ary
    non_group_meeting_request_ids = Meeting.unscoped.where(program_id: program_ids).non_group_meetings.mentee_created_meeting.pluck(:meeting_request_id).compact
    accepted_non_group_meeting_request_ids = MeetingRequest.where(id: non_group_meeting_request_ids).accepted.where("accepted_at > ? AND accepted_at < ?", *ytd_time_objects).pluck(:id).compact
    Meeting.unscoped.non_group_meetings.where(program_id: program_ids, meeting_request_id: accepted_non_group_meeting_request_ids).count
  end

  def get_flash_meeting_completed_ytd_count
    program_ids = get_program_ids_ary
    Meeting.unscoped.where(program_id: program_ids).non_group_meetings.completed.where("state_marked_at > ? AND state_marked_at < ?", *ytd_time_objects).count
  end

  def users_with_accepted_flash_meeting_ytd_count
   program_ids = get_program_ids_ary
    non_group_meeting_request_ids = Meeting.unscoped.where(program_id: program_ids).non_group_meetings.mentee_created_meeting.pluck(:meeting_request_id).compact
    accepted_non_group_meeting_request_ids = MeetingRequest.where(id: non_group_meeting_request_ids).accepted.where("accepted_at > ? AND accepted_at < ?", *ytd_time_objects).pluck(:id).compact
    meeting_ids = Meeting.unscoped.non_group_meetings.where(program_id: program_ids, meeting_request_id: accepted_non_group_meeting_request_ids).pluck(:id).compact
    MemberMeeting.where(meeting_id: meeting_ids).pluck(:member_id).uniq.count
  end

  def users_with_completed_flash_meeting_ytd_count
    program_ids = get_program_ids_ary
    non_group_meeting_ids = Meeting.unscoped.where(program_id: program_ids).non_group_meetings.completed.where("state_marked_at > ? AND state_marked_at < ?", *ytd_time_objects).pluck(:id).compact
    MemberMeeting.where(meeting_id: non_group_meeting_ids).pluck(:member_id).uniq.count
  end

  def closed_connections_ytd_arel
    Group.where(program_id: get_program_ids_ary).closed.closed_between(*ytd_time_objects)
  end

  def closed_connections_ytd_count
    closed_connections_ytd_arel.count
  end

  def users_closed_connections_ytd_count
    query = closed_connections_ytd_arel.joins(:memberships).select("connection_memberships.user_id")
    User.where(id: ActiveRecord::Base.connection.exec_query(query.to_sql).rows.flatten.uniq).pluck(:member_id).uniq.size
  end

  def copy_program_asset(abstract_program_ids, override = false)
    return if self.program_asset.blank?

    locales = self.program_asset.translations.pluck(:locale).uniq
    abstract_program_ids.each do |abstract_program_id|
      asset = ProgramAsset.find_or_create_by(program_id: abstract_program_id)
      locales.each do |locale|
        GlobalizationUtils.run_in_locale(locale) do
          asset.logo = self.logo if self.logo.exists? && (override || !asset.logo.exists?)
          asset.banner = self.banner if self.banner.exists? && (override || !asset.banner.exists?)
          asset.save!
        end
      end
    end
  end

  def get_organization
    self.is_a?(Program) ? self.organization : self
  end

  #-----------------------------------------------------------------------------
  # PRODUCT DASHBOARD METHODS - END
  #-----------------------------------------------------------------------------

  def handle_feature_dependency_mentor_to_mentee_matching(enabled)
    return if enabled
    ids = self.is_a?(Program) ? [self.id] : self.programs.pluck(:id)
    enabled_program_ids = Program.where(id: ids).includes([:enabled_db_features, :disabled_db_features, organization: [:enabled_db_features, :disabled_db_features]]).select{|program|program.mentor_to_mentee_matching_enabled?}.collect(&:id)
    BulkMatch.where(program_id: ids - enabled_program_ids, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE).collect(&:destroy)
  end

  private

  def construct_options(role_name, permissions)
    base_term = self.send("#{role_name}_name".to_sym) if self.is_a?(Program) && RoleConstants::MENTORING_ROLES.include?(role_name)
    return { :name => role_name, :permissions => permissions, :program => self, base_term: base_term}.merge(RoleConstants::DEFAULT_ROLE_SETTINGS[role_name])
  end
end
