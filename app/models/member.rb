# == Schema Information
#
# Table name: members
#
#  id                            :integer          not null, primary key
#  organization_id               :integer          not null
#  admin                         :boolean          default(FALSE)
#  state                         :integer          default(0), not null
#  created_at                    :datetime
#  updated_at                    :datetime
#  login_name                    :string(255)
#  email                         :string(100)      not null
#  crypted_password              :string(40)
#  remember_token                :string(40)
#  remember_token_expires_at     :datetime
#  salt                          :string(40)
#  time_zone                     :string(255)
#  first_name                    :string(255)
#  last_name                     :string(255)
#  auth_config_id                :integer
#  api_key                       :string(255)      default("")
#  calendar_api_key              :string(255)
#  failed_login_attempts         :integer          default(0)
#  imported_at                   :datetime
#  account_locked_at             :datetime
#  password_updated_at           :datetime
#  delta                         :boolean          default(FALSE)
#  will_set_availability_slots   :boolean          default(FALSE)
#  availability_not_set_message  :text(65535)
#  terms_and_conditions_accepted :datetime
#  browser_warning_shown_at      :datetime
#  calendar_sync_count           :integer          default(0)
#

require 'digest/sha1'

class Member < ActiveRecord::Base
  extend ClearInvalidDependentAnswers
  extend DateProfileFilter

  include MemberElasticsearchSettings
  include MemberElasticsearchQueries

  include AuthorizationManager::UserExtensions
  include Authentication
  include Authentication::ByPassword
  include Authentication::ByCookieToken
  include EmailFormatCheck

  MASS_UPDATE_ATTRIBUTES = {
    :from_registration => {
      :create_admin => [:first_name, :last_name, :email, :password, :password_confirmation, :time_zone],
      :update => [:first_name, :last_name, :password, :password_confirmation]
    },
    :from_organization_admin => {
      :create => [:first_name, :last_name, :email]
    },
    update_settings: [:time_zone, :will_set_availability_slots, :availability_not_set_message],
    profile_picture: [:image, :image_url],
    user: {
      create: [:first_name, :last_name, :email, :time_zone],
      update: [:state, :activated_at, :admin_notes, :last_seen_at, :group_notification_setting, :program_notification_setting, :max_connections_limit, :state_changer_id, :state_change_reason, :qa_answers_count, :last_weekly_update_sent_time, :profile_updated_at, :primary_home_tab, :hide_profile_completion_bar, :creation_source, :mentoring_mode, :track_reactivation_state, :global_reactivation_state, :image_url, :created_by, :imported_from_other_program, :existing_member_as_admin, :addition_message, :created_for_sales_demo],
      user_settings: [:max_meeting_slots]
    },
    user_notification_settings: [:notification_setting_name,:disabled],
    update: [:admin, :state, :email, :crypted_password, :remember_token, :remember_token_expires_at, :salt, :time_zone, :first_name, :last_name, :api_key, :calendar_api_key, :failed_login_attempts, :imported_at, :account_locked_at, :password_updated_at, :will_set_availability_slots, :availability_not_set_message, :terms_and_conditions_accepted, :browser_warning_shown_at, :calendar_sync_count, :password, :password_confirmation, :validate_password, :current_password, :email_changer],
    new_user_invite: [:first_name, :last_name, :password, :password_confirmation]
  }.merge!(ProfileAnswer::MASS_UPDATE_ATTRIBUTES.pick(:manager, :experience, :education, :publication))

  has_paper_trail only: [:crypted_password], on: [:update], class_name: 'ChronusVersion'

  FULL_NAME_SORT = "LOWER(TRIM(CONCAT(CONCAT(COALESCE(TRIM(first_name),''), ' '), TRIM(last_name))))"
  LAST_NAME_SORT = "LOWER(CONCAT(TRIM(last_name),TRIM(COALESCE(first_name, ''))))"

  module ErrorMessage
    DUPLICATE_USER = "already has the user"
  end

  module EncryptionType
    SHA1 = 'sha1'
    INTERMEDIATE = 'intermediate'
    SHA2 = 'sha2'
  end

  module Status
    ACTIVE    = 0
    SUSPENDED = 2
    DORMANT   = 3

    class << self
      def all
        [ACTIVE, SUSPENDED, DORMANT]
      end

      def all_except(*statuses)
        all - statuses
      end
    end
  end

  module DoNotDisturbTimes
    WEEKDAY = [{start_time: {hour: 0, min: 0, sec: 0}, end_time: {hour: 8, min: 30, sec: 0}}, {start_time: {hour: 19, min: 0, sec: 0}, end_time: {hour: 24, min: 0, sec: 0}}]
    WEEKEND = [{start_time: {hour: 0, min: 0, sec: 0}, end_time: {hour: 24, min: 0, sec: 0}}]
  end

  #-----------------------------------------------------------------------------
  # ASSOCIATIONS
  #-----------------------------------------------------------------------------

  belongs_to  :organization, :foreign_key => "organization_id"

  has_one      :profile_picture, :dependent => :destroy
  has_many    :passwords, :dependent => :destroy
  has_many    :one_time_flags, :as => :ref_obj, :dependent => :destroy
  has_many    :users,     :dependent => :destroy
  has_many    :active_users, -> {where(:state => [User::Status::ACTIVE, User::Status::PENDING])}, :class_name => "User"

  has_many    :programs,  :through => :users
  has_many    :active_programs,  -> {preload(:translations)}, :through => :active_users, :source => :program
  has_many    :active_tracks,  -> {where("programs.type = ?", Program.name)}, :through => :active_users, :source => :program
  has_many    :active_portals,  :through => :active_users, :source => :portal
  has_many :o_auth_credentials, as: :ref_obj, dependent: :destroy
  has_many :google_o_auth_credentials, as: :ref_obj
  has_many :microsoft_o_auth_credentials, as: :ref_obj
  has_many :outlook_o_auth_credentials, as: :ref_obj
  has_many :office365_o_auth_credentials, as: :ref_obj


  # member does not own these messages, hence, no dependent destroy.
  # Appropriate actions will be taken in MessageObserver
  has_many  :sent_messages,
            -> { where(auto_email: false).order(id: :desc)},
            :class_name => "AbstractMessage",
            :foreign_key => 'sender_id'

  has_many  :message_receivers,
            -> { order(id: :desc) },
            :class_name => "AbstractMessageReceiver",
            :foreign_key => 'member_id',
            :dependent => :destroy

  # member does not own these messages, hence, no dependent destroy
  has_many  :received_messages,
            -> { where("abstract_message_receivers.status != ?", AbstractMessageReceiver::Status::DELETED).order("messages.id DESC")},
            :through => :message_receivers,
            :source => :message

  has_many  :articles, :foreign_key => 'author_id', :dependent => :destroy

  has_many  :activities,
            :class_name => "RecentActivity",
            :dependent => :destroy

  has_many :member_meetings, :dependent => :destroy
  has_many :meetings, :through => :member_meetings
  has_many :accepted_meetings, -> {where('member_meetings.attending = ?', MemberMeeting::ATTENDING::YES)}, :through => :member_meetings, source: :meeting
  has_many :accepted_flash_meetings, -> {where('member_meetings.attending = ? && meetings.group_id IS NULL', MemberMeeting::ATTENDING::YES)}, :through => :member_meetings, source: :meeting
  has_many :member_meeting_responses, :through => :member_meetings

  has_many :mentoring_slots, :dependent => :destroy, inverse_of: :member

  has_many :profile_answers, :as => :ref_obj, :dependent => :destroy
  has_many :answer_choice_versions
  has_many :answered_profile_questions, :through => :profile_answers, :source => :profile_question

  has_many  :locations, :through => :profile_answers
  has_one  :location_answer, -> {where("location_id IS NOT NULL")}, :as => :ref_obj, :class_name => 'ProfileAnswer', :dependent => :destroy

  has_many :educations, -> {order "graduation_year DESC"}, :through => :profile_answers, :validate => false
  # Present should come first, followed by records having end_year, followed by records having end_year as nil
  has_many :experiences, -> {order "current_job DESC, end_year DESC, end_month DESC"}, :through => :profile_answers, :validate => false
  has_many :publications, -> {order "created_at DESC"}, :through => :profile_answers, :validate => false
  has_many :membership_requests, :dependent => :destroy
  has_many :job_logs, as: :ref_obj, dependent: :destroy
  has_many :loggable_job_logs, as: :loggable_object, class_name: "JobLog"

  has_one :member_language, :dependent => :destroy

  has_many :three_sixty_survey_assessees, :dependent => :destroy, :class_name => 'ThreeSixty::SurveyAssessee'
  has_many :three_sixty_surveys, :through => :three_sixty_survey_assessees, :source => :survey
  has_many :three_sixty_survey_reviewers, :through => :three_sixty_survey_assessees, :source => :reviewers

  has_many :manager_entries, :class_name => "Manager", :inverse_of => :member, :dependent => :nullify
  has_many :managees, :through => :manager_entries

  has_many :mobile_devices, dependent: :destroy
  has_many :push_notifications, dependent: :destroy

  has_many :vulnerable_content_logs
  has_many :dismissed_rollout_emails, :class_name => "RolloutEmail", :as => :ref_obj, :dependent => :destroy
  has_many :content_updated_emails, class_name: "Mailer::Template", foreign_key: :content_changer_member_id, dependent: :nullify
  has_many :private_meeting_notes,
            :through => :member_meetings,
            :class_name => "PrivateMeetingNote"
  has_many :ratings, -> { where(rateable_type: ["Article", "Resource"]) }, foreign_key: "user_id", :dependent => :destroy
  has_many :shown_recent_activities, foreign_key: "for_id", class_name: "RecentActivity"
  has_many :owned_meetings, class_name: "Meeting", foreign_key: "owner_id"
  has_many :mentoring_model_activities, class_name: "MentoringModel::Activity"
  has_many :invited_three_sixty_survey_reviewers, class_name: "ThreeSixty::SurveyReviewer", foreign_key: "inviter_id"
  has_many :user_csv_imports
  has_many :mentoring_model_task_comments, class_name: "MentoringModel::Task::Comment", foreign_key: "sender_id"
  has_many :mentee_meetings, class_name: "Meeting", foreign_key: "mentee_id"
  has_many :login_tokens, dependent: :destroy

  #-----------------------------------------------------------------------------
  # UNION COLLECTIONS
  #-----------------------------------------------------------------------------

  # Member has many roles through their roles in various programs.

  has_many :roles, :through => :users
  has_many :user_activities
  has_many :login_identifiers, autosave: true, dependent: :destroy
  has_many :auth_configs, through: :login_identifiers
  has_union :qa_questions,          :class_name => 'QaQuestion',      :collections => {:users => :qa_questions}
  has_union :qa_answers,            :class_name => 'QaAnswer',        :collections => {:users => :qa_answers}
  has_union	:answered_qa_questions, :class_name => 'QaQuestion',      :collections => {:users => :answered_qa_questions}
  has_union :recent_activities,     :class_name => 'RecentActivity',  :collections => {:users => :recent_activities}
  has_union :groups,                :class_name => 'Group',           :collections => {:users => :groups}
  has_union :mentoring_groups,      :class_name => 'Group',           :collections => {:users => :mentoring_groups}
  has_union :studying_groups,       :class_name => 'Group',           :collections => {:users => :studying_groups}

  #-----------------------------------------------------------------------------
  # VALIDATIONS
  #-----------------------------------------------------------------------------

  validates_presence_of :email, :last_name, :organization, :state, :calendar_sync_count
  validates_presence_of :first_name, :on => :create

  validates_length_of :last_name,  :maximum => 100,  :allow_blank => false
  validates_length_of :first_name, :maximum => 100, :allow_nil => true
  validates_length_of :email, :within => 6..100

  #Validation to avoid Numeric characters in the first_name and the last_name
  validates :first_name, :format => {:with => RegexConstants::RE_NO_NUMBERS, :message => ->(err,hsh){RegexConstants::MSG_NAME_INVALID.translate} }
  validates :last_name, :format => {:with => RegexConstants::RE_NO_NUMBERS, :message => ->(err,hsh){RegexConstants::MSG_NAME_INVALID.translate} }

  validates_format_of :last_name, :with => RE_NAME_OK, :message => MSG_NAME_BAD, :allow_nil => true
  validates :email, :email_format => {:generate_message => true}, :on => :update
  validates :state, inclusion: { in: [Status::ACTIVE, Status::SUSPENDED, Status::DORMANT] }

  validates_uniqueness_of :email,      :scope => [:organization_id], :case_sensitive => false
  validates_uniqueness_of :calendar_api_key, :scope => [:organization_id]

  # Security related validation
  validate :custom_password_auth, :check_email_format, :check_indigenous_login_identifier
  validate :check_valid_email, :on => :create
  validates :time_zone, :inclusion => TimezoneConstants::VALID_TIMEZONE_IDENTIFIERS, :allow_nil => true, :allow_blank => true


  #-----------------------------------------------------------------------------
  # SCOPES
  #-----------------------------------------------------------------------------
  scope :admins, -> { where(admin: true) }
  scope :active, -> { where(state: Status::ACTIVE) }
  scope :suspended, -> { where(state: Status::SUSPENDED) }
  scope :non_suspended, -> { where.not(state: Status::SUSPENDED) }

  scope :of_organization, ->(organization) {
    where({ :organization_id => organization })
  }

  scope :exceeded_maximum_login_attempts, Proc.new { |maximum_login_attempts|
    where("`members`.`failed_login_attempts` > ?", maximum_login_attempts)
  }

  scope :locked_out, Proc.new { |maximum_login_attempts, auto_reactivation_time|
    where("`members`.`failed_login_attempts` > ?", maximum_login_attempts).where("DATE_ADD(IFNULL(`members`.`account_locked_at`, UTC_TIMESTAMP()), INTERVAL ? HOUR) >= UTC_TIMESTAMP()", auto_reactivation_time)
  }


  ################################################################
  # Elasticsearch indexing methods
  ################################################################

  def name_only
    name(name_only: true)
  end

  #-----------------------------------------------------------------------------
  # CONFIGURATION
  #-----------------------------------------------------------------------------

  # attr_protected :admin
  attr_accessor :password, :password_confirmation, :validate_password, :current_password
  attr_accessor :email_changer # The +Member+ who changed the email
  #needed to update last_notified_time from handle_
  attr_accessor :skip_observer

  alias_method :topic_author_name_only, :name_only

  # Extracts the email from a string of the form 'Name <email>'
  def self.extract_email_from_name_with_email(name_with_email)
    name_with_email.match(/<(.*)>$/)
    $1
  end

  def self.format_time_with_time_zone(str)
    Time.zone.parse(str[0..-2]) # The zone information is taken from what's set for the member
  end

  def self.sorted_by_answer(initial_scope, profile_question, sort_order, options = {})
    # we need members data only
    selects = ['members.id']
    # sort param
    sort_param = 'LOWER(answer_text)'
    #
    profile_answers_joiner = "LEFT JOIN profile_answers ON profile_answers.ref_obj_id=members.id AND profile_answers.ref_obj_type='Member' AND profile_answers.profile_question_id=#{profile_question.id}"
    # basic members scope
    members_scope = initial_scope.joins(profile_answers_joiner)
    if profile_question.file_type?
      sort_param = 'LOWER(attachment_file_name)'
    elsif profile_question.education?
      educations_joiner = "LEFT JOIN educations ON educations.profile_answer_id=profile_answers.id"
      selects << "LOWER(CONVERT(GROUP_CONCAT(CONCAT_WS(', ', educations.school_name, educations.degree, educations.major, educations.graduation_year) ORDER BY graduation_year DESC SEPARATOR '/') USING utf8)) as education_string"
      sort_param = 'education_string'
      members_scope = members_scope.joins(educations_joiner).group('members.id')
    elsif profile_question.experience?
      experience_joiner = "LEFT JOIN experiences ON experiences.profile_answer_id=profile_answers.id"
      selects << "LOWER(CONVERT(GROUP_CONCAT(CONCAT_WS(', ', experiences.job_title, experiences.start_year, experiences.end_year, experiences.company) ORDER BY current_job DESC,end_year DESC,end_month DESC SEPARATOR '/') USING utf8)) as experiences_string"
      sort_param = 'experiences_string'
      members_scope = members_scope.joins(experience_joiner).group('members.id')
    elsif profile_question.publication?
      publication_joiner = "LEFT JOIN publications ON publications.profile_answer_id=profile_answers.id"
      selects << "LOWER(CONVERT(GROUP_CONCAT(CONCAT_WS(', ', publications.title, publications.publisher, publications.year, publications.month, publications.day, publications.authors, publications.description) ORDER BY title DESC,year DESC,month DESC,day DESC SEPARATOR '/') USING utf8)) as publication_string"
      sort_param = 'publication_string'
      members_scope = members_scope.joins(publication_joiner).group('members.id')
    elsif profile_question.manager?
      manager_joiner = "LEFT JOIN managers ON managers.profile_answer_id=profile_answers.id"
      selects << "LOWER(CONVERT(GROUP_CONCAT(CONCAT_WS(', ', managers.first_name, managers.last_name, managers.email) ORDER BY managers.first_name DESC,managers.last_name DESC,managers.email DESC SEPARATOR '/') USING utf8)) as manager_string"
      sort_param = 'manager_string'
      members_scope = members_scope.joins(manager_joiner).group('members.id')
    elsif profile_question.location? && options[:location_scope]
      locations_joiner = "LEFT JOIN locations ON locations.id=profile_answers.location_id"
      selects << "locations.#{options[:location_scope]}"
      sort_param = "LOWER(locations.#{options[:location_scope]})"
      members_scope = members_scope.joins(locations_joiner).group('members.id')
    elsif profile_question.choice_or_select_type?
      choices_joiner = "LEFT JOIN answer_choices ON answer_choices.ref_obj_id = profile_answers.id AND answer_choices.ref_obj_type='#{ProfileAnswer.name}' LEFT JOIN question_choice_translations ON answer_choices.question_choice_id = question_choice_translations.question_choice_id AND question_choice_translations.locale IN ('#{I18n.default_locale}', '#{I18n.locale}')"
      selects << "LOWER(question_choice_translations.text) as choices"
      sort_param = 'choices'
      members_scope = members_scope.joins(choices_joiner).group('members.id')
    elsif profile_question.date?
      selects << "date_answers.answer"
      sort_param = "date_answers.answer"
      members_scope = members_scope.joins(join_date_answers(join_type: "left")).group('members.id')
    end
    sort_order = "#{sort_param} #{sort_order}"
    members_scope.select(selects.join(',')).order(sort_order)
  end

  # TODO_GLOBALIZE: Provision locale-based sorting
  def self.sorted_by_program_roles(initial_scope, sort_order)
    initial_scope.
      select("members.id, BINARY(GROUP_CONCAT(program_translations.name ORDER BY BINARY(program_translations.name))) AS program_names").
      left_joins(users: { program: :translations } ).
      where(program_translations: { locale: [nil, I18n.default_locale] } ).
      group("members.id").
      order("program_names #{sort_order}")
  end

  def self.member_ids_of_users(options = {})
    user_ids = options[:user_ids].present? ? options[:user_ids] : options[:users]&.pluck(:id)
    arel_chain = User.where(id: user_ids).distinct
    arel_chain = arel_chain.active if options[:filter_active_users_scope]
    arel_chain.pluck(:member_id)
  end

  # email_or_name_with_email should be one of the following: member.email, member.name_with_email, member.name(:name_only => true), member.name
  def self.by_email_or_name(email_or_name_with_email, organization)
    email = ValidatesEmailFormatOf::validate_email_format(email_or_name_with_email).nil? ? email_or_name_with_email : Member.extract_email_from_name_with_email(email_or_name_with_email)
    es_options = { with: {organization_id: organization.id}, match_fields: (email.present? ? ["email"] : ["name_only"]) }
    Member.get_filtered_members(email.presence || email_or_name_with_email.presence, es_options)
  end

  def self.prepare_answer_hash(member_ids, profile_question_ids = [])
    answers_hash = {}
    answers_hash.default = {}
    if profile_question_ids.present?
      profile_answers = ProfileAnswer.where(ref_obj_type: Member.to_s, ref_obj_id: member_ids, profile_question_id: profile_question_ids).includes({profile_question: [:translations, {question_choices: :translations}]}, :answer_choices, :educations, :experiences, :publications, :manager, :location)
      profile_answers.group_by(&:ref_obj_id).each_pair do |member_id, profile_answer_array|
        answers_hash[member_id] = profile_answer_array.group_by(&:profile_question_id)
      end
    end
    answers_hash
  end

  def self.members_with_role_names_and_deactivation_dates(member_ids, organization, options = {})
    return {} if member_ids.blank?

    program_ids = organization.program_ids
    role_ids = Role.where(program_id: program_ids).pluck(:id)
    program_id_program_map = Program.where(id: program_ids).includes(:translations).index_by(&:id)
    role_id_custom_term_map = CustomizedTerm.where(ref_obj_type: Role.name, ref_obj_id: role_ids).includes(:translations).index_by(&:ref_obj_id)
    sorted_program_ids = program_id_program_map.values.sort_by(&:name).map(&:id).join(",")
    sorted_role_ids = role_id_custom_term_map.values.sort_by(&:term).map(&:ref_obj_id).join(",")

    select_list = ["users.id", "users.member_id", "users.state", "users.program_id", "role_references.role_id"]
    select_list << "users.last_deactivated_at" if options[:last_deactivated_at_needed]
    order_list = "FIELD(users.program_id, #{sorted_program_ids}), FIELD(role_references.role_id, #{sorted_role_ids})"
    query = User.select(select_list).where(member_id: member_ids).joins(:role_references).order(order_list)
    self.construct_members_with_role_names_and_deactivation_dates(query, program_id_program_map, role_id_custom_term_map, options)
  end

  def self.get_groups_count_map_for_status(member_ids, status=Group::Status::ACTIVE_CRITERIA)
    Connection::Membership.
      select("users.member_id").
      joins(user: :member).
      joins(:group).
      where(groups: { status: status } ).
      where(users: { member_id: member_ids } ).
      group("users.member_id").size
  end

  def get_attending_or_unanswred_recurrent_meetings_within_time(start_time, end_time, program = nil)
    meetings_array = []
    meetings_scope = program.present? ? self.meetings.of_program(program).accepted_or_pending_meetings : self.meetings.accepted_or_pending_meetings
    meetings = meetings_scope.between_time(start_time, end_time)
    Meeting.recurrent_meetings(meetings, {get_merged_list: true, with_in_time: true, start_time: start_time, end_time: end_time})
  end

  def get_attending_recurring_meetings(recurring_meetings)
    meetings_array = []
    recurring_meetings.each do |recurring_meeting|
      member_meeting = recurring_meeting[:meeting].member_meetings.find{|mm| mm.member_id == self.id}
      meetings_array << recurring_meeting if member_meeting.get_response_object(recurring_meeting[:current_occurrence_time]).accepted?
    end
    meetings_array
  end

  def location
    self.locations.first
  end

  def active_programs_with_translations
     self.active_programs.ordered.includes(:translations).all
  end

  #-----------------------------------------------------------------------------
  # INSTANCE METHODS
  #-----------------------------------------------------------------------------
  #
  # Returns the name of the member with '(Admin)' suffix if administrator.
  #
  def name(opts = {})
    real_name = "#{first_name} #{last_name}".strip
    if !opts[:name_only] && self.admin?
      "feature.member.content.name_with_admin_term".translate(name: real_name, Administrator: self.organization.admin_custom_term.term)
    else
      real_name
    end
  end

  def language_title
    if dormant?
      AdminViewColumn::LANGUAGE_NOT_SET_DISPLAY
    else
      self.member_language.try(:organization_language).try(:title) || Language.for_english.title
    end
  end

  def member_language_id
    member_language.try(:language_id).to_i
  end

  def mentoradmin?
    email == SUPERADMIN_EMAIL
  end

  #
  # Returns a "name <email>" identifier string for the member.
  #
  def name_with_email
    "#{self.name(name_only: true)} #{AUTOCOMPLETE_EMAIL_BEGINNING}#{self.email}#{AUTOCOMPLETE_EMAIL_END}"
  end

  def password_required?
    return true if self.validate_password
    return !self.password.nil?
  end

  # Used only in migration. Encrypt existing SHA1 password to SHA2 and set the encryption_type to intermediate
  def migrate_pwd_to_intermediate
    crypted_password = Member.password_digest(self.crypted_password, self.salt, Member::EncryptionType::SHA2)
    # We should skip versioning this change and update_columns method bypasses the versioning callbacks
    self.update_columns(encryption_type: Member::EncryptionType::INTERMEDIATE, crypted_password: crypted_password)
  end

  # During login, take the plain password and encrypt to SHA2
  def encrypt_with_sha2(password)
    crypted_password = self.class.password_digest(password, self.salt, Member::EncryptionType::SHA2)
    # We should skip versioning this change and update_columns method bypasses the versioning callbacks
    self.update_columns(encryption_type: Member::EncryptionType::SHA2, crypted_password: crypted_password)
  end

  # Returns whether this member is the author of the given article.
  def authored?(article)
    self == article.author
  end

  #
  # Returns true if the member is connected with +other_member+ in any of
  # of the programs.
  #
  def connected_with?(other_member)
    (self.groups & other_member.groups).any?
  end

  #
  # Students (members) of the member.
  #
  def students(group_status = :active)
    return [] unless self.is_mentor?
    self.users.collect{|u| u.students(group_status)}.flatten.collect(&:member).uniq
  end

  #
  # Mentors (members) of the member.
  #
  def mentors(group_status = :active)
    return [] unless self.is_student?
    self.users.collect{|u| u.mentors(group_status)}.flatten.collect(&:member).uniq
  end

  #
  # Returns the programs in which the member has the permission +permission+
  #
  def programs_with_permission(permission)
    self.users.select(&:"can_#{permission}?").collect(&:program)
  end

  #
  # The programs that this member has in common with +other_member+
  #
  def common_programs_with(other_member)
    self.active_programs.ordered & other_member.active_programs.ordered
  end

  #-----------------------------------------------------------------------------
  # -- STATE MANAGEMENT
  #-----------------------------------------------------------------------------

  # Returns whether the member is active i.e., not in SUSPENDED state.
  def active?
    self.state != Status::SUSPENDED
  end

  def suspended?
    self.state == Status::SUSPENDED
  end

  def suspend!(admin, reason, send_email = true)
    return if self.suspended? || !self.can_be_removed_or_suspended?
    options = { send_email: false, global_suspension: true }
    ActiveRecord::Base.transaction do
      self.state = Status::SUSPENDED
      self.last_suspended_at = Time.current
      self.save!
      self.users.each { |user| user.suspend_from_program!(admin.get_and_cache_user_in_program(user.program), reason, options) }
    end
    ChronusMailer.member_suspension_notification(self, reason, admin).deliver_now if send_email
  end

  def self.suspend_members(member_ids, admin, reason, job_uuid)
    members = admin.organization.members.non_suspended.where(id: member_ids).includes(:users)
    JobLog.compute_with_uuid(members, job_uuid, "Bulk suspend members") do |member|
      member.suspend!(admin, reason)
    end
  end

  def has_upcoming_meeting_with?(mentee)
    meetings = Meeting.involving(self.id, mentee.id).upcoming.accepted_meetings
    upcoming_meets = Meeting.upcoming_recurrent_meetings(meetings)
    meetings_array = []
    upcoming_meets.each do |upcoming_meet|
      member_meetings = upcoming_meet[:meeting].member_meetings.where(member_id: [self.id, mentee.id])
      is_attending = true
      member_meetings.each do |member_meeting|
        is_attending = is_attending & member_meeting.get_response_object(upcoming_meet[:current_occurrence_time]).accepted_or_not_responded?
      end
      meetings_array << upcoming_meet if is_attending
    end
    meetings_array.present?
  end

  def reactivate!(admin, send_email = true)
    return unless self.suspended?
    options = { send_email: false, global_reactivation: true }
    reactivation_state = self.users.empty? ? Status::DORMANT : Status::ACTIVE
    ActiveRecord::Base.transaction do
      # Reactivate the member first, that user reactivation of globally suspended member is restricted
      self.state = reactivation_state
      self.save!
      self.users.each { |user| user.reactivate_in_program!(admin.get_and_cache_user_in_program(user.program), options) }
    end
    ChronusMailer.member_activation_notification(self).deliver_now if send_email
  end

  def self.reactivate_members(member_ids, admin, job_uuid)
    members = admin.organization.members.suspended.where(id: member_ids).includes(:users)
    JobLog.compute_with_uuid(members, job_uuid, "Bulk reactivate members") do |member|
      member.reactivate!(admin)
    end
  end

  def state_transition_allowed?(to_status)
    to_status = to_status.to_s
    from_status =  self.state.to_s

    return false if (to_status == Member::Status::SUSPENDED.to_s) && !self.can_be_removed_or_suspended?
    return Member.state_transitions_allowed[from_status] && Member.state_transitions_allowed[from_status].include?(to_status)
  end

  def self.state_transitions_allowed
    {
      Member::Status::ACTIVE.to_s => [Member::Status::SUSPENDED.to_s],
      Member::Status::DORMANT.to_s => [Member::Status::SUSPENDED.to_s],
      Member::Status::SUSPENDED.to_s => [Member::Status::ACTIVE.to_s]
    }
  end

  def has_more_answers?(offset)
    !!self.answered_qa_questions.first(:offset => offset)
  end

  #-----------------------------------------------------------------------------
  # -- MISCELLANEOUS
  #-----------------------------------------------------------------------------

  #
  # Sends the email right away if notification setting is ALL, otherwise creates
  # a pending notification.
  #
  def send_email(object, action, options = {})

    # If suspended member, notify right away, ignoring the notification setting.
    is_notif_to_suspended_member = !self.active? && action == RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION

    return if !self.active? && !is_notif_to_suspended_member

    # Deliver right away if individual emails setting,
    ChronusMailer.send(RecentActivityConstants::EmailTemplate[action], self, object, options).deliver_now
  end

  def self.send_email_change_notification(member_id, new_email, old_email, email_changer_id)
    member = Member.find_by(id: member_id)
    return if member.nil? || member.email != new_email

    member.email_changer = Member.find_by(id: email_changer_id)
    ChronusMailer.email_change_notification(member, old_email).deliver_now
  end
  #-----------------------------------------------------------------------------
  # STATE MANAGEMENT
  #-----------------------------------------------------------------------------

  def dormant?
    self.state == Status::DORMANT
  end

  #-----------------------------------------------------------------------------
  # --- PROFILE
  #-----------------------------------------------------------------------------

  # Returns the url to the profile picture of the user
  def picture_url(size, discard_image_tag = false)
    if self.profile_picture && !self.profile_picture.not_applicable?
      self.profile_picture.image.url(size)
    elsif discard_image_tag
      {image_with_initials: true}
    else
      UserConstants::DEFAULT_PICTURE[size]
    end
  end

  def picture_path_for_pdf(size)
    if Rails.env.development?
      if self.profile_picture.present? && !profile_picture.not_applicable?
        "#{Rails.root}/public#{self.picture_url(size).gsub(/\?.*/, '')}"
      else
        "#{Rails.root}/app#{self.picture_url(size).gsub(/assets/, 'assets/images')}"
      end
    else
      self.picture_url(size)
    end
  end
  #-----------------------------------------------------------------------------
  # --- ROLE MANAGEMENT
  #-----------------------------------------------------------------------------

  #
  # Promotes the member as an admin of the organization.
  #

  def promote_as_admin!
    return if self.suspended? || self.admin?

    self.admin = true
    self.save!
  end

  def administered_programs(options = {})
    if options[:include_program_translations]
      include_list = [:roles, :program => :translations]
    else
      include_list = [:roles, :program]
    end
    self.users.includes(include_list).order('programs.position ASC').select{|u| u.is_admin?}.collect{|u| u.program}
  end
  #
  # Demotes the member from being an admin of the organization.
  #
  def demote_from_admin!
    self.admin = false
    self.save!
  end

  # Fetches the organization activities to show for the member.
  def activities_to_show(opts = {})
    active_users = users.active.not_for_only_role([RoleConstants::BOARD_OF_ADVISOR_NAME]).
      includes(:groups, program: [{ organization: :enabled_db_features }, :enabled_db_features, :disabled_db_features])

    return [] unless active_users.present?
    user_conditions, user_conditions_data = [], []

    active_users.find_each do |user|
      type_conditions_str, type_conditions_data = user.ra_type_conditions
      role_conditions_str, role_conditions_data = user.ra_role_conditions

      user_conditions << "(#{[type_conditions_str, role_conditions_str].join(' AND ')})"
      user_conditions_data += type_conditions_data
      user_conditions_data += role_conditions_data
    end

    conditions_str = "(#{user_conditions.join(' OR ')})"

    # all conditions for the organization is inside conditions_str+user_conditions_data
    scope = RecentActivity.includes(:programs).references(:program).latest_first.where("ref_obj_id IS NOT NULL").
      not_of_types(org_ra_exclude_types).
      for_display.where(conditions_str, *user_conditions_data).limit(RecentActivityConstants::PER_PAGE)

    scope = scope.by_member(opts[:actor])             if opts[:actor]
    scope = scope.with_upper_offset(opts[:offset_id]) if opts[:offset_id]
    scope
  end

  def get_and_cache_user_in_program(program, all_programs = true)
    @users_in_program ||= {}
    @users_in_program[self.id] ||= (all_programs ? self.users.index_by(&:program_id) : {})
    @users_in_program[self.id][program.id] ||= self.user_in_program(program)
  end

  def user_in_program(program)
    self.users.in_program(program).first
  end

  def user_roles_in_program(program)
    self.roles.where(:program_id => program.id).pluck(:name)
  end

  # This method is used only in the context of messages / inbox. Not the admin messages
  def inbox_unread_count
    self.message_receivers.unread.select("DISTINCT message_root_id").count
  end

  #Returns the number of unread messages in a group or meeting messages
  def scrap_inbox_unread_count(group_or_meeting)
    self.message_receivers.where(message_id: group_or_meeting.scrap_ids).unread.select("DISTINCT abstract_message_receivers.message_root_id").count
  end

  def allowed_to_send_message?(other_member)
    return true if self.is_admin?
    self.common_programs_with(other_member).inject(false) do |status, program|
      status || self.user_in_program(program).allowed_to_send_message?(other_member.user_in_program(program))
    end
  end

  def can_be_removed_or_suspended?
    !self.is_chronus_admin? && self.no_owner_in_organization?
  end

  def can_remove_or_suspend?(member)
    (self != member) && self.admin? && member.can_be_removed_or_suspended?
  end

  def self.removal_or_suspension_scope(members_scope, organization, wob_member_id)
    program_owners_ids = organization.programs.pluck(:user_id)
    chronus_admin = organization.chronus_admin

    member_ids_ignored = [wob_member_id]
    member_ids_ignored += User.where(id: program_owners_ids).pluck(:member_id)
    member_ids_ignored << chronus_admin.id if chronus_admin.present?
    members_scope.where.not(id: member_ids_ignored)
  end

  def has_no_users?
    self.users.empty?
  end

  def article_manageable_programs
    self.users.select([:id, :program_id]).includes(:program).order('programs.position ASC').select{|user| user.can_manage_articles?}.collect(&:program)
  end

  def is_attending?(meeting, occurence)
    member_meeting = meeting.member_meetings.find{|mm| mm.member_id == self.id}
    member_meeting.get_response_object(occurence).accepted? if member_meeting.present?
  end

  # Marks the member as attending or nont attending based on the boolean argument
  # *attending*. When set to true, the member will be marked attending.
  def mark_attending!(meeting, options = {})
    attending = options[:attending].nil? ? MemberMeeting::ATTENDING::YES : options[:attending]
    member_meeting = self.member_meetings.find_by(meeting_id: meeting.id)
    if member_meeting.present?
      member_meeting.skip_rsvp_change_email ||= options[:skip_rsvp_change_email]
      member_meeting.perform_sync_to_calendar = options[:perform_sync_to_calendar].nil? ? true : options[:perform_sync_to_calendar]
      member_meeting.skip_mail_for_calendar_sync = options[:skip_mail_for_calendar_sync]
      member_meeting.rsvp_change_source = options[:rsvp_change_source]
      member_meeting.update_attributes!(attending: attending)
    end
  end

  def mark_attending_for_an_occurrence!(meeting, attending, current_occurrence_time, options = {})
    member_meeting = self.member_meetings.where(:meeting_id => meeting.id).first
    member_meeting_response = member_meeting.member_meeting_responses.find_or_initialize_by(meeting_occurrence_time: current_occurrence_time)
    member_meeting_response.perform_sync_to_calendar = options[:perform_sync_to_calendar].nil? ? true : options[:perform_sync_to_calendar]
    member_meeting_response.skip_mail_for_calendar_sync = options[:skip_mail_for_calendar_sync]
    member_meeting_response.rsvp_change_source = options[:rsvp_change_source]
    member_meeting_response.update_attributes!(attending: attending)
  end

  def no_owner_in_organization?
    (organization.programs.pluck(:user_id) & self.user_ids).empty?
  end

  # Returns the member's answer for the given question. Nil if empty
  def answer_for(question)
    self.profile_answers.includes(:answer_choices).for_question(question).first
  end

   # st and en are Time objects
  def get_mentoring_slots(start_time, end_time, clickable = false, score = nil, mentoring_calendar = false, mentoring_slot_self = false, is_mentoring_session_report = false, load_member = false, options={})
    men_slots = []
    mentoring_slots = options[:mentoring_slots] || self.mentoring_slots
    mentoring_slots.select { |slot| slot.start_time < end_time }.each do |slot|
      loc = slot.location.blank? ? (options[:mentor_settings_page] ? "feature.mentoring_slot.content.no_location_text".translate : "-") : slot.location
      title = "feature.calendar.content.user_available_at".translate(user: self.name, loc: loc)
      slot_start_time = slot.start_time
      slot_end_time = slot.end_time
      if slot.repeats == MentoringSlot::Repeats::NONE
        if slot_start_time >= start_time && slot_end_time <= end_time
          men_slots << (is_mentoring_session_report ? construct_mentoring_report_objects(slot, slot_start_time) :
            slot.get_json_objects(title, loc, clickable, score, mentoring_calendar, mentoring_slot_self, nil, load_member, options.slice(:check_for_expired_availability)))
        end
      elsif slot.repeats_end_date.blank? || (slot.repeats_end_date >= start_time)
        recurring_start_time = [start_time.to_date, slot_start_time.to_date].max
        recurring_end_time = (slot.repeats_end_date && end_time >= slot.repeats_end_date) ? (slot.repeats_end_date - 1.day) : end_time
        recur_opts = {:starts => recurring_start_time, :until => recurring_end_time.to_date}
        recur_opts.merge!({:recurring_slot_end_time => (slot.repeats_end_date ? (slot.repeats_end_date - 1.day) : "")}) if options[:mentor_settings_page]
        get_recurring_options!(slot, recur_opts)
        recurring_options = options[:mentor_settings_page] ? recur_opts : {}
        parse_recurrent_events(recur_opts, {show_only_first_event: options[:mentor_settings_page]}) do |event|
          men_slots << (is_mentoring_session_report ? construct_mentoring_report_objects(slot, event.to_time) :
            slot.get_json_objects(title, loc, clickable, score, mentoring_calendar, mentoring_slot_self, event, load_member, recurring_options.merge(options.slice(:check_for_expired_availability))))
        end
      end
    end
    men_slots
  end

  #This returns the availability slots hash the member has after removing the meetings booked for the mentor.
  #It also takes into account the maximum no. of hours user wants to get connected in that particular program. So, if mentor
  #has set his maximum connection hours to be 3 hours per month and he already has meetings booked for more than 3 hours, an empty
  #hash will be returned for that month(irrespective of the no. of mentoring slots he has kept in the month). Similarly, if
  #we pass the 'student' attribute, it will check if the program admin has set any limit on the no. of hours a particular student-mentor
  #pair can interact in that interval and check if the limit has been reached.
  #In the function, if either of the above two limits have been set, we calculate availability mointh-by-month for the interval and
  #return the slots accordingly.
  def get_availability_slots(start_time, end_time, program, clickable=true, score=nil, mentoring_calendar=false, student=nil, load_member = false, user = nil)
    availability = []
    user ||= self.user_in_program(program)
    if user.is_max_capacity_setting_initialized? || (student && program.is_max_capacity_student_setting_initialized?)
      start_month = start_time.month
      end_month = end_time.month
      start_year = start_time.year
      end_year = end_time.year

      #month count returns the count of months between the given start date and the end date
      #e.g., if the start date is 25 Jan, 2012  and the end date is 02 Feb, 2012, the month count will be 2.
      month_count = (end_year-start_year)*12 + (end_month - start_month) + 1
      temp_start_time = start_time
      temp_end_time = start_time
      month_count.times do
        unless user.is_meeting_capacity_reached?(temp_start_time, student)
          temp_start_time = (temp_start_time.month == start_time.month) ? start_time : temp_start_time.in_time_zone.beginning_of_month.beginning_of_day
          temp_end_time = (temp_end_time.month == end_time.month) ? end_time : temp_start_time.in_time_zone.end_of_month.end_of_day
          availability << self.get_member_availability_after_meetings(self.get_mentoring_slots(temp_start_time, temp_end_time, clickable, score, mentoring_calendar, false, false, load_member, check_for_expired_availability: true),
            temp_start_time, temp_end_time, program)
        end
        temp_start_time += 1.month
        temp_end_time += 1.month
      end
    else
      availability << self.get_member_availability_after_meetings(self.get_mentoring_slots(start_time, end_time, clickable, score, mentoring_calendar, false, false, load_member, check_for_expired_availability: true),
        start_time, end_time, program)
    end
    availability.flatten
  end

  def not_having_any_meeting_during_interval?(start_time, end_time)
    start_time = start_time.utc
    end_time = end_time.utc
    is_available = true

    meetings = self.get_attending_or_unanswred_recurrent_meetings_within_time(start_time.beginning_of_day, end_time.end_of_day)

    meetings.each do |meeting_hash|
      meeting = meeting_hash[:meeting]
      meeting_start_time = meeting_hash[:current_occurrence_time]
      meeting_end_time = meeting.occurrence_end_time(meeting_start_time)
      is_available = (end_time <= meeting_start_time) || (start_time >= meeting_end_time)
      break unless is_available
    end
    return is_available
  end

  def get_member_availability_after_meetings(mentoring_slots, start_time, end_time, program, options = {})
    meets = options[:meets] || self.get_attending_or_unanswred_recurrent_meetings_within_time(start_time.utc, end_time.utc, program)
    availability_slots = []
    mentoring_slots.each do |slot|
      slot_start_time = Member.format_time_with_time_zone(slot[:start])
      slot_end_time = Member.format_time_with_time_zone(slot[:end])
      meets.each do |recurring_meeting|
        meeting = options[:flash_meetings_only] ? recurring_meeting : recurring_meeting[:meeting]
        meeting_start_time = options[:flash_meetings_only] ? meeting.start_time : recurring_meeting[:current_occurrence_time]
        meeting_end_time = options[:flash_meetings_only] ? meeting.end_time : meeting_start_time + meeting.schedule.duration
        slot = get_valid_slot(meeting_end_time, meeting_start_time, slot_end_time, slot_start_time, slot, mentoring_slots, meeting)
        break if slot.nil?
      end
      availability_slots << slot if slot.present?
    end
    availability_slots
  end

  def get_next_available_slots(program, upper_bound_in_days = Meeting::Interval::MONTH, student = nil, start_time = nil, end_time = nil, options = {})
    current_time = Time.now.utc
    start_time = set_time_with_offset(start_time, program) if start_time
    start_time ||= (current_time + program.get_allowed_advance_slot_booking_time.hours)
    end_time ||= (start_time.next_month.end_of_month)
    availability_slots = compute_availability_slots(start_time, end_time, program, student, options)
    MentoringSlot.sort_slots!(availability_slots)
  end

  def get_meeting_slots(recurrent_meetings, profile_viewer_meeting_ids = [], viewer_member)
    men_slot = []
    recurrent_meetings.each do |rm|
      m = rm[:meeting]
      current_occurrence_time = rm[:current_occurrence_time]
      member_meeting = m.member_meetings.find{|mm| mm.member_id == self.id}
      is_self_meeting = profile_viewer_meeting_ids.include?(m.id)
      if member_meeting.present? && member_meeting.get_response_object(current_occurrence_time).accepted_or_not_responded?
        men_slot << {
          :title => is_self_meeting ? m.topic : "feature.calendar.content.user_busy_v1".translate(user: self.name),
          :start => DateTime.localize(current_occurrence_time, format: :full_date_full_time_utc),
          :end => DateTime.localize(m.occurrence_end_time(current_occurrence_time), format: :full_date_full_time_utc),
          :allDay => false,
          :dbId => m.id,
          :show_meeting_url => Rails.application.routes.url_helpers.meeting_path(m, current_occurrence_time: current_occurrence_time, root: m.program.root, outside_group: true),
          :eventMemberId => self.id,
          :className => get_calendar_event_class(m.accepted?, is_self_meeting),
          :clickable => is_self_meeting || !m.archived?(current_occurrence_time),
          :editable => false,
          :onclick_message => get_calendar_event_on_click_message(m, !is_self_meeting, self.name, viewer_member)
        }
      end
    end
    men_slot
  end

  def self.get_busy_slot_events(member, busy_slots_array, options = {})
    viewing_member = options[:viewing_member].present? ? options[:viewing_member] : member
    busy_slots_array.collect do |busy_slot|
      {
        title: "feature.calendar.content.user_busy_v1".translate(user: member.name),
        start: DateTime.localize(busy_slot[:start_time].in_time_zone(viewing_member.get_valid_time_zone), format: :full_date_full_time_cal_sync),
        end: DateTime.localize(busy_slot[:end_time].in_time_zone(viewing_member.get_valid_time_zone), format: :full_date_full_time_cal_sync),
        allDay: false,
        eventMemberId: member.id,
        className: member.get_calendar_event_class(false, false),
        clickable: false,
        editable: false,
      }
    end
  end

  def self.get_busy_slots_for_members(start_time, end_time, options = {})
    members = options[:members] || Member.where(id: options[:member_ids])
    members_by_id = members.index_by(&:id)
    busy_time = CalendarQuery.get_busy_slots_for_members(start_time, end_time, members: members, organization_wide_calendar: get_organization_wide_calendar_access_for(options[:program]))
    calendar_slot = []
    busy_time.each do |key, value|
      calendar_slot += get_busy_slot_events(members_by_id[key], value[:busy_slots], viewing_member: options[:viewing_member])
    end
    calendar_slot
  end

  def self.get_chronus_calendar_meeting_slots(start_time, end_time, options = {})
    members = options[:members] || Member.where(id: options[:member_ids])
    meeting_slots = []
    members.each do |member|
      member.get_attending_or_unanswred_recurrent_meetings_within_time(start_time, end_time).each do |slot|
        meeting_slots << slot
      end
    end
    meetings = []
    meeting_slots.each do |meeting_hash|
      meeting = meeting_hash[:meeting]
      meeting_start_time = meeting_hash[:current_occurrence_time].in_time_zone(TimezoneConstants::DEFAULT_TIMEZONE).utc
      meeting_end_time = meeting.occurrence_end_time(meeting_start_time).in_time_zone(TimezoneConstants::DEFAULT_TIMEZONE).utc
      meetings << {start_time: meeting_start_time, end_time: meeting_end_time}
    end
    meetings
  end

  def self.get_members_free_slots_after_meetings(date_str, members, options = {})
    # date_str format = "March 03, 2018"
    time_zone = options[:time_zone]
    start_date = DateTime.strptime(date_str + " " + time_zone, "#{'time.formats.full_display_no_time'.translate} #{'time.formats.time_zone'.translate}").to_time.utc
    end_date = 
      if options[:end_date_str]
        DateTime.strptime(options[:end_date_str] + " " + time_zone, "#{'time.formats.full_display_no_time'.translate} #{'time.formats.time_zone'.translate}").to_time.tomorrow.utc
      else
        start_date.tomorrow
      end
    meetings = Member.get_members_busy_times(start_date, end_date, members, options)
    meetings += Member.get_members_dnd_times(date_str, (options[:end_date_str] || date_str), members - [options[:scheduling_member]], time_zone, options)
    Member.round_off_slots(meetings)
    meetings = Member.merge_busy_slots(meetings)
    free_slots = Member.get_member_availability_after_all_meetings(meetings, start_date, end_date)
    add_mandatory_slot_to_free_slots(free_slots, options)
  end

  def self.get_members_busy_times(start_date, end_date, members, options)
    # personal calendar + chronus calendar
    meetings = CalendarQuery.get_merged_busy_slots_for_member(start_date, end_date, members: members, organization_wide_calendar: get_organization_wide_calendar_access_for(options[:program]))[:busy_slots]
    (meetings + Member.get_chronus_calendar_meeting_slots(start_date, end_date, members: members))
  end

  def self.get_members_dnd_times(start_date_str, end_date_str, members, time_zone, options)
    options[:program].enhanced_meeting_scheduler_enabled? ? Member.get_default_dnd_times(start_date_str, end_date_str, members, time_zone) : []
  end


  def self.get_default_dnd_times(start_date_str, end_date_str, members, base_time_zone)
    time_zones = members.collect(&:get_valid_time_zone).uniq
    start_date = DateTime.strptime(start_date_str + " " + base_time_zone, "#{'time.formats.full_display_no_time'.translate} #{'time.formats.time_zone'.translate}")
    end_date = DateTime.strptime(end_date_str + " " + base_time_zone, "#{'time.formats.full_display_no_time'.translate} #{'time.formats.time_zone'.translate}")
    start_date.upto(end_date).collect{ |selected_date| get_dnd_times_in_timezones(selected_date, time_zones) }.flatten
  end

  def self.get_dnd_times_in_timezones(date, time_zones)
    beginning_of_day = date.beginning_of_day
    end_of_day = date.tomorrow
    time_zones.map do |time_zone|
      [get_default_dnd_time(beginning_of_day.in_time_zone(time_zone)),
       get_default_dnd_time(end_of_day.in_time_zone(time_zone))]
    end.flatten
  end

  def self.get_default_dnd_time(date)
    do_not_disturb_times = 
    if date.saturday? || date.sunday?
      DoNotDisturbTimes::WEEKEND
    else
      DoNotDisturbTimes::WEEKDAY
    end
    do_not_disturb_times.collect{|dnd_hash| get_dnd_hash(dnd_hash, date)}
  end

  def self.get_dnd_hash(dnd_hash, date)
    {
      start_time: Member.get_formatted_dnd_time(date, dnd_hash[:start_time]),
      end_time: Member.get_formatted_dnd_time(date, dnd_hash[:end_time])
    }
  end

  def self.get_formatted_dnd_time(date, time_hash)
    DateTime.new(date.year, date.month, date.day, time_hash[:hour], time_hash[:min], time_hash[:sec], date.time_zone.formatted_offset).utc
  end

  def self.add_mandatory_slot_to_free_slots(free_slots, options)
    options[:mandatory_times].present? ? Member.merge_busy_slots(free_slots + options[:mandatory_times], true) : free_slots
  end

  def self.get_organization_wide_calendar_access_for(program)
    return false unless program.present?
    program.organization_wide_calendar_access_enabled?
  end
  def self.get_member_availability_after_all_meetings(meetings_hash, start_date, end_date)
    # meetings_hash format = [{start_time: , end_time: }, {start_time: , end_time: }]
    # works only when the meetings_hash is sorted by start time
    mentoring_slots = []
    slot = {start: start_date, end: end_date}
    meetings_hash.each do |meeting|
      slot_start_end_time_hash = {}
      slot_start_end_time_hash[:start] = slot[:start]
      slot_start_end_time_hash[:end] = slot[:end]
      slot = get_free_slot(meeting, slot_start_end_time_hash, slot, mentoring_slots)
      break if slot.nil?
    end
    mentoring_slots << slot if slot.present?
    mentoring_slots
  end

  def self.merge_busy_slots(slots, free_slot_hash_format = false)
    return [] if slots.empty?
    start_time = free_slot_hash_format ? :start : :start_time
    end_time = free_slot_hash_format ? :end : :end_time
    slots.sort!{|slot1, slot2| slot1[start_time] <=> slot2[start_time]}
    busy_slots = []
    busy_slots << slots.shift
    slots.each do |slot|
      busy_interval = busy_slots.last
      if busy_interval[end_time] < slot[start_time]
        busy_slots << slot
      elsif busy_interval[end_time] < slot[end_time]
        busy_interval[end_time] = slot[end_time]
      end
    end
    busy_slots
  end

  def self.get_free_slot(meeting_hash, slot_hash, slot, mentoring_slots)

    return nil if meeting_larger_than_slot?(meeting_hash, slot_hash)

    meeting_left_overlap_slot(meeting_hash, slot_hash, slot)

    meeting_right_overlap_slot(meeting_hash, slot_hash, slot)

    meeting_smaller_inside_slot(meeting_hash, slot_hash, slot, mentoring_slots)

    slot
  end

  def self.meeting_larger_than_slot?(meeting, slot_hash)
    #Case: 0
    #M:  |------------|
    #S:    |--------|
    meeting[:end_time] >= slot_hash[:end] && meeting[:start_time] <= slot_hash[:start]
  end

  def self.meeting_left_overlap_slot(meeting, slot_hash, slot)
    #Case: 1
    #M: |-----|
    #S:   |-----|
    if meeting[:end_time] <= slot_hash[:end] && meeting[:start_time] < slot_hash[:start] && meeting[:end_time] > slot_hash[:start]
      slot[:start] = meeting[:end_time]
    end
  end

  def self.meeting_right_overlap_slot(meeting, slot_hash, slot)
    #Case: 2
    #M:   |-----|
    #S: |-----|
    if slot_hash[:start] <= meeting[:start_time] && meeting[:start_time] < slot_hash[:end] && slot_hash[:end] < meeting[:end_time]
      slot[:end] = meeting[:start_time]
    end
  end

  def self.meeting_smaller_inside_slot(meeting, slot_hash, slot, mentoring_slots)
    #Case: 3
    #M:   |-----|
    #S: |---------|
    if meeting[:end_time] <= slot_hash[:end] && meeting[:start_time] >= slot_hash[:start]
      if (meeting[:end_time] == slot_hash[:end])
        slot[:end] = meeting[:start_time]
      elsif (meeting[:start_time] == slot_hash[:start])
        slot[:start] = meeting[:end_time]
      else
        new_slot = slot.dup
        slot[:start] = meeting[:end_time]
        new_slot[:end] = meeting[:start_time]
        mentoring_slots.push(new_slot)
      end
    end
  end

  def has_availability_between?(program, start_time, end_time, student=nil, options = {})
    return true unless self.will_set_availability_slots?
    start_time = set_time_with_offset(start_time, program) unless options[:with_offset]
    clickable = true
    score = options[:score]
    mentoring_calendar = false
    load_member = options[:load_member].present?
    user = options[:mentor_user] || self.user_in_program(program)
    if user.is_max_capacity_setting_initialized? || (student && program.is_max_capacity_student_setting_initialized?)
      start_month = start_time.month
      end_month = end_time.month
      start_year = start_time.year
      end_year = end_time.year
      month_count = (end_year-start_year)*12 + (end_month - start_month) + 1
      temp_start_time = start_time
      temp_end_time = [start_time.in_time_zone.end_of_month, end_time].min
      month_count.times do
        availability = []
        unless user.is_meeting_capacity_reached?(temp_start_time, student)
          mentoring_slots = self.get_mentoring_slots(temp_start_time, temp_end_time, clickable, score, mentoring_calendar, false, false, load_member)
          availability << self.get_member_availability_after_meetings(mentoring_slots, temp_start_time, temp_end_time, program)
        end
        return true if valid_availability_slot_present?(program, availability.flatten)
        temp_start_time = [start_time, temp_start_time.in_time_zone.beginning_of_month + 1.month].max
        temp_end_time = [end_time.in_time_zone.end_of_month + 1.month, end_time].min
      end
    else
      availability = self.get_member_availability_after_meetings(self.get_mentoring_slots(start_time, end_time, clickable, score, mentoring_calendar, false, false, load_member),
        start_time, end_time, program)
      return true if valid_availability_slot_present?(program, availability.flatten)
    end
    false
  end

  def available_slots(program, start_time, end_time, student=nil)
    available_slots = self.get_availability_slots(start_time, end_time, program, true, nil, false, student)
    available_slots.size
  end

  def not_connected_for?(num_of_days, program)
    current_time = Time.now.utc
    start_time = (current_time - num_of_days.days)
    meetings = self.meetings.of_program(program)
    self.get_attending_recurring_meetings(Meeting.recurrent_meetings(meetings, {get_occurrences_between_time: true, start_time: start_time.beginning_of_day, end_time: current_time.end_of_day, get_merged_list: true})).empty?
  end

  def enable_api!
    self.generate_key!(:api_key)
  end

  def enable_calendar_ics_api!
    self.generate_key!(:calendar_api_key)
  end

  def set_calendar_api_key
    self.calendar_api_key = secure_digest(Time.now, (1..10).map{ rand.to_s })
  end

  def disable_api!
    self.update_attribute(:api_key, "")
  end

  def api_is_enabled?
    !self.api_key.empty?
  end

  def get_locations
    slot_locations = self.mentoring_slots.where(["location IS NOT NULL AND location != ''"]).distinct.pluck(:location)
    meeting_locations = self.meetings.where(["location IS NOT NULL AND location != ''"]).distinct.pluck(:location)
    return (slot_locations + meeting_locations).uniq
  end

  def full_time_zone
    ActiveSupport::TimeZone.new(self.get_valid_time_zone).to_s
  end

  ## Methods related to the account lock out feature
  def login_attempts_exceeded?
    self.failed_login_attempts > self.organization.security_setting.maximum_login_attempts
  end

  def increment_login_counter!
    if self.organization.login_attempts_enabled?
      self.failed_login_attempts += 1
      self.save!
    end
  end

  def reset_login_counter!
    self.update_attributes!(:failed_login_attempts => 0)
  end

  def account_lockout!(force_lockout = false)
    params = {:account_locked_at => Time.now.utc}
    params.merge!(:failed_login_attempts => self.organization.security_setting.maximum_login_attempts + 1) if force_lockout
    self.update_attributes!(params)
  end

  def send_reactivation_email(account_lockout = true)
    password = Password.create!(:email => self.email, :member => self)
    ChronusMailer.send(account_lockout ? "reactivate_account" : "password_expiry_notification", password,
      self.organization, :force_send => true).deliver_now
  end

  def can_reactivate_account?
    if organization.login_attempts_enabled? && self.account_locked_at.present?
      self.organization.auto_reactivate_enabled? ? ((self.account_locked_at + self.organization.security_setting.auto_reactivate_account.hours) < Time.now.utc) : false
    else
      true
    end
  end

  def reactivate_account!(validate = true)
    handle_reactivate_account!(validate) if self.organization.login_attempts_enabled?
  end

  def handle_reactivate_account!(validate = true)
    if validate
      self.reset_login_counter!
      self.update_attributes!(:account_locked_at => nil)
    else
      self.update_attributes(:account_locked_at => nil, :failed_login_attempts => 0)
    end
  end

  def password_expired?
    return false if !self.organization.password_auto_expire_enabled? || self.is_chronus_admin?
    expiration_frequency = self.organization.security_setting.password_expiration_frequency
    return (self.password_updated_at + expiration_frequency.days) < Time.now.utc
  end

  def update_password_timestamp!
    self.update_attributes!(:password_updated_at => Time.now.utc)
  end

  def articles_enabled_programs
    self.active_programs.includes(:organization, :disabled_db_features, :enabled_db_features).select(&:articles_enabled?)
  end

  def qa_enabled_programs
    self.active_programs.includes(:organization, :disabled_db_features, :enabled_db_features).select(&:qa_enabled?)
  end

  def articles_enabled?
    self.articles_enabled_programs.any?
  end

  def qa_enabled?
    self.qa_enabled_programs.any?
  end

  def is_chronus_admin?
    self.email == SUPERADMIN_EMAIL && self.admin?
  end

  def accessible_programs_for(cur_member)
    common_programs = self.common_programs_with(cur_member)
    accessible_programs = []
    common_programs.each do |program|
      user = self.user_in_program(program)
      cur_user = cur_member.user_in_program(program)
      accessible_programs << program if user.visible_to?(cur_user)
    end
    accessible_programs
  end

  def fetch_or_create_password(update_expiration = true)
    password = self.passwords.last || Password.create!(:member => self)
    if update_expiration
      password.expiration_date = 6.months.from_now
      password.save!
    end
    password
  end

  def ask_to_set_availability?
    self.can_set_availability? && self.will_set_availability_slots?
  end

  def remove_answers_from_unanswerable_questions
    self.profile_answers.where("profile_question_id NOT IN (?)", answerable_profile_questions.collect(&:id)).destroy_all
  end

  def terms_and_conditions_accepted?
    !terms_and_conditions_accepted.nil?
  end

  def accept_terms_and_conditions!
    update_attribute(:terms_and_conditions_accepted, Time.zone.now) unless terms_and_conditions_accepted?
  end

  def can_update_password?
    !(self.organization.password_history_enabled? && is_an_existing_password?)
  end

  def is_an_existing_password?
    # Check the previous passwords only if password_history limit is greater than 0
    return false if self.organization.security_setting.password_history_limit.blank? || self.organization.security_setting.password_history_limit == 0
    # existing_passwords includes the current password and the past password_history_limit-1 passwords
    old_passwords = get_past_passwords(self.organization.security_setting.password_history_limit - 1) + [self.crypted_password]
    # old passwords may be encrypted with sha1 or sha2 or intermediate. Seperate them based on the size of the encryption.
    old_sha1_passwords, old_sha2_passwords = old_passwords.partition { |p| p.blank? || p.size == 40 }
    sha1_crypted_password = Member.sha1_digest(self.password, self.salt)
    sha2_crypted_password = Member.sha2_digest(self.password, self.salt)
    intermediate_password = Member.sha1_sha2_digest(self.password, self.salt)
    # old_sha2_passwords may also contain the password in intermediate state (sha1+sha2 encrypted).So we also compare old_sha2_passwords with intermediate password.
    old_sha1_passwords.include?(sha1_crypted_password) || old_sha2_passwords.include?(sha2_crypted_password) || old_sha2_passwords.include?(intermediate_password)
  end

  def update_attribute_skipping_observer(attribute, value)
    self.skip_observer = true
    self.update_attribute(attribute, value)
    self.skip_observer = false
  end

  def visible_to?(other_member)
    return true if self.admin? || other_member.admin?

    self.common_programs_with(other_member).any? do |program|
      self.user_in_program(program).visible_to?(other_member.user_in_program(program))
    end
  end

  def prevent_matching_enabled?
    self.programs.any?{|p| p.prevent_manager_matching && p.matching_enabled?}
  end

  def prevent_manager_matching_level
    levels =  self.programs.collect{|p| p.manager_matching_level if p.prevent_manager_matching && p.matching_enabled?}.compact
    levels.include?(-1) ? -1 : levels.max
  end

  # TODO: mobile_v2
  # After mobile_v1 is deprecated completely, modify this method to update only device_token and remove mobile_auth_token column from mobile_devices
  def set_mobile_access_tokens!(device_token = nil, mobile_auth_token = nil, platform = MobileDevice::Platform::IOS)
    mobile_auth_token.present? ? mobile_devices.where(mobile_auth_token: mobile_auth_token, platform: platform).first : mobile_devices.create!(device_token: device_token, mobile_auth_token: secure_digest(Time.now, (1..10).map{ rand.to_s }), platform: platform)
  end

  def set_mobile_access_tokens_v2!(device_token, mobile_auth_token, platform)
    return if device_token.blank? || mobile_auth_token.blank? || platform.blank?
    device = mobile_devices.where(mobile_auth_token: mobile_auth_token, platform: platform).first
    device.present? ? device.update_attributes!(device_token: device_token) : mobile_devices.create!(device_token: device_token, mobile_auth_token: mobile_auth_token, platform: platform)
  end

  # start_time - expects a time object eg. Time.now.beginning_of_day
  def self.set_time_with_offset(start_time, program)
    current_time = Time.now.utc
    offset = current_time - current_time.beginning_of_day
    start_time += offset
    if start_time < (current_time + program.get_allowed_advance_slot_booking_time.hours)
      start_time = current_time + program.get_allowed_advance_slot_booking_time.hours
    end
    return start_time
  end

  def manager
    self.profile_answers.includes(:profile_question).find{|a| a.profile_question.manager? }.try(:manager)
  end

  def save_answer!(question, answer_text, options = {})
    ProfileAnswer.transaction do
      # Find out if the member has already answered the question or create a new answer
      profile_answer = self.get_answer_for(question)
      profile_answer.save_answer!(question, answer_text, nil, options)
    end
  end

  def is_eligible_to_join?(roles)
    is_eligible = true
    eligible_to_join_directly = nil
    roles.each do |role|
      if role.eligibility_rules && role.program.membership_eligibility_rules_enabled?
        is_eligible = is_eligible && (role.admin_view.nil? || role.admin_view.generate_organization_view(nil, nil, nil, {member_ids: [self.id], only_profile_filters: true}, {}).include?(self.id))
        eligible_to_join_directly = eligible_to_join_directly.nil? ? is_eligible : (eligible_to_join_directly && is_eligible)
      else
        eligible_to_join_directly = false
      end
    end
    eligible_to_join_directly = false if eligible_to_join_directly.nil?
    return is_eligible, eligible_to_join_directly
  end

  def can_modify_eligibility_details?(roles)
    can_modify_eligibility_details = nil
    roles.each do |role|
      can_modify_eligibility_details = can_modify_eligibility_details || role.can_member_modify_eligibility_details?
    end
    return can_modify_eligibility_details.nil? ? true : can_modify_eligibility_details
  end

  # TODO: Refactor
  # Adding users manually, profile updation can also use this method
  def update_answers(profile_questions, question_id_answer_map, membership_request = nil, is_new_member = false, is_pending_or_admin_view = false, params = {})
    is_success = true
    from_import = (params && params.delete(:from_import)) || false
    question_id_answer_map = question_id_answer_map.presence || {}
    member_question_id_answer_map = self.profile_answers.includes(:answer_choices).index_by(&:profile_question_id)

    # handling of deleted files
    if params[:persisted_files].present?
      params[:persisted_files].select { |_, v| v == "0" }.each do |question_id, _|
        # set to blank only if removed file is not replaced
        question_id_answer_map[question_id] ||= ""
      end
    end

    question_id_answer_map.each do |question_id, answer|
      begin
        question_id = question_id.to_i
        profile_question = profile_questions.find { |pq| pq.id == question_id }
        next if profile_question && profile_question.handled_after_check_for_conditional_question_applicability?(self)
        special_question_params = [profile_question, answer, membership_request, is_pending_or_admin_view, is_new_member]
        saved_successfully = if profile_question.education?
          self.update_education_answers(*special_question_params)
        elsif profile_question.experience?
          self.update_experience_answers(*special_question_params)
        elsif profile_question.publication?
          self.update_publication_answers(*special_question_params)
        elsif profile_question.manager?
          self.update_manager_answers(*special_question_params)
        else
          profile_answer = member_question_id_answer_map[question_id] || self.profile_answers.build(profile_question_id: profile_question.id)
          profile_answer.user_or_membership_request = membership_request
          if profile_question.file_type?
            file_member_id = is_new_member ? "new" : self.id
            file_code = params["question_#{question_id}_code"] || "empty"
            path_to_file = FileUploader.get_file_path(question_id, file_member_id, ProfileAnswer::TEMP_BASE_PATH, { code: file_code, file_name: answer })
            if path_to_file
              profile_answer.assign_file_name_and_code(answer, file_code)
              File.open(path_to_file, "rb") { |file_stream| profile_answer.answer_value = file_stream }
            else
              profile_answer.answer_value = nil
            end
            profile_answer.save!
          else
            profile_answer.save_answer!(profile_question, answer, nil, from_import: from_import)
          end
        end
        profile_question.update_dependent_questions(self) if saved_successfully
      rescue => e
        is_success = false
      end
    end
    return is_success
  end

  def update_education_answers(question, values, user_or_membership_request = nil, is_pending_or_admin_view = false, is_new_member = false)
    unless is_new_member
      answer = self.answer_for(question)
      answer.try(:handle_existing_education_answers, values["existing_education_attributes"])
    end
    new_edu_attributes = values["new_education_attributes"].present? ? (values["new_education_attributes"].collect(&:values).flatten) : []
    answer = self.get_answer_for(question, is_new_member)
    answer.build_new_education_answers(new_edu_attributes)
    answer.user_or_membership_request = user_or_membership_request if user_or_membership_request.present?
    is_pending_or_admin_view ? answer.save : answer.save!
  end

  def update_experience_answers(question, values, user_or_membership_request = nil, is_pending_or_admin_view = false, is_new_member = false)
    unless is_new_member
      answer = self.answer_for(question)
      answer.try(:handle_existing_experience_answers, values["existing_experience_attributes"])
    end
    new_exp_attributes = values["new_experience_attributes"].present? ? (values["new_experience_attributes"].collect(&:values).flatten) : []
    answer = self.get_answer_for(question, is_new_member)
    answer.build_new_experience_answers(new_exp_attributes)
    answer.user_or_membership_request = user_or_membership_request if user_or_membership_request.present?
    is_pending_or_admin_view ? answer.save : answer.save!
  end

  def update_publication_answers(question, values, user_or_membership_request = nil, is_pending_or_admin_view = false, is_new_member = false)
    unless is_new_member
      # If values isn't hash then question added to basic section
      answer = self.answer_for(question)
      answer.try(:handle_existing_publication_answers, values["existing_publication_attributes"])
    end
    new_publication_attributes = values["new_publication_attributes"].present? ? values["new_publication_attributes"].map{|attrs| attrs.values.first.is_a?(Hash) ? attrs.values : attrs}.flatten : []
    answer = self.get_answer_for(question, is_new_member)
    answer.build_new_publication_answers(new_publication_attributes)
    answer.user_or_membership_request = user_or_membership_request if user_or_membership_request.present?
    is_pending_or_admin_view ? answer.save : answer.save!
  end

  def update_manager_answers(question, values, user_or_membership_request = nil, is_pending_or_admin_view = false, is_new_member = false)
    unless is_new_member
      # If values isn't hash then question added to basic section
      answer = self.answer_for(question)
      answer.try(:handle_existing_manager_answers, values["existing_manager_attributes"])
    end
    new_manager_attributes = values["new_manager_attributes"].present? ? values["new_manager_attributes"] : []
    answer = self.get_answer_for(question, is_new_member)
    answer.build_new_manager_answers(new_manager_attributes)
    answer.user_or_membership_request = user_or_membership_request if user_or_membership_request.present?
    is_pending_or_admin_view ? answer.save : answer.save!
  end

  def self.transition_global_suspensions_to_program(member_ids = [])
    suspended_members = Member.suspended.where(id: member_ids)
    return unless suspended_members.present?

    suspended_member_users = User.suspended.where(member_id: suspended_members.pluck(:id))
    ActiveRecord::Base.transaction do
      suspended_member_users.where("track_reactivation_state IS NULL").update_all("track_reactivation_state = global_reactivation_state")
      suspended_member_users.update_all("global_reactivation_state = NULL")
      suspended_members.update_all("state = #{Member::Status::ACTIVE}")
    end
  end

  def get_invalid_profile_answer_details
    details = []
    self.profile_answers.each do |profile_answer|
      profile_question = profile_answer.profile_question
      profile_answer.ref_obj = self
      unless profile_answer.valid?
        details << {
          id: profile_question.id.to_s,
          message: profile_answer.errors.full_messages.join(" ,"),
          type: profile_question.question_type
        }
      end
    end
    if details.present?
      logger_message = "Invalid answer: #{details.collect { |detail| detail.values.join(' - ') }.join(';')}"
      respond_to?(:logger) ? logger.error(logger_message) : (puts logger_message)
    end
    details
  end

  def can_show_browser_warning?
    return true unless self.browser_warning_shown_at
    return (Time.now.to_i - self.browser_warning_shown_at.to_i)/(24*60*60) >= SHOW_WARNING_INTERVAL_DAYS
  end

  def sign_out_of_other_sessions(current_session_id, remember_me_cookie, mobile_auth_token)
    self.forget_me if self.remember_token.present? && self.remember_token != remember_me_cookie

    mobile_logins = self.mobile_devices
    mobile_logins = mobile_logins.where("mobile_auth_token != ?", mobile_auth_token) if mobile_auth_token.present?
    mobile_logins.destroy_all

    other_sessions = ActiveRecord::SessionStore::Session.where(member_id: self.id).where("session_id != ?", current_session_id)
    other_sessions.destroy_all
  end

  def get_attending_and_not_responded_meetings(meetings)
    meetings.select { |meeting| meeting[:meeting].any_attending?(meeting[:current_occurrence_time], [self.id]) }
  end

  def get_not_responded_meetings(meetings)
    meetings.select do |meeting|
      member_meeting = meeting[:meeting].member_meetings.find { |member_meeting| member_meeting.member_id == self.id }
      member_meeting.get_response_object(meeting[:current_occurrence_time]).not_responded?
    end
  end

  def get_upcoming_not_responded_meetings_count(program, group = nil)
    meetings = group.present? ? Meeting.upcoming_recurrent_meetings(self.meetings.of_group(group)) : Meeting.upcoming_recurrent_meetings(Meeting.get_meetings_for_view(nil, nil, self, program, {from_my_availability: true}))
    self.get_not_responded_meetings(meetings).size
  end

  def self.es_reindex(member, options = {})
    member_ids = Array(member).collect(&:id)
    return if member_ids.empty?
    user_ids = User.where(member_id: member_ids).pluck(:id)
    DelayedEsDocument.delayed_bulk_update_es_documents(User, user_ids) if options[:reindex_user] || options.blank?
    self.reindex_member_meeting(member_ids, options)
    self.reindex_mentor_request(user_ids, options)
    self.reindex_project_request(user_ids, options)
    self.reindex_survey_assessee(member_ids, options)
    self.reindex_qa_question(user_ids, options)
    self.reindex_group(user_ids, options)
    self.reindex_article(member_ids, options)
    self.reindex_topic(user_ids, options)
  end

  def get_active_or_closed_groups_count(status)
    self.users.inject(0) { |count, user|  count + user.groups.select {|group| Array(status).include?(group.status) }.size }
  end

  def closed_engagements_count # closed_groups_count
    self.get_active_or_closed_groups_count(Group::Status::CLOSED)
  end

  def ongoing_engagements_count # ongoing_groups_count
    self.get_active_or_closed_groups_count(Group::Status::ACTIVE_CRITERIA)
  end

  def total_engagements_count
    self.closed_engagements_count + self.ongoing_engagements_count
  end

  def synced_external_calendar?
    o_auth_credentials.size > 0
  end

  def show_one_time_settings?(program)
    !(program.calendar_sync_v2_enabled? && synced_external_calendar?)
  end

  def can_signin?
    self.auth_configs.exists?
  end

  def allow_password_update?
    self.crypted_password.present? && self.organization.chronus_auth.present?
  end

  def login_identifiers_for_custom_auths
    custom_auth_config_ids = self.organization.get_and_cache_custom_auth_config_ids

    if self.login_identifiers.loaded?
      self.login_identifiers.select { |login_identifier| login_identifier.auth_config_id.in?(custom_auth_config_ids) }
    else
      self.login_identifiers.where(auth_config_id: custom_auth_config_ids)
    end
  end

  def build_login_identifiers_for_custom_auths(identifier)
    return if identifier.blank?

    custom_auth_config_ids = self.organization.get_and_cache_custom_auth_config_ids
    custom_login_identifiers = self.login_identifiers_for_custom_auths
    default_login_identifiers = self.login_identifiers - custom_login_identifiers
    custom_login_identifiers_map = custom_login_identifiers.index_by(&:auth_config_id)

    updated_custom_login_identifiers =
      custom_auth_config_ids.map do |custom_auth_config_id|
        login_identifier = custom_login_identifiers_map[custom_auth_config_id] || self.login_identifiers.build(auth_config_id: custom_auth_config_id)
        login_identifier.identifier = identifier
        login_identifier
      end
    self.login_identifiers = default_login_identifiers + updated_custom_login_identifiers
  end

  def activate_from_dormant
    return unless self.dormant?

    self.state = Member::Status::ACTIVE
    self.created_at = Time.now
  end

  def get_calendar_event_class(accepted_meeting, is_self_meeting)
    if !is_self_meeting
      "non_self_meetings"
    else
      accepted_meeting ? "meetings" : "requested_meetings"
    end
  end

  def show_admin_dashboard?(recent_activities_view = false)
    admin? || (track_level_admin? && !recent_activities_view)
  end

  def admin_only_at_track_level?
    !admin? && track_level_admin?
  end

  def track_level_admin?
    managing_programs.count > 0
  end

  def managing_programs(options = {})
    managing_program_ids = users.includes(:roles).select(&:is_admin?).collect(&:program_id)
    return managing_program_ids if options[:ids_only]
    Program.includes(:translations).where(id: managing_program_ids)
  end

  def programs_to_add_users
    return organization.programs if admin?
    users.includes(:roles).any?(&:import_members_from_subprograms?) ? organization.programs : managing_programs
  end
  
  def most_recent_user
    self.users.order(last_seen_at: :desc)[0]
  end

  def get_recently_visited_program_from_activity_log
    user_ids = self.users.pluck(:id) 
    recently_visited_program_activity_log = ActivityLog.program_visits.where(user_id: user_ids).order(created_at: :desc).first
    recently_visited_program = recently_visited_program_activity_log.try(:program) || self.programs.first
  end
  
  def create_login_token_and_send_email(uniq_token)
    login_token = self.login_tokens.new
    ChronusMailer.mobile_app_login(self, login_token, uniq_token).deliver_now if login_token.save! && self.organization.mobile_view_enabled? && self.programs.count > 0
  end

  def send_report_alert(programs, program_alerts_hash)
    if programs.size == 1
      program = programs.first
      return unless program_alerts_hash[program].present?
      ChronusMailer.program_report_alert(self.user_in_program(program), program_alerts_hash[program]).deliver_now
    else
      sliced_program_alerts_hash = program_alerts_hash.slice(*programs)
      return unless sliced_program_alerts_hash.present?
      ChronusMailer.organization_report_alert(self, sliced_program_alerts_hash).deliver_now
    end
  end

  protected

  def get_answer_for(question, is_new_member = false)
    (!is_new_member && (answer = self.answer_for(question)).present?) ? answer : self.profile_answers.build(profile_question: question)
  end

  def secure_digest(*args)
    Digest::SHA1.hexdigest(args.flatten.join('--'))
  end

  def generate_key!(key_type)
    self.update_attribute(key_type, secure_digest(Time.now, (1..10).map{ rand.to_s }))
  end

  private

  def self.reindex_member_meeting(member_ids, options)
    return unless (options[:reindex_member_meeting] || options.blank?)
    member_meeting_ids = MemberMeeting.where(member_id: member_ids).pluck(:meeting_id)
    DelayedEsDocument.delayed_bulk_update_es_documents(Meeting, member_meeting_ids)
  end

  def self.reindex_mentor_request(user_ids, options)
    return unless (options[:reindex_mentor_request] || options.blank?)
    mentor_request_ids = MentorRequest.where("sender_id IN (?) OR receiver_id IN (?)",  user_ids, user_ids).pluck(:id)
    DelayedEsDocument.delayed_bulk_update_es_documents(MentorRequest, mentor_request_ids)
  end

  def self.reindex_project_request(user_ids, options)
    return unless (options[:reindex_project_request] || options.blank?)
    project_request_ids = ProjectRequest.where(sender_id: user_ids).pluck(:id)
    DelayedEsDocument.delayed_bulk_update_es_documents(ProjectRequest, project_request_ids)
  end

  def self.reindex_survey_assessee(member_ids, options)
    return unless (options[:reindex_survey_assessee] || options.blank?)
    survey_assessee_ids = ThreeSixty::SurveyAssessee.where(member_id: member_ids).pluck(:id)
    DelayedEsDocument.delayed_bulk_update_es_documents(ThreeSixty::SurveyAssessee, survey_assessee_ids)
  end

  def self.reindex_qa_question(user_ids, options)
    return unless (options[:reindex_qa_question] || options.blank?)
    qa_answer_ids = QaAnswer.where(user_id: user_ids).pluck(:qa_question_id).uniq
    qa_question_ids = QaQuestion.where("id IN (?) OR user_id IN (?)", qa_answer_ids, user_ids).pluck(:id)
    DelayedEsDocument.delayed_bulk_update_es_documents(QaQuestion, qa_question_ids)
  end

  def self.reindex_group(user_ids, options)
    return unless (options[:reindex_group] || options.blank?)
    group_ids = Group.where(created_by: user_ids).pluck(:id)
    group_ids += Connection::Membership.where(user_id: user_ids).pluck(:group_id)
    DelayedEsDocument.delayed_bulk_update_es_documents(Group, group_ids)
  end

  def self.reindex_article(member_ids, options)
    return unless (options[:reindex_article] || options.blank?)
    article_ids = Article.where(author_id: member_ids).published.pluck(:id)
    DelayedEsDocument.delayed_bulk_update_es_documents(Article, article_ids)
  end

  def self.reindex_topic(user_ids, options)
    return unless (options[:reindex_topic] || options.blank?)
    topic_ids = Topic.where(user_id: user_ids).pluck(:id)
    DelayedEsDocument.delayed_bulk_update_es_documents(Topic, topic_ids)
  end


  def self.construct_members_with_role_names_and_deactivation_dates(query, program_id_program_map, role_id_custom_term_map, options)
    user_program_roles_hashes = User.connection.select_all(query)
    user_program_roles_hashes.inject({}) do |result, user_program_roles_hash|
      state = user_program_roles_hash["state"]
      member_id = user_program_roles_hash["member_id"]
      program_name = program_id_program_map[user_program_roles_hash["program_id"].to_i].name
      role_id = user_program_roles_hash["role_id"].to_i
      role_term = role_id_custom_term_map[role_id].term

      result[member_id] ||= {}
      result[member_id][program_name] ||=
        if options[:only_suspended_status]
          { "user_suspended" => (state == User::Status::SUSPENDED), "roles" => [] }
        else
          { "status" => state, "roles" => [] }
        end

      result[member_id][program_name]["roles"] << (options[:role_ids_needed] ? "#{role_term}#{UNDERSCORE_SEPARATOR}#{role_id}" : role_term)
      result[member_id][program_name]["last_deactivated_at"] = user_program_roles_hash['last_deactivated_at'] if options[:last_deactivated_at_needed]
      result
    end
  end

  def get_calendar_event_on_click_message(meeting, non_self_meeting, mentor_name, viewer_member)
    if non_self_meeting
      "feature.calendar.content.busy_message".translate(user: mentor_name)
    elsif !meeting.accepted?
      "feature.calendar.content.pending_request_slot_message".translate
    end
  end

  def permitted_params(params, action)
    return params unless params.is_a?(ActionController::Parameters)
    params.permit(MASS_UPDATE_ATTRIBUTES[action])
  end

  # start_time - expects a time object eg. Time.now.beginning_of_day
  def set_time_with_offset(start_time, program)
    Member.set_time_with_offset(start_time, program)
  end

  def valid_availability_slot_present?(program, availability_slots)
    get_valid_availability_slots(program, availability_slots).present?
  end

  def get_valid_availability_slots(program, availability_slots)
    availability_slots.each do |availability_slot|
      availability_slots -= [availability_slot] if (availability_slot[:end].to_datetime.to_i - availability_slot[:start].to_datetime.to_i) < program.get_calendar_slot_time.minutes
    end
    availability_slots
  end

  def compute_availability_slots(start_time, end_time, program, student = nil, options = {})
    availability_slots = self.get_availability_slots(start_time, end_time, program, true, options[:score], false, student, options[:load_member].present?, options[:mentor_user])
    get_valid_availability_slots(program, availability_slots)
  end

  def check_educations_must_be_valid
    # Custom error message for educations
    unless educations.map(&:valid?).all? # all? is called later to ensure valid? is called on all educations
      errors[:base] << "activerecord.custom_errors.member.invalid_educations".translate
    end
  end

  def check_experiences_must_be_valid
    # Custon error message for experiences
    unless experiences.map(&:valid?).all? # all? is called later to ensure valid? is called on all experiences
      errors[:base] << "activerecord.custom_errors.member.invalid_experiences".translate
    end
  end

  def custom_password_auth
    unless self.is_chronus_admin?
      check_password_regex
      validate_with_login_name_and_email
    end
  end

  def check_valid_email
    unless ValidatesEmailFormatOf::validate_email_format(self.email, check_mx: false).nil?
      errors[:email] << RegexConstants::MSG_EMAIL_BAD.translate
    end
  end

  def check_indigenous_login_identifier
    return if self.crypted_password.blank? || self.organization.blank?

    unless LoginIdentifier.exists?(auth_config_id: self.organization.chronus_auth(true).id, member_id: self.id)
      self.errors.add(:password, "activerecord.custom_errors.member.invalid_current_password".translate)
    end
  end

  #
  # Security Setting related methods
  #

  def check_password_regex
    auth_config = self.organization.chronus_auth
    if self.password_required? && auth_config.try(:regex_string).present?
      is_regex_match = self.password.regex_scan?(auth_config.regex_string)
      unless is_regex_match
        errors.delete(:password)
        errors.add(:password, "activerecord.custom_errors.member.invalid_current_password".translate)
      end
    end
  end

  def validate_with_login_name_and_email
    security_setting = self.organization.security_setting
    # Here the presence of security_setting is checked, as in registrations_controller we create
    # member object and organization, so member is validated before the organization is created,
    # this validation call the current method, where security_setting is nil
    if self.password.present? && security_setting.present? && !security_setting.can_contain_login_name?
      password = self.password
      split_email = self.email.split("@").first
      if password.regex_scan?(self.first_name, true) || password.regex_scan?(self.last_name, true) || password.regex_scan?(split_email, true)
        errors.add(:password, "flash_message.password_flash.contains_login_name".translate)
      end
    end
  end

  def check_email_format
    security_setting = self.organization.security_setting
    validate_email_format(!self.is_chronus_admin?, self.email, security_setting) if self.email_changed?
  end

  def get_recurring_options!(mentoring_slot, recurring_opts_hash)
    slot_start_time = mentoring_slot.start_time
    case mentoring_slot.repeats
    when MentoringSlot::Repeats::DAILY
      recurring_opts_hash.merge!({:every => :week, :on => Date::DAYNAMES[0..6].collect{|day| day.downcase.to_sym}})
    when MentoringSlot::Repeats::WEEKLY
      day_list = mentoring_slot.repeats_on_week.split(",").map(&:to_i)
      day_list.collect!{|ind| Date::DAYNAMES[ind].downcase.to_sym}
      recurring_opts_hash.merge!({:every => :week, :on => day_list})
    when MentoringSlot::Repeats::MONTHLY
      if mentoring_slot.repeats_by_month_date?
        recurring_opts_hash.merge!({:every => :month, :on => slot_start_time.day})
      else
        day_of_week = [:first, :second, :third, :fourth, :fifth][((slot_start_time.day - 1)/7)]
        recurring_opts_hash.merge!({:every => :month, :weekday => slot_start_time.strftime("%A").downcase.to_sym,
          :on => day_of_week})
      end
    end
  end

  def parse_recurrent_events(recurring_opts_hash, options = {}, &block)
    recur = Recurrence.new(recurring_opts_hash)
    events = recur.events
    return block.call(events.first) if options[:show_only_first_event]
    events.each do |event|
      block.call(event)
    end
  end

  def construct_mentoring_report_objects(mentoring_slot, start_time)
    mentoring_slot.computed_start_time = start_time
    Meeting.construct_display_mentoring_report_objects([mentoring_slot])
  end

  def answerable_profile_questions
    member_role_ids = Role.of_member(self).collect(&:id)
    self.organization.profile_questions.for_role_ids(member_role_ids)
  end

  def get_past_passwords(password_limit)
    versions.order("id DESC").limit(password_limit).collect{|member| member.modifications["crypted_password"].first}
  end

  def get_valid_slot(meeting_end_time, meeting_start_time, slot_end_time, slot_start_time, slot, mentoring_slots, meeting)
    #Case: 0
    #M:  |------------|
    #S:    |--------|
    if meeting_end_time >= slot_end_time && meeting_start_time <= slot_start_time
      return nil
    end

    #Case: 1
    #M: |-----|
    #S:   |-----|
    if meeting_end_time <= slot_end_time && meeting_start_time < slot_start_time && meeting_end_time > slot_start_time
      slot[:start] = DateTime.localize(meeting_end_time, format: :full_date_full_time_utc)
    end

    #Case: 2
    #M:   |-----|
    #S: |-----|
    if slot_start_time <= meeting_start_time && meeting_start_time < slot_end_time && slot_end_time < meeting_end_time
      slot[:end] = DateTime.localize(meeting_start_time, format: :full_date_full_time_utc)
    end

    #Case: 3
    #M:   |-----|
    #S: |---------|
    if meeting_end_time <= slot_end_time && meeting_start_time >= slot_start_time
      if (meeting_end_time == slot_end_time)
        slot[:end] = DateTime.localize(meeting_start_time, format: :full_date_full_time_utc)
      elsif (meeting_start_time == slot_start_time)
        slot[:start] = DateTime.localize(meeting_end_time, format: :full_date_full_time_utc)
      else
        new_slot = slot.dup
        new_slot[:start] = DateTime.localize(meeting_end_time, format: :full_date_full_time_utc)
        slot[:end] = DateTime.localize(meeting_start_time, format: :full_date_full_time_utc)
        mentoring_slots.push(new_slot)
      end
    end
    return slot
  end

  # Adding it as a method instead of constant as some RA types could be excluded conditionally later.
  def org_ra_exclude_types
    [
      RecentActivityConstants::Type::ARTICLE_CREATION,
      RecentActivityConstants::Type::ARTICLE_MARKED_AS_HELPFUL,
      RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION
    ]
  end

  def self.round_off_slots(slots)
    slots.each do |slot|
      slot[:start_time] = floor(slot[:start_time], 30.minutes)
      slot[:end_time] = ceil(slot[:end_time], 30.minutes)
    end
  end

  # TODO_CALENDAR_SYNC_V2 : still need to get alternative
  def self.ceil(time, seconds = 30.minutes)
    Time.at((time.to_f / seconds).ceil * seconds).utc
  end

  def self.floor(time, seconds = 30.minutes)
    Time.at((time.to_f / seconds).floor * seconds).utc
  end
end
