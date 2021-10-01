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
#  include_surveys_for_satisfaction_rate             :boolean

#
# ==== Program flags and explanation:
# * <tt>mentor_request_style</tt>: Mentor to Mentee, Mentor to Admin, None
# * <tt>allow_one_to_many_mentoring</tt>: Can a group have more than 1 mentee?
#
class Program < AbstractProgram
  include MentoringPeriodUtils
  include Program::Dashboard
  include Program::MatchReportHelper

  MASS_UPDATE_ATTRIBUTES = {
    :from_registration => {
      :create_admin => [:name, :engagement_type, :mentor_name, :student_name, :enabled_features, :creation_way, :program_type, :number_of_licenses, :solution_pack_file],
      :new_admin => [:name, :engagement_type, :mentor_name, :student_name, :enabled_features, :creation_way, :program_type, :number_of_licenses, :solution_pack_file]
    },
    :update => {
      :general => [:name, :description, :published, :allow_one_to_many_mentoring, :number_of_licenses, :mentor_request_style, :sort_users_by],
      :membership => [:show_multiple_role_option],
      :connection => [:allow_one_to_many_mentoring, :mentoring_period_unit, :allow_users_to_leave_connection, :allow_to_change_connection_expiry_date, :inactivity_tracking_period_in_days, :auto_terminate_reason_id, :mentoring_period_value, :allow_users_to_mark_connection_public, :allow_private_journals, :allow_connection_feedback, :hybrid_templates_enabled],
      :features => [:enabled_features],
      :permissions => [:allow_track_admins_to_access_all_users, :allow_user_to_send_message_outside_mentoring_area, :admin_access_to_mentoring_area],
      :security => [],
      :matching => [:enabled_features, :needs_project_request_reminder, :project_request_reminder_duration, :engagement_type, :allow_mentoring_mode_change, :allow_end_users_to_see_match_scores, :mentoring_request_reminder_duration, :mentor_request_expiration_days, :max_connections_for_mentee, :allow_mentoring_requests, :allow_mentoring_requests_message, :allow_mentee_withdraw_mentor_request, :allow_preference_mentor_request, :min_preferred_mentors, :mentor_offer_needs_acceptance, :prevent_manager_matching, :manager_matching_level, :prevent_past_mentor_matching, :allow_non_match_connection, :zero_match_score_message, :needs_meeting_request_reminder, :meeting_request_auto_expiration_days, :meeting_request_reminder_duration, :default_max_connections_limit, :max_pending_requests_for_mentee, :needs_mentoring_request_reminder, :circle_request_auto_expiration_days, :allow_circle_start_date]
    }
  }
  # TODO: Cleanup the list for create action since many of them might not be necessary

  class << self
    attr_accessor :skip_match_report_admin_view_observer
  end

  DEFAULT_ROOT = 'main'

  # Default value for +inactivity_tracking_period+
  DEFAULT_CONNECTION_TRACKING_PERIOD = 30
  DEFAULT_MENTORING_PERIOD           = 180.days

  UNCONNECTED_USER_WIDGET_TILES_COUNT = 5

  ORGANIZATION_ATTRIBUTES = [
    :privacy_policy, :agreement, :browser_warning, :footer_code, :programs_listing_visibility, :show_text_type_answers_per_reviewer_category, :audit_user_communication
  ]

  module ProgramTypeConstants
    PORTAL = "CareerDev::Portal"
    TRACK = "Program"

    ProgramsType = {
      PORTAL => {
        instance_name: "portals",
        order: 1,
        association: "portals",
        title_key: "feature.portal.header.career_development_programs",
        show_condition: "can_show_portals?"
      },

      TRACK => {
        instance_name: "tracks",
        order: 2,
        association: "tracks",
        title_key: "feature.portal.header.tracks",
        show_condition: true
      }
    }

  end

  module ProgramType
    CHRONUS_MENTOR = 'mentor'
    CHRONUS_COACH = 'coach'
    CHRONUS_LEARN = 'learn'

    def self.all
      [CHRONUS_MENTOR, CHRONUS_COACH, CHRONUS_LEARN]
    end
  end

  module EngagementType
    CAREER_BASED = 1
    PROJECT_BASED = 2
    CAREER_BASED_WITH_ONGOING = 3

    def self.all
      [CAREER_BASED, PROJECT_BASED, CAREER_BASED_WITH_ONGOING]
    end

    def self.career_based
      [CAREER_BASED, CAREER_BASED_WITH_ONGOING]
    end
  end

  module CreationWay
    MANUAL = 0
    SOLUTION_PACK = 2
  end

  # How to sort the users based on name in users listing
  module SortUsersBy
    FULL_NAME = 0
    LAST_NAME = 1
  end

  module MentorRequestStyle
    MENTEE_TO_MENTOR = 0
    MENTEE_TO_ADMIN  = 1
    NONE             = 2

    def self.all
      [MENTEE_TO_MENTOR, MENTEE_TO_ADMIN, NONE]
    end
  end

  module ConnectionLimit
    NONE          = 0
    ONLY_DECREASE = 1
    ONLY_INCREASE = 2
    BOTH          = 3
  end

  module AdminAccessToMentoringArea
    OPEN = 0
    AUDITED_ACCESS = 1
    DISABLED = 2
  end

  module Permissions
    PUBLISH_ARTICLES = [
      {:label => "mentees_publish_articles", :role => RoleConstants::STUDENT_NAME, :permission => "write_article"}]
    def self.content_related
      PUBLISH_ARTICLES
    end
  end

  module RA_TABS
    ALL_ACTIVITY = 0
    MY_ACTIVITY = 1
    CONNECTION_ACTIVITY = 2
  end

  module MENTORING_MODE_CONFIG
    NON_EDITABLE = 0
    EDITABLE = 1
  end

  module MAILS_TO_DISABLE_BY_DEFAULT
    def self.mail_classes_at_program_level
      [
        MeetingRequestStatusAcceptedNotificationToSelf,
        NewArticleNotification,
        MeetingCreationNotificationToOwner,
        MembershipRequestSentNotification
      ]
    end
  end

  module CAMPAIGNS
    CSV_FILES = ["default_campaigns.csv", "featured_campaigns.csv"]
  end


  #-----------------------------------------------------------------------------
  # ASSOCIATIONS
  #-----------------------------------------------------------------------------

  belongs_to  :owner,         :foreign_key => "user_id",    :class_name => "User"
  belongs_to  :organization,  :foreign_key => "parent_id",  :class_name => "Organization"
  counter_culture :organization
  belongs_to  :auto_terminate_reason,  :foreign_key => "auto_terminate_reason_id", :class_name => "GroupClosureReason"

  # Returns [admins + mentors + mentees]
  has_many  :all_users, :class_name => 'User', :dependent => :destroy

  has_many :mentor_requests,      :dependent  => :destroy
  has_many :meeting_requests,     :dependent  => :destroy
  has_many :mentor_offers,        :dependent  => :destroy
  has_many :project_requests,     :dependent  => :destroy
  has_many :membership_requests,  :dependent  => :destroy
  has_many :program_invitations,  :dependent  => :destroy
  has_many :program_languages,    dependent: :destroy
  has_many :groups,               :dependent  => :destroy
  has_many :active_groups,        -> { where("groups.status in (?)", Group::Status::ACTIVE_CRITERIA) }, class_name: Group.name
  has_many :connection_memberships, through: :groups, source: :memberships
  has_many :tasks,                -> {where("groups.status != ?", Group::Status::CLOSED)}, :through    => :groups
  has_many :scraps,               :dependent  => :destroy
  has_many :qa_questions,         -> { includes([:user])}, :dependent  => :destroy
  has_many :qa_answers,           :through    => :qa_questions
  has_many :announcements,        -> { includes([:translations])}, :dependent  => :destroy
  has_many :program_activities,   :dependent  => :destroy
  has_many :recent_activities,    -> {order "recent_activities.id DESC"}, :through    => :program_activities, :source => :activity
  has_many :forums,               :dependent  => :destroy
  has_many :topics,               :through    => :forums
  has_many :posts,                :through    => :topics
  has_many :flags,                :dependent  => :destroy
  has_many :matching_documents,   :dependent  => :destroy     

  # Warning: program.articles loads published + draft articles. You should do
  # program.articles.published to get only published articles.
  has_many :article_publications, :class_name => 'Article::Publication',  :dependent => :destroy
  has_many :articles,             -> { includes([:author]) }, :through => :article_publications
  has_many :article_contents,     :through => :articles
  has_many :comments,             :through => :article_publications

  has_many :mentoring_tips,             -> {order "mentoring_tips.id DESC"}, :dependent => :destroy
  has_many :surveys,                    -> {order "surveys.id DESC"}, :dependent => :destroy
  has_many :program_surveys,            -> { where(type: ProgramSurvey.name) }
  has_many :confidentiality_audit_logs, -> {order "id DESC"}, :dependent => :destroy
  has_many :connection_questions,       -> {order 'position'}, :dependent => :destroy, :class_name => "Connection::Question"
  has_many :summaries, :through => :connection_questions, source: :summary
  has_many :match_configs,              -> { includes([:student_question, :mentor_question]) }, :dependent => :destroy
  has_many :roles,                      :dependent => :destroy

  has_one :membership_instruction, -> { includes([:translations])}, :class_name => "MembershipRequest::Instruction", :dependent => :destroy

  has_many :abstract_instructions, :dependent => :destroy

  has_one :mentor_request_instruction, -> { includes([:translations]) }, :class_name => "MentorRequest::Instruction", :dependent => :destroy
  has_one :contact_admin_setting,       :dependent => :destroy

  has_many :meetings, ->{ where(active: true) }, :dependent => :destroy
  has_many :member_meetings, through: :meetings
  has_many :all_meetings, class_name: "Meeting", :dependent => :destroy

  has_many :role_questions, :dependent => :destroy, :through => :roles

  has_many :activity_logs, :dependent => :destroy

  has_many :mentoring_models, -> { includes([:translations])}, dependent: :destroy
  has_one :default_mentoring_model, -> { where(default: true) }, class_name: MentoringModel.name
  has_many :mentoring_model_tasks, :through => :groups #Needed for groups activity report

  has_many :admin_views, :dependent => :destroy
  has_many :report_sections, -> {order "report_sections.position ASC"}, dependent: :destroy, class_name: Report::Section.name
  has_many :program_events, -> {order('program_events.start_time ASC, program_events.updated_at DESC').includes([:translations])}, dependent: :destroy
  has_many :bulk_matches, :dependent => :destroy
  has_one :student_bulk_match, -> { where(orientation_type: BulkMatch::OrientationType::MENTEE_TO_MENTOR) }, class_name: BulkMatch.name
  has_one :mentor_bulk_match, -> { where(orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE) }, class_name: BulkMatch.name
  has_one :bulk_recommendation, dependent: :destroy
  has_one :calendar_setting, :dependent => :destroy
  has_one :group_view, :dependent => :destroy
  has_many :three_sixty_surveys, :dependent => :destroy, :class_name => "ThreeSixty::Survey"
  has_many :three_sixty_survey_assessees, :through => :three_sixty_surveys, :source => :survey_assessees
  has_one :notification_setting, :dependent => :destroy
  has_many :report_view_columns, -> {order "position asc"}, :dependent => :destroy
  has_many :resource_publications, dependent: :destroy
  has_many :user_campaigns, -> { includes([:translations])}, :class_name => 'CampaignManagement::UserCampaign', dependent: :destroy
  has_many :survey_campaigns, -> { includes([:translations])}, :class_name => 'CampaignManagement::SurveyCampaign', dependent: :destroy
  has_one :program_invitation_campaign, :class_name => 'CampaignManagement::ProgramInvitationCampaign', dependent: :destroy
  has_many :abstract_campaigns, -> { includes([:translations])}, :class_name => 'CampaignManagement::AbstractCampaign', dependent: :destroy
  has_many :group_closure_reasons, dependent: :destroy
  has_many :feedback_forms, :class_name => "Feedback::Form", :dependent => :destroy
  has_many :solution_packs
  has_many :mentor_recommendations, :dependent => :destroy
  has_many :common_questions, :dependent => :destroy
  has_many :survey_questions, -> {order 'position'}, class_name: "SurveyQuestion"
  has_many :user_activities
  has_many :context_messages, foreign_key: "context_program_id", class_name: "AbstractMessage"
  has_many :pending_notifications
  has_many :group_checkins
  has_many :mentoring_model_task_comments, class_name: "MentoringModel::Task::Comment"
  has_many :associated_recent_activities, :as => :ref_obj, class_name: "RecentActivity"
  has_many :dashboard_reports, dependent: :destroy, class_name: "DashboardReportSubSection"
  has_many :supplementary_matching_pairs, dependent: :destroy, inverse_of: :program
  has_many :user_search_activities, dependent: :destroy
  has_many :match_report_admin_views, dependent: :destroy

  #-----------------------------------------------------------------------------
  # UNION COLLECTIONS
  #-----------------------------------------------------------------------------

  has_union   :all_roles,
    :class_name => 'Role',
    :collections => ["roles", "organization.roles"]

  has_union   :all_pages,
    :class_name => 'Page',
    :collections => ["pages", "organization.pages"], :order => "position"

  #-----------------------------------------------------------------------------
  # SCOPES
  #-----------------------------------------------------------------------------

  # If you are trying to use .size/count on allowing_membership_requests(or on any scope with uniq use .all.size)
  scope :allowing_membership_requests, -> {joins(:roles).where("roles.membership_request = ? OR roles.join_directly = ? OR roles.eligibility_rules = ? OR roles.join_directly_only_with_sso = ?", true, true, true, true).distinct}
  scope :active, -> {joins(:organization).where("organizations_programs.active = 1")}

  scope :in_organization, -> (organization) { where('parent_id = ?', organization.id) }
  scope :published_programs, -> {where(:published => true)}
  scope :project_based, -> {where(engagement_type: Program::EngagementType::PROJECT_BASED)}

  scope :ordered, -> {order('programs.position')}

  scope :tracks,  -> { where(type: Program.name)}
  scope :portals, -> { where(type: CareerDev::Portal.name)}

  before_validation :set_position, on: :create

  #-----------------------------------------------------------------------------
  # VALIDATIONS
  #-----------------------------------------------------------------------------

  validates :organization, :name, :position, :presence => true
  validates :root, :presence => true,
    :format => {
      :with => /\A[A-Za-z0-9\-]+\z/,
      :allow_blank => true
    },
    :uniqueness => {
      :scope => :parent_id,
      :case_sensitive => false,
      :allow_nil => true
    }

  validates_numericality_of         :default_max_connections_limit,
    :greater_than => 0,
    :only_integer => true

  validates_inclusion_of            :sort_users_by,
    :in => [SortUsersBy::FULL_NAME, SortUsersBy::LAST_NAME]

  attr_accessor :skip_organization_validation, :can_increase_connection_limit, :can_decrease_connection_limit, :apply_to_all_mentors, :mentor_name, :student_name, :feedback_survey_id, :solution_pack_file, :created_for_sales_demo, :third_role_enabled
  validates_associated :organization, unless: lambda { |p| p.skip_organization_validation }
  validates :engagement_type, allow_blank: true, numericality: true, inclusion: { in: EngagementType.all }
  validates :mentor_request_style, numericality: true, inclusion: { in: MentorRequestStyle.all }
  validates :mentor_request_expiration_days, numericality: { greater_than: 0, only_integer: true }, allow_nil: true
  validates :number_of_licenses, allow_blank: true , numericality: { greater_than: 0 }

  validates :meeting_request_reminder_duration, numericality: { greater_than: 0 }, if: :needs_meeting_request_reminder?
  validates :mentoring_request_reminder_duration, numericality: { greater_than: 0 }, if: :needs_mentoring_request_reminder?
  validates :project_request_reminder_duration, numericality: { greater_than: 0 }, if: :needs_project_request_reminder?
  validates :meeting_request_auto_expiration_days, numericality: {greater_than: 0, only_integer: true}, allow_nil: true
  validates :circle_request_auto_expiration_days, numericality: {greater_than: 0, only_integer: true}, allow_nil: true
  restrict_sti_attributes ORGANIZATION_ATTRIBUTES

  validate :meeting_request_reminder_duration_less_than_auto_expiration
  validate :project_request_reminder_duration_less_than_auto_expiration
  validate :mentoring_period_must_be_greater_than_zero

  #-----------------------------------------------------------------------------
  # OTHER SETTINGS
  #-----------------------------------------------------------------------------

  # attr_protected :root
  # attr_protected :owner, :mentor_request_style, :sort_users_by

  def disable_program_observer
    false
  end

  [:active?, :basic_type?, :account_name].each do |method_name|
    delegate method_name, :to => :organization
  end

  #-----------------------------------------------------------------------------
  # INSTANCE METHODS
  #-----------------------------------------------------------------------------

  #
  # Returns whether this program is standalone, which means, this is the only
  # program under it's organization.
  #
  def standalone?
    self.organization.standalone?
  end

  def self.program_root_name(n = 1)
    "p#{n}"
  end

  def is_career_developement_program?
    false
  end

  def mentoring_slots
    mentor_role = self.find_role(RoleConstants::MENTOR_NAME)
    mentor_role.present? ? MentoringSlot.joins(:member => [:users => :role_references]).where('role_references.role_id = ?', mentor_role.id) : []
  end

  # Retuns the list of admins for this program, excluding the organization admins.
  def additional_admins
    self.admin_users.reject{|admin| admin.member.admin?}
  end

  # Retuns the list of active admins for this program, excluding the mentor admins.
  def active_admins_except_mentor_admins
    self.admin_users.active.includes(:member).reject{|admin| admin.member.is_chronus_admin?}
  end

  def active_users_by_roles(roles)
    self.users.active.joins(:roles).where("roles.id IN (?)", self.get_roles(roles)).readonly(false).distinct
  end

  def same_organization?(other_prog_or_organization)
    if other_prog_or_organization.is_a?(Organization)
      self.organization.same_organization?(other_prog_or_organization)
    else
      self == other_prog_or_organization
    end
  end

  def confidentiality_audit_logs_enabled?
    self.admin_access_to_mentoring_area == Program::AdminAccessToMentoringArea::AUDITED_ACCESS
  end

  def has_allowing_join_with_criteria?
    self.roles.allowing_join_with_criteria.count > 0
  end

  def invitable_roles_by_admins
    admin_role_permissions = self.find_role(RoleConstants::ADMIN_NAME).permission_names
    self.roles.for_mentoring.select{|role| admin_role_permissions.include?(RoleConstants::InviteRolePermission::Permission[role.name])}
  end

  def admin_access_to_mentoring_area_disabled?
    self.admin_access_to_mentoring_area == Program::AdminAccessToMentoringArea::DISABLED
  end

  def career_based?
    Program::EngagementType.career_based.include?(self.engagement_type)
  end

  def only_career_based_ongoing_mentoring_enabled?
    self.engagement_type == Program::EngagementType::CAREER_BASED_WITH_ONGOING
  end

  def ongoing_mentoring_enabled?
    self.engagement_type == Program::EngagementType::CAREER_BASED_WITH_ONGOING || self.project_based?
  end

  def only_one_time_mentoring_enabled?
    self.calendar_enabled? && !self.ongoing_mentoring_enabled?
  end

  def project_based?
    self.engagement_type == Program::EngagementType::PROJECT_BASED
  end

  def created_using_solution_pack?
    self.creation_way == Program::CreationWay::SOLUTION_PACK
  end

  def self_match_and_not_pbe?
    self.career_based? && self.self_match?
  end

  def ignored_survey_satisfaction_configuration?
    include_surveys_for_satisfaction_rate == false
  end
  
  def career_based_self_match_or_only_flash?
    self.career_based? && (self.self_match? || self.only_one_time_mentoring_enabled?) 
  end

  def career_based_self_match_or_flash?
    self.career_based? && (self.self_match? || self.calendar_enabled?) 
  end

  def career_based_ongoing_mentoring_and_not_calendar_enabled?
    only_career_based_ongoing_mentoring_enabled? && !calendar_enabled?
  end

  def is_ongoing_carrer_based_matching_by_admin_alone?
    self.only_career_based_ongoing_mentoring_enabled? && self.matching_by_admin_alone? 
  end

  def role_questions_for(role_names, options = {})
    include_privacy_settings = options.delete(:include_privacy_settings)
    eager_loaded = options.delete(:eager_loaded)
    default_options = RoleQuestion::DEFAULT_FOR_USER_OPTIONS.merge(options)
    if eager_loaded
      role_qns = self.role_questions.select{|role_qn| role_qn.role.name.in?(role_names)}
      return RoleQuestion.for_user_from_loaded_role_questions(role_qns, default_options)
    end

    query = self.role_questions.of_roles_with_program([role_names].flatten).for_user(default_options)
    include_privacy_settings ? query.includes(:privacy_settings) : query
  end

  def role_profile_questions_excluding_name_type(role, user)
    self.role_questions_for(role, user: user, include_privacy_settings: true).role_profile_questions.includes(profile_question: [:section, :translations, question_choices: :translations]).select{ |rq| !rq.profile_question.name_type? }
  end

  def in_summary_role_profile_questions_excluding_name_type(role, user)
    self.role_profile_questions_excluding_name_type(role, user).select(&:show_in_summary?)
  end

  def choice_based_questions_ids_for_role(role)
    self.role_questions_for(role, fetch_all: true).role_profile_questions
        .joins(:profile_question).where("profile_questions.question_type IN (?)", [ProfileQuestion::Type::SINGLE_CHOICE, ProfileQuestion::Type::MULTI_CHOICE, ProfileQuestion::Type::ORDERED_OPTIONS]).pluck("role_questions.id")
  end

  def show_match_label_questions_ids_for_role(role)
    self.role_questions_for(role, fetch_all: true).role_profile_questions
        .joins(:profile_question).where("profile_questions.question_type IN (?)", [ProfileQuestion::Type::LOCATION]).pluck("role_questions.id")
  end

  def mentoring_role_ids
    self.roles.for_mentoring.pluck(:id)
  end

  def membership_questions_for(role_names, options = { need_translations: false })
    role_names = [role_names].flatten
    includes_list = options[:need_translations] ? { profile_question: [:translations, {section: :translations}, {question_choices: :translations}] } : { profile_question: [:section, :question_choices] }
    questions_for_roles = self.role_questions_for(role_names, options).includes(includes_list)
    role_questions = questions_for_roles.membership_questions
    role_questions += questions_for_roles.admin_only_editable if options[:include_admin_only_editable]
    profile_questions = role_questions.collect(&:profile_question).uniq
    ProfileQuestion.sort_listing_page_filters(profile_questions)
  end

  def profile_questions_for(role_names, options = {default: true, skype: true})
    for_user_options = RoleQuestion::DEFAULT_FOR_USER_OPTIONS.merge(options.select{|k,v| [:user, :view, :edit, :fetch_all].include?(k)})
    for_user_options.merge!(eager_loaded: options[:eager_loaded])
    role_qns = self.role_questions_for(role_names, for_user_options)

    pqs = get_role_profile_questions(role_qns, options)

    unless options[:default]
      pqs = pqs.select(&:non_default_type?)
    end

    unless options[:skype]
      pqs = pqs.select{|pq| !pq.skype_id_type? }
    end
    return pqs
  end

  def required_profile_questions_except_default_for(role_names)
    self.role_questions_for(role_names).role_profile_questions.required.includes(:profile_question => :translations).collect(&:profile_question).uniq.select(&:non_default_type?)
  end

  def sections_for(role_names)
    self.role_questions_for(role_names).includes([:profile_question => [:section, :translations]]).collect(&:profile_question).collect(&:section).uniq.flatten
  end

  def get_first_role_term(transformation = :term, admin = false)
    self.roles.where(administrative: admin).first.customized_term.send(transformation)
  end

  def default_role_names
    RoleConstants::DEFAULT_ROLE_NAMES
  end

  def default_survey_types
    Survey::Type.for_program
  end

  #-----------------------------------------------------------------------------
  # --- MATCHING MODES
  #-----------------------------------------------------------------------------

  def matching_by_mentee_and_admin?
    self.mentor_request_style == MentorRequestStyle::MENTEE_TO_ADMIN
  end

  def matching_by_mentee_and_admin_with_preference?
    self.matching_by_mentee_and_admin? && self.preferred_mentoring_for_mentee_to_admin?
  end

  def matching_by_mentee_alone?
    self.mentor_request_style == MentorRequestStyle::MENTEE_TO_MENTOR
  end

  def matching_by_admin_alone?
    self.mentor_request_style == MentorRequestStyle::NONE
  end

  #-----------------------------------------------------------------------------
  # --- SLOT CONFIG RELATED METHODS
  #-----------------------------------------------------------------------------

  def is_slot_config_required_for?(role)
    self.project_based? && role.slot_config_required?
  end

  def is_slot_config_optional_for?(role)
    self.project_based? && role.slot_config_optional?
  end

  def is_slot_config_enabled_for?(role)
   self.project_based? && role.slot_config_enabled?
  end

  def slot_config_enabled?
    self.project_based? && self.roles.for_mentoring.any?(&:slot_config_enabled?)
  end

  #-----------------------------------------------------------------------------
  # PRODUCT DASHBOARD METHODS - START
  #-----------------------------------------------------------------------------

  def url(with_protocol = false)
    organization.url(with_protocol) + "/" + SubProgram::PROGRAM_PREFIX + root
  end

  def status_string(other = nil)
    other = nil if ["Active", "Inactive"].include?(other)
    other.present? ? other : (organization.active && active ? "Active" : "Inactive")
  end

  def organization_name
    organization.name
  end

  def mentor_enrollment_mode_string
    find_role(RoleConstants::MENTOR_NAME).try(:allowed_enrollment_options).try(:join, ", ") || ""
  end

  def mentee_enrollment_mode_string
    find_role(RoleConstants::STUDENT_NAME).try(:allowed_enrollment_options).try(:join, ", ") || ""
  end

  def admin_match?
    matching_by_mentee_and_admin? || matching_by_mentee_and_admin_with_preference? || matching_by_admin_alone?
  end

  def self_match?
    matching_by_mentee_alone?
  end

  def matching_mode_string
    ret = []
    ret << "Mentee requesting Admin" if matching_by_mentee_and_admin?
    ret << "Mentee requesting Admin (with preference)" if matching_by_mentee_and_admin_with_preference?
    ret << "Mentee requesting mentor" if matching_by_mentee_alone?
    ret << "Admin Matching" if matching_by_admin_alone?
    ret.join(", ")
  end

  def engagement_mode_string
    if project_based?
      "Circles"
    elsif only_career_based_ongoing_mentoring_enabled? && calendar_enabled?
      "Ongoing & Flash"
    elsif only_career_based_ongoing_mentoring_enabled?
      "Ongoing"
    elsif calendar_enabled?
      "Flash"
    end
  end

  def current_users_with_unpublished_or_published_profiles_count
    users.active_or_pending.size
  end

  def current_users_with_published_profiles_count
    users.active.size
  end

  def current_connected_users_count
    ActiveRecord::Base.connection.exec_query(groups.active.joins(:memberships).select("connection_memberships.user_id").to_sql).rows.flatten.uniq.size
  end

  def current_active_connections_count
    groups.active.count
  end

  def last_login(options = {})
    @__last_login = nil if options[:invalidate_cache]
    @__last_login ||= users.select("MAX(users.last_seen_at) AS last_seen_at").first.try(:last_seen_at)
  end

  def users_with_unpublished_or_published_profiles_ytd_count
    User.get_ids_of_users_active_between(self, *ytd_time_objects, include_unpublished: true).size
  end

  def users_with_published_profiles_ytd_count
    User.get_ids_of_users_active_between(self, *ytd_time_objects).size
  end

  def users_connected_ytd_count
    User.get_ids_of_connected_users_active_between(self, *ytd_time_objects).size
  end

  def connections_ytd_count(options = {})
    connections_in_date_range(ytd_time_objects, options)
  end

  def connections_in_date_range(date_range, options = {})
    @__connections_ytd_count = nil if options[:invalidate_cache]
    @__connections_ytd_count ||= Group.get_ids_of_groups_active_between(self, *date_range).size
  end

  def users_completed_connections_ytd_count
    query = completed_connections_ytd_query.joins(:memberships).select("connection_memberships.user_id")
    ActiveRecord::Base.connection.exec_query(query.to_sql).rows.flatten.compact.uniq.size
  end

  def users_successful_completed_connections_ytd_count(options = {})
    @__positive_completed_connections_data = nil if options[:invalidate_cache]
    @__positive_completed_connections_data ||= ActiveRecord::Base.connection.exec_query(get_positive_outcome_groups_ytd_query.to_sql).to_hash
    positive_outcome_group_ids = @__positive_completed_connections_data.map{ |hsh| hsh["group_id"] }.compact.uniq
    surveys.of_engagement_type.joins(survey_questions_with_matrix_rating_questions: [survey_answers: :answer_choices]).where("common_answers.group_id IN (?) and FIND_IN_SET(answer_choices.question_choice_id, common_questions.positive_outcome_options) > 0", positive_outcome_group_ids).pluck(:user_id).compact.uniq.size
  end

  #-----------------------------------------------------------------------------
  # PRODUCT DASHBOARD METHODS - END
  #-----------------------------------------------------------------------------

  #-----------------------------------------------------------------------------
  # --- FEATURES
  #-----------------------------------------------------------------------------

  def enabled_features
    enabled_features = (organization.enabled_db_features + enabled_db_features).collect(&:name)
    enabled_features -= (disabled_db_features.collect(&:name) - FeatureName.organization_level_features)
    enabled_features.uniq
  end

  def disabled_features
    FeatureName.all - self.enabled_features
  end

  def preferred_mentoring_for_mentee_to_admin?
    self.allow_preference_mentor_request?
  end

  def removed_as_feature_from_ui
    return standalone? ? super : (super + FeatureName.career_dev_specific_features).uniq
  end

   #-----------------------------------------------------------------------------
  # --- ACTIVITY TRACKING
  #-----------------------------------------------------------------------------

  #
  # Returns whether connection feedback is enabled.
  #
  def connection_feedback_enabled?
    !self.inactivity_tracking_period.nil?
  end

  def matching_enabled?
    self.engagement_enabled?
  end

  def engagement_enabled?
    self.engagement_type.present? || self.calendar_enabled?
  end

  def dual_request_mode?(mentor, student, is_request_creation_action = false)
    can_recommend_meeting = self.matching_by_mentee_alone? &&
      self.calendar_enabled? &&
      student.can_view_mentoring_calendar? &&
      mentor.opting_for_one_time_mentoring?
    return can_recommend_meeting unless is_request_creation_action

    can_recommend_meeting && !mentor.received_meeting_requests.exists?(sender_id: student.id) &&
        !mentor.is_capacity_reached_for_current_and_next_month?(Time.now.in_time_zone(student.member.get_valid_time_zone), student, error_message: true)[0]
  end

  def does_not_have_mailer_templates_with_calendar_tags?
    !campaign_management_enabled? || mailer_templates.map(&:is_valid_on_disabling_calendar?).inject(true, :&)
  end

  def is_mailer_template_enabled(uid)
    if self.mailer_templates.find_by(uid: uid).present?
      self.mailer_templates.find_by(uid: uid).enabled
    else
      return true
    end
  end

  def can_disable_calendar?
    ongoing_mentoring_enabled? && !meeting_requests.active.exists? && does_not_have_mailer_templates_with_calendar_tags?
  end

  def self.destroy_all_non_group_meetings(program_id)
    program = Program.where(id: program_id).first
    return if program.nil?
    program.meetings.non_group_meetings.pluck(:id).each { |meeting_id| Meeting.delay.false_destroy_without_email!(meeting_id) }
  end

  def prepare_to_disable_calendar
    Program.delay.destroy_all_non_group_meetings(id)
    users.where(mentoring_mode: User::MentoringMode.one_time_sanctioned).update_all(mentoring_mode: User::MentoringMode::ONGOING)
  end

  def prepare_to_re_enable_calendar
    users.where(mentoring_mode: User::MentoringMode.one_time_sanctioned + User::MentoringMode.ongoing_sanctioned).update_all(mentoring_mode: User::MentoringMode::ONE_TIME_AND_ONGOING)
  end

  #
  # Returns the inactivity tracking period in units of days.
  #
  def inactivity_tracking_period_in_days
    if self.inactivity_tracking_period.blank?
      nil
    else
      self.inactivity_tracking_period/(1.day)
    end
  end

  #
  # Sets the inactivity tracking period to the given number of days.
  # If nil/blank is passed, sets the period to nil, which means, switch off
  # tracking.
  #
  def inactivity_tracking_period_in_days=(num_days)
    self.inactivity_tracking_period = num_days.blank? ? nil : (num_days.to_i * 1.day)
  end

  def build_and_save_user!(user_attributes, role_names, member, options = {})
    return if member.suspended?
    user = self.all_users.of_member(member.id).first

    # If a user exists in the program just add the requested roles, else build a
    # new user with corresponding roles
    if user
      role_names_to_add = role_names - user.role_names
      user.role_names += role_names_to_add
      user.save!
      user.create_ra_and_mail_for_promoting_to_role(role_names_to_add, user_attributes[:created_by], '', !options[:send_email]) if options[:send_email]
      if user.suspended? && options[:admin].present?
        user.reactivate_in_program!(options[:admin], send_email: options[:send_reactivation_email].present?)
      else
        Matching.perform_users_delta_index_and_refresh_later([user.id], user.program)
      end
    else
      user = User.new_from_params({:program => self,:member => member, :role_names => role_names}.merge(user_attributes))
      user.save!
    end

    return user
  end

  def self.delayed_sending_of_program_invitations(program_id, member_ids, message, invitor_id, role_names, role_type, options = {})
    program = Program.find_by(id: program_id)
    return unless program.present?
    invitor = User.find_by(id: invitor_id)
    invites = []
    program.organization.members.where(id: member_ids).each do |member|
      invites << program.invite_member_for_roles(role_names, invitor, member, message, role_type, {skip_sending_instantly: true, locale: options[:locale]})
    end
    ProgramInvitation.send_invitations(invites.compact.collect(&:id), program.id, invitor_id, skip_sending_instantly: true, is_sender_admin: options[:is_sender_admin])
  end

  def invite_member_for_roles(roles, invitor, member, message, role_type, options = {})
    return if member.suspended?
    user = member.user_in_program(self)
    user_role_names = (user.blank? || user.suspended?) ? [] : user.role_names
    roles_to_add = roles - user_role_names

    return if roles_to_add.empty? || (user_role_names.any? && role_type == ProgramInvitation::RoleType::ALLOW_ROLE)
    create_member_invitation_for_roles(roles, member.email, message, invitor, role_type, options)
  end

  def non_admin_role_can_send_invite?
    non_admin_role_list = self.roles_without_admin_role
    non_admin_role_name_list = non_admin_role_list.pluck(:name)

    atleast_one_role_can_invite = false
    non_admin_role_name_list.each do |role_name|
      non_admin_role_list.each do |non_admin_role|
        can_invite = non_admin_role.can_invite_role?(role_name)
        atleast_one_role_can_invite ||= can_invite
      end
    end
    atleast_one_role_can_invite
  end

  def create_member_invitation_for_roles(roles, member_email, message, invitor, role_type, options)
    invite = program_invitations.build(:sent_to => member_email, :message => message, :user => invitor)
    invite.role_names = roles
    invite.role_type = role_type
    invite.locale = options[:locale]
    invite.skip_observer = options[:skip_sending_instantly]
    invite.save!
    invite
  end

  #-----------------------------------------------------------------------------
  # --- DEFAULT SET CREATION
  #-----------------------------------------------------------------------------

  def find_invitation(invite_code = '')
    self.program_invitations.where("code = ? and expires_on > ?", invite_code, Time.now.utc).first
  end

  def get_instruction_for_role_names(role_names)
    case role_names
    when [RoleConstants::STUDENT_NAME] then membership_instruction_for_students
    when [RoleConstants::MENTOR_NAME] then membership_instruction_for_mentors
    when [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME] then membership_instruction_for_mentor_students
    end
  end

  def create_default_name_role_question!(prof_q)
    roles = self.roles_without_admin_role
    roles.each do |role|
      RoleQuestion.create!(:profile_question => prof_q, :available_for => RoleQuestion::AVAILABLE_FOR::BOTH, :role => role, :required => true, :private => RoleQuestion::PRIVACY_SETTING::ALL, :filterable => true, :in_summary => true)
    end
  end

  def management_report_related_custom_term_interpolations
    @_management_report_related_custom_term_interpolations ||= {
      program: self.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase,
      :Program => self.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term,
      :Mentoring => self.term_for(CustomizedTerm::TermType::MENTORING_TERM).term,
      :Meeting => self.term_for(CustomizedTerm::TermType::MEETING_TERM).term,
      :Connections => self.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term,
      mentoring: self.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase,
      :Mentees => self.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term,
      :Mentors => self.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term,
      :connections => self.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase
    }
  end

  def update_default_abstract_views_for_program_management_report
    create_default_abstract_views_for_program_management_report
    create_default_program_management_report
  end

  def create_default_abstract_views_for_program_management_report
    AbstractView::DefaultViewsCommons.default_subview_classes.each do |klass|
      klass::DefaultViews.create_for(self)
    end
  end

  def create_default_sections_for_program_management_report
    report_sections.where("default_section NOT IN (?)", Report::Section::DefaultSections.all_default_sections_in_order + [nil]).each{ |section| section.destroy }
    Report::Section::DefaultSections.all_default_sections_in_order.each_with_index do |default_section, section_index|
      section = self.report_sections.where(default_section: default_section).first_or_initialize
      section.update_attributes!({
        position: section_index,
        title: ->{ "feature.reports.default.default_section_#{default_section}_title".translate(management_report_related_custom_term_interpolations) }.call,
        description: ->{ "feature.reports.default.default_section_#{default_section}_description".translate(management_report_related_custom_term_interpolations) }.call
      })
    end
  end

  def create_default_metrics_for_program_management_report
    default_metric_mapping = Report::Metric::DefaultMetrics::DEFAULT_METRIC_MAPPING
    Report::Metric.where(section_id: report_sections.pluck(:id)).where("default_metric NOT IN (?)", default_metric_mapping.keys + [nil]).each{ |metric| metric.destroy }
    create_metrics_for_program_management_report(default_metric_mapping)
  end

  def create_metrics_for_program_management_report(metric_mapping)
    position = 0
    metric_mapping.each do |default_metric, association|
      section = report_sections.where(default_section: association[:section]).first
      if section
        abstract_view = abstract_views.where(default_view: association[:abstract_view]).first
        if association[:condition] && !self.send(association[:condition])
          AbstractView.handle_invalid_subview_klass_view(self, association[:abstract_view], abstract_view.title) if abstract_view.present?
          next
        end
        abstract_view_class = abstract_view.class
        if can_create_metric?(abstract_view, abstract_view_class)
          create_metric_for_program_management_report(section, default_metric, abstract_view, position)          
          position += 1
        end
      end
    end
  end

  def can_create_metric?(abstract_view, abstract_view_class)
    abstract_view && (abstract_view_class.respond_to?(:is_accessible?) ? abstract_view_class.is_accessible?(self) : true)
  end

  def create_metric_for_program_management_report(section, default_metric, abstract_view, position)
    metric = section.metrics.where(default_metric: default_metric).first_or_initialize
    description_key = Report::Metric::DefaultMetrics::METRICS_WITH_UPDATED_DESCRIPTION.include?(metric.default_metric) ? "feature.reports.default.default_metric_#{default_metric}_description_v1" : "feature.reports.default.default_metric_#{default_metric}_description"
    metric.update_attributes!({
      title: ->{ "feature.reports.default.default_metric_#{default_metric}_title".translate(management_report_related_custom_term_interpolations) }.call,
      description: ->{ description_key.translate(management_report_related_custom_term_interpolations) }.call,
      abstract_view_id: abstract_view.id,
      position: position
    })
  end

  def create_default_alerts_for_program_management_report(affilation_map=ReportAlertUtils::DefaultAlerts.affiliation_map)
    program_metrics = self.abstract_views.includes([metrics: :alerts]).collect(&:metrics).flatten.index_by(&:default_metric)
    affilation_map.each do |default_alert, attribute_proc|
      attr_hsh = attribute_proc.call(self)
      alert_attributes = Hash[attr_hsh.to_a.map{|k, v| [k, v.call]}]
      default_metric_id = alert_attributes.delete(:metric)
      metric = program_metrics[default_metric_id]
      next if metric.nil? || metric.alerts.count > 0
      create_alert!(metric, alert_attributes, default_alert)
    end
  end

  def create_alert!(metric, alert_attributes, default_alert)
    new_alert = metric.alerts.new(alert_attributes.merge({default_alert: default_alert}))
    new_alert.save!
  end

  def self.create_default_program_management_report(program_id)
    program = Program.find_by(id: program_id)
    return unless program.present?
    program.create_default_sections_for_program_management_report
    program.create_default_metrics_for_program_management_report
    program.create_default_alerts_for_program_management_report
  end

  def create_default_program_management_report
    self.create_default_sections_for_program_management_report
    self.create_default_metrics_for_program_management_report
    self.create_default_alerts_for_program_management_report
  end

  def self.create_default_admin_views_and_its_dependencies(program_id)
    program = Program.find(program_id)
    program.create_default_admin_views
    program.create_default_abstract_views_for_program_management_report
    program.populate_default_campaigns unless program.created_using_solution_pack?
  end

  #-----------------------------------------------------------------------------
  # --- CUSTOM PROFILE AND MEMBERSHIP FORM
  #-----------------------------------------------------------------------------

  def program_forums_with_role(role_name)
    program_forums = self.forums.program_forums
    role_name == Forum::For::ALL ? program_forums : program_forums.for_role(role_name)
  end

  #-----------------------------------------------------------------------------
  # --- PROGRAM RELATED EMAILS
  #-----------------------------------------------------------------------------

  def notify_added_user(user, creator)
    if user.is_admin_only?
      # No pending email for admin
      deliver_user_added_notifcation_mail(user, creator, :admin_added_directly_notification)
    elsif user.is_mentor_only?
      deliver_user_added_notifcation_mail(user, creator, :mentor_added_notification)
    elsif user.is_student_only?
      deliver_user_added_notifcation_mail(user, creator, :mentee_added_notification)
    else
      deliver_user_added_notifcation_mail(user, creator, :user_with_set_of_roles_added_notification)
    end
  end
  #-----------------------------------------------------------------------------
  # --- MISCELLANEOUS
  #-----------------------------------------------------------------------------

  # Returns the list of Classes (indices) to be searched for the given user.
  def searchable_classes(user)
    classes = []
    role_names = user.program.role_names_without_admin_role
    classes << User if role_names.any? { |role_name| user.can_view_role?(role_name) }
    classes << Group if user.can_view_find_new_projects?
    classes + searchable_feature_classes(user)
  end

  def searchable_feature_classes(user)
    classes = []
    classes << QaQuestion if include_qa_question?(user)
    classes << Article if include_article?(user)
    classes << Resource if resources_enabled?
    classes << Topic if forums_enabled?
    classes
  end

  def include_qa_question?(user)
    self.qa_enabled? && user.can_view_questions?
  end

  def include_article?(user)
    self.articles_enabled? && user.can_view_articles?
  end

  def set_owner!(user=nil)
    admin = user || self.admin_users.first
    self.owner = admin
    self.save!
  end

  def deliver_facilitation_messages_v2(options = {})
    admin_member = self.admin_users.first.member
    self.mentoring_models.includes(active_groups: [memberships: :user], mentoring_model_facilitation_templates: [:roles]).select do |mentoring_model|
      mentoring_model.can_manage_mm_messages?(self.get_roles(RoleConstants::ADMIN_NAME))
    end.each do |mentoring_model|
      mentoring_model.mentoring_model_facilitation_templates.each do |facilitation_template|
        mentoring_model.active_groups.each do |group|
          curr_dt = Time.now.utc
          prev_dt = curr_dt - 1.days
          should_send = false
          if facilitation_template.specific_date.present?
            date = facilitation_template.specific_date
            # specific date contains info regarding [date, timezone]
            # so 1 day time window should be w.r.t specific date
            should_send = date <= curr_dt && curr_dt < date + 1.days
            # If the cron failed/got missed yesterday, this will send the notification
            should_send ||= (date <= prev_dt && prev_dt < date + 1.days)
          else
            time_to_notify = group.published_at + facilitation_template.send_on.days
            should_send = curr_dt.to_date == time_to_notify.to_date
            # If the cron failed/got missed yesterday, this will send the notification
            should_send ||= (curr_dt.to_date == time_to_notify.to_date + 1.days)
          end
          facilitation_template.deliver_to_eligible_recipients(group, admin_member) if should_send
        end
      end
    end
  end

  #
  # Returns whether the user belongs to this program.
  #
  def member?(user)
    user.program == self
  end

  def unresolved_flagged_content_count
    Flag.get_flags(self, {filter: {unresolved: true}}).count
  end

  def members_in_connections(connection_ids, send_message_type_or_role)
    user_ids = Connection::Membership.user_ids_in_groups(connection_ids, self, send_message_type_or_role)
    self.users.includes(:member).where("users.id IN (?)", user_ids).collect(&:member).uniq
  end

  def has_role_permission?(role_name, permission_name)
    role = self.roles.with_name(role_name).first
    return role.has_permission_name?(permission_name)
  end

  def add_role_permission(role_name, permission_name)
    role = self.roles.with_name(role_name).first
    return role.add_permission(permission_name)
  end

  def remove_role_permission(role_name, permission_name)
    role = self.roles.with_name(role_name).first
    return role.remove_permission(permission_name)
  end

  def update_permissions(new_permissions)
    all_permissions = self.class::Permissions.content_related
    all_permissions.each do |permission|
      if new_permissions.include?(permission[:label])
        self.add_role_permission(permission[:role], permission[:permission]) unless self.has_role_permission?(permission[:role], permission[:permission])
      else
        self.remove_role_permission(permission[:role], permission[:permission]) if self.has_role_permission?(permission[:role], permission[:permission])
      end
    end
  end

  def update_join_settings(role_join_settings)
    role_join_settings.each do |role_name, join_settings|
      self.find_role(role_name).update_role_join_settings!(join_settings)
      permission = "invite_#{role_name.pluralize}"
      self.roles_without_admin_role.each do |non_admin_role|
        join_settings.include?("#{non_admin_role.name}_invite") ? self.add_role_permission(non_admin_role.name, permission) : self.remove_role_permission(non_admin_role.name, permission)
      end
    end
  end

  def should_display_proposed_projects_emails?
    self.roles_without_admin_role.each do |non_admin_role|
      if self.has_role_permission?(non_admin_role.name, RolePermission::PROPOSE_GROUPS) && non_admin_role.needs_approval_to_create_circle?
        return true
      end
    end
    return false
  end

  def has_roles_that_can_invite?
    non_admins = self.roles_without_admin_role
    non_admins.each do |non_admin|
      non_admins.each do |role|
        if self.has_role_permission?(non_admin.name, "invite_#{role.name.pluralize}")
          return true
        end
      end
    end
    return false
  end

  def logo_url_with_fallback
    self.logo_url || self.organization.logo_url
  end

  def logo_or_banner_url(asset_priority = [:logo, :banner], with_type = false)
    asset_url, asset_type = super(asset_priority, true)
    asset_url, asset_type = self.organization.logo_or_banner_url(asset_priority, true) if asset_url.nil?
    with_type ? [asset_url, asset_type] : asset_url
  end

  def mobile_logo_url
    super || self.organization.mobile_logo_url
  end

  def can_render_mobile_logo?
    super || self.organization.can_render_mobile_logo?
  end

  #
  # Assigns the organization theme to this program
  #
  def assign_default_theme
    self.activate_theme(self.organization.active_theme)
  end

  def allow_users_to_join_directly_only_with_sso?
    self.roles.allowing_join_directly_only_with_sso.present?
  end

  def allow_join_now?
    self.roles.allowing_join_now.present?
  end

  def role_names_to_join_directly_only_with_sso
    self.roles.allowing_join_directly_only_with_sso.collect(&:name)
  end

  def role_names_allowing_join_with_criteria
    self.roles.allowing_join_with_criteria.collect(&:name)
  end

  def allow_join_directly_in_enrollment?
    self.roles.allowing_join_directly_or_join_directly_only_with_sso.present?
  end

  def role_names_with_join_directly_or_join_directly_only_with_sso
    self.roles.allowing_join_directly_or_join_directly_only_with_sso.collect(&:name)
  end

  def join_directly_only_with_sso_roles_present?(role_names)
    ([role_names].flatten & self.role_names_to_join_directly_only_with_sso).present?
  end

  def role_names_allowing_membership_request
    self.roles.allowing_membership_request.collect(&:name)
  end

  def membership_request_only_roles_present?(role_names)
    ([role_names].flatten & role_names_allowing_membership_request).present?
  end

  def allows_apply_to_join_for_a_role?
    self.roles_without_admin_role.inject(false){|allow_apply_to_join, role| allow_apply_to_join || role.can_show_apply_to_join_ticked?(self)}
  end

  def can_show_apply_to_join_mailer_templates?
    self.organization.chronus_auth.present? && self.allows_apply_to_join_for_a_role?
  end

  def allows_users_to_apply_to_join_in_project?
    self.roles.for_mentoring.includes(:permissions).inject(false){|allow_apply_to_join, role| allow_apply_to_join || role.has_permission_name?(RolePermission::SEND_PROJECT_REQUEST)}
  end

  def make_subscription_changes
    mentor_invite_mentor = [RoleConstants::MENTOR_NAME,RoleConstants::InviteRolePermission::Permission[RoleConstants::MENTOR_NAME]]
    mentee_invite_mentee = [RoleConstants::STUDENT_NAME,RoleConstants::InviteRolePermission::Permission[RoleConstants::STUDENT_NAME]]
    self.add_role_permission(mentor_invite_mentor[0],mentor_invite_mentor[1])
    self.add_role_permission(mentee_invite_mentee[0],mentee_invite_mentee[1])
    self.roles.default.each do |role|
      role.membership_request = true if (role.default == RoleConstants::Default::MENTOR || role.default == RoleConstants::Default::STUDENT)
      role.save
    end
  end

  def email_template_disabled_for_activity?(mailer)
    template = mailer.prog_template(self)
    if template.nil?
      return self.organization.email_template_disabled_for_activity?(mailer)
    else
      return !template.enabled?
    end
  end

  # The admin_view_params_hash argument should comply to the format speicified in the method params_wrapper in admin_view.rb
  # Also check out tasks/admin_view.rake and admin_view.rb -> AdminView::DefaultAdminView::PARAMS
  def create_default_admin_views(admin_view_params_hash = [])
    default_views = [admin_view_params_hash].flatten.presence || AdminView::DefaultAdminView.mandatory_views(self)
    ActiveRecord::Base.transaction do
      default_views.each do |view_record|
        title = view_record[:title]
        default_view = view_record[:default_view]
        same_view = self.admin_views.where("title = ? OR default_view = ?", title, default_view).first
        unless same_view.present?
          admin_view = self.admin_views.create!({:filter_params => AdminView.convert_to_yaml(view_record.delete(:admin_view)), :favourite => true, :favourited_at => Time.now }.merge(view_record))
          admin_view.create_default_columns
        end
      end
    end
  end

  def has_membership_requests?
    self.roles.allowing_membership_request.present? || self.membership_requests.not_joined_directly.pending.present?
  end

  def allow_multiple_role_option_in_membership_request?
    self.roles_without_admin_role.allowing_membership_request.size > 1 ||
    self.roles_without_admin_role.allowing_join_directly_or_join_directly_only_with_sso.size > 1 ||
    self.roles_without_admin_role.allowing_join_with_criteria.size > 1
  end

  # This is needed because when allow_multiple_role_option_in_membership_request? above becomes FALSE,
  # it does not reset "show_multiple_role_option" column to FALSE!
  def show_and_allow_multiple_role_memberships?
    self.allow_multiple_role_option_in_membership_request? && self.show_multiple_role_option?
  end

  def find_role(role_name)
    self.roles.find_by(name: role_name)
  end

  def find_roles(role_names)
    self.roles.where(:name => role_names)
  end

  def get_calendar_slot_time
    self.calendar_setting.present? && !self.calendar_setting.slot_time_in_minutes.zero? ? self.calendar_setting.slot_time_in_minutes : Meeting::SLOT_TIME_IN_MINUTES
  end

  def is_max_capacity_student_setting_initialized?
    self.calendar_setting.max_meetings_for_mentee.present?
  end

  def get_allowed_advance_slot_booking_time
    self.calendar_setting.advance_booking_time
  end

  def create_calendar_setting
    calendar_setting = CalendarSetting.new(:program_id => self.id)
    calendar_setting.slot_time_in_minutes = Meeting::SLOT_TIME_IN_MINUTES
    calendar_setting.allow_create_meeting_for_mentor = false
    calendar_setting.allow_mentor_to_describe_meeting_preference = true
    calendar_setting.advance_booking_time = Meeting::CAN_CREATE_MEETINGS_AFTER
    calendar_setting.save!
  end

  def self.create_calendar_setting_for_program(program_id)
    program = Program.find_by(id: program_id)
    return unless program.present?
    program.create_calendar_setting
  end

  def self.create_default_match_setting!(program_id)
    program = Program.find_by(id: program_id)
    return unless program.present?
    Matching::Persistence::Setting.create!(program_id: program_id) unless program.match_setting.present?
  end

  def update_match_setting_attributes!(min_score, max_score)
    match_setting = self.match_setting
    if match_setting.present?
      match_setting.update_attributes!(min_match_score: min_score, max_match_score: max_score)
    else
      Matching::Persistence::Setting.create!(min_match_score: min_score, max_match_score: max_score, program_id: self.id)
    end
  end

  def update_match_scores_range_later!(old_min_score = nil, old_max_score = nil)
    queue_name = Matching.get_mongo_cache_queue_name(self.organization.id)
    DJUtils.enqueue_unless_duplicates(queue: queue_name).update_match_scores_range!(self, old_min_score, old_max_score)
  end

  #--Update min_max range of a program
  #--min_reference_score and max_reference_score means min_old_score and max_old_score respectively
  #--Old scores are the previous scores of mentor or mentee before updating of profile or before removal of their profiles
  #--It will try to compute complete min-max of the program. And during computation if it finds those old 
  #--values, it will abort the process there.
  def update_match_scores_range!(min_reference_score = nil, max_reference_score = nil)
    student_ids = get_user_ids_based_on_roles(RoleConstants::STUDENT_NAME)
    update_min, update_max = min_reference_score.present?, max_reference_score.present? 
    update_flag = (update_min | update_max)
    temp_min, temp_max = Float::INFINITY, -1*Float::INFINITY 
    student_ids.each do |student_id|
      temp_min, temp_max = get_updated_temp_min_max(temp_min, temp_max, student_id)
      if update_flag
        update_min = false if update_min && temp_min <= min_reference_score
        update_max = false if update_max && temp_max >= max_reference_score
        return nil if !(update_max | update_min)
      end
    end
    temp_min, temp_max = nil, nil if temp_min == Float::INFINITY
    update_match_setting_attributes!(temp_min, temp_max)
  end

  def update_match_scores_range_for_student!(user, old_min_score = nil, old_max_score = nil)
    scores_min, scores_max = Matching::Database::Score.new.get_min_max_by_mentee_id(user.id) 
    if self.match_setting.present?
      self.update_match_scores_range_for_min_max!(scores_min, scores_max)
      if old_min_score.present? && (scores_min.nil? || scores_min > old_min_score || scores_max < old_max_score) 
        self.update_program_match_scores_range_wrt_old_scores(old_min_score, old_max_score)
      end
    else
      Matching::Persistence::Setting.create!(min_match_score: scores_min, max_match_score: scores_max, program_id: self.id)
    end
  end

  def update_match_scores_range_for_min_max!(min_score, max_score)
    return if min_score.nil?

    match_setting = self.match_setting
    if match_setting.min_match_score.nil? || min_score <= match_setting.min_match_score.to_f
      match_setting.min_match_score = min_score
    end
    if match_setting.max_match_score.nil? || max_score >= match_setting.max_match_score.to_f
      match_setting.max_match_score = max_score
    end
    match_setting.save!
  end

  def update_program_match_scores_range_wrt_old_scores(min_score, max_score)
    return if min_score.nil?

    match_setting = self.match_setting
    min_update_score, max_update_score = nil, nil
    if match_setting.min_match_score.present? && match_setting.max_match_score.present? 
      min_update_score = min_score if min_score <= match_setting.min_match_score
      max_update_score = max_score if max_score >= match_setting.max_match_score
      self.update_match_scores_range_later!(min_update_score, max_update_score) if max_update_score || min_update_score
    end
  end

  #--Return and update partition attribute of a program
  def get_partition_size_for_program
    partition = 1
    match_setting = self.match_setting
    if match_setting.present?
      partition = match_setting.partition
      if partition.nil?
        match_setting.update_attributes!(partition: 1)
        partition = 1
      end
    else
      Matching::Persistence::Setting.create!(min_match_score: nil, max_match_score: nil, program_id: self.id, partition: 1)
    end
    partition
  end

  #--return user_ids of program based on roles eg: mentor, student
  def get_user_ids_based_on_roles(role_name)
    role_id = self.roles.where(name: role_name).first.id
    RoleReference.where(role_id: role_id, ref_obj_type: User.name).pluck(:ref_obj_id)
  end

  def create_or_promote_user_as_admin(member, promoted_by)
    return if member.suspended?
    user = member.user_in_program(self)
    if user.present?
      user.promote_to_role!(RoleConstants::ADMIN_NAME, promoted_by)
    else
      user = self.build_and_save_user!({:created_by => promoted_by, :existing_member_as_admin => true}, [RoleConstants::ADMIN_NAME], member, {admin: promoted_by})
      user.delay(:queue => DjQueues::HIGH_PRIORITY).send_promotion_notification_mail([RoleConstants::ADMIN_NAME], promoted_by, "", false, JobLog.generate_uuid)
    end
  end

  def self.create_default_group_view(program_id)
    program = Program.find_by(id: program_id)
    return unless program.present?
    ActiveRecord::Base.transaction do
      group_view = GroupView.create!(program: program)
      group_view.create_default_columns
    end
  end

  def students_by_user
    Connection::MentorMembership.select(:user_id).
      joins(group: :student_memberships).
      where('groups.status!=?', Group::Status::CLOSED).
      where('groups.program_id=?', id).
      group('connection_memberships.user_id').count
  end

  def pending_mentor_offers_size
    mentor_offers.pending.group(:mentor_id).count
  end

  def available_slots_by_user
    options = students_by_user.inject({}) { |res, pair| res[pair[0]] = pair[1]; res }
    pending_mentor_offers_size.each { |user_id, count| options[user_id] ||= 0; options[user_id] += count }
    options
  end

  def get_all_tags(list = true)
    select_columns = list ? "name" : "id, name"
    tags = ActsAsTaggableOn::Tag.select(select_columns).where(:tags => { :id =>
                    ActsAsTaggableOn::Tagging.select("DISTINCT tag_id")
                      .joins("LEFT JOIN users ON taggings.taggable_id = users.id")
                      .where( :taggable_type => 'User', :users => {:program_id => self.id} ) })
    list ? tags.pluck(:name) : tags
  end

  # creates and returns the mentoring_model
  # if the mentoring_model already exits then returns that mentoring_model
  def create_default_mentoring_model!
    return self.default_mentoring_model if self.default_mentoring_model.present?

    self.mentoring_models.create!(
      title: "#{name} #{"feature.mentoring_model.label.Template".translate}",
      default: true,
      mentoring_period: DEFAULT_MENTORING_PERIOD
    )
    self.reload_default_mentoring_model
  end

  def has_new_updates_from?(time_ago)
    self.new_articles(time_ago).size > 0 ||
    self.new_qa_questions(time_ago).size > 0
  end

  def match_setting
    Matching::Persistence::Setting.where(program_id: self.id).first
  end

  def populate_default_campaigns
    # Admin views are getting created from the program observer. The import has to be called only after the admin views are created. So, adding the default campaigns creation as djob
    # Although this doesn't ensure that import campaign is called after admin view creation, I think this is a reasonable assumption.
    campaigns_csv_files = self.class::CAMPAIGNS::CSV_FILES
    CampaignPopulator.setup_program_with_default_campaigns(id, campaigns_csv_files)
    self.user_campaigns.destroy_all if !self.campaign_management_enabled?
    CampaignPopulator.link_program_invitation_campaign_to_mailer_template(id) if program_invitation_campaign.present?
  end

  def populate_default_customized_terms
    return if self.customized_terms.any?

    default_customized_terms = [["feature.custom_terms.mentoring_connection_v1".translate, CustomizedTerm::TermType::MENTORING_CONNECTION_TERM],
     ["feature.custom_terms.meeting".translate, CustomizedTerm::TermType::MEETING_TERM],
     ["feature.custom_terms.resource".translate, CustomizedTerm::TermType::RESOURCE_TERM],
     ["feature.custom_terms.article".translate, CustomizedTerm::TermType::ARTICLE_TERM],
     ["feature.custom_terms.mentoring".translate, CustomizedTerm::TermType::MENTORING_TERM]]

    default_customized_terms.each do |term_and_type|
      self.customized_terms.new.save_term(term_and_type[0], term_and_type[1])
    end
  end

  def self.create_default_group_report_view_colums!(program_id)
    program = Program.find_by(id: program_id)
    return unless program.present?
    column_keys = ReportViewColumn.get_default_groups_report_columns(program)
    column_keys.each_with_index do |column_key, position|
      program.report_view_columns.create!(
        :report_type => ReportViewColumn::ReportType::GROUPS_REPORT,
        :column_key => column_key,
        :position => position)
    end
  end

  def create_default_group_closure_columns!
    tracked_keys = {}
    column_keys = GroupClosureReason::DefaultClosureReason.all(:Mentoring_Connection => self.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term, :mentoring_connection => self.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)
    column_keys.each do |key, attributes|
      tracked_keys[key] = self.group_closure_reasons.create!(attributes)
    end
    tracked_keys
  end

  def demographic_report_role_based_view_columns
    {
      RoleConstants::MENTOR_NAME => ReportViewColumn::DemographicReport::Key::MENTORS_COUNT,
      RoleConstants::STUDENT_NAME => ReportViewColumn::DemographicReport::Key::MENTEES_COUNT
    }
  end

  def demographic_report_view_columns
    ReportViewColumn::DemographicReport::Key::DEFAULT_KEYS + demographic_report_role_based_view_columns.values
  end

  def self.create_demographic_report_view_colums!(program_id)
    program = Program.find_by(id: program_id)
    return unless program.present?
    program.demographic_report_view_columns.each_with_index do |column_key, position|
      program.report_view_columns.create!(
        :report_type => ReportViewColumn::ReportType::DEMOGRAPHIC_REPORT,
        :column_key => column_key,
        :position => position)
    end
  end

  #can_increase_connection_limit = 1 if connection_limit is 2 or 3
  #can_decrease_connection_limit = 1 if connection_limit is 1 or 3
  def get_connection_limit
    limit = self.connection_limit_permission
    if limit == ConnectionLimit::ONLY_INCREASE || limit == ConnectionLimit::BOTH
      self.can_increase_connection_limit = 1
    else
      self.can_increase_connection_limit = 0
    end

    if limit == ConnectionLimit::ONLY_DECREASE || limit == ConnectionLimit::BOTH
      self.can_decrease_connection_limit = 1
    else
      self.can_decrease_connection_limit = 0
    end
  end

  def set_connection_limit(increase_limit, decrease_limit)
    if increase_limit == 1
      self.connection_limit_permission = decrease_limit == 1 ? ConnectionLimit::BOTH : ConnectionLimit::ONLY_INCREASE
    elsif increase_limit == 0
      self.connection_limit_permission = decrease_limit == 1 ? ConnectionLimit::ONLY_DECREASE : ConnectionLimit::NONE
    end
  end

  def allow_mentor_update_maxlimit?
    self.connection_limit_permission != ConnectionLimit::NONE
  end

  def update_mentors_connection_limit(limit)
    self.mentor_users.each do |mentor|
      mentor.max_connections_limit = limit
      mentor.save(:validate => false)
    end
  end

  def get_groups_report_view_columns
    column_keys = ReportViewColumn.get_applicable_groups_report_columns(self)
    report_view_columns = self.report_view_columns.for_groups_report.where(column_key: column_keys)
    report_view_columns
  end

  # Create surveys with questions mentioned in the specified file.
  def create_survey(filename, role_name = nil, survey_name = nil, survey_type = EngagementSurvey.name, edit_mode = nil, feedback_survey = false)
    yml_data = IO.read(filename)
    data = YAML::load(ERB.new(yml_data).result)
    survey = survey_type.constantize.new(:program => self, :name => survey_name || data["name"], :edit_mode => edit_mode)
    survey.program = self
    survey.recipient_role_names = role_name || [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME] if survey.program_survey?
    survey.form_type = Survey::FormType::FEEDBACK if !self.feedback_survey.present? && feedback_survey
    survey.save!

    # Add program attribute each question data hash.
    data["questions"].each do |q_data|
      q_data.merge!(:program => self)
      choices = q_data.delete("question_choices") || []
      survey_question = survey.survey_questions.create(q_data)
      choices.each_with_index{|choice, pos| survey_question.question_choices.create(text: choice, position: pos+1, is_other: false)}
    end

    return survey
  end

  def feedback_survey
    self.surveys.find_by(form_type: Survey::FormType::FEEDBACK)
  end

  def feedback_survey_changed?(new_survey_id)
    self.feedback_survey.try(:id) != new_survey_id.to_i
  end

  def permitted_closure_reasons
    self.group_closure_reasons.permitted
  end

  def default_closure_reasons
    self.group_closure_reasons.default
  end

  def auto_terminate?
    self.auto_terminate_reason_id.present?
  end

  def consider_mentoring_mode?
    self.ongoing_mentoring_enabled? && self.calendar_enabled? && self.allow_mentoring_mode_change == MENTORING_MODE_CONFIG::EDITABLE
  end

  def has_general_availability?
    self.calendar_setting.present? && self.calendar_setting.allow_mentor_to_describe_meeting_preference?
  end

  def has_custom_role?
    self.custom_roles.exists?
  end

  def custom_roles
    self.roles.where.not(name: RoleConstants::DEFAULT_ROLE_NAMES)
  end

  def mentoring_roles_with_permission(permission_name)
    self.roles.for_mentoring.with_permission_name(permission_name)
  end

  def self.create_default_meeting_feedback_surveys(program_id, skip_questions=false)
    program = Program.find_by(id: program_id)
    return unless program.present?

    custom_terms_hash = program.return_custom_term_hash
    mentee_survey = MeetingFeedbackSurvey.create!(name: Proc.new{"feature.survey.content.meeting_feedback_survey_for_mentees".translate(custom_terms_hash)}.call, program_id: program_id, role_name: RoleConstants::STUDENT_NAME)
    mentor_survey = MeetingFeedbackSurvey.create!(name: Proc.new{"feature.survey.content.meeting_feedback_survey_for_mentors".translate(custom_terms_hash)}.call, program_id: program_id, role_name: RoleConstants::MENTOR_NAME)
    unless skip_questions
      mentee_survey.add_default_questions!(custom_terms_hash)
      mentor_survey.add_default_questions!(custom_terms_hash)
    end
  end

  def get_old_meeting_feedback_survey
    Survey.unscoped.where(type: MeetingFeedbackSurvey.name, program_id: self.id).find_by(role_name: nil)
  end

  def get_meeting_feedback_survey_for_role(role_name)
    self.surveys.of_meeting_feedback_type.find_by(role_name: role_name)
  end

  def get_meeting_feedback_survey_for_user_in_meeting(user, meeting)
    get_meeting_feedback_survey_for_role(meeting.get_role_of_user(user))
  end

  def ab_test_enabled?(experiment_name)
    program_ab_test = self.ab_tests.find_by(test: experiment_name)
    program_ab_test ||= self.organization.ab_tests.find_by(test: experiment_name)
    program_ab_test.present? ? program_ab_test.enabled? : ProgramAbTest.experiment(experiment_name).enabled?
  end

  def create_default_feedback_rating_questions
    question1 = {question_text: "feature.coach_rating.label.comments".translate, program_id: self.id, question_type: CommonQuestion::Type::TEXT}

    feedback_form = Feedback::Form.create!(program_id: self.id, form_type: Feedback::Form::Type::COACH_RATING)
    feedback_form.questions.create!(question1)
  end

  def email_priamry_color
    self.email_theme_override.present? ? self.email_theme_override : (self.theme_vars[EmailTheme::PRIMARY_COLOR] || self.organization.email_priamry_color)
  end

  def should_send_admin_weekly_status?(since = 1.week.ago)
    return true if self.membership_requests.not_joined_directly.pending.recent(since).exists?
    return true if self.roles_without_admin_role.default.any? { |role| self.send("#{role.name}_users").recent(since).exists? }
    return true if self.can_mentor_get_mentor_requests? && self.mentor_requests.recent(since).exists?
    return true if self.ongoing_mentoring_enabled? && self.groups.published.recent(since).exists?
    return true if self.calendar_enabled? && self.meeting_requests.recent(since).exists?
    return true if self.articles.published.recent(since).exists?
    return true if self.groups.active.any?(&:expiring_next_week?)
    return true if self.project_based? && (self.groups.proposed.exists? || self.project_requests.active.recent(since).exists?)
    return true if SurveyAnswer.where(common_question_id: self.survey_question_ids).last_answered(since).exists?
    return false
  end

  def can_mentor_get_mentor_requests?
    !self.matching_by_admin_alone? && self.ongoing_mentoring_enabled?
  end

  def get_admin_weekly_status_hash
    since = 1.week.ago
    week_before = 2.weeks.ago
    admin_weekly_status_hash = {}

    admin_weekly_status_hash[:membership_requests] = {}
    admin_weekly_status_hash[:articles] = {}


    ## MembershipRequest data
    last_week_value = admin_weekly_status_hash[:membership_requests][:since] = self.membership_requests.not_joined_directly.pending.recent(since).count
    week_before_value = admin_weekly_status_hash[:membership_requests][:week_before] = self.membership_requests.not_joined_directly.pending.recent(week_before).count
    admin_weekly_status_hash[:membership_requests][:show_mr_data] = self.has_membership_requests?
    admin_weekly_status_hash[:membership_requests][:values_not_changed] = (last_week_value == 0 && week_before_value == 0)

    ## Articles data
    last_week_value = admin_weekly_status_hash[:articles][:since] = self.articles.published.recent(since).count
    week_before_value = admin_weekly_status_hash[:articles][:week_before] = self.articles.published.recent(week_before).count
    admin_weekly_status_hash[:articles][:values_not_changed] = (last_week_value == 0 && week_before_value == 0)

    admin_weekly_status_hash[:new_survey_responses] = SurveyAnswer.where(common_question_id: self.survey_question_ids).last_answered(since).pluck(:response_id).uniq.count

    self.roles_without_admin_role.default.collect(&:name).each do |role_name|
      role_key = "#{role_name}_users".to_sym
      admin_weekly_status_hash[role_key] = {}
      last_week_value = admin_weekly_status_hash[role_key][:since] = self.send(role_key).recent(since).count
      week_before_value = admin_weekly_status_hash[role_key][:week_before] = self.send(role_key).recent(week_before).count
      admin_weekly_status_hash[role_key][:values_not_changed] = (last_week_value == 0 && week_before_value == 0)
    end

    if can_mentor_get_mentor_requests?
      ## MentorRequests data
      admin_weekly_status_hash[:mentor_requests] = {}
      admin_weekly_status_hash[:pending_mentor_requests] = {}
      last_week_value = admin_weekly_status_hash[:mentor_requests][:since] = self.mentor_requests.recent(since).count
      week_before_value = admin_weekly_status_hash[:mentor_requests][:week_before] = self.mentor_requests.recent(week_before).count
      admin_weekly_status_hash[:mentor_requests][:values_not_changed] = (last_week_value == 0 && week_before_value == 0)

      ## Active MentorRequests data
      last_week_value = admin_weekly_status_hash[:pending_mentor_requests][:since] = self.mentor_requests.active.recent(since).count
      week_before_value = admin_weekly_status_hash[:pending_mentor_requests][:week_before] = self.mentor_requests.active.recent(week_before).count
      admin_weekly_status_hash[:pending_mentor_requests][:values_not_changed] = (last_week_value == 0 && week_before_value == 0)
    end

    if ongoing_mentoring_enabled?
      ## Groups data
      admin_weekly_status_hash[:groups] = {}
      last_week_value = admin_weekly_status_hash[:groups][:since] = self.groups.published.recent(since).count
      week_before_value = admin_weekly_status_hash[:groups][:week_before] = self.groups.published.recent(week_before).count
      admin_weekly_status_hash[:groups][:values_not_changed] = (last_week_value == 0 && week_before_value == 0)
    end

    if calendar_enabled?
      admin_weekly_status_hash[:meeting_requests] = {}
      admin_weekly_status_hash[:active_meeting_requests] = {}
      ## MeetingRequests data
      last_week_value = admin_weekly_status_hash[:meeting_requests][:since] = self.meeting_requests.recent(since).count
      week_before_value = admin_weekly_status_hash[:meeting_requests][:week_before] = self.meeting_requests.recent(week_before).count
      admin_weekly_status_hash[:meeting_requests][:values_not_changed] = (last_week_value == 0 && week_before_value == 0)
      ## Active MeetingRequests data
      last_week_value = admin_weekly_status_hash[:active_meeting_requests][:since] = self.meeting_requests.active.recent(since).count
      week_before_value = admin_weekly_status_hash[:active_meeting_requests][:week_before] = self.meeting_requests.active.recent(week_before).count
      admin_weekly_status_hash[:active_meeting_requests][:values_not_changed] = (last_week_value == 0 && week_before_value == 0)
    end
    if project_based?
      admin_weekly_status_hash[:pending_project_requests] = {}
      ## Projects waiting for approval data
      admin_weekly_status_hash[:pending_projects_for_approval] = self.groups.proposed.count
      ## Pending ProjectRequest data
      last_week_value = admin_weekly_status_hash[:pending_project_requests][:since] = self.project_requests.active.recent(since).count
      week_before_value = admin_weekly_status_hash[:pending_project_requests][:week_before] = self.project_requests.active.recent(week_before).count
      admin_weekly_status_hash[:pending_project_requests][:values_not_changed] = (last_week_value == 0 && week_before_value == 0)
    end
    admin_weekly_status_hash
  end

  def unconnected_user_widget_content(view_options)
    widget_content = []
    time_range_1 = (((Time.now - 1.month).beginning_of_day)..Time.now)
    time_range_2 = (((Time.now - 2.month).beginning_of_day)..((Time.now - 1.month).end_of_day))
    widget_content += self.get_most_viewed_community_contents(time_range_1, UNCONNECTED_USER_WIDGET_TILES_COUNT, view_options)
    widget_content += self.get_most_viewed_community_contents(time_range_2, UNCONNECTED_USER_WIDGET_TILES_COUNT, view_options)
    widget_content += self.get_recent_community_contents(UNCONNECTED_USER_WIDGET_TILES_COUNT, view_options)
    widget_content
  end

  def get_recent_community_contents(count, view_options)
    objects = []
    objects += get_recent_community_of_type(self.articles, count, DigestV2::PopularContentType::Priority::ARTICLE) if view_options[:articles]
    objects += get_recent_community_of_type(self.qa_questions, count, DigestV2::PopularContentType::Priority::QA_QUESTION) if view_options[:qa]
    objects += self.get_recent_topics(count, DigestV2::PopularContentType::Priority::TOPIC) if view_options[:forums]
    objects.sort_by{ |obj| [obj[:obj_priority], obj[:object].id, obj[:role_id].to_i] }
  end

  def get_recent_topics(count, priority)
    self.roles.map do |role|
      role_forum_ids = self.program_forums_with_role(role.name).pluck(:id)
      Topic.where(forum_id: role_forum_ids).order("created_at desc").limit(count).map{ |object| {object: object, obj_priority: priority, role_id: role.id} }
    end.flatten.compact
  end

  def get_most_viewed_community_contents(time_range, count, view_options = {articles: true, forums: true, qa: true})
    objects = []
    objects += get_most_view_of_type(self.articles, time_range, :view_count, count, DigestV2::PopularContentType::Priority::ARTICLE) if view_options[:articles]
    objects += get_most_view_of_type(self.qa_questions, time_range, :views, count, DigestV2::PopularContentType::Priority::QA_QUESTION) if view_options[:qa]
    objects += self.get_most_viewed_topics(time_range, count, DigestV2::PopularContentType::Priority::TOPIC) if view_options[:forums]
    objects.sort_by{ |obj| [-1 * obj[:views], obj[:obj_priority]] }
  end

  def get_most_viewed_topics(time_range, count, priority)
    self.roles.map do |role|
      role_forum_ids = self.program_forums_with_role(role.name).pluck(:id)
      Topic.where(forum_id: role_forum_ids).where(created_at: time_range).order("hits desc").limit(count).map{ |object| {object: object, views: object.hits, obj_priority: priority, role_id: role.id} }
    end.flatten.compact
  end

  def visible_surveys
    types = ["ProgramSurvey"]
    types << "EngagementSurvey" if self.mentoring_connections_v2_enabled?
    types << "MeetingFeedbackSurvey" if self.calendar_enabled?
    self.surveys.where(type: types)
  end

  def create_organization_admins_sub_program_admins
    # Making the other organization-admins admins for the new sub-program
    all_admins = self.organization.members.admins.non_suspended
    all_admins.each do |a|
      user = self.all_users.new
      user.member = a
      user.role_names = [RoleConstants::ADMIN_NAME]
      user.save!
    end
  end

  def create_program_languages
    self.organization.organization_languages.each do |organization_language|
      self.program_languages.create!(organization_language: organization_language)
    end
  end

  def set_default_program_options
    self.mentoring_period = Program::DEFAULT_MENTORING_PERIOD if self.mentoring_period.nil?
    self.set_project_based_specific_settings if self.project_based?
  end

  def set_project_based_specific_settings
    self.mentor_request_style = Program::MentorRequestStyle::NONE
    self.allow_one_to_many_mentoring = true
  end

  def create_recent_activity
    # Create a recent activity for all admin
    recent_activity = RecentActivity.create!(
      ref_obj: self,
      action_type: RecentActivityConstants::Type::PROGRAM_CREATION,
      target: RecentActivityConstants::Target::ADMINS
    )
    recent_activity.programs = [self]
    recent_activity.save!
  end

  def self.create_default_resource_publications(program_id)
    program = Program.find_by(id: program_id)
    return unless program.present?
    program.organization.resources.default.each do |resource|
      resource.resource_publications.create!(program_id: program.id)
    end
  end

  def create_additional_roles_and_permissions
    OrganizationFeature::WITH_DEPENDANCIES.each do |feature_name|
      self.send("invoke_feature_dependancy_#{feature_name}", self.organization.has_feature?(feature_name))
    end
  end

  def languages_enabled_and_has_multiple_languages_for_everyone?
    organization.language_settings_enabled? && program_languages.enabled_for_all.exists?
  end

  def get_enabled_organization_language(language_name)
    if language_name.to_sym == I18n.default_locale
      OrganizationLanguage.for_english
    else
      OrganizationLanguage.find_by(id: program_languages.enabled_for_all.pluck(:organization_language_id), language_name: language_name)
    end
  end

  def enabled_organization_languages_including_english
    [OrganizationLanguage.for_english] + OrganizationLanguage.where(id: program_languages.enabled_for_all.select(:organization_language_id))
  end

  def self.populate_default_static_content_for_globalization(program_id)
    program = Program.find_by(id: program_id)
    return unless program.present?
    locales = [I18n.default_locale] + program.organization.languages.pluck(:language_name)
    program.populate_zero_match_score_message_with_default_value_if_nil(locales)
    program.mentor_request_instruction.populate_content_with_default_value_if_nil(locales)
    program.roles_without_admin_role.collect{ |role| role.populate_description_with_default_value_if_nil(locales) }
  end

  def populate_zero_match_score_message_with_default_value_if_nil(locales)
    return unless self.matching_enabled?
    locales.each do |locale|
      translation = self.translations.find_or_initialize_by(locale: locale)
      translation.zero_match_score_message = "program_settings_strings.content.zero_match_score_message_placeholder".translate(locale: locale) if translation.zero_match_score_message.nil?
      translation.save!
    end
  end

  def self.add_translation_for_zero_match_score_message_in_locales(org, locale)
    org.programs.each {|prog| prog.populate_zero_match_score_message_with_default_value_if_nil([locale])}
  end

  def update_bulk_match_default(match_or_recommendation, orientation_type = BulkMatch::OrientationType::MENTEE_TO_MENTOR)
    bulk_entry = AbstractBulkMatch.find_by(type: match_or_recommendation, orientation_type: orientation_type)
    AbstractBulkMatch.where(program_id: self.id).update_all(default: 0)
    bulk_entry.update_attribute(:default, 1) if bulk_entry.present?
  end

  def get_program_health_url
    "email_translations.welcome_message_to_admin.program_health_url".translate
  end

  def survey_question_ids
    SurveyQuestion.where(survey_id: self.surveys.pluck(:id)).pluck(:id)
  end

  def get_mentor_recommendation_example_content
    if self.matching_by_mentee_and_admin_with_preference?
      if self.can_end_users_see_match_scores?
        'email_translations.mentor_recommendation_notification.tags.recommended_mentors_details.example_v5_html'.translate(self.return_custom_term_hash)
      else
        'email_translations.mentor_recommendation_notification.tags.recommended_mentors_details.example_v6_html'.translate(self.return_custom_term_hash)
      end
    else
      if self.can_end_users_see_match_scores?
        'email_translations.mentor_recommendation_notification.tags.recommended_mentors_details.example_v2_html'.translate(self.return_custom_term_hash)
      else
        'email_translations.mentor_recommendation_notification.tags.recommended_mentors_details.example_v4_html'.translate(self.return_custom_term_hash)
      end
    end
  end

  def allow_multiple_groups_between_student_mentor_pair?
    return true unless self.ongoing_mentoring_enabled?

    self.project_based? || (self.allow_one_to_many_mentoring? && self.matching_by_admin_alone? && !self.mentor_offer_enabled?)
  end

  def show_existing_groups_alert?
    self.career_based? && self.allow_multiple_groups_between_student_mentor_pair?
  end

  def handle_program_asset_of_standalone_program
    self.copy_program_asset([self.parent_id], true)
    self.program_asset.try(:destroy)
  end

  def handle_organization_features_of_standalone_program
    organization = self.organization
    program_level_only_feature_ids = Feature.where(name: FeatureName.program_level_only).pluck(:id)
    program__organization_features = self.organization_features.where.not(feature_id: program_level_only_feature_ids)
    program__organization_features.each do |program__organization_feature|
      organization__organization_feature = organization.organization_features.find_or_initialize_by(feature_id: program__organization_feature.feature_id)
      organization__organization_feature.enabled = program__organization_feature.enabled
      organization__organization_feature.save!
    end
    program__organization_features.destroy_all
  end

  def handle_pages_of_standalone_program
    maximum_position = self.organization.pages.last.try(:position).to_i

    self.pages.each_with_index do |page, index|
      page.update_attributes(position: (maximum_position + index + 1), program_id: self.parent_id)
    end
  end

  def group_messaging_enabled?
    !self.mentoring_connections_v2_enabled? || self.mentoring_models.where(allow_messaging: true).exists?
  end

  def group_forum_enabled?
    self.mentoring_connections_v2_enabled? && self.mentoring_models.where(allow_forum: true).exists?
  end

  def show_groups_report?
    self.ongoing_mentoring_enabled? && ReportViewColumn.get_applicable_groups_report_columns(self, ReportViewColumn::GroupsReport.activity_columns).any?
  end

  def community_features_enabled?
    self.resources_enabled? || self.articles_enabled? || self.qa_enabled? || self.forums_enabled?
  end

  def mails_disabled_by_default
    mails_to_disable = Program::MAILS_TO_DISABLE_BY_DEFAULT.mail_classes_at_program_level
    mails_to_disable -= Meeting::CALENDAR_SYNC_NECESSARY_EMAILS if self.calendar_sync_enabled?
    return mails_to_disable
  end

  ##### OUTCOMES REPORT METHODS - START #####

  def get_positive_outcomes_questions_array(for_management_report=false)
    questions_array = []
    self.meeting_or_engagement_surveys_scope.includes(:translations, :survey_questions).select(:id).collect do |survey|
      questions_array << { text: survey.name, children: survey.get_survey_questions_for_outcomes(for_management_report) }
    end
    return questions_array
  end

  def get_positive_outcome_surveys
    scoped_survey_ids = self.meeting_or_engagement_surveys_scope.pluck(:id)
    SurveyQuestion.where(program_id: self.id, survey_id: scoped_survey_ids).where("positive_outcome_options IS NOT ?", nil).includes(survey: :translations).reject{|q| q.positive_outcome_options.blank? }.map(&:survey).uniq
  end

  def meeting_or_engagement_surveys_scope
    surveys = self.surveys
    self.ongoing_mentoring_enabled? ? surveys.of_engagement_type : surveys.of_meeting_feedback_type
  end

  def update_positive_outcomes_options!(page_data, for_management_report=false)
    self.meeting_or_engagement_surveys_scope.includes(:translations, :survey_questions).select([:id]).map{|survey| survey.get_questions_in_order_for_report_filters.select(&:choice_based?)}.flatten.each do |question|
      for_management_report ? question.update_attributes!({positive_outcome_options_management_report: page_data[question.id].presence}) : question.update_attributes!({positive_outcome_options: page_data[question.id].presence})
    end
  end

  ##### OUTCOMES REPORT METHODS - END #####

  def published_groups_in_date_range(start_date, end_date)
    self.groups.where("groups.published_at < ? ", end_date).where("groups.closed_at IS NULL OR groups.closed_at > ? ", start_date)
  end

  def create_views_related_to_connections?
    self.ongoing_mentoring_enabled?
  end

  def create_views_related_to_drafted_connections?
    self.ongoing_mentoring_enabled? && self.matching_by_admin_alone?
  end

  def create_views_related_to_mentoring_requests?
    MentorRequestView.is_accessible?(self)
  end

  def handle_destroy
    # When an organization becomes standalone post program deletion,
    # 1. Transition global suspension of members to program suspension, as global suspension is not allowed in standalone organizations
    # 2. Transition global admin messages and resources to program-level
    # 3. Transition Page, ProgramAsset & OrganizationFeature (of non program-level only features) in program-level to organization-level

    organization = self.organization
    if organization.present? && organization.programs.size == 1
      Member.delay.transition_global_suspensions_to_program(organization.members.suspended.pluck(:id))
      Organization.delay.transition_global_objects_to_standalone_program(organization.id)
      Organization.delay.transition_standalone_program_objects_to_organization(organization.id)
    end
  end

  def connection_summary_question
    self.summaries.first.try(:connection_question)
  end

  def roles_applicable_for_auto_approval
    self.roles.where(name: [RoleConstants::AUTO_APPROVAL_ROLE_MAPPING.keys])
  end

  #-----------------------------------------------------------------------------
  # EXPLICIT PREFERENCE METHODS
  #-----------------------------------------------------------------------------
  def get_valid_role_questions_for_explicit_preferences
    self.role_questions_for(RoleConstants::MENTOR_NAME, include_privacy_settings: true).role_profile_questions.includes(profile_question: [:translations, question_choices: :translations]).select{ |rq| rq.filterable && rq.profile_question.eligible_for_explicit_preferences? }
  end

  def can_end_users_see_match_scores?
    self.allow_end_users_to_see_match_scores? && !explicit_user_preferences_enabled?
  end

  def allow_user_to_see_match_score?(user)
    self.allow_end_users_to_see_match_scores? && !user.explicit_preferences_configured?
  end

  #----------------------------------------------------------------------------

  def preferece_based_mentor_lists_enabled?
    self.has_feature?(FeatureName::POPULAR_CATEGORIES) && self.career_based_self_match_or_flash? && self.find_role(RoleConstants::STUDENT_NAME).has_permission_name?("view_mentors")
  end

  #-----------------------------------------------------------------------------
  # MATCH REPORT METHODS
  #-----------------------------------------------------------------------------

  def create_default_match_report_section_settings
    mentor_distribution_mentor_view = self.match_report_admin_views.find_or_initialize_by(section_type: MatchReport::Sections::MentorDistribution, role_type: RoleConstants::MENTOR_NAME)
    mentor_distribution_mentor_view.update_attributes!(admin_view: MatchReport::Sections::SectionClasses[MatchReport::Sections::MentorDistribution].constantize.fetch_default_admin_view(self, RoleConstants::MENTOR_NAME))

    mentor_distribution_mentee_view = self.match_report_admin_views.find_or_initialize_by(section_type: MatchReport::Sections::MentorDistribution, role_type: RoleConstants::STUDENT_NAME)
    mentor_distribution_mentee_view.update_attributes!(admin_view: MatchReport::Sections::SectionClasses[MatchReport::Sections::MentorDistribution].constantize.fetch_default_admin_view(self, RoleConstants::STUDENT_NAME))

    mentee_actions_view = self.match_report_admin_views.find_or_initialize_by(section_type: MatchReport::Sections::MenteeActions, role_type: RoleConstants::STUDENT_NAME)
    mentee_actions_view.update_attributes!(admin_view: MatchReport::Sections::SectionClasses[MatchReport::Sections::MenteeActions].constantize.fetch_default_admin_view(self))
  end

  def can_show_match_report?
    self.match_report_enabled? && self.can_have_match_report?
  end

  def can_have_match_report?
    !(self.is_career_developement_program? || self.project_based?) && (!self.matching_by_mentee_and_admin? || self.matching_by_mentee_and_admin_with_preference?)
  end

  def get_match_report_admin_view(section_type, role_type)
    self.match_report_admin_views.find_by(section_type: section_type, role_type: role_type)
  end

  def create_default_match_report_admin_views
    views = self.only_one_time_mentoring_enabled? ? [AdminView::DefaultViews::NEVER_CONNECTED_MENTEES] : [AdminView::DefaultViews::CURRENTLY_NOT_CONNECTED_MENTEES, AdminView::DefaultViews::AVAILABLE_MENTORS]
    AdminView::DefaultViews.create_views_for(self, views, AdminView)
  end

  def create_default_match_config_discrepancy_cache
    match_configs = self.match_configs.select(&:questions_choice_based?)
    match_configs.each do |config|
      config.refresh_match_config_discrepancy_cache
    end
  end
  #-----------------------------------------------------------------------------
  # PRIVATE METHODS
  #-----------------------------------------------------------------------------

  private

  def get_role_profile_questions(role_qns, options)
    role_qns =  if options[:eager_loaded]
                  role_qns.select{|role_qn| role_qn.role_profile_question? }
                elsif options[:all_role_questions]
                  role_qns
                else
                  include_options = get_include_options(options)
                  role_qns.role_profile_questions.includes(include_options[:include])
                end
    role_qns.collect(&:profile_question).uniq
  end

  def get_include_options(options = {pq_translation_include: true})
    if options[:dont_include_section]
      options[:pq_translation_include] ? {include: {profile_question: [:translations, {question_choices: :translations}]}} : {include: :profile_question}
    else
      options[:pq_translation_include] ? {include: {profile_question: [:translations, {section: [:translations]}, {question_choices: :translations}]}} : {include: {profile_question: [:section]}}
    end
  end

  def set_position
    return if self.position.present? || self.organization.nil?
    self.position = self.organization.programs.maximum(:position).to_i + 1
  end

  def get_most_view_of_type(arel, time_range, count_column, count, priority)
    arel.where(created_at: time_range).order("#{count_column} desc").limit(count).map{ |object| {object: object, views: object.send(count_column), obj_priority: priority, role_id: nil} }
  end

  def get_recent_community_of_type(arel, count, priority)
    arel.order("created_at desc").limit(count).map{ |object| {object: object, obj_priority: priority, role_id: nil} }
  end

  def meeting_request_reminder_duration_less_than_auto_expiration
    if self.needs_meeting_request_reminder? && self.meeting_request_reminder_duration.present? && self.meeting_request_auto_expiration_days.present?
      self.errors.add(:meeting_request_reminder_duration, "activerecord.custom_errors.program.meeting_request_reminder_duration_less_than_auto_expiration".translate) if self.meeting_request_reminder_duration > self.meeting_request_auto_expiration_days 
    end
  end

  def project_request_reminder_duration_less_than_auto_expiration
    if self.needs_project_request_reminder? && self.project_request_reminder_duration.present? && self.circle_request_auto_expiration_days.present?
      self.errors.add(:project_request_reminder_duration, "activerecord.custom_errors.program.meeting_request_reminder_duration_less_than_auto_expiration".translate) if self.project_request_reminder_duration > self.circle_request_auto_expiration_days 
    end
  end

  def mentoring_period_must_be_greater_than_zero
    days = self.mentoring_period_before_type_cast
    if days.blank? || !(days.is_a? Numeric) || days <= 0
      mentoring_term = self.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).nil? ? "feature.custom_terms.mentoring".translate : self.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term
      self.errors.add(:base, "activerecord.custom_errors.program.mentoring_period".translate(mentoring_term: mentoring_term, days_count: 0))
    end
  end

  def deliver_user_added_notifcation_mail(user, creator, mail, pending_mail = nil)
    reset_password = Password.create!(:member => user.member)
    ChronusMailer.send(user.profile_pending? && pending_mail ? pending_mail : mail, user, creator, reset_password).deliver_now
  end

  def get_updated_temp_min_max(temp_min, temp_max, student_id)
    min_score, max_score = Matching::Database::Score.new.get_min_max_by_mentee_id(student_id)
    if min_score.present?
      temp_min = min_score if min_score < temp_min
      temp_max = max_score if max_score > temp_max
    end
    [temp_min, temp_max]
  end

end
