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

class Organization < AbstractProgram

  MASS_UPDATE_ATTRIBUTES = {
    :update => {
      # General Tab
      :general => [:name, :description, :logo, :programs_listing_visibility, :privacy_policy, :agreement, :browser_warning],
      # General Tab for super console user
      :general_super_console => [:account_name, :email_theme_override, :mobile_logo, :banner, :name, :description, :logo, :programs_listing_visibility, :privacy_policy, :agreement, :browser_warning],
      # Security Tab
      :security => [:security_setting_attributes => [:login_exp_per_enable, :login_expiry_period, :account_lockout, :maximum_login_attempts, :reactivation_email_enabled, :auto_reactivate_account]],
      # Security Tab for super console user
      :security_super_console => [:security_setting_attributes => [:secure_invite_link_enable, :password_expiration_frequency, :password_history_limit, :can_contain_login_name, :can_show_remember_me, :email_domain, :allowed_ips, :allow_search_engine_indexing, :login_exp_per_enable, :login_expiry_period, :account_lockout, :maximum_login_attempts, :reactivation_email_enabled, :auto_reactivate_account]]
    },
    :program_update => [:name, :account_name, :agreement, :privacy_policy, :browser_warning, :security_setting_attributes => [:allowed_ips, :id, :login_expiry_period, :maximum_login_attempts, :auto_reactivate_account, :password_expiration_frequency, :password_history_limit, :can_contain_login_name, :can_show_remember_me, :email_domain, :allow_search_engine_indexing, :login_exp_per_enable, :account_lockout, :reactivation_email_enabled]]
  }

  DISABLE_LOGIN_EXPIRY        = 0
  DISABLE_MAXIMUM_LOGIN_ATTEMPTS = 0
  DISABLE_PASSWORD_AUTO_EXPIRY = 0
  DISABLE_AUTO_REACTIVATE_PASSWORD = 0.0

  PROGRAM_ATTRIBUTES = [:engagement_type, :program_type, :number_of_licenses, :mentor_request_expiration_days, :meeting_request_auto_expiration_days]

  module SubscriptionType
    BASIC     = 0
    PREMIUM   = 1
    ENTERPRISE= 2

    def self.all
      [
        ["feature.program.label.subsciption_type_basic".translate, BASIC],
        ["feature.program.label.subsciption_type_premium".translate, PREMIUM],
        ["feature.program.label.subsciption_type_enterprise".translate, ENTERPRISE]
      ]
    end
  end

  module TermsAndPrivacyPolicy
    TERMS = "agreement"
    PRIVACYPOLICY = "privacy_policy"

    def self.all
      [
        TERMS, PRIVACYPOLICY
      ]
    end
  end

  module ProgramsListingVisibility
    ALL = 0
    ONLY_LOGGED_IN_USERS = 1
    NONE = 2

    def self.all
      [ALL, ONLY_LOGGED_IN_USERS, NONE]
    end
  end

  sanitize_attributes_content :privacy_policy, :agreement, :browser_warning
  #-----------------------------------------------------------------------------
  # ASSOCIATIONS
  #-----------------------------------------------------------------------------
  has_many :members,    :dependent => :destroy
  has_many :programs,   :foreign_key => "parent_id",  :dependent => :destroy
  has_many :portals,    :foreign_key => "parent_id",  :class_name => "CareerDev::Portal", :dependent => :destroy
  has_many :tracks,    -> {where("programs.type = ?", Program.name).includes([:translations])}, :foreign_key => "parent_id",  :class_name => "Program", :dependent => :destroy
  has_many :messages,   :foreign_key => 'program_id', :dependent  => :destroy
  has_many :articles,   :dependent  => :destroy
  has_many :recent_activities, :dependent => :destroy
  has_many :ckassets,  :foreign_key => "program_id", :dependent => :destroy, :class_name => "Ckeditor::Asset"

  has_many :profile_questions,     -> {where("profile_questions.question_type NOT IN (?) ", [ProfileQuestion::Type::EMAIL, ProfileQuestion::Type::NAME]).order('profile_questions.position')},        :foreign_key => "organization_id", :dependent => :destroy
  has_many :profile_questions_with_email_and_name, -> {order 'profile_questions.position'}, :foreign_key => 'organization_id', :dependent => :destroy, :class_name => "ProfileQuestion"
  has_many :default_questions,      -> {where("profile_questions.question_type IN (?) ", [ProfileQuestion::Type::EMAIL, ProfileQuestion::Type::NAME]).order('profile_questions.position')}, :foreign_key => "organization_id", :dependent => :destroy, :class_name => "ProfileQuestion"
  has_many :role_questions, :through => :profile_questions
  has_many :diversity_reports, dependent: :destroy

  has_many :program_domains, :foreign_key => "program_id", :dependent => :destroy, :class_name => "Program::Domain"
  has_one :default_program_domain, -> { where("program_domains.is_default = 1") },  :foreign_key => "program_id", :class_name => "Program::Domain"
  has_many :admin_views, :foreign_key => "program_id", :dependent => :destroy
  has_many :data_imports, dependent: :destroy
  has_many :organization_languages, :foreign_key => "organization_id", :dependent => :destroy
  has_many :languages, :through => :organization_languages
  has_many :three_sixty_competencies, -> { includes([:translations]) }, :dependent => :destroy, :class_name => "ThreeSixty::Competency"
  has_many :three_sixty_questions, -> { includes([:translations]) }, :dependent => :destroy, :class_name => "ThreeSixty::Question"
  has_many :three_sixty_oeqs, -> { where("three_sixty_questions.three_sixty_competency_id IS NULL").includes([:translations]) }, :class_name => "ThreeSixty::Question"
  has_many :three_sixty_surveys, :dependent => :destroy, :class_name => "ThreeSixty::Survey"
  has_many :three_sixty_survey_assessees, :through => :three_sixty_surveys, :source => :survey_assessees
  has_many :published_three_sixty_surveys, -> {where("three_sixty_surveys.state = '#{ThreeSixty::Survey::PUBLISHED}'")}, :class_name => "ThreeSixty::Survey"
  has_many :published_three_sixty_survey_assessees, :through => :published_three_sixty_surveys, :source => :survey_assessees
  has_many :three_sixty_reviewer_groups, :dependent => :destroy, :class_name => "ThreeSixty::ReviewerGroup"
  has_many :user_activities
  has_many :auth_configs, dependent: :destroy
  has_many :o_auth_credentials, as: :ref_obj, dependent: :destroy
  has_many :google_o_auth_credentials, as: :ref_obj
  has_many :microsoft_o_auth_credentials, as: :ref_obj
  has_many :outlook_o_auth_credentials, as: :ref_obj
  has_many :office365_o_auth_credentials, as: :ref_obj

  has_one :security_setting, :foreign_key => "program_id", :dependent => :destroy
  has_one :feed_exporter, :foreign_key => "program_id", :dependent => :destroy
  has_one :feed_import_configuration, dependent: :destroy
  has_one :auth_config_setting, dependent: :destroy

  #-----------------------------------------------------------------------------
  # UNION COLLECTIONS
  #-----------------------------------------------------------------------------

  has_union :all_roles,         :class_name => 'Role',            :collections => ["roles", {:programs => :roles}]
  has_union :article_contents,  :class_name => 'ArticleContent',  :collections => {:programs => :article_contents}
  has_union :users,             :class_name => 'User',            :collections => {:programs => :users}
  has_union :all_users,         :class_name => 'User',            :collections => {:programs => :all_users}
  has_union :qa_questions,      :class_name => 'QaQuestion',      :collections => {:programs => :qa_questions}
  has_union :forums,            :class_name => 'Forum',           :collections => {:programs => :forums}
  has_union :groups,            :class_name => 'Group',           :collections => {:programs => :groups}

  #-----------------------------------------------------------------------------
  # VALIDATIONS
  #-----------------------------------------------------------------------------

  validates :name, presence: true
  validates :subscription_type, inclusion: { in: [SubscriptionType::BASIC, SubscriptionType::PREMIUM, SubscriptionType::ENTERPRISE] }
  validates :email_from_address, email_format: { generate_message: true, check_mx: false, allow_blank: true }
  validates :programs_listing_visibility, presence: true, inclusion: { in: ProgramsListingVisibility.all }
  validates :account_name, uniqueness: true
  restrict_sti_attributes PROGRAM_ATTRIBUTES

  validate :basic_organization_has_no_custom_terms_only_flag

  scope :active, -> { where(active: true) }

  #-----------------------------------------------------------------------------
  # OTHER SETTINGS
  #-----------------------------------------------------------------------------

  attr_accessor :created_for_sales_demo, :creating_using_solution_pack
  accepts_nested_attributes_for :security_setting
  publicize_ckassets attrs: [:agreement, :privacy_policy, :browser_warning, :footer_code]

  #-----------------------------------------------------------------------------
  # INSTANCE METHODS
  #-----------------------------------------------------------------------------

  def amazon?
    id == 876 && Rails.env.production?
  end

  def same_organization?(other_prog_or_organization)
    self == (other_prog_or_organization.is_a?(Organization) ?
          other_prog_or_organization : other_prog_or_organization.organization
    )
  end

  def domain
    self.default_program_domain.domain
  end

  def subdomain
    self.default_program_domain.subdomain
  end

  def default_domain?
    self.domain == DEFAULT_DOMAIN_NAME
  end

  def has_custom_domain?
    self.program_domains.where("domain != ?", DEFAULT_DOMAIN_NAME).any?
  end

  def basic_type?
    self.subscription_type == SubscriptionType::BASIC
  end

  def verbose_subscription_type
    case subscription_type
    when SubscriptionType::BASIC
      "Basic"
    when SubscriptionType::PREMIUM
      "Premium"
    when SubscriptionType::ENTERPRISE
      "Enterprise"
    end
  end

  def sorted_resources(field, order)
    if field == 'title'
      resources.order_by_translated_field(:title, order)
    else
      resources.order("#{field} #{order}")
    end.includes(:translations, :ratings, resource_publications: [program: :translations])
  end

  # To reload programs_count in program-callbacks for ensuring that the 'standalone?' method works fine
  # And, we do not want to reload objects in callbacks
  def reload_programs_count
    count = Organization.find_by(id: self.id).try(:programs_count)
    self.programs_count = count if count
  end

  # Returns whether the organization has exactly one program
  def standalone?
    self.programs_count == 1
  end

  def ongoing_enabled_programs_present?
    (self.programs.collect(&:engagement_type).uniq & [Program::EngagementType::CAREER_BASED_WITH_ONGOING, Program::EngagementType::PROJECT_BASED]).any?
  end

  #
  # Returns whether the organization zero or one published program.
  #
  def standalone_published?
    self.programs.published_programs.size <= 1
  end

  def get_enrollment_content(member, options = {})
    users = member.users.includes(:roles).group_by(&:program_id)
    published_program_ids = self.programs.published_programs.pluck(:id)
    programs_allowing_roles = Role.where(program_id: published_program_ids)
      .non_administrative.allowing_join_now.group_by(&:program_id)
    visible_programs_ids = (users.keys + programs_allowing_roles.keys).uniq

    if options[:ids_only]
      return [users, programs_allowing_roles, visible_programs_ids]
    end

    visible_programs = self.programs.ordered.includes([{:organization => :program_asset}, :translations, :program_asset])
    .select(['programs.id, root, parent_id, show_multiple_role_option'])
    .where(id: visible_programs_ids)

    [users, programs_allowing_roles, visible_programs]
  end

  def can_show_portals?
    self.career_development_enabled? && self.portals.size > 0
  end

  #-----------------------------------------------------------------------------
  # --- FEATURES
  #-----------------------------------------------------------------------------

  #
  # Getter that returns array of enabled features.
  #
  def enabled_features
    self.enabled_db_features.collect(&:name)
  end

  def disabled_features
    FeatureName.all - enabled_features
  end

  #
  # Setter for features where <i>feature_names</i> is an array of feature names.
  #
  def enabled_features=(feature_names)
    feature_names.reject!(&:blank?) # Remove empty entries.
    skip_feature_names = FeatureName.tandem_features
    FeatureName.all.each do |name|
      # <code>feature_names.include?(name)</code> will give whether to enable or
      # not.
      self.enable_feature(name, feature_names.include?(name)) unless skip_feature_names.include?(name)
    end
  end

  def email_template_disabled_for_activity?(mailer)
    template = mailer.org_template(self)
    if template.nil?
      return false
    else
      return !template.enabled?
    end
  end

  def login_expiry_disabled?
    self.security_setting.login_expiry_period == DISABLE_LOGIN_EXPIRY
  end

  def make_subscription_changes
    (FeatureName.default_features + FeatureName.default_basic_features).uniq.each do |feature|
      self.enable_feature(feature, (self.basic_type? && FeatureName.default_basic_features.include?(feature)) || (!self.basic_type? && FeatureName.default_features.include?(feature)))
    end
  end

  def login_attempts_enabled?
    self.security_setting.maximum_login_attempts != DISABLE_MAXIMUM_LOGIN_ATTEMPTS
  end

  def password_auto_expire_enabled?
    self.security_setting.password_expiration_frequency.to_i != DISABLE_PASSWORD_AUTO_EXPIRY
  end

  def password_history_enabled?
    self.security_setting.password_history_limit.present?
  end

  def auto_reactivate_enabled?
    self.security_setting.auto_reactivate_account != DISABLE_AUTO_REACTIVATE_PASSWORD
  end

  def name_question
    self.default_questions.name_question.first
  end

  def email_question
    self.default_questions.email_question.first
  end

  def email_question_help_text(default_text = '')
    self.email_question.nil? || self.email_question.help_text.blank? ? default_text : self.email_question.help_text.html_safe
  end

  def create_default_name_profile_question!
    self.profile_questions.create!(:question_text => "feature.program.label.name".translate, :question_type => ProfileQuestion::Type::NAME, :section => self.sections.default_section.first, :position => 1)
  end

  def self.create_default_admin_views(organization_id)
    organization = Organization.find_by(id: organization_id)
    return unless organization.present?
    default_views = [
      {:title => "feature.admin_view.content.license_count_v1".translate, :filter_params => AdminView.convert_to_yaml({program_role_state: {inclusion: AdminView::ProgramRoleStateFilterObjectKey::INCLUDE, filter_conditions: {parent_filter_1: {child_filter_1: {state: ["active"]}}}}}), :default_view => AbstractView::DefaultType::LICENSE_COUNT, :favourite => true, :favourited_at => Time.now},
      {:title => "manage_strings.common.All_Members".translate, :filter_params => AdminView.convert_to_yaml({program_role_state: {all_members: true}}), :default_view => AbstractView::DefaultType::ALL_MEMBERS, :favourite => true, :favourited_at => Time.now}
    ]
    ActiveRecord::Base.transaction do
      default_views.each do |default_view|
        admin_view = organization.admin_views.create!(default_view)
        admin_view.create_default_columns
      end
    end
  end

  def create_default_auth_configs(for_sales_demo = false)
    AuthConfig.attr_value_map_for_default_auths(for_sales_demo).each do |attr_value_map|
      self.auth_configs.create!(attr_value_map)
    end
  end

  def get_locked_out_members
    if self.auto_reactivate_enabled?
      self.members.locked_out(self.security_setting.maximum_login_attempts, self.security_setting.auto_reactivate_account)
    else
      self.members.exceeded_maximum_login_attempts(self.security_setting.maximum_login_attempts)
    end
  end

  def populate_default_customized_terms
    return if self.customized_terms.any?

    default_customized_terms = [["feature.custom_terms.mentoring_connection_v1".translate, CustomizedTerm::TermType::MENTORING_CONNECTION_TERM],
     ["feature.custom_terms.meeting".translate, CustomizedTerm::TermType::MEETING_TERM],
     ["feature.custom_terms.program".translate, CustomizedTerm::TermType::PROGRAM_TERM],
     ["feature.custom_terms.resource".translate, CustomizedTerm::TermType::RESOURCE_TERM],
     ["feature.custom_terms.article".translate, CustomizedTerm::TermType::ARTICLE_TERM],
     ["feature.custom_terms.admin".translate, CustomizedTerm::TermType::ADMIN_TERM],
     ["feature.custom_terms.mentoring".translate, CustomizedTerm::TermType::MENTORING_TERM],
     ["feature.custom_terms.career_development".translate, CustomizedTerm::TermType::CAREER_DEVELOPMENT_TERM]]

    default_customized_terms.each do |term_and_type|
      self.customized_terms.new.save_term(term_and_type[0], term_and_type[1])
    end
  end

  def get_accesible_group_meetings(meetings_list)
    meetings = []
    self.programs.select(&:mentoring_connection_meeting_enabled?).each do |program|
      meetings += meetings_list.group_meetings.of_program(program)
    end
    meetings
  end

  def get_next_program_root(program)
    n = 0
    program_roots = programs.pluck(:root)
    begin
      last_root = program.class.program_root_name(n += 1)
    end while program_roots.include?(last_root)
    last_root
  end

  def role_profile_questions
    self.role_questions.role_profile_questions.collect(&:profile_question).uniq
  end

  def create_and_populate_default_three_sixty_settings!
    ThreeSixty::ReviewerGroup.create_default_review_groups_for_organization!(self) unless self.three_sixty_reviewer_groups.any?
  end

  def create_competency_and_questions!
    question_data = YAML::load(ERB.new(IO.read("#{Rails.root.to_s}/config/three_sixty/default_questions.yml")).result)

    question_data.each do |data|
      competency = self.three_sixty_competencies.create!(data.pick("title","description"))
      if data["questions"].present?
        data["questions"].each do |question|
          competency.questions.create!(question.merge(:organization_id => self.id))
        end
      end
    end
  end

  def self.clone_program_asset!(organization_id, program_id = nil)
    organization = Organization.find_by(id: organization_id)
    return unless organization.present?

    if program_id.present?
      program = organization.programs.find_by(id: program_id)
      return unless program.present?
      program_ids = [program_id]
    end

    program_ids ||= organization.program_ids
    organization.copy_program_asset(program_ids)
  end

  def self.transition_global_objects_to_standalone_program(organization_id)
    organization = Organization.find_by(id: organization_id)
    return unless organization.try(:standalone?)

    program = organization.programs.first
    return if program.blank?

    organization_resources = organization.resources.non_default
    organization_resources.each do |resource|
      resource.resource_publications.find_or_create_by(program_id: program.id)
    end
    organization_resources.update_all(program_id: program.id)
    organization.admin_messages.update_all(program_id: program.id)
  end

  def self.transition_standalone_program_objects_to_organization(organization_id)
    organization = Organization.find_by(id: organization_id)
    return unless organization.try(:standalone?)

    program = organization.programs.first
    return if program.blank?

    organization.update_attributes!(name: program.name, description: program.description)
    program.handle_program_asset_of_standalone_program
    program.handle_organization_features_of_standalone_program
    program.handle_pages_of_standalone_program
  end

  def get_protocol
    Rails.application.config.force_ssl ? "https" : "http"
  end

  def get_programs_with_feature_disabled(feature)
    self.programs.joins(:organization_features).where("organization_features.feature_id = ? AND organization_features.enabled = ?", feature.id, false).pluck("programs.id")
  end

  def enabled_organization_languages_including_english
    [OrganizationLanguage.for_english] + organization_languages.enabled
  end

  def chronus_default_domain
    self.program_domains.where(domain: DEFAULT_DOMAIN_NAME).first
  end

  def languages_filter_enabled?
    language_settings_enabled? && languages.exists?
  end

  #-----------------------------------------------------------------------------
  # PRODUCT DASHBOARD METHODS - START
  #-----------------------------------------------------------------------------

  def sandbox?
    account_name.blank? || account_name.to_s.downcase.match(/^\s*sandbox/).present?
  end

  def status_string(other = nil)
    other = nil if ["Active", "Inactive"].include?(other)
    other.present? ? other : (active ? "Active" : "Inactive")
  end

  def tracks_count
    programs.size
  end

  def current_users_with_unpublished_or_published_profiles_count
    User.active_or_pending.where(program_id: program_ids).pluck(:member_id).uniq.size
  end

  def current_users_with_published_profiles_count
    User.active.where(program_id: program_ids).pluck(:member_id).uniq.size
  end

  def current_connected_users_count(options = {})
    current_connected_member_ids(options).size
  end

  def current_connected_member_ids(options = {})
    scoped_program_ids = options[:program_ids] || program_ids
    query = Group.active.where(program_id: scoped_program_ids).joins(:memberships).select("connection_memberships.user_id")
    arel_chain = User.where(id: ActiveRecord::Base.connection.exec_query(query.to_sql).rows.flatten.uniq)
    arel_chain = arel_chain.active if options[:include_active_users_only]
    arel_chain.pluck(:member_id).uniq
  end

  def current_active_connections_count
    Group.active.where(program_id: program_ids).count
  end

  def current_active_connection_ids(options = {})
    scoped_program_ids = options[:program_ids] || program_ids
    Group.active.where(program_id: scoped_program_ids).pluck(:id)
  end

  def closed_connections_count(options = {})
    scoped_program_ids = options[:program_ids] || program_ids
    Group.closed.where(program_id: scoped_program_ids).count
  end

  def last_login
    programs.map(&:last_login).compact.max
  end

  def users_with_unpublished_or_published_profiles_ytd_count
    user_ids = programs.map { |program| User.get_ids_of_users_active_between(program, *ytd_time_objects, include_unpublished: true) }.flatten
    User.where(id: user_ids).pluck(:member_id).uniq.size
  end

  def users_with_published_profiles_ytd_count
    users_with_published_profiles_in_date_range(ytd_time_objects)
  end

  def users_with_published_profiles_in_date_range_for_organization(date_range, options = {})
    scoped_program_ids = options[:program_ids] || program_ids
    role_ids = options[:role_ids] || Role.where(program_id: scoped_program_ids, for_mentoring: true).pluck(:id)
    filterable_ids = User.where(program_id: scoped_program_ids).pluck(:id)
    user_ids = User.get_ids_of_users_active_between(nil, *date_range, role_ids: role_ids, ids: filterable_ids)
    User.where(id: user_ids).pluck(:member_id).uniq
  end

  def users_with_published_profiles_in_date_range(date_range)
    user_ids = programs.map { |program| User.get_ids_of_users_active_between(program, *date_range) }.flatten
    User.where(id: user_ids).pluck(:member_id).uniq.size
  end

  def users_connected_ytd_count
    user_ids = programs.map { |program| User.get_ids_of_connected_users_active_between(program, *ytd_time_objects) }.flatten
    User.where(id: user_ids).pluck(:member_id).uniq.size
  end

  def connections_ytd_count
    programs.map(&:connections_ytd_count).inject(:+)
  end

  def connections_in_date_range(date_range, options = {})
    programs.map {|program| program.connections_in_date_range(date_range, options)}.inject(:+)
  end

  def connections_in_date_range_for_organization(date_range)
    filterable_ids = Group.where(program_id: program_ids).pluck(:id)
    Group.get_ids_of_groups_active_between(nil, *date_range, ids: filterable_ids)
  end

  def users_completed_connections_ytd_count
    query = completed_connections_ytd_query.joins(:memberships).select("connection_memberships.user_id")
    User.where(id: ActiveRecord::Base.connection.exec_query(query.to_sql).rows.flatten.uniq).pluck(:member_id).uniq.size
  end

  def users_successful_completed_connections_ytd_count(options = {})
    @__positive_completed_connections_data = nil if options[:invalidate_cache]
    @__positive_completed_connections_data ||= ActiveRecord::Base.connection.exec_query(get_positive_outcome_groups_ytd_query.to_sql).to_hash
    positive_outcome_group_ids = @__positive_completed_connections_data.map{ |hsh| hsh["group_id"] }.compact.uniq
    user_ids = Survey.where(program_id: program_ids).of_engagement_type.joins(survey_questions_with_matrix_rating_questions: [survey_answers: :answer_choices]).where("common_answers.group_id IN (?) and FIND_IN_SET(answer_choices.question_choice_id, common_questions.positive_outcome_options) > 0", positive_outcome_group_ids).pluck(:user_id).compact.uniq
    User.where(id: user_ids).pluck(:member_id).compact.uniq.size
  end

  #-----------------------------------------------------------------------------
  # PRODUCT DASHBOARD METHODS - END
  #-----------------------------------------------------------------------------

  #-----------------------------------------------------------------------------
  # --- DEFAULT ASSOCIATION CREATORS
  #-----------------------------------------------------------------------------

  def sync_customized_terms
    terms_to_copy = CustomizedTerm::TermType::ORGANIZATION_LEVEL_TERMS
    organization_custom_terms = self.customized_terms.includes(:translations).group_by(&:term_type)
    self.programs.includes(customized_terms: :translations).each do |program|
      terms = program.customized_terms.where(term_type: terms_to_copy)
      terms.each do |term|
        organization_custom_term = organization_custom_terms[term.term_type].first
        attributes_to_update = organization_custom_term.attributes.slice("term", "term_downcase", "pluralized_term", "pluralized_term_downcase", "articleized_term", "articleized_term_downcase")
        term.update_attributes!(attributes_to_update)
      end
    end
  end

  def admin_custom_term
    self.term_for(CustomizedTerm::TermType::ADMIN_TERM)
  end

  def resources_enabled_any?
    self.programs.find(&:resources_enabled?).present?
  end

  def programs_listing_visible_to_all?
    self.programs_listing_visibility == ProgramsListingVisibility::ALL
  end

  def programs_listing_visible_to_only_logged_in_users?
    self.programs_listing_visibility == ProgramsListingVisibility::ONLY_LOGGED_IN_USERS
  end

  def programs_listing_visible_to_none?
    self.programs_listing_visibility == ProgramsListingVisibility::NONE
  end

  def programs_listing_visible_to_logged_in_users?
    self.programs_listing_visibility != ProgramsListingVisibility::NONE
  end

  def reorder_programs(new_order)
    fetched_programs = programs.index_by(&:id)
    Program.transaction do
      new_order.map(&:to_i).each_with_index do |id, index|
        program = fetched_programs[id]
        program.update_column(:position, index + 1)
      end
    end
  end

  def get_from_email_address
    self.email_from_address || MAILER_ACCOUNT[:email_address]
  end

  def url(with_protocol = false)
    url = (subdomain.present? ? "#{subdomain}.#{domain}" : domain)
    return url unless with_protocol

     "#{self.get_protocol}://#{url}"
  end

  def ab_test_enabled?(experiment_name)
    org_ab_test = self.ab_tests.find_by(test: experiment_name)
    org_ab_test.present? ? org_ab_test.enabled? : ProgramAbTest.experiment(experiment_name).enabled?
  end

  def basic_organization_has_no_custom_terms_only_flag
    if self.display_custom_terms_only && self.basic_type?
      self.errors.add(:display_custom_terms_only, "activerecord.custom_errors.organization.display_custom_terms".translate)
    end
  end

  def email_priamry_color
    self.email_theme_override.present? ? self.email_theme_override : self.theme_vars[EmailTheme::PRIMARY_COLOR]
  end

  def linkedin_imports_allowed?
    self.security_setting.linkedin_token.present? && self.security_setting.linkedin_secret.present?
  end

  def programs_with_active_user_campaigns_present?
    active_user_campaigns_present = false
    self.programs.each do |program|
      active_user_campaigns_present = active_user_campaigns_present || program.user_campaigns.active.present?
    end
    return active_user_campaigns_present
  end

  def hostnames
    self.program_domains.collect(&:get_url)
  end

  def can_preview_membership_questions_for_any_program?
    programs.allowing_membership_requests.exists?
  end

  def chronus_admin
    self.members.admins.find_by(email: SUPERADMIN_EMAIL)
  end

  def auth_configs(unscoped = false)
    unscoped ? AuthConfig.unscoped.where(organization_id: self.id) : super()
  end

  def chronussupport_auth_config(step1_complete = false)
    if step1_complete
      auth_config = self.auth_configs.new(auth_type: AuthConfig::Type::OPEN)
      auth_config.config = Base64.encode64(Marshal.dump( { "configuration" => OpenAuthUtils::Configurations::Google } ))
    else
      auth_config = self.auth_configs.new(auth_type: AuthConfig::Type::CHRONUS)
    end
    auth_config.readonly!
    auth_config
  end

  def standalone_auth?
    self.auth_configs.size == 1
  end

  def chronus_auth(unscoped = false)
    auth_configs(unscoped).find(&:indigenous?)
  end

  def linkedin_oauth(unscoped = false)
    auth_configs(unscoped).find(&:linkedin_oauth?)
  end

  def google_oauth
    self.auth_configs.find(&:google_oauth?)
  end

  def saml_auth
    self.auth_configs.find_by(auth_type: AuthConfig::Type::SAML)
  end

  def has_saml_auth?
    self.saml_auth.present?
  end

  def get_and_cache_custom_auth_config_ids
    @custom_auth_config_ids ||= {}
    @custom_auth_config_ids[self.id] ||= self.auth_configs.select(&:custom?).map(&:id)
  end

  def three_sixty_competencies
    super.order_by_translated_field(:title).includes(:translations)
  end

  def three_sixty_competency_ids
    three_sixty_competencies.pluck(:id)
  end

  def get_admin_programs_hash
    member_programs_hash = {}
    all_programs = self.programs.select(:id, :root).to_a
    self.members.admins.active.each { |admin| member_programs_hash[admin] = all_programs }
    all_programs.each do |program|
      program.admin_users.active.includes(:member).each do |user|
        member = user.member
        next if member.admin?
        member_programs_hash[member] ||= []
        member_programs_hash[member] << program
      end
    end
    member_programs_hash
  end

  def get_program_alerts_hash
    program_alerts_hash = {}
    self.programs.select(:id, :root).each do |program|
      alerts_to_notify = program.get_report_alerts_to_notify
      next unless alerts_to_notify.present?
      program_alerts_hash[program] = alerts_to_notify
    end
    program_alerts_hash
  end
end