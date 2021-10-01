# == Schema Information
#
# Table name: users
#
#  id                           :integer          not null, primary key
#  state                        :string(255)      default("active"), not null
#  activated_at                 :datetime
#  created_at                   :datetime
#  updated_at                   :datetime
#  admin_notes                  :text(65535)
#  program_id                   :integer
#  last_seen_at                 :datetime
#  delta                        :boolean          default(FALSE)
#  max_connections_limit        :integer
#  state_changer_id             :integer
#  state_change_reason          :text(65535)
#  qa_answers_count             :integer          default(0)
#  last_weekly_update_sent_time :datetime
#  profile_updated_at           :datetime
#  member_id                    :integer          not null
#  badge_text                   :string(255)
#  primary_home_tab             :integer          default(0)
#  hide_profile_completion_bar  :boolean          default(FALSE)
#  creation_source              :integer          default(0)
#  mentoring_mode               :integer          default(3)
#  track_reactivation_state     :string(255)
#  global_reactivation_state    :string(255)
#  last_deactivated_at          :datetime
#

class User < ActiveRecord::Base
  extend ClearInvalidDependentAnswers
  extend DateProfileFilter

  include AuthorizationManager::UserExtensions
  include AasmRoles::User
  include UserDependencies
  include MeetingMentorSuggest
  include GroupPermissions
  include CalendarSettingPermissions
  include UserElasticsearchQueries
  include UserElasticsearchSettings
  include User::QuickConnectBox::QuickConnectBoxHelpers
  include User::HomePageWidget
  include User::DraftedSurveyResponsesWidget
  include User::MeetingFeedbackWidget
  include User::ConnectionStatus

  # Time for which we consider a user, new user.
  NEW_USER_PERIOD = 2.weeks

  PUBLISH_CIRCLES_WIDGET_PENDING_DURATION = 1.week

  # The previous statement use to be the reverse of the sort by last name. It gave a problem when
  # the user doesnt have first name. So the current logic works fine when users first name is NULL
  FULL_NAME_SORT = "LOWER(TRIM(CONCAT(CONCAT(COALESCE(TRIM(members.first_name),''), ' '), TRIM(members.last_name))))"
  LAST_NAME_SORT = "LOWER(CONCAT(TRIM(members.last_name),TRIM(COALESCE(members.first_name, ''))))"

  acts_as_role_based(:validate_on => :create, :mentors_scope => 'mentors', :students_scope => 'students', role_assoc_after_add: :track_user_role_addition, role_assoc_before_remove: :track_user_role_removal)
  acts_as_taggable

  MAX_RECOMMEND_USERS_FETCH_LIMIT = 1000000

  module Status
    PENDING   = 'pending'
    ACTIVE    = 'active'
    SUSPENDED = 'suspended'

    def self.all
      [PENDING, ACTIVE, SUSPENDED]
    end

    def self.allowed_in_api
      [ACTIVE, SUSPENDED]
    end
  end

  module ConnectionStatusForGA
    CURRENT = "Current"
    PAST = "Past"
    NEVER = "Never"
    NEVER_CONNECTED_NEVER_INITIATED = "Never Connected Never Initiated"
    NEVER_CONNECTED_INITIATED = "Never Connected Initiated"
    NA = "NA"
  end

  module CreationSource
    UNKNOWN = 0
    MEMBERSHIP_REQUEST_ACCEPTED = 1 # Membership request (via 'Join Now') & Enrollment page (Apply for role etc)

    def self.valid_creation_source?(value)
      [UNKNOWN, MEMBERSHIP_REQUEST_ACCEPTED].include?(value)
    end

    def self.all
      constants.collect{|c| const_get(c)}
    end
  end

  module MentoringMode
    NOT_APPLICABLE = 0
    ONGOING = 1
    ONE_TIME = 2
    ONE_TIME_AND_ONGOING = 3

    def self.one_time_sanctioned
      [ONE_TIME, ONE_TIME_AND_ONGOING]
    end

    def self.ongoing_sanctioned
      [ONGOING, ONE_TIME_AND_ONGOING]
    end

    def self.all
      constants.collect{|c| const_get(c)}
    end
  end

  class ProfileScore
    attr_accessor :default, :location, :image, :education_experience, :profile, :article, :sum, :profile_image_ratio

    def initialize(user, options={}, profile_answers_hash={})
      self.default = ProfileCompletion::Score::DEFAULT
      self.set_custom_profile_score(user, options, profile_answers_hash)
      self.set_total_score
    end

    def set_custom_profile_score(user, options = {}, profile_answers_hash = {})
      max_score = ProfileCompletion::Score::PROFILE
      questions_ratio, image_ratio, image_answered = (case user
      when User
        user.get_profile_questions_ratio_for_user(false, {:user => user, :edit => true}.merge(options))
      when Hash
        User.get_profile_questions_ratio_for_user_hash(user, false, {:user => user, :edit => true}.merge(options), profile_answers_hash)
      end)

      self.profile_image_ratio = (max_score * image_ratio).round
      self.image = image_answered ? self.profile_image_ratio : 0
      self.profile = (max_score * questions_ratio).round - self.image
    end

    def set_total_score
      self.sum = self.default + self.image + self.profile
      self.sum = self.sum > 100 ? 100 : self.sum
    end
  end

  # Attribute for storing downloaded image url.
  attr_accessor :image_url

  # Attribute for pointing to the the admin who created the profile or imported
  # from another program.
  attr_accessor :created_by

  # True if the user profile was imported from another sub program inside the
  # organization.
  attr_accessor :imported_from_other_program, :existing_member_as_admin

  attr_accessor :existing_education_attributes, :new_education_attributes, :existing_experience_attributes, :new_experience_attributes, :existing_publication_attributes, :new_publication_attributes, :addition_message,
                :existing_manager_attributes, :new_manager_attributes, :created_for_sales_demo

  attr_accessor :skip_observer, :is_pending_user_creation_case

  belongs_to_program
  belongs_to_portal
  belongs_to :member

  belongs_to :state_changer, :class_name => "User", :foreign_key => "state_changer_id"
  has_many :state_changed_users, class_name: "User", :foreign_key => "state_changer_id"

  has_many :feedback_responses_given, :class_name => "Feedback::Response", :foreign_key => "user_id", :dependent => :nullify

  has_many :feedback_responses_received, :class_name => "Feedback::Response", :foreign_key => "recipient_id", :dependent => :destroy

  has_many :group_checkins, :dependent => :destroy

  has_many :progress_statuses, :as => :ref_obj, :dependent => :destroy

  has_one :user_stat, :dependent => :destroy

  has_one :owned_program, foreign_key: "user_id", class_name: "Program"
  has_many :terminated_groups, class_name: "Group", foreign_key: "terminator_id"
  has_many :created_groups, class_name: "Group", foreign_key: "creator_id"
  has_many :closed_mentor_requests, foreign_key: "closed_by_id", class_name: "MentorRequest"
  has_many :closed_mentor_offers, foreign_key: "closed_by_id", class_name: "MentorOffer"
  has_many :resolved_flags, foreign_key: "resolver_id", class_name: "Flag"
  has_many :program_invitations
  has_many :user_campaign_jobs,  as: :abstract_object,
    :class_name => 'CampaignManagement::UserCampaignMessageJob'
  has_one :user_campaign_status, as: :abstract_object,
          :class_name => "CampaignManagement::UserCampaignStatus"
  has_many :sent_campaign_messages, foreign_key: "sender_id", class_name: "CampaignManagement::AbstractCampaignMessage"
  has_many :meeting_proposed_slots, foreign_key: "proposer_id"
  has_many :associated_program_events, class_name: "ProgramEvent"
  has_many :user_notification_settings , :dependent => :destroy
  has_many :viewed_objects, :dependent => :destroy
  has_many :matching_documents, foreign_key: "record_id"
  has_many :explicit_user_preferences, dependent: :destroy
  has_many :user_search_activities, dependent: :destroy


  [:email, :first_name, :last_name, :name_with_email, :phone, :skype_id, :picture_url, :location, :name_with_id, :terms_and_conditions_accepted, :name_only, :synced_external_calendar?, :topic_author_name_only].each do |attr|
    delegate attr, :to => :member
  end

  attr_accessor :updated_by_admin, :last_state_change
  # All the User has_many, has_one dependancies are present in user_dependencies.rb
  include_user_dependencies

  # Validations
  validates_presence_of :program, :member, :roles
  validates_presence_of :max_connections_limit, :if => Proc.new { |u| u.is_mentor? }
  validates_presence_of :mentoring_mode, :if => Proc.new { |u| u.is_mentor? && u.program.consider_mentoring_mode?}
  validates_numericality_of :max_connections_limit, :blank => false, :greater_than_or_equal_to => 0, :only_integer => true, :if => Proc.new { |u| u.is_mentor? }
  validates_uniqueness_of :program_id, :scope => [:member_id], :message => Proc.new { "activerecord.custom_errors.user.already_exists".translate }
  validates_inclusion_of  :primary_home_tab, :in => Program::RA_TABS::ALL_ACTIVITY..Program::RA_TABS::CONNECTION_ACTIVITY

  validates :track_reactivation_state, inclusion: { in: [Status::ACTIVE, Status::PENDING] }, if: Proc.new { |user| user.suspended? && !user.member.suspended? }
  validates :global_reactivation_state, inclusion: { in: [Status::ACTIVE, Status::PENDING, Status::SUSPENDED] }, if: Proc.new { |user| user.suspended? && user.member.suspended? }
  validates :creation_source, inclusion: {in: CreationSource.all}, allow_nil: true
  validates :mentoring_mode, inclusion: {in: MentoringMode.all}, allow_nil: true
  validates :group_notification_setting, inclusion: {in: UserConstants::DigestV2Setting::GroupUpdates.all}
  validates :program_notification_setting, inclusion: {in: UserConstants::DigestV2Setting::ProgramUpdates.all_db_valid}
  validate :check_state_changer_must_be_admin, if: Proc.new { |user| user.state_changer_id.present? && user.state_changer_id_changed? }
  validate :check_group_students_count_is_less_than_max_connections_limit, :if => Proc.new { |u| u.is_mentor? }
  validate :check_cannot_reactivate_when_member_suspended, on: :update
  validate :check_cannot_add_suspended_member_to_program, on: :create

  before_create :set_last_weekly_updates_sent_time

  scope :active_or_pending, -> { where("users.state = ? OR users.state = ?", Status::ACTIVE, Status::PENDING)}
  scope :available_for_sessions, -> { where("users.mentoring_mode IN (?)", MentoringMode.one_time_sanctioned)}

  # Users belonging to the member
  scope :of_member, ->(member) {
    where({:member_id => member})
  }

  # Users belonging to the program(s)
  scope :in_program, ->(programs) {
    where({:program_id => programs})
  }

  # Users belonging to the organization(s)
  scope :in_organization, ->(organizations) {
    joins(:program).where({:programs => {:parent_id => organizations}})
  }

  def self.sorted_by_answer(initial_scope, profile_question, sort_order, options = {})
    # we need users data only
    selects = ['users.id']
    # sort param
    sort_param = 'LOWER(answer_text)'
    #
    profile_answers_joiner = "LEFT JOIN profile_answers ON profile_answers.ref_obj_id=users.member_id AND profile_answers.ref_obj_type='Member' AND profile_answers.profile_question_id=#{profile_question.id}"
    # basic users scope
    users_scope = initial_scope.joins(profile_answers_joiner)
    if profile_question.file_type?
      sort_param = 'LOWER(attachment_file_name)'
    elsif profile_question.education?
      educations_joiner = "LEFT JOIN educations ON educations.profile_answer_id=profile_answers.id"
      selects << "LOWER(CONVERT(GROUP_CONCAT(CONCAT_WS(', ', educations.school_name, educations.degree, educations.major, educations.graduation_year) ORDER BY graduation_year DESC SEPARATOR '/') USING utf8)) as education_string"
      sort_param = 'education_string'
      users_scope = users_scope.joins(educations_joiner).group('users.id')
    elsif profile_question.experience?
      experience_joiner = "LEFT JOIN experiences ON experiences.profile_answer_id=profile_answers.id"
      selects << "LOWER(CONVERT(GROUP_CONCAT(CONCAT_WS(', ', experiences.job_title, experiences.start_year, experiences.end_year, experiences.company) ORDER BY current_job DESC,end_year DESC,end_month DESC SEPARATOR '/') USING utf8)) as experiences_string"
      sort_param = 'experiences_string'
      users_scope = users_scope.joins(experience_joiner).group('users.id')
    elsif profile_question.publication?
      publication_joiner = "LEFT JOIN publications ON publications.profile_answer_id=profile_answers.id"
      selects << "LOWER(CONVERT(GROUP_CONCAT(CONCAT_WS(', ', publications.title, publications.publisher, publications.year, publications.month, publications.day, publications.authors, publications.description) ORDER BY title DESC,year DESC,month DESC,day DESC SEPARATOR '/') USING utf8)) as publication_string"
      sort_param = 'publication_string'
      users_scope = users_scope.joins(publication_joiner).group('users.id')
    elsif profile_question.manager?
      manager_joiner = "LEFT JOIN managers ON managers.profile_answer_id=profile_answers.id"
      selects << "LOWER(CONVERT(GROUP_CONCAT(CONCAT_WS(', ', managers.first_name, managers.last_name, managers.email) ORDER BY managers.first_name DESC,managers.last_name DESC,managers.email DESC SEPARATOR '/') USING utf8)) as manager_string"
      sort_param = 'manager_string'
      users_scope = users_scope.joins(manager_joiner).group('users.id')
    elsif profile_question.location? && options[:location_scope]
      locations_joiner = "LEFT JOIN locations ON locations.id=profile_answers.location_id"
      selects << "locations.#{options[:location_scope]}"
      sort_param = "LOWER(locations.#{options[:location_scope]})"
      users_scope = users_scope.joins(locations_joiner).group('users.id')
    elsif profile_question.choice_or_select_type?
      choices_joiner = "LEFT JOIN answer_choices ON answer_choices.ref_obj_id = profile_answers.id AND answer_choices.ref_obj_type='#{ProfileAnswer.name}' LEFT JOIN question_choice_translations ON answer_choices.question_choice_id = question_choice_translations.question_choice_id AND question_choice_translations.locale IN ('#{I18n.default_locale}', '#{I18n.locale}')"
      selects << "LOWER(question_choice_translations.text) as choices"
      sort_param = 'choices'
      users_scope = users_scope.joins(choices_joiner).group('users.id')
    elsif profile_question.date?
      selects << "date_answers.answer"
      sort_param = "date_answers.answer"
      users_scope = users_scope.joins(join_date_answers(join_type: "left")).group('users.id')
    end
    sort_order = "#{sort_param} #{sort_order}"
    users_scope.select(selects.join(',')).order(sort_order)
  end

  # Permission Mocked methods
  def can_manage_mentoring_sessions?
    self.is_admin?
  end

  def can_view_received_mentor_requests?
    self.is_mentor?
  end

  def can_receive_mentoring_offer?
    self.is_student?
  end

  def is_notification_disabled_for?(setting_name)
    user_notification_object = self.user_notification_settings.find_by(:notification_setting_name => setting_name)
    user_notification_object.present? && user_notification_object.disabled?
  end

  def can_offer_mentoring_to?(receiver)
    offer_mentoring = receiver.can_receive_mentoring_offer?
    offer_mentoring &&= self.can_offer_mentoring?
    offer_mentoring &&= self.can_mentor?
    offer_mentoring &&= Group.involving(receiver, self).blank?
    offer_mentoring &&= !receiver.connection_limit_as_mentee_reached?
  end

  def show_recommended_ongoing_mentors?
    program = self.program
    show_recommendations = self.can_send_mentor_request? && program.allow_mentoring_requests? && program.only_career_based_ongoing_mentoring_enabled? && (program.matching_by_mentee_and_admin_with_preference? || program.matching_by_mentee_alone? )
    show_recommendations && self.is_student? && !self.connection_limit_as_mentee_reached? && !self.pending_request_limit_reached_for_mentee?
  end

  def has_multiple_default_roles?
    self.is_mentor_and_student? || self.is_mentor_and_admin? || self.is_admin_and_student?
  end

  def name(options = {})
    return unless self.member
    if !options[:name_only] && self.is_admin?
      "feature.member.content.name_with_admin_term".translate(name: self.member.name(name_only: true), Administrator: self.member.organization.admin_custom_term.term)
    else
      self.member.name(options)
    end
  end

  def self.find_by_email_program(email, program)
    member = program.organization.members.find_by(email: email)
    program.users.find_by(member_id: member.id) if member
  end

  # name_with_email can be just name or name_with_email string
  # email format should be: /<(.*)>$/
  # example:
  # User.search_by_name_with_email(program, "test user <test_user@example.com>")
  # User.search_by_name_with_email(program, "<test_user@example.com>")
  # User.search_by_name_with_email(program, "test user")
  def self.search_by_name_with_email(program, name_with_email, includes_email = true)
    email = Member.extract_email_from_name_with_email(name_with_email)
    if email.present? && includes_email
      result = User.find_by_email_program(email, program)
      result.present? ? [result] : []
    else
      search_name_text = QueryHelper::EsUtils.sanitize_es_query(name_with_email)
      User.get_filtered_objects(search_conditions: {fields: ["name_only"], search_text: search_name_text, operator: "AND"}, must_filters: {program_id: program.id})
    end
  end

  def self.sort(users, program)
    if program.sort_users_by == Program::SortUsersBy::LAST_NAME
      users.to_a.sort {|a,b| a.last_name.downcase <=> b.last_name.downcase }
    else
      users.to_a.sort {|a,b| a.name(:name_only => true).downcase <=> b.name(:name_only => true).downcase }
    end
  end

  def self.priority_array_for_match_score_sorting(match_score, availability_slots)
    [-1 * match_score.to_i, -1 * availability_slots.to_i]
  end

  def self.resend_instructions_email(program, user_ids, job_uuid = nil)
    users = program.users.where(:id => user_ids).includes(:member)
    JobLog.compute_with_uuid(users, job_uuid, "Resend Signup Instructions") do |user|
      reset_password = user.member.fetch_or_create_password
      ChronusMailer.resend_signup_instructions(user, reset_password).deliver_now
    end
  end

  def self.send_welcome_email(user_id, roles)
    user = User.find_by(id: user_id)
    if user.nil?
      JobLog.log_info("Ignoring the user object record for :send_welcome_email as user_id ##{user_id} is nil")
      return
    end
    roles &= user.role_names
    if roles.include? RoleConstants::ADMIN_NAME
      ChronusMailer.welcome_message_to_admin(user).deliver_now
    elsif roles.include? RoleConstants::MENTOR_NAME
      ChronusMailer.welcome_message_to_mentor(user).deliver_now
    elsif roles.include? RoleConstants::STUDENT_NAME
      ChronusMailer.welcome_message_to_mentee(user).deliver_now
    end
  end

  def group_checkins_duration
    self.group_checkins.sum(:duration).to_f / 60
  end

  # Returns the articles authored by this user in the program.
  def articles
    self.member.articles.published_in(self.program)
  end

  # Returns the priority role
  def get_priority_role
    # Assuming First Admin Role takes precedence
    return self.roles.administrative.first.name if self.roles.administrative.present?
    return RoleConstants::MENTOR_NAME if self.is_mentor?
    return RoleConstants::STUDENT_NAME if self.is_student?
    return self.roles.first.name # if he has other roles assuming first one takes precedence
  end

  def common_groups(other_user, group_status = nil)
    if group_status.present?
      self.groups.send(group_status) & other_user.groups.send(group_status)
    else
      self.groups & other_user.groups
    end
  end

  def connected_with?(other_user)
    self.common_groups(other_user).any?
  end

  def actively_connected_with?(other_user)
    self.common_groups(other_user, :active).any?
  end

  def new_mentor_requests_count
    self.received_mentor_requests.active.count
  end

  def self.track_state_changes(timestamp, user_state_roles_map, users_groups_info, state_transition)
    date_id = timestamp / 1.day.to_i
    user_state_roles_map.each do |user_state_roles|
      user = User.find_by(id: user_state_roles["user_id"])
      if user.present?
        user_info = { state: {}, role: {} }
        user_info[:state][:from] = user_state_roles["from_state"] || state_transition[:from]
        user_info[:state][:to] = user_state_roles["to_state"] || state_transition[:to]
        role_ids = user_state_roles["role_ids"].split(",").collect(&:to_i)
        user_info[:role][:from] = role_ids
        user_info[:role][:to] = role_ids
        User.create_user_and_membership_state_changes(user.id, date_id, user_info, users_groups_info[user.id])
      end
    end
  end

  def self.track_state_changes_for_bulk_role_addition(timestamp, old_state_role_mappings, new_state_role_mappings, users_groups_info)
    date_id = timestamp / 1.day.to_i
    processed_state_role_mappings = {}
    old_state_role_mappings.each do |old_state_role_mapping|
      processed_state_role_mappings[old_state_role_mapping["user_id"]] = old_state_role_mapping
    end
    new_state_role_mappings.each do |user_state_roles|
      user_id = user_state_roles["user_id"]
      user = User.find_by(id: user_id)
      if user.present?
        user_info = { state: {}, role: {} }
        user_info[:state][:from] = processed_state_role_mappings[user_id]["state"]
        user_info[:state][:to] = user_state_roles["state"]
        user_info[:role][:from] = processed_state_role_mappings[user_id]["role_ids"].split(",").collect(&:to_i)
        user_info[:role][:to] = user_state_roles["role_ids"].split(",").collect(&:to_i)
        User.create_user_and_membership_state_changes(user.id, date_id, user_info, users_groups_info[user.id])
      end
    end
  end

  def self.create_user_and_membership_state_changes(user_id, date_id, user_info, groups_info)
    user = User.find_by(id: user_id)
    return unless user.present?
    role_ids_in_active_groups = groups_info[:role_ids_in_active_groups]
    connection_membership_info = {role: {from_role: role_ids_in_active_groups, to_role: role_ids_in_active_groups}}

    transition = user.state_transitions.new(date_id: date_id)
    transition.set_info(user_info)
    transition.set_connection_membership_info(connection_membership_info)
    transition.save!

    user.connection_memberships.each do |membership|
      if groups_info[membership.id].present?
        info  = {
          user: {from_state: user_info[:state][:from], to_state: user_info[:state][:to]},
          group: groups_info[membership.id],
          connection_membership: {from_state: Connection::Membership::Status::ACTIVE, to_state: Connection::Membership::Status::ACTIVE}
        }
        membership.create_membership_state_change(date_id, info)
      end
    end
  end

  def member_time_zone
    self.member.time_zone || ""
  end

  # Returns <code>self.location.full_address</code> if location is present,
  # 'Unkown' otherwise.
  def location_name
    self.location.full_address if self.location
  end

  def self.suspend_users_by_ids(user_ids, admin, reason, options = {send_email: true})
    program = admin.program
    users_scope = program.all_users.where(id: user_ids).active_or_pending
    user_ids = users_scope.pluck(:id)
    return if user_ids.empty?

    state_role_mappings = get_state_roles_map(user_ids, "from_state")
    current_time = DateTime.localize(Time.current.utc, format: :full_date_full_time)
    update_query = sanitize_sql_for_assignment(["state_changer_id = ?, state_change_reason = ?, track_reactivation_state = state, state = ?, last_deactivated_at = ?", admin.id, reason, Status::SUSPENDED, current_time])
    users_scope.update_all(update_query)
    DelayedEsDocument.delayed_bulk_update_es_documents(User, user_ids)
    users_groups_info = User.get_active_roles_and_membership_info(user_ids)
    User.delay.track_state_changes(Time.now.utc.to_i, state_role_mappings, users_groups_info, to: Status::SUSPENDED)
    Matching.perform_users_delta_index_and_refresh_later(user_ids, program)
    User.delay.process_users_suspend(user_ids, options[:send_email], JobLog.generate_uuid)
    return true
  end

  def self.process_users_suspend(user_ids, send_email, job_uuid = nil)
    job_uuid ||= JobLog.generate_uuid
    User.where(id: user_ids).includes(:recommendation_preferences).find_each do |user|
      UserObserver.recent_activity_for_user_state_change(user, RecentActivityConstants::Type::USER_SUSPENSION, RecentActivityConstants::Target::ADMINS)
      UserObserver.send_user_suspension_emails(user, job_uuid) if send_email
      user.recommendation_preferences.destroy_all
      user.close_pending_received_requests_and_offers
    end
  end

  def suspend_from_program!(admin, reason, options = {send_email: true})
    if self.suspended?
      if options[:global_suspension]
        self.global_reactivation_state = self.state
        self.save!
      end
    else
      self.state_changer = admin
      self.state_change_reason = reason
      self.track_reactivation_state = self.state unless options[:global_suspension]
      self.global_reactivation_state = self.state if options[:global_suspension]
      self.last_deactivated_at = Time.current
      self.suspend!
      UserObserver.delay.send_user_suspension_emails_by_id(self.id, JobLog.generate_uuid) if options[:send_email]
      Matching.perform_users_delta_index_and_refresh_later([self.id], self.program)
    end
  end

  def self.activate_users_by_ids(user_ids, admin, options = {send_email: true, track_changes: true})
    program = admin.program
    user_ids = program.all_users.joins(:member).
      where("users.state = '#{Status::SUSPENDED}' AND users.id IN (?)", user_ids).
      where("members.state != #{Member::Status::SUSPENDED}").pluck("users.id")
    return if user_ids.empty?

    users_scope = User.where(id: user_ids)
    to_active_scope = users_scope.where(track_reactivation_state: Status::ACTIVE)
    to_pending_scope = users_scope.where(track_reactivation_state: Status::PENDING).includes(:roles, :member, :groups)
    pending_to_active_user_ids = to_pending_scope.select { |user| user.can_be_published? }.collect(&:id)
    to_active_user_ids = (to_active_scope.pluck(:id) + pending_to_active_user_ids).flatten

    update_query = "state_changer_id = #{admin.id}, activated_at = '#{Time.now.to_formatted_s(:db)}', track_reactivation_state = NULL"
    to_active_scope = User.where(id: to_active_user_ids)
    to_pending_scope = to_pending_scope.where("id NOT IN (?)", pending_to_active_user_ids) if pending_to_active_user_ids.present?
    to_active_scope.update_all("state = '#{Status::ACTIVE}', #{update_query}")
    to_pending_scope.update_all("state = '#{Status::PENDING}',  #{update_query}")
    DelayedEsDocument.delayed_bulk_update_es_documents(User, user_ids)

    if options[:track_changes]
      state_role_mappings = get_state_roles_map(user_ids, "to_state")
      users_groups_info = User.get_active_roles_and_membership_info(user_ids)
      User.delay.track_state_changes(Time.now.utc.to_i, state_role_mappings, users_groups_info, from: Status::SUSPENDED)
    end
    Matching.perform_users_delta_index_and_refresh_later(user_ids, program) unless options[:skip_matching_index]
    User.delay.process_users_reactivation(user_ids, options[:send_email])
    return true
  end

  def self.process_users_reactivation(user_ids, send_email)
    users_scope = User.where(id: user_ids)
    users_scope.each { |user| UserObserver.recent_activity_for_user_state_change(user, RecentActivityConstants::Type::USER_ACTIVATION, RecentActivityConstants::Target::ADMINS) }
    if send_email
      JobLog.compute_with_uuid(users_scope, JobLog.generate_uuid, "Reactivation Mail Trigger") do |user|
        ChronusMailer.user_activation_notification(user).deliver_now
      end
    end
  end

  def reactivate_in_program!(admin, options = {send_email: true})
    return unless self.suspended?
    reactivation_state = self.get_reactivation_state(options[:global_reactivation])
    self.track_reactivation_state = nil unless options[:global_reactivation]
    self.global_reactivation_state = nil if options[:global_reactivation]

    if [Status::ACTIVE, Status::PENDING].include? reactivation_state
      self.state_changer = admin
      self.activated_at = Time.now
      self.state = reactivation_state
      self.save!
      ChronusMailer.user_activation_notification(self).deliver_now if options[:send_email]
      Matching.perform_users_delta_index_and_refresh_later([self.id], self.program)
    else
      # reactivation_state can also be 'Suspended'
      self.save!
    end
  end

  def get_reactivation_state(global_reactivation)
    reactivation_state = global_reactivation ? self.global_reactivation_state : self.track_reactivation_state
    (reactivation_state == Status::PENDING && self.can_be_published?) ? Status::ACTIVE : reactivation_state
  end

  def can_be_published?
    self.profile_incomplete_roles.empty? || (self.groups.collect(&:status) & Group::Status::USER_TO_BE_ACTIVATED_CRITERIA).any?
  end

  def display_name(user = nil)
    return "You" if self == user
    return self.name
  end

  def has_more_answers?(offset)
    !!self.answered_qa_questions.first(:offset => offset)
  end

  # Removes the role with name <i>role_name</i> as done by <i>demoted_by</i>
  # and delivers a notification to the user about the demotion.
  def demote_from_role!(role_names, demoted_by, reason = '')
    role_names = [role_names].flatten
    return unless (self.role_names & role_names).any?
    program = self.program
    original_events_for_user = program.program_events.published.for_user(self).all
    if (self.program.standalone? && role_names.include?(RoleConstants::ADMIN_NAME))
      self.member.demote_from_admin!
    end
    self.max_connections_limit = nil if role_names.include?(RoleConstants::MENTOR_NAME)
    self.role_names -= role_names
    self.state_changer = demoted_by

    ActiveRecord::Base.transaction do
      # During demoting max_connections_limit is not reset if its set already
      # because the groups etc. are not deleted

      #Discard all drafted connections
      self.remove_drafted_connections_for_role_names(role_names)

      #clear all explicit preferences
      if role_names.include?(RoleConstants::STUDENT_NAME)
        ExplicitUserPreference.destroy_invalid_records(self)
      end

      #Clear event RSVP
      current_events_for_user = program.program_events.published.for_user(self).all
      events_to_remove_rsvp = original_events_for_user - current_events_for_user
      self.remove_events_rsvp(events_to_remove_rsvp)

      #Unsubscribe from forums
      forum_ids = (program.forums - program.forums.for_role(self.role_names)).collect(&:id)
      self.unsubscribe_from_forums(forum_ids)

      #Unsubscribe from topics
      topic_ids = Topic.where(:forum_id => forum_ids).collect(&:id)
      self.unsubscribe_from_topics(topic_ids)

      #Remove the answers of questions the member isnt supposed to answer any more due to role removal
      self.member.remove_answers_from_unanswerable_questions
      #Probably, self.role_names cannot be empty

      # Handling favorite & ignore preferences
      self.remove_preferences(role_names)

      if (self.role_names - role_names).empty?
        self.destroy
        self.create_user_demotion_ra(reason)
        ChronusMailer.demotion_notification(self, role_names, demoted_by, reason, :force_send => true).deliver_now
      else
        self.save!
        #Create Demotion RA
        self.create_user_demotion_ra(reason)
        Matching.remove_mentor_later(self.id, self.program) if role_names.include?(RoleConstants::MENTOR_NAME)
        Matching.remove_student_later(self.id, self.program) if role_names.include?(RoleConstants::STUDENT_NAME)
        Matching.perform_users_delta_index_and_refresh_later([self.id], self.program)
        ChronusMailer.demotion_notification(self, role_names, demoted_by, reason).deliver_now
      end
    end
  end

  def remove_preferences(role_names)
    if role_names.include?(RoleConstants::MENTOR_NAME)
      self.mentee_marked_favorite_preferences.destroy_all
      self.mentee_marked_ignore_preferences.destroy_all
    end
    if role_names.include?(RoleConstants::STUDENT_NAME)
      self.favorite_preferences.destroy_all
      self.ignore_preferences.destroy_all
    end
  end

  def remove_drafted_connections_for_role_names(role_names)
    if role_names.include?(RoleConstants::MENTOR_NAME)
      program.groups.drafted.with_mentor(self).destroy_all
    end
    if role_names.include?(RoleConstants::STUDENT_NAME)
      program.groups.drafted.with_student(self).destroy_all
    end
  end

  def remove_events_rsvp(events)
    events.each do |event|
      event.clear_user_rsvp(self)
    end
  end

  def role_ids_in_active_groups
    self.connection_memberships.of_active_criteria_groups.pluck(:role_id)
  end

  def track_user_role_addition(role)
    return if self.created_for_sales_demo
    unless new_record?
      info = {}
      info[:state] = {from: self.state, to: self.state}
      current_role_ids = self.role_ids
      info[:role] = {}
      info[:role][:from] = current_role_ids - [role.id]
      info[:role][:to] = current_role_ids

      connection_role_ids_in_active_groups = self.role_ids_in_active_groups.uniq
      connection_membership_info = {role: {from_role: connection_role_ids_in_active_groups, to_role: connection_role_ids_in_active_groups}}

      transition = self.state_transitions.new(date_id: (Time.now.utc.to_i/1.day.to_i))
      transition.set_info(info)
      transition.set_connection_membership_info(connection_membership_info)
      transition.save!
    end
  end

  def track_user_role_removal(role)
    return if self.created_for_sales_demo
    unless new_record?
      info = {}
      info[:state] = {from: self.state, to: self.state}
      current_role_ids = (@_current_role_ids ||= self.role_ids).dup
      info[:role] = {}
      info[:role][:from] = current_role_ids
      @_current_role_ids = info[:role][:to] = (current_role_ids - [role.id])

      connection_role_ids_in_active_groups = self.role_ids_in_active_groups.uniq
      connection_membership_info = {role: {from_role: connection_role_ids_in_active_groups, to_role: connection_role_ids_in_active_groups}}

      transition = self.state_transitions.new(date_id: (Time.now.utc.to_i/1.day.to_i))
      transition.set_info(info)
      transition.set_connection_membership_info(connection_membership_info)
      transition.save!
    end
  end

  def create_user_demotion_ra(reason)
    RecentActivity.create!(
      :programs => [self.program],
      :member => self.state_changer.member,
      :ref_obj => self,
      :action_type => RecentActivityConstants::Type::USER_DEMOTION,
      :target => RecentActivityConstants::Target::NONE,
      :message => (reason.blank? ? nil : reason))
  end

  def unsubscribe_from_forums(forum_ids)
    unsubscribe_from_obj(forum_ids, Forum.to_s)
  end

  def unsubscribe_from_topics(topic_ids)
    unsubscribe_from_obj(topic_ids, Topic.to_s)
  end

  def self.promote_to_roles(program, user_ids, new_role_names, promoted_by, promotion_reason = '')
    user_ids = program.all_users.joins(:member).
      where("users.id IN (?)", user_ids).
      where("members.state != #{Member::Status::SUSPENDED}").pluck("users.id")
    return if user_ids.empty?

    users_scope = User.where(id: user_ids)
    member_ids = users_scope.pluck(:member_id)
    roles_to_add = program.roles.where(name: new_role_names).select([:id, :name])
    role_names_to_add = roles_to_add.map(&:name)
    old_state_role_mappings = get_state_roles_map(user_ids)

    user_ids_to_update = update_role_references(program, user_ids, roles_to_add)
    promote_to_admin_role(program, user_ids_to_update, role_names_to_add)
    User.activate_users_by_ids(user_ids_to_update, promoted_by, { send_email: false, track_changes: false, skip_matching_index: true })
    new_state_role_mappings = get_state_roles_map(user_ids_to_update)
    users_groups_info = User.get_active_roles_and_membership_info(user_ids_to_update)
    User.delay.track_state_changes_for_bulk_role_addition(Time.now.utc.to_i, old_state_role_mappings, new_state_role_mappings, users_groups_info)
    User.delay.delete_not_applicable_answers(member_ids, new_role_names)

    Matching.perform_users_delta_index_and_refresh_later(user_ids_to_update, program)
    User.delay.bulk_create_ra_and_mail_for_promoting_to_role(user_ids_to_update, program, role_names_to_add, promoted_by, promotion_reason, false)
    return true
  end

  # Promotes the user to the new role(s) in <i>new_role_names</i> as done
  # by <i>promoted_by</i>
  #
  # ==== Params
  # * <tt>new_role_names</tt> : array of names of the roles to promote to.
  # to
  def promote_to_role!(new_role_names, promoted_by, promotion_reason = '', options = {})
    new_role_names = [new_role_names].flatten
    # What new roles are we adding effectively?
    existing_role_names = self.role_names
    role_names_to_add = new_role_names - existing_role_names
    return if role_names_to_add.empty? # Return if no new role.
    self.role_names += role_names_to_add
    self.suspended? ? self.reactivate_in_program!(promoted_by, send_email: false) : self.save!
    if (self.program.standalone? && new_role_names == [RoleConstants::ADMIN_NAME])
      self.member.promote_as_admin!
    end
    User.delay.delete_not_applicable_answers([self.member_id], new_role_names)
    Matching.perform_users_delta_index_and_refresh_later([self.id], self.program)
    self.create_ra_and_mail_for_promoting_to_role(role_names_to_add, promoted_by, promotion_reason, options[:no_email])
    return true
  end

  def self.delete_not_applicable_answers(member_ids, role_names)
    ProfileAnswer.not_applicable.member_answers.
                  joins(:profile_question => {:role_questions => :role}).
                  where(:ref_obj_id => member_ids, :ref_obj_type => Member.name).
                  where(:role_questions => {:required => true}).
                  where(:roles => {:name => role_names}).destroy_all
  end

  def self.bulk_create_ra_and_mail_for_promoting_to_role(user_ids, program, role_names_to_add, promoted_by, promotion_reason, no_email)
    promoted_by_member = promoted_by.member
    user_class = User.name
    user_ids.each do |user_id|
      RecentActivity.create!(
        programs: [program],
        member: promoted_by_member,
        ref_obj_id: user_id,
        ref_obj_type: user_class,
        action_type: RecentActivityConstants::Type::USER_PROMOTION,
        target: RecentActivityConstants::Target::ADMINS,
        message: promotion_reason)
    end
    User.where(id: user_ids).find_each do |user|
      user.send_promotion_notification_mail(role_names_to_add, promoted_by, promotion_reason, no_email, JobLog.generate_uuid)
    end
  end

  def create_ra_and_mail_for_promoting_to_role(role_names_to_add, promoted_by, promotion_reason, no_email)
    if role_names_to_add.present?
      self.state_changer = promoted_by
      # RA for Admins
      RecentActivity.create!(
        :programs => [self.program],
        :member => self.state_changer.member,
        :ref_obj => self,
        :action_type => RecentActivityConstants::Type::USER_PROMOTION,
        :target => RecentActivityConstants::Target::ADMINS,
        :message => (promotion_reason.blank? ? nil : promotion_reason))

      self.delay(:queue => DjQueues::HIGH_PRIORITY).send_promotion_notification_mail(role_names_to_add, promoted_by, promotion_reason, no_email, JobLog.generate_uuid)
    end
  end

  def send_promotion_notification_mail(new_role_names, promoted_by, promotion_reason, no_email, job_uuid = nil)
    return if no_email || self == promoted_by
    JobLog.compute_with_uuid(self, job_uuid, "Promotion notification") do |user|
      ChronusMailer.promotion_notification(user, new_role_names, promoted_by, promotion_reason).deliver_now
    end
  end

  def admin_of?(program)
    program.admin_users.include?(self)
  end

  def admin_and_other?
    self.is_admin? && !(self.is_admin_only?)
  end

  def connection_limit_as_mentee_reached?
    !self.program.max_connections_for_mentee.nil? && (self.studying_groups.active.count >= self.program.max_connections_for_mentee)
  end

  def connection_limit_as_mentor_reached?
    self.mentoring_groups.active.count >= self.program.default_max_connections_limit
  end

  def pending_request_limit_reached_for_mentee?
    self.program.max_pending_requests_for_mentee.present? && (self.sent_mentor_requests.active.count >= self.program.max_pending_requests_for_mentee)
  end

  def ready_to_request?
    self.user_favorites.count >= self.program.min_preferred_mentors
  end

  def prompt_to_request?
    self.program.allow_mentoring_requests? &&
      self.can_send_mentor_request? &&
      self.sent_mentor_requests.empty? &&
      self.studying_groups.empty? &&
      self.favorites.any? &&
      self.ready_to_request? &&
      !self.connection_limit_as_mentee_reached? &&
    !self.pending_request_limit_reached_for_mentee?
  end

  def can_get_mentor_recommendations?
    self.program.ongoing_mentoring_enabled? && self.is_student? &&
      self.program.matching_by_mentee_alone? && self.program.allow_mentoring_requests? &&
      !self.connection_limit_as_mentee_reached? &&
      !self.pending_request_limit_reached_for_mentee? &&
      self.studying_groups.active.count == 0
  end

  def recommended_mentors(options = {})
    options.reverse_merge!({count: 5, match_score_cutoff: 50})
    if self.is_student?
      mentor_role = program.get_roles(RoleConstants::MENTOR_NAME)[0]

      with_options = {program_id: program.id, "roles.id" => mentor_role.id, can_accept_request: true, state: User::Status::ACTIVE}
      with_options.merge!({mentoring_mode: User::MentoringMode.ongoing_sanctioned}) if self.program.consider_mentoring_mode?

      raise "Mentor role not present" unless mentor_role
      user_ids = User.get_filtered_users("", page: 1, per_page: MAX_RECOMMEND_USERS_FETCH_LIMIT, with: with_options, source_columns: [:id]).map(&:to_i)
      user_ids -= (
        self.studying_groups.active_or_drafted.includes(:mentors).map{|g| g.mentors.map(&:id)}.flatten.uniq +
        [self.id] +
        self.received_mentor_offers.pending.map(&:mentor_id) +
        self.sent_mentor_requests.active.map(&:receiver_id)
      )
      if self.student_document_available?
        match_results = self.student_cache_normalized
        user_ids = user_ids & match_results.select{|id, score| score > options[:match_score_cutoff]}.keys.sort_by{|user_id| -(match_results[user_id]||0)}
        user_ids_string = user_ids.join(',')
        mentors = User.where(id: user_ids).order(user_ids_string.present? ? "field(id,#{user_ids_string})" : "").limit(options[:count] + 5)
        mentors.sample(options[:count])
      end
    end
  end

  def get_student_cache_normalized
    return self.student_document_available? ? self.student_cache_normalized : {}
  end

  def cached_available_and_can_accept_request?
    Rails.cache.fetch([self, "available_and_can_accept_request?"]) do
      is_mentor? && (
        max_connections_limit > (
          Connection::MenteeMembership.where(group_id: Group.with_mentor(self).active_or_drafted.pluck(:id)).count +
          MentorRequest.where(receiver_id: id, status: AbstractRequest::Status::NOT_ANSWERED).count +
          MentorOffer.where(mentor_id: id, status: MentorOffer::Status::PENDING).count
        )
      )
    end
  end

  # True if this user is a member of the mentoring group.
  # Assumes the presence of group_obj
  def belongs_to_group?(group_obj)
    group_obj.has_member?(self)
  end

  # Students of the mentor through his groups.
  # The argument group_type is to collect students of mentoring_groups which are of
  # that type. Takes the values :active, :closed, :drafted, :active_or_drafted and :all
  def students(group_status = :active)
    return [] unless self.is_mentor?

    groups = self.mentoring_groups.includes(:students)
    if group_status == :all
      groups.collect(&:students).flatten
    else
      groups.send(group_status).collect(&:students).flatten
    end
  end

  # Mentor of the user through his groups.
  # The argument group_type is to collect mentors of studying_groups which are of
  # that type. Takes the values :active, :closed, :published, :drafted and :all
  def mentors(group_status = :active)
    return [] unless self.is_student?

    groups = self.studying_groups.includes(:mentors)
    if group_status == :all
      groups.collect(&:mentors).flatten
    else
      groups.send(group_status).collect(&:mentors).flatten
    end
  end

  def mentor_connections_map
    studying_groups = self.studying_groups.active_or_drafted
    construct_user_groups_map(studying_groups, :mentors)
  end

  def mentee_connections_map
    mentoring_groups = self.mentoring_groups.active_or_drafted
    construct_user_groups_map(mentoring_groups, :students)
  end

  # The mentor request sent by the student. For loosely managed, returns the request
  # sent to <i>opts[:to_mentor]</i>.
  def my_request(opts = {})
    return nil unless self.can_send_mentor_request?
    return self.sent_mentor_requests.first if self.program.matching_by_mentee_and_admin?
    return self.sent_mentor_requests.to_mentor(opts[:to_mentor]).first
  end

  def member_of?(program_arg)
    program_arg == self.program
  end

  # Returns whether the user is a relatively new user.
  def recently_joined?
    (Time.now - self.created_at) < NEW_USER_PERIOD
  end

  # Sends the email right away if notification setting is all,
  # otherwise creates a pending notification.
  #
  # If opts[:send_now] is set, delivers email right away, even if notification
  # setting is not UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE
  #
  def send_email(object, action_type, opts = {})
    # If individual emails or force_send set to true, deliver right away.
    send_now = opts[:send_now] || immediate_program_update?
    if send_now
      template = RecentActivityConstants::EmailTemplate[action_type]
      #We pass attributes for cases when object is getting deleted
      if opts.delete(:deletion)
        ChronusMailer.send(template, self, opts).deliver_now
      else
        ChronusMailer.send(template, self, object, opts).deliver_now
      end
    elsif digest_v2_program_update?
      PendingNotification.create!(
        :ref_obj_creator => self,
        :ref_obj => object,
        :program => program,
        :action_type => action_type,
        :initiator => opts[:initiator])
    end
  end

  # This is similar to the answer_for method below.
  # The advantage in the aggregated_answer_for method is that - all the profile_answers for that user is loaded into the memory.
  # where method which is a ActiveRecord::Relation method, which will fire sql queries.
  # So when many answers are requested for the same user, rails loads from the memory instead of firing a sql query.
  # The use case is in the admin_views#show page.
  def aggregated_answer_for(question_id)
    self.member.profile_answers.select{|profile_answer| profile_answer.profile_question_id == question_id}.first
  end

  # Returns the user's answer for the given question. Nil if empty
  def answer_for(question, with_scope = true)
    self.member.answer_for(question) if self.member
  end

  def save_answer!(question, answer_text, is_new_member = false, options = {})
    ProfileAnswer.transaction do
      # Find out if the user has already answered the question or create a new answer
      profile_answer = get_answer_for(question, is_new_member)
      profile_answer.save_answer!(question, answer_text, self, options)
    end
  end

  # Assign program, picture from params and return a new object. Doesn't save the object
  def self.new_from_params(params)
    params.symbolize_keys!

    program           = params[:program] || (params[:program_id] ? Program.find(params[:program_id]) : nil)
    creator           = params.delete(:created_by)
    user_roles        = [params.delete(:role_names)].flatten
    member            = params.delete(:member)
    name              = params.delete(:name)
    email             = params.delete(:email)
    creation_source   = params.delete(:creation_source)

    params.delete(:program)
    params.delete(:program_id)
    user = User.new(params)
    user.member = member
    user.program = program
    user.role_names = user_roles
    user.created_by = creator
    user.creation_source = creation_source if CreationSource.valid_creation_source?(creation_source)
    return user
  end

  def get_user_favorite(mentor)
    self.user_favorites.select { |user_favorite| user_favorite.favorite == mentor }.first
  end

  def student_of_moderated_groups?
    self.is_student? && self.program.matching_by_mentee_and_admin?
  end

  def answers_last_updated_at
    self.member.profile_answers.maximum('updated_at').to_i
  end

  def self.profile_score_by_hash(user_hash, profile_answers_hash, options)
    ProfileScore.new(user_hash, options, profile_answers_hash)
  end

  def profile_score(options={})
    @profile_score ||= ProfileScore.new(self, options)
  end

  # Returns how many more new mentoring connections the mentor can take
  def slots_available
    [self.max_connections_limit - self.filled_slots, 0].max
  end

  def filled_slots
    students(:active_or_drafted).size + self.sent_mentor_offers.pending.size
  end

  def slots_available_for_mentor_request
    [slots_available - new_mentor_requests_count, 0].max
  end

  def can_receive_mentoring_requests?
    self.is_mentor? && (slots_available_for_mentor_request > 0)
  end

  def can_mentor?
    (self.is_mentor? && (slots_available() > 0))
  end

  # Returns whether the user can view the management console. This is a hybrid
  # permission which requires *atleast* one of the permissions in
  # RoleConstants::MANAGEMENT_PERMISSIONS to be present for the user.
  def view_management_console?
    self.roles.includes(:permissions)
                    .where(:permissions => { :name => RoleConstants::MANAGEMENT_PERMISSIONS })
                    .any?
  end

  def same_member?(other_user)
    self.member_id == other_user.member_id
  end

  #
  # Returns whether the user is visible to the +other_user+ based on their
  # roles and the permissions.
  #
  def visible_to?(other_user)
    # Always visible to self.
    return true if self.same_member?(other_user)

    # Always visible if self is Admin
    return true if self.is_admin?

    # No permission check if the user is not having any non-administrative roles.
    return true unless self.has_non_admin_role?

    #Other user received an admin recommendation for self
    return true if is_recommended?(other_user)

    # If other user is admin
    _is_visible = other_user.is_admin?

    # If other_user has permission to view any of the users roles
    _is_visible ||= has_role_visible_to?(other_user)

    # If not visible, then check if the two users are actively connected or connected in the past. Allow visiblity
    # if connected.
    _is_visible ||= self.connected_with?(other_user)

    # If not visible, then check if the two users are have accepted flash mentoring meeting. Allow visiblity
    _is_visible ||= self.has_accepted_flash_mentoring_meeting_with?(other_user)

    # If other user received a mentor_request
    _is_visible ||= other_user.received_mentor_requests.from_student(self).any?

    # If other user received a meeting_request
    _is_visible ||= other_user.received_meeting_requests.from_student(self).any?

    # If other user received a mentor_offer
    _is_visible ||= other_user.received_mentor_offers.from_mentor(self).any?
  end

  # This function Returns the list of roles for  which the users profile is incomplete.
  def profile_incomplete_roles
    self.role_names.select{|r| self.profile_incomplete_for?(r)}
  end

  # Returns if the user is in pending state.
  def profile_pending?
    self.state == Status::PENDING
  end

  def profile_active?
    self.state == Status::ACTIVE
  end

  def active_or_pending?
    self.state == Status::ACTIVE || self.state == Status::PENDING
  end

  def publish_profile!(publisher)
    return if self.active?

    if self.profile_incomplete_roles.blank?
      self.created_by = publisher
      self.state = User::Status::ACTIVE
      self.save!
    end
  end

  # Returns whether the profile for the given role is incomplete
  def profile_incomplete_for?(role, program = nil, options = {})
    program ||= self.program
    return profile_incomplete_questions(role, program, options).any?
  end

  def profile_incomplete_questions(role, program, options = {})
    questions_to_be_answered = options[:required_questions] || program.required_profile_questions_except_default_for(role)
    all_answers = member.profile_answers.group_by(&:profile_question_id)
    questions_to_be_answered.select!{ |profile_question| profile_question.conditional_text_matches?(all_answers) }
    # Now, the profile is incomplete for this role, if at least one question in
    # +questions_to_be_answered+ is unaswered by this user.
    return (questions_to_be_answered - self.member.answered_profile_questions)
  end

  def accessible_program_forums
    program_forums = self.program.forums.program_forums
    program_forums = program_forums.for_role(self.role_names) unless self.can_manage_forums?
    program_forums
  end

  def add_user_directly?(roles)
    return false unless roles.present?
    res = true
    res &&= self.can_manage_admins? if roles.include?(RoleConstants::ADMIN_NAME)
    res &&= self.can_add_non_admin_profiles? if (roles - [RoleConstants::ADMIN_NAME]).present?
    return res
  end

  def allowed_to_send_message?(other_user)
    return true if self.program.allow_user_to_send_message_outside_mentoring_area?
    return true if self.is_admin?
    return true if self.common_groups(other_user, :active).any?(&:scraps_enabled?)
    return self.has_accepted_flash_mentoring_meeting_with?(other_user)
  end

  def set_last_profile_update_time
    # This is set to see when the user has last updated his program specific profile
    DelayedEsDocument.skip_es_delta_indexing do
      self.update_attribute(:profile_updated_at, Time.now)
    end
  end

  def hide_profile_completion_bar!
    update_attribute(:hide_profile_completion_bar, true)
  end

  # This function returns whether current user can add user from other program using track level permission.
  def import_members_from_subprograms?
    self.is_admin? && self.program.allow_track_admins_to_access_all_users
  end

  # This is to update the roles of user from console.
  # This is not exposed to the end-user
  # ==== Arguments:
  # * <tt>roles_names</tt> : An array of the new role_names for the user
  def update_roles(roles_names)
    self.role_names = roles_names
    self.save!
  end

  #
  # Returns the list of activities to show for the user.
  #
  def activities_to_show(opts = {})
    all_activities = []
    include_options = [:ref_obj, :member => [:users, :profile_picture, :active_programs]]

    if opts[:connection]
      self.groups.each do |group|
        all_activities << group.activities.joins(:programs).includes(include_options).for_display.latest_first.fetch_with_offset(
          opts[:per_page], opts[:offset_id], {}
        ).to_a
      end
      all_activities.flatten!.uniq! unless all_activities.empty?
      all_activities.sort!{|r1, r2| r2.id <=> r1.id}
    else
      role_scope = if self.is_admin?; RecentActivityConstants::Scope::ADMIN
      elsif self.is_mentor_and_student?; RecentActivityConstants::Scope::MENTOR_AND_STUDENT
      elsif self.is_mentor?; RecentActivityConstants::Scope::MENTOR
      elsif self.is_student?; RecentActivityConstants::Scope::STUDENT
      elsif self.roles.non_administrative.non_default.any?; RecentActivityConstants::Scope::OTHER_NON_ADMINISTRATIVE_ROLES
      else RecentActivityConstants::Scope::ALL
      end

      all_activities = program.recent_activities.joins(:programs).includes(include_options).send("for_#{role_scope}", self).for_display
      all_activities = all_activities.by_member(opts[:actor]) if opts[:actor]
      all_activities = all_activities.with_upper_offset(opts[:offset_id]) if opts[:offset_id]
      all_activities = all_activities.with_length(opts[:per_page])
      exclude_types = ra_exclude_types
      all_activities = all_activities.not_of_types(exclude_types) if exclude_types.any?
      all_activities = all_activities.to_a
    end
    last_id = all_activities[-1] ? all_activities[-1].id : false
    all_activities.reject!{|act| act.ref_obj.blank?} # No reference object, and hence nothing to display.

    [all_activities, last_id]
  end

  def skype_id
    skype_question = self.program.organization.profile_questions.skype_question.first
    return nil unless skype_question.present?
    skype_answer = self.answer_for(skype_question)
    return skype_answer.present? ? skype_answer.answer_text : nil
  end

  def accessible_resources(options = {})
    resource_query = self.program.resource_publications
    resource_query = resource_query.joins(role_resources: :role).where(roles: { name: self.role_names, program_id: self.program_id } ) unless options[:admin_view]
    resource_query = get_quick_access_or_pinned_resources(resource_query) if options[:only_quick_links]

    resource_ids = options[:resource_ids] || []
    resource_ids = resource_ids.concat(get_orderded_resource_ids(resource_query, options)).uniq
    resource_ids_string = resource_ids.join(",")
    resources = Resource.where(id: resource_ids).order(resource_ids_string.present? ? "field(id,#{resource_ids_string})" : "")
    if options[:only_quick_links]
      get_default_resources_for_pinning(resource_ids, resources, options)
    else
      resources
    end
  end

  def get_default_resources_for_pinning(resource_ids, resources, options={})
    return resources unless resources.count < Resource::RESOURCE_PINNED_THRESHOLD && options[:resources_widget]
    self.accessible_resources(admin_view: options[:admin_view], only_quick_links: false, resource_ids: resource_ids).limit(Resource::RESOURCE_PINNED_THRESHOLD)
  end

  def get_accessible_admin_view_ids(options = {})
    admin_view_ids = options[:admin_view_ids].present? ? options[:admin_view_ids] : program.admin_views.pluck(:id)
    AdminViewUserCache.where(admin_view_id: admin_view_ids).select{|admin_view_user_cache| admin_view_user_cache.get_admin_view_user_ids.include?(self.id)}.collect(&:admin_view_id)
  end

  def get_orderded_resource_ids(resource_query, options={})
    if options[:sort_field] == "title"
      Resource.where(id: resource_query.pluck(:resource_id)).order_by_translated_field(:title, options[:sort_order]).pluck(:id)
    else
      resource_query.order("resource_publications.position #{options[:sort_order]}").pluck(:resource_id)
    end.uniq
  end

  def get_quick_access_or_pinned_resources(resource_publications)
    admin_view_ids = resource_publications.pluck(:admin_view_id).uniq.compact
    admin_view_ids = self.get_accessible_admin_view_ids(admin_view_ids: admin_view_ids)
    resource_publications.where("show_in_quick_links in (?) OR admin_view_id in (?)", true, admin_view_ids)
  end

  def get_meeting_slots_booked_in_the_month(view_date)
    start_time, end_time = Meeting.fetch_start_end_time_for_the_month(view_date)
    meetings = self.member.meetings.of_program(self.program).accepted_meetings.between_time(start_time, end_time)
    recurrent_meetings = Meeting.recurrent_meetings(meetings, {start_time: start_time, end_time: end_time, get_occurrences_between_time: true, get_merged_list: true})
    return recurrent_meetings.size
  end

  def get_received_pending_meeting_requests_in_the_month(view_date)
    pending_requests_ids = self.pending_received_meeting_requests.pluck(:id)
    start_time, end_time = Meeting.fetch_start_end_time_for_the_month(view_date)
    requests_with_proposed_slots = self.pending_received_meeting_requests.joins(:meeting_proposed_slots).pluck(:id)
    requests_with_proposed_slots_in_the_interval = MeetingProposedSlot.where(:meeting_request_id => requests_with_proposed_slots).earliest_slots.between_time(start_time, end_time).pluck(:meeting_request_id).uniq
    requests_with_no_slots_in_the_interval = self.member.meetings.of_program(self.program).between_time(start_time, end_time).where(:meeting_request_id => (pending_requests_ids - requests_with_proposed_slots))
    return (requests_with_proposed_slots_in_the_interval + requests_with_no_slots_in_the_interval).size
  end

  def is_capacity_reached_for_current_and_next_month?(view_date, student, options = {})
    error_message = ""
    is_mentor_capacity_reached_current_month = self.is_max_capacity_user_reached?(view_date)
    is_mentor_capacity_reached_next_month = self.is_max_capacity_user_reached?(view_date.next_month)
    is_meeting_capacity_reached_current_month = student.is_student_meeting_limit_reached?(view_date)
    is_meeting_capacity_reached_next_month = student.is_student_meeting_limit_reached?(view_date.next_month)
    is_request_capacity_reached = student.is_student_meeting_request_limit_reached?

    is_capacity_reached_current_month = is_mentor_capacity_reached_current_month || is_meeting_capacity_reached_current_month || is_request_capacity_reached

    is_capacity_reached_next_month = is_mentor_capacity_reached_next_month || is_meeting_capacity_reached_next_month || is_request_capacity_reached

    customized_meeting_term = self.program.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase
    customized_meeting_term_plural = self.program.term_for(CustomizedTerm::TermType::MEETING_TERM).pluralized_term_downcase
    if is_capacity_reached_current_month && is_capacity_reached_next_month
      if is_mentor_capacity_reached_current_month && is_mentor_capacity_reached_next_month
        error_message = "feature.meetings.content.mentor_limit_exceeded_tooltip".translate(meetings: customized_meeting_term_plural, mentor_name: self.member.name(:name_only => true))
      elsif is_meeting_capacity_reached_current_month && is_meeting_capacity_reached_next_month
        error_message = "feature.meetings.content.mentee_meeting_limit_exceeded_tooltip".translate(meeting: customized_meeting_term, meetings: customized_meeting_term_plural)
      elsif (is_mentor_capacity_reached_current_month || is_mentor_capacity_reached_next_month) && (is_meeting_capacity_reached_current_month || is_meeting_capacity_reached_next_month)
         error_message = "feature.meetings.content.mentee_meeting_limit_exceeded_tooltip".translate(meeting: customized_meeting_term, meetings: customized_meeting_term_plural)
      else
        error_message = "feature.meetings.content.mentee_request_limit_exceeded_tooltip_v1".translate(meeting: customized_meeting_term)
      end
      return options[:error_message] ? [true, error_message.html_safe] : true
    end
    return false, error_message
  end

  def is_meeting_capacity_reached?(view_date, student = nil)
    self.is_max_capacity_user_reached?(view_date) || self.is_max_capacity_program_reached?(view_date, student)
  end

  def is_max_capacity_setting_initialized?
    self.user_setting.present? && self.user_setting.max_meeting_slots.present?
  end

  def is_max_capacity_user_reached?(view_date)
    return true if self.is_mentoring_slots_limit_reached?(view_date)
    return false unless self.is_max_capacity_setting_initialized?
    meeting_slots = self.get_meeting_slots_booked_in_the_month(view_date)
    pending_requests = self.get_received_pending_meeting_requests_in_the_month(view_date)
    is_meeting_slots_more_than_the_allowed_slots?((meeting_slots + pending_requests), self.user_setting.max_meeting_slots)
  end

  def is_mentoring_slots_limit_reached?(view_date)
    return false if (@available_mentor_member_ids.present? && @available_mentor_member_ids.include?(self.member.id)) || !self.is_opted_for_slot_availability?
    start_time, end_time = Meeting.fetch_start_end_time_for_the_month(view_date)
    all_slots = self.member.get_mentoring_slots(start_time, end_time)
    slots_after_meetings = self.member.get_member_availability_after_meetings(all_slots, start_time, end_time, @current_program)
    slots_after_meetings.size.zero?
  end

  def is_max_capacity_program_reached?(view_date, student)
    return false if student.nil?
    student.is_student_meeting_limit_reached?(view_date) || student.is_student_meeting_request_limit_reached?
  end

  def is_student_meeting_limit_reached?(view_date)
    program = self.program
    return false unless (program.is_max_capacity_student_setting_initialized?)
    accepted_or_unanswered_meetings = self.get_meeting_slots_booked_in_the_month(view_date)
    allowed_meetings = program.calendar_setting.max_meetings_for_mentee
    return accepted_or_unanswered_meetings >= allowed_meetings
  end

  def is_student_meeting_request_limit_reached?
    program = self.program
    return false unless (program.calendar_setting.max_pending_meeting_requests_for_mentee.present?)
    pending_requests = self.pending_sent_meeting_requests.size
    allowed_requests = program.calendar_setting.max_pending_meeting_requests_for_mentee
    return pending_requests >= allowed_requests
  end

  def can_create_meeting?(program)
    self.is_mentor? && program.calendar_setting.allow_create_meeting_for_mentor && program.calendar_enabled?
  end

  def can_be_shown_group_start_date?(group)
    ((group.drafted? && self.is_admin?) || group.proposed? || group.pending?) && (self.is_admin? || group.has_member?(self))
  end

  def can_set_start_date_for_group?(group)
    connection_membership = group.membership_of(self)
    self.is_admin? || (connection_membership.present? && connection_membership.owner)
  end

  def can_create_group_without_approval?
    self.roles.select{ |role| !role.needs_approval_to_create_circle? }.present?
  end

  def can_be_shown_proposed_groups?
    self.can_manage_connections? || !self.can_create_group_without_approval? || self.groups.proposed.present?
  end

  def has_non_admin_role?
    self.roles.find{|r| !r.administrative}.present?
  end

  def self.get_profile_questions_ratio_for_user_hash(user_hash, include_default_type, options, profile_answers_hash)
    user_questions = []
    questions = options.delete(:questions)
    all_questions = questions[:all]
    editable_questions = questions[:editable_by_user]
    user_role_names = options[:users_role_names][user_hash['id']]
    is_admin = user_role_names.include?(RoleConstants::ADMIN_NAME)

    user_role_names.each do |role|
      if editable_questions.present? && !is_admin
        user_questions += editable_questions[role] if editable_questions[role].present?
      elsif all_questions.present?
        user_questions += all_questions[role] if all_questions[role].present?
      end
    end

    grouped_answers = profile_answers_hash[is_admin ? :all_answers : :editable_by_user_answers][user_hash['member_id']]

    user_question_ids = user_questions.select { |q| q.conditional_text_matches?(grouped_answers) }.collect(&:id).uniq

    answered_question_ids = user_question_ids & grouped_answers.keys

    image_answered = options[:users_pictures].has_key?(user_hash['id'])
    answered_questions_size = image_answered ? (answered_question_ids.size.to_f + 1.0) : answered_question_ids.size.to_f
    # All questions + image
    all_questions_size = user_question_ids.size + 1

    image_ratio = 1.0 / all_questions_size
    questions_ratio = answered_questions_size / all_questions_size

    [questions_ratio, image_ratio, image_answered]
  end

  def get_profile_questions_ratio_for_user(include_default_type = true, options = {})
    user_questions = []
    questions = options.delete(:questions)
    role_names = self.roles.collect(&:name)

    if questions.present? && !self.is_admin?
      role_names.each do |role|
        if questions[role].present?
          user_questions += questions[role]
        end
      end
      user_questions.uniq!
    else
      program = self.program
      user_questions = program.profile_questions_for(role_names, {:default => include_default_type, :skype => program.organization.skype_enabled?, :dont_include_section => true,  pq_translation_include: false}.merge(options))
    end

    all_answers = self.member.profile_answers

    grouped_answers = all_answers.group_by(&:profile_question_id)
    user_question_ids = user_questions.select { |q| q.conditional_text_matches?(grouped_answers) }.collect(&:id)

    answered_question_ids = all_answers.select { |ans| user_question_ids.include?(ans.profile_question_id) }

    image_answered = self.member.profile_picture
    answered_questions_size = image_answered ? (answered_question_ids.size.to_f + 1.0) : answered_question_ids.size.to_f
    # All questions + image
    all_questions_size = user_question_ids.size + 1

    image_ratio = 1.0 / all_questions_size
    questions_ratio = answered_questions_size / all_questions_size

    [questions_ratio, image_ratio, image_answered]
  end

  def requires_signup?
    self.last_seen_at.nil? && !self.member.can_signin?
  end

  def ask_to_set_availability?
    self.program.calendar_setting.allow_mentor_to_configure_availability_slots? && self.can_set_availability? && self.member.will_set_availability_slots?
  end

  def withdraw_active_requests!
    if connection_limit_as_mentee_reached?
      self.sent_mentor_requests.active.update_all(status: AbstractRequest::Status::WITHDRAWN)
    end
  end

  def withdraw_active_meeting_requests!(view_date)
    return unless self.is_student_meeting_limit_reached?(view_date)

    start_time, end_time = Meeting.fetch_start_end_time_for_the_month(view_date)
    self.pending_sent_meeting_requests.includes(:meeting_proposed_slots).each do |meeting_request|
      if meeting_request.meeting_proposed_slots.blank? || meeting_request.meeting_proposed_slots.between_time(start_time, end_time).exists?
        meeting_request.update_status!(self, AbstractRequest::Status::WITHDRAWN)
      end
    end
  end

  def student_document_available?
    MatchingDocument.where(:program_id => self.program_id, :record_id => self.id, :mentor => false).exists?
  end

  def can_manage_admin_role_for(user, program)
    self.can_manage_admins? && (user != program.owner) && (program.standalone? || !user.member.admin?)
  end

  def can_view_role?(role_name)
    self.is_admin? || self.send("can_view_#{role_name.pluralize}?")
  end

  def visible_non_admin_roles
    program_role_names = self.program.roles.non_administrative.pluck(:name)
    return program_role_names if self.is_admin?
    program_role_names.select { |role_name| self.send("can_view_#{role_name.pluralize}?") }
  end

  def can_invite_roles?
    return true if self.is_admin?
    self.program.roles.collect(&:name).each do |role_name|
      return true if Permission.find_by(name: "invite_#{role_name.pluralize}").present? && self.send("can_invite_#{role_name.pluralize}?")
    end
    return false
  end

  def get_visible_favorites
    user_states = [User::Status::ACTIVE]
    user_states += [User::Status::PENDING] if self.is_admin?
    self.user_favorites.joins(:favorite).where(users: {state: user_states})
  end

  def student_cache_normalized(for_admin = false)
    if for_admin
      setting = program.match_setting
      min_max = [setting.min_match_score, setting.max_match_score]
    else
      min_max = Matching::Database::Score.new.get_min_max_by_mentee_id(self.id).compact
    end
    mentor_ids = self.program.get_user_ids_based_on_roles(RoleConstants::MENTOR_NAME)
    results = ScoreNormalizer.normalize_for([self.id], mentor_ids, min_max)
    mark_zero_for_ignored_mentors(results[self.id] || {}, for_admin)
  end

  def mark_zero_for_ignored_mentors(results, for_admin)
    return results if for_admin || !self.program.skip_and_favorite_profiles_enabled?
    ignored_user_ids = self.ignored_users.pluck(:id)
    results.each { |k, _v| results[k] = 0 if ignored_user_ids.include?(k) } 
  end

  def self.partition_on_notification_setting(users_relation)
    [
      users_relation.where(users: {program_notification_setting: UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE}),
      users_relation.where(users: {program_notification_setting: UserConstants::DigestV2Setting::ProgramUpdates::NONE}),
      users_relation.where(users: {program_notification_setting: UserConstants::DigestV2Setting::ProgramUpdates::DAILY}),
      users_relation.where(users: {program_notification_setting: UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY})
    ]
  end

  def can_connect_to_mentor?(mentor, match_results = nil)
    is_allowed = true
    unless self.program.allow_non_match_connection?
      mentor_match_score = match_score(mentor.id, match_results)
      is_allowed = mentor_match_score && !mentor_match_score.zero?
    end
    !!is_allowed # !!nil => false; !!true => true; !!false => false
  end

  def match_score(mentor_id, match_results = nil)
    match_results ||= self.student_document_available? && self.student_cache_normalized
    (match_results || nil) && match_results[mentor_id] # should return nil or value. match_results itself can be false, thus we should return nil in this case.
  end

  def get_mentee_recos_to_mentor
    program = self.program
    mentee_recos = program.student_users.active.select{ |mentee| !mentee.connection_limit_as_mentee_reached? } - self.students
    mentee_match_score_hash = {}
    mentee_recos.each do |mentee|
      mentee_match_score = mentee.match_score(self.id)
      if mentee_match_score && !mentee_match_score.zero?
        mentee_match_score_hash[mentee.id] = mentee_match_score
      end
    end
    relevant_mentee_recos = program.student_users.active.where(:id => mentee_match_score_hash.keys).sort_by{|user| -(mentee_match_score_hash[user.id]||0)}
    mentees_list = []
    relevant_mentee_recos.each do |mentee|
      mentees_list << {mentee: mentee, score: mentee_match_score_hash[mentee.id]}
    end
    mentees_list
  end

  def get_notes_hash
    recommendation_preferences = self.try(:mentor_recommendation).try(:recommendation_preferences)
    return {} unless recommendation_preferences
    notes_hash = {}
    recommendation_preferences.each do |rp|
      notes_hash[rp.preferred_user.id] = rp.note
    end
    notes_hash
  end

  def is_recommended?(student)
    student.mentor_recommendation.try(:recommended_users).try(:include?, self)
  end

  #TODO - Remove after cache score fix is pushed in [To prioritize small jobs]
  def get_dj_priority
    (self.program.present? && self.program.users.size < 5000) ? DjPriority::MONGO_DELTA_INDEX : DjPriority::MONGO_BIG_INDEX
  end

  def can_change_connection_limit?(limit)
    return false if limit < 0

    connection_limit = self.program.connection_limit_permission
    case connection_limit
    when Program::ConnectionLimit::NONE
      return false
    when Program::ConnectionLimit::ONLY_DECREASE
      return self.program.default_max_connections_limit >= limit
    when Program::ConnectionLimit::ONLY_INCREASE
      return self.program.default_max_connections_limit <= limit
    when Program::ConnectionLimit::BOTH
      return true
    end
  end

  def can_apply_for_join?(group)
    can_send_project_request? && group.open? && !group.has_member?(self) && group.available_roles_for_user_to_join(self).present? && !self.has_pending_request?(group)
  end

  def has_pending_request?(group)
    self.sent_project_requests.where(group_id: group.id).active.exists?
  end

  def ra_type_conditions
    type_conditions_str = "programs.id=?"
    type_conditions_data = [program_id]
    unless (exclude_types = ra_exclude_types).empty?
      type_conditions_str << " AND recent_activities.action_type NOT IN (?)"
      type_conditions_data << exclude_types
    end
    [type_conditions_str, type_conditions_data]
  end

  def ra_role_conditions
    role_scope_proc = case
      when is_admin?
        RecentActivity::ScopeConditions::ADMIN
      when is_mentor_and_student?
        RecentActivity::ScopeConditions::MENTOR_MENTEE
      when is_mentor?
        RecentActivity::ScopeConditions::MENTOR
      when is_student?
        RecentActivity::ScopeConditions::MENTEE
      when roles.non_administrative.non_default.exists?
        RecentActivity::ScopeConditions::OTHER_NON_ADMINISTRATIVE_ROLE
      else
        RecentActivity::ScopeConditions::ALL
      end

    role_condition, *role_condition_data = role_scope_proc.call(self)[:conditions]

    [role_condition, role_condition_data]
  end

  def unanswered_questions
    questions_for_completion = []
    program_questions = program.profile_questions_for(self.role_names, {:default => false, :skype => program.organization.skype_enabled?, user: self, :edit => true})
    all_answers = self.member.profile_answers.includes([:profile_question, :location, :answer_choices]).group_by(&:profile_question_id)

    program_questions.each do |question|
      questions_for_completion << question if all_answers[question.id].blank? && question.conditional_text_matches?(all_answers)
    end

    ProfileQuestion.sort_listing_page_filters(questions_for_completion)
  end

  def meeting_request_average_reponse_time
    meeting_requests  = self.received_meeting_requests.accepted + self.received_meeting_requests.rejected
    return nil if meeting_requests.count == 0
    total_time = 0
    meeting_requests.each do |request|
      total_time += request.updated_at - request.created_at
    end
    average_time = total_time/(meeting_requests.size * 1.hours)
    average_time.round(2)
  end

  def mentor_request_average_reponse_time
    mentor_requests  = self.received_mentor_requests.accepted + self.received_mentor_requests.rejected
    return nil if mentor_requests.count == 0
    total_time = 0
    mentor_requests.each do |request|
      total_time += request.updated_at - request.created_at
    end
    average_time = total_time/(mentor_requests.size * 1.hours)
    average_time.round(2)
  end

  def meeting_request_acceptance_rate
    meeting_requests = self.received_meeting_requests
    responded_meeting_request = meeting_requests.accepted + meeting_requests.rejected
    responded_meeting_request.count == 0 ? 0 : (meeting_requests.accepted.count*100.0/(responded_meeting_request.count)).round(2)
  end

  def mentor_request_acceptance_rate
    mentor_requests = self.received_mentor_requests
    responded_mentor_request = mentor_requests.accepted + mentor_requests.rejected
    responded_mentor_request.count == 0 ? 0 : (mentor_requests.accepted.count*100.0/(responded_mentor_request.count)).round(2)
  end

  def is_available_for_ongoing_and_one_time_mentoring?
    self.program.consider_mentoring_mode? && self.mentoring_mode == User::MentoringMode::ONE_TIME_AND_ONGOING
  end

  def is_available_only_for_ongoing_mentoring?
    self.program.consider_mentoring_mode? && self.mentoring_mode == User::MentoringMode::ONGOING
  end

  def is_available_only_for_one_time_mentoring?
    self.program.consider_mentoring_mode? && self.mentoring_mode == User::MentoringMode::ONE_TIME
  end

  def opting_for_ongoing_mentoring?(program=nil)
    program ||= self.program
    !program.consider_mentoring_mode? || User::MentoringMode.ongoing_sanctioned.include?(self.mentoring_mode)
  end

  def opting_for_one_time_mentoring?(program=nil)
    program ||= self.program
    !program.consider_mentoring_mode? || User::MentoringMode.one_time_sanctioned.include?(self.mentoring_mode)
  end

  def can_update_goal_progress?(group)
    group.active? && group.mentors.include?(self)
  end

  def state_transition_allowed_in_api?(to_status)
    return (to_status != User::Status::SUSPENDED) || self.can_be_removed_or_suspended?
  end

  def get_state_based_message(custom_terms = {})
    if self.profile_pending?
      if self.is_mentor?
        return "flash_message.user_flash.profile_not_published_admin_view".translate
      elsif self.is_student?
        return "flash_message.user_flash.user_signup_process_incomplete".translate(user: self.name)
      end
    elsif self.suspended? && !self.member.suspended?
      return "flash_message.user_flash.user_suspended_v2".translate(user: self.name, program: custom_terms[:program])
    elsif self.suspended? && self.member.suspended?
      return "flash_message.user_flash.membership_suspended_v1".translate(member: self.name, programs: custom_terms[:programs])
    end
  end

  def pending_mentor_request_of?(other_user)
    other_user.present? && self.is_mentor? && other_user.is_student? && self.received_mentor_requests.active.from_student(other_user).first
  end

  def public_groups_available_for_others_to_join
    self.groups.active_or_pending.global
  end

  def can_render_calendar_ui_elements?(role)
    program.calendar_enabled? && can_view_mentoring_calendar? && role == RoleConstants::MENTOR_NAME
  end

  def mentoring_mode_option_text
    case self.mentoring_mode
    when User::MentoringMode::ONGOING
      "feature.admin_view.mentoring_model_preference.ongoing".translate(Mentoring: self.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term)
    when User::MentoringMode::ONE_TIME
      "feature.admin_view.mentoring_model_preference.one_time".translate(Mentoring: self.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term)
    when User::MentoringMode::ONE_TIME_AND_ONGOING
      "feature.admin_view.mentoring_model_preference.one_time_and_ongoing".translate(Mentoring: self.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term)
    else
      "display_string.NA".translate
    end
  end

  def ordered_viewed_by_users_from_last_program_update(count, options = {ignore_self: true})
    start_time = [last_program_update_sent_time, 1.week.ago].max
    selected_users = []
    profile_views.where(created_at: (start_time..(Time.current))).order('id desc').includes(:viewed_by).map(&:viewed_by).uniq.each do |user|
      break if selected_users.size >= count
      next if options[:ignore_self] && self == user
      selected_users << user if user.visible_to?(self)
    end
    selected_users
  end

  def digest_v2_work_or_education
    experience = digest_v2_get_sorted_experience_object
    return digest_v2_work(experience) if experience
    education = member.educations.sort_by { |edu| edu.graduation_year.to_i }.last
    return digest_v2_education(education) if education
    {}
  end

  # Please eager load the necessary objects beforehand
  def get_selected_connection_membership_and_details_for_digest_v2
    project_based_program = program.project_based?
    selected_connection_membership_details = {}
    selected_connection_memberships = if digest_v2_group_update_required?
      period_length = UserConstants::DigestV2Setting::GroupUpdates.days_count[group_notification_setting]
      connection_memberships.select do |membership|
        if membership.group.active? || (project_based_program && membership.group.pending?)
          selected_connection_membership_details[membership.id] = {}
          selected_connection_membership_details[membership.id][:upcoming_tasks] = membership.group.mentoring_model_tasks.required.upcoming(period_length).owned_by(self)
          selected_connection_membership_details[membership.id][:pending_tasks] = membership.group.mentoring_model_tasks.required.overdue_in_last(period_length.days).owned_by(self)
          selected_pending_notifications = membership.pending_notifications.select{ |pending_notification| DigestV2::MEMBERSHIP_PENDING_NOTIFICATION_TO_PRIORITY.keys.include?(pending_notification.action_type) }.sort_by{ |pending_notification| DigestV2::MEMBERSHIP_PENDING_NOTIFICATION_TO_PRIORITY[pending_notification.action_type] }
          # need to split this code into smaller methods
          member_update_pending_notification_added = false
          discussion_related_pending_notification_added = {}
          selected_pending_notifications_with_cleanup = []
          selected_pending_notifications.each do |pending_notification|
            if pending_notification.action_type == RecentActivityConstants::Type::GROUP_MEMBER_UPDATE
              unless member_update_pending_notification_added
                selected_pending_notifications_with_cleanup << pending_notification
                member_update_pending_notification_added = true
              end
            elsif pending_notification.action_type.in?([RecentActivityConstants::Type::TOPIC_CREATION, RecentActivityConstants::Type::POST_CREATION])
              topic_id = pending_notification.ref_obj.is_a?(Topic) ? pending_notification.ref_obj.id : pending_notification.ref_obj.topic.id
              unless discussion_related_pending_notification_added[topic_id] || self.is_topic_or_post_viewed?(pending_notification.ref_obj)
                selected_pending_notifications_with_cleanup << pending_notification
                discussion_related_pending_notification_added[topic_id] = true
              end
            else
              selected_pending_notifications_with_cleanup << pending_notification
            end
          end
          selected_connection_membership_details[membership.id][:pending_notifications] = selected_pending_notifications_with_cleanup
          selected_connection_membership_details[membership.id][:upcoming_tasks].present? || selected_connection_membership_details[membership.id][:pending_tasks].present? || selected_connection_membership_details[membership.id][:pending_notifications].present?
        else
          false
        end
      end
    else
      []
    end
    selected_connection_memberships.sort_by! { |membership| get_selected_connection_memberships_priority_for_digest_v2(selected_connection_membership_details[membership.id]) }
    [selected_connection_memberships, selected_connection_membership_details]
  end

  # Please eager load the necessary objects beforehand
  def get_received_requests_count_and_action
    received_mentor_requests_count = received_mentor_requests.select(&:active?).size
    received_meeting_requests_count = received_meeting_requests.select(&:active?).size
    received_mentor_offers_count = received_mentor_offers.select(&:pending?).size
    call_to_action, url_params = if received_meeting_requests_count > 0
      [:meeting_requests_url]
    elsif received_mentor_requests_count > 0
      [:mentor_requests_url, filter: AbstractRequest::Filter::TO_ME]
    elsif received_mentor_offers_count > 0
      [:mentor_offers_url]
    else
      []
    end
    [received_mentor_requests_count + received_meeting_requests_count + received_mentor_offers_count, (Array(call_to_action) << (url_params || {}))]
  end

  def immediate_program_update?
    program_notification_setting == UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE
  end

  def digest_v2_weekly_program_update?
    program_notification_setting == UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY
  end

  def digest_v2_daily_program_update?
    program_notification_setting == UserConstants::DigestV2Setting::ProgramUpdates::DAILY
  end

  def digest_v2_program_update?
    program_notification_setting.in?([UserConstants::DigestV2Setting::ProgramUpdates::DAILY, UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY])
  end

  def digest_v2_group_update_required?
    group_notification_setting.in?([UserConstants::DigestV2Setting::GroupUpdates::DAILY, UserConstants::DigestV2Setting::GroupUpdates::WEEKLY]) && (last_group_update_sent_time < digest_v2_group_update_start_time)
  end

  def digest_v2_program_update_required?
    digest_v2_program_update? && (last_program_update_sent_time < digest_v2_program_update_start_time)
  end

  def digest_v2_required?
    digest_v2_group_update_required? || digest_v2_program_update_required?
  end

  def is_topic_or_post_viewed?(topic_or_post)
    posts_ids = topic_or_post.is_a?(Topic) ? topic_or_post.posts.pluck(:id) : [topic_or_post.id]
    self.viewed_objects.where(ref_obj_type: "Post", ref_obj_id: posts_ids).size > 0
  end

  def has_accepted_flash_mentoring_meeting_with?(user)
     user_accepted_meeting_ids = user.member.accepted_meetings.of_program(user.program).non_group_meetings.pluck(:id)
     current_user_accepted_meeting_ids = self.member.accepted_meetings.of_program(self.program).non_group_meetings.pluck(:id)
     common_accepted_meeting_ids = user_accepted_meeting_ids & current_user_accepted_meeting_ids
     return !common_accepted_meeting_ids.empty?
  end

  def can_send_mentor_request_to_mentor_with_error_flash?(mentor, custom_terms)
    program = self.program
    error_flash_message = ""
    can_send_request = self.can_send_mentor_request? && program.only_career_based_ongoing_mentoring_enabled? && program.matching_by_mentee_alone?

    if !mentor.opting_for_ongoing_mentoring?
      can_send_request = false
      error_flash_message = "feature.mentor_request.content.no_longer_valid_request.mentor_does_not_allow_ongoing_mentoring_v1".translate(mentoring_connection: custom_terms[:mentoring_connection], meetings: custom_terms[:meetings], mentor_name: mentor.name, :click_here => ActionController::Base.helpers.link_to('display_string.Click_here'.translate, Rails.application.routes.url_helpers.member_path(mentor.member, :root => mentor.program.root)))
    elsif program.groups.involving(self, mentor).count > 0
      can_send_request = false
      error_flash_message = "feature.mentor_request.content.no_longer_valid_request.already_connected".translate(mentoring_connection: custom_terms[:mentoring_connection], mentors: custom_terms[:mentors], mentor_name: mentor.name, :mentors_page => ActionController::Base.helpers.link_to('display_string.here'.translate, Rails.application.routes.url_helpers.users_path(:root => program.root)))
    elsif mentor.received_mentor_requests.from_student(self).active.count > 0
      can_send_request = false
      error_flash_message = "feature.mentor_request.content.no_longer_valid_request.duplicate_request_to_mentor".translate(mentoring_connection: custom_terms[:mentoring_connection], mentors: custom_terms[:mentors], mentor_name: mentor.name, :mentors_page => ActionController::Base.helpers.link_to('display_string.here'.translate, Rails.application.routes.url_helpers.users_path(:root => program.root)))
    elsif !program.allow_mentoring_requests?
      can_send_request = false
      error_flash_message = program.allow_mentoring_requests_message.blank? ? "feature.mentor_request.content.no_longer_valid_request.blocked_by_admin".translate(mentoring_connection: custom_terms[:mentoring_connection], mentors: custom_terms[:mentors], program: custom_terms[:program], admin: custom_terms[:admin]) : program.allow_mentoring_requests_message
    elsif self.connection_limit_as_mentee_reached?
      can_send_request = false
      error_flash_message = "feature.mentor_request.content.no_longer_valid_request.limit_for_mentee_reached".translate(mentoring_connection: custom_terms[:mentoring_connection], mentoring_connections: custom_terms[:mentoring_connections])
    elsif self.pending_request_limit_reached_for_mentee?
      can_send_request = false
      error_flash_message = "feature.mentor_request.content.no_longer_valid_request.request_limit_for_mentee_reached".translate(:click_here => ActionController::Base.helpers.link_to('display_string.Click_here'.translate, Rails.application.routes.url_helpers.mentor_requests_path(:root => program.root)), mentoring_connection: custom_terms[:mentoring_connection])
    elsif (mentor.slots_available_for_mentor_request <= 0) || (!mentor.active?)
      can_send_request = false
      error_flash_message = "feature.mentor_request.content.no_longer_valid_request.mentor_slots_unavailable".translate(mentoring_connection: custom_terms[:mentoring_connection], mentors: custom_terms[:mentors], mentor_name: mentor.name, :mentors_page => ActionController::Base.helpers.link_to('display_string.here'.translate, Rails.application.routes.url_helpers.users_path(:root => program.root)))
    end

    return can_send_request, error_flash_message
  end

  def self.get_active_roles_and_membership_info(user_ids)
    user_ids.uniq!

    user_id_connection_memberships_map = Connection::Membership.select("connection_memberships.user_id, GROUP_CONCAT(DISTINCT(connection_memberships.role_id)) as role_ids").where(user_id: user_ids).of_active_criteria_groups.group("connection_memberships.user_id").index_by(&:user_id)

    user_id_connection_memberships_with_group_info_map = Connection::Membership.joins(:group).select("connection_memberships.id, groups.status as group_status, connection_memberships.user_id").where(user_id: user_ids).group_by(&:user_id)

    user_id_active_role_and_membership_info_map = {}
    user_ids.each do |user_id|
      user_id_active_role_and_membership_info_map[user_id] = {}
      active_group_role_ids = user_id_connection_memberships_map[user_id].try {|membership| membership[:role_ids].split(",").collect(&:to_i)}
      user_id_active_role_and_membership_info_map[user_id][:role_ids_in_active_groups] = (active_group_role_ids || [])
      memberships = user_id_connection_memberships_with_group_info_map[user_id] || []
      memberships.each do |membership|
        user_id_active_role_and_membership_info_map[user_id][membership.id] = { from_state: membership.group_status, to_state: membership.group_status }
      end
    end

    user_id_active_role_and_membership_info_map
  end

  def get_unanswered_program_events
    program_events = self.program.program_events.published.for_user(self)
    unanswered_events = program_events.upcoming - self.event_invites.includes([:program_event]).collect(&:program_event).uniq
    unanswered_events.select{|event| !event.archived? && event.has_current_user_as_attendee?(self)}
  end

  def can_be_shown_meetings_listing?
    program = self.program
    user_meetings = self.member.meetings.of_program(program)

    (program.calendar_enabled? && (!self.is_available_only_for_ongoing_mentoring? || user_meetings.present?)) || (program.mentoring_connection_meeting_enabled? && (!program.mentoring_connections_v2_enabled? || self.can_be_shown_mm_meetings?))
  end

  def can_be_shown_mm_meetings?
    program_roles = self.program.roles.for_mentoring
    self.groups.published.inject(false){|can_have_mm_meetings, group| can_have_mm_meetings || group.can_manage_mm_meetings?(program_roles)}
  end

  def can_be_removed_or_suspended?
    (self != self.program.owner) && (self.program.standalone? ? !self.member.is_chronus_admin? : !self.member.admin?)
  end

  def can_remove_or_suspend?(user)
    (self != user) && self.is_admin? && user.can_be_removed_or_suspended?
  end

  def self.removal_or_suspension_scope(users_scope, program, wob_member_id)
    organization = program.organization
    member_ids_ignored = [wob_member_id]
    member_ids_ignored << program.owner.member_id if program.owner.present?

    if program.standalone?
      chronus_admin = organization.chronus_admin
      member_ids_ignored << chronus_admin.id if chronus_admin.present?
    else
      member_ids_ignored += organization.members.admins.pluck(:id)
    end
    users_scope.where.not(member_id: member_ids_ignored)
  end

  def can_connect_with_a_mentor?
    (self.is_student? && self.can_view_mentors? && (self.program.matching_by_mentee_alone? || self.program.calendar_enabled? || self.program.matching_by_mentee_and_admin?))
  end

  def can_connect_with_a_mentee?
    (self.is_mentor? && self.can_view_students? && self.program.mentor_offer_enabled? && self.opting_for_ongoing_mentoring?)
  end

  def can_be_shown_connection_tab_or_widget?
    self.program.ongoing_mentoring_enabled? && (self.roles.for_mentoring.exists? && (self.program.project_based? || ((self.groups.active.present? || self.groups.closed.present?) && (self.opting_for_ongoing_mentoring? || self.groups.active.present?))))
  end

  def can_be_shown_connection_widget?
    can_be_shown_connection_tab_or_widget? && self.get_active_or_recently_closed_groups.count > 0
  end

  def can_be_shown_flash_meetings_widget?
    self.program.only_one_time_mentoring_enabled? || (self.program.calendar_enabled? && !self.can_be_shown_connection_widget?)
  end

  def allowed_to_ignore_and_mark_favorite?
    self.program.skip_and_favorite_profiles_enabled? && self.can_ignore_and_mark_favorite?
  end

  def get_groups_to_display_in_publish_circle_widget
    groups_to_display = self.owned_groups.includes([:mentors, :students, :members]).pending.pending_more_than(PUBLISH_CIRCLES_WIDGET_PENDING_DURATION.ago)
    groups_to_display = groups_to_display.select{|group| group.can_be_published?}
    get_ordered_groups_inside_publish_circle_widget(groups_to_display)
  end

  def is_unconnected?
    program = self.program
    upcoming_meetings_count = self.member.meetings.of_program(self.program).non_group_meetings.accepted_meetings.upcoming.count
    active_groups_count =  self.groups.active.count
    if program.calendar_enabled? && program.ongoing_mentoring_enabled?
       upcoming_meetings_count == 0 && active_groups_count == 0
    elsif program.calendar_enabled?
      upcoming_meetings_count == 0
    elsif program.ongoing_mentoring_enabled?
      active_groups_count == 0
    end
  end

  def get_active_or_recently_closed_groups
    #get only active groups for now
    self.groups.active.includes(:members).order(last_member_activity_at: :desc)
  end

  def can_connect_with_mentor_and_has_slots?(can_connect_with_a_mentor)
    program = self.program
    self.is_student? && can_connect_with_a_mentor && (program.calendar_enabled? || (program.allow_mentoring_requests? && !self.connection_limit_as_mentee_reached? && !self.pending_request_limit_reached_for_mentee?))
  end

  def can_be_shown_match_tab?(can_connect_with_a_mentor)
    program = self.program
    self.can_connect_with_mentor_and_has_slots?(can_connect_with_a_mentor) || (self.is_mentor? && !can_connect_with_a_mentor && self.can_offer_mentoring? && self.can_mentor? && self.can_connect_with_a_mentee?)
  end

  def get_mentor_limit_to_reset
    ongoing_connections = self.students(:active).count
    default_limit = self.program.default_max_connections_limit
    if self.program.connection_limit_permission == Program::ConnectionLimit::ONLY_INCREASE
      if ongoing_connections <  default_limit
        default_limit
      elsif ongoing_connections < self.max_connections_limit
        ongoing_connections
      end
    elsif self.program.connection_limit_permission == Program::ConnectionLimit::ONLY_DECREASE || self.program.connection_limit_permission == Program::ConnectionLimit::BOTH
        ongoing_connections if ongoing_connections < self.max_connections_limit || ongoing_connections <  default_limit
    end
  end

  def get_meeting_limit_to_reset
    current_time = Time.now
    slot_filled_this_month = self.get_meeting_slots_booked_in_the_month(current_time)
    slot_filled_next_month = self.get_meeting_slots_booked_in_the_month(current_time.next_month)
    [slot_filled_this_month, slot_filled_next_month].max
  end

  def close_pending_received_requests_and_offers
    program = self.program

    reason_for_closing_request = "feature.mentor_request.content.receiver_unavailable".translate(receiver: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term)
    reason_for_closing_offer = "feature.mentor_request.content.receiver_unavailable".translate(receiver: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term)
    close_pending_received_requests_or_offers(self.pending_received_mentor_requests, MentorRequest, reason_for_closing_request)
    close_pending_received_requests_or_offers(self.pending_received_meeting_requests, MeetingRequest, reason_for_closing_request)
    close_pending_received_requests_or_offers(self.pending_received_mentor_offers, MentorOffer, reason_for_closing_offer)
  end

  def can_see_match_details?
    self.program.match_configs.with_label.present?
  end

  def get_match_details_answer_pairs(user)
    details = []
    if can_see_match_details? && self.is_student? && user.is_mentor?
      client = Matching::Client.new(self.program, true)
      details = client.service.get_match_details(self.id, user.id)
    end
    return process_match_details(details)
  end

  def can_see_match_details_of?(user, options = {})
    if self.explicit_preferences_configured? && !options[:show_match_config_matches]
      get_match_details_of_explicit_preferences(user).collect{|tag| tag[:answers]}.flatten.present?
    else
      answers = []
      details = get_match_details_answer_pairs(user)
      answers = details.collect{|detail| detail.last}.flatten if details.present?
      answers.compact.present?
    end
  end

  def get_unconnected_user_widget_content_list
    content_list = []
    widget_content = self.unconnected_user_widget_content
    widget_content.each do |object|
      content_list << {object: object} unless content_list.include?({object: object})
    end
    append_unconnected_user_widget_new_content_list(content_list)
  end

  def append_unconnected_user_widget_new_content_list(content_list)
    program = self.program
    if content_list.size < Program::UNCONNECTED_USER_WIDGET_TILES_COUNT && program.articles_enabled? && self.can_write_article?
      content_list << {new_content: true, klass: Article.to_s}
    end
    if content_list.size < Program::UNCONNECTED_USER_WIDGET_TILES_COUNT && program.forums_enabled?
      content_list += self.unconnected_user_widget_forum_list(Program::UNCONNECTED_USER_WIDGET_TILES_COUNT - content_list.size)
    end
    if content_list.size < Program::UNCONNECTED_USER_WIDGET_TILES_COUNT && program.qa_enabled? && self.can_ask_question?
      content_list << {new_content: true, klass: QaQuestion.to_s}
    end
    content_list
  end

  def unconnected_user_widget_forum_list(count)
    subscribed_program_forums = self.subscribed_forums.program_forums
    other_program_forums = self.accessible_program_forums - subscribed_program_forums
    (subscribed_program_forums + other_program_forums).first(count).map{|forum| {object: forum}}
  end

  def unconnected_user_widget_content
    program = self.program
    allowed_role_ids = self.role_ids + [nil]
    widget_content = []
    view_options = {articles: program.articles_enabled? && self.can_view_articles?, forums: program.forums_enabled?, qa: program.qa_enabled? && self.can_view_questions?}
    self.program.unconnected_user_widget_content(view_options).select{|hsh| hsh[:role_id].in?(allowed_role_ids)}.each do |hsh|
      widget_content << hsh[:object]
      break if widget_content.size >= Program::UNCONNECTED_USER_WIDGET_TILES_COUNT
    end
    widget_content
  end

  def get_match_details_of(user, program_questions_for_user, show_match_config_matches = false)
    (self.explicit_preferences_configured? && !show_match_config_matches)  ? get_match_details_of_explicit_preferences(user) : get_match_details_of_match_configs(user, program_questions_for_user)
  end

  def get_match_details_of_match_configs(user, program_questions_for_user)
    details = get_match_details_answer_pairs(user)
    return [] if details.blank? || program_questions_for_user.blank?
    details = details.sort {|a,b| b[0] <=> a[0]}
    match_configs = get_match_configs_from_match_details(details)
    mentor_question_ids = match_configs.collect{|config| config.mentor_question.profile_question_id}
    mentor_profile_answers = user.member.profile_answers.where(profile_question_id: mentor_question_ids).group_by(&:profile_question_id)
    get_tags_from_profile_details(details, match_configs, mentor_profile_answers, program_questions_for_user)
  end

  def get_match_configs_from_match_details(details)
    match_config_ids = details.collect{|d| d[1]}
    self.program.match_configs.where(id: match_config_ids).includes(:mentor_question)
  end

  def get_match_details_of_explicit_preferences(mentor)
    mentor_profile_answers = mentor.profile_answers
    answered_question_choice_ids = AnswerChoice.where(ref_obj_id: mentor_profile_answers.pluck(:id), ref_obj_type: ProfileAnswer.name).pluck(:question_choice_id)
    mentor_profile_answers = mentor_profile_answers.index_by(&:profile_question_id)
    answered_question_choices = QuestionChoice.where(id: answered_question_choice_ids)
    explicit_preferences = self.explicit_user_preferences.includes(question_choices: :translations, role_question: :profile_question)
    explicit_preferences.includes(role_question: :profile_question).collect do |preference|
      {
        question_text: preference.role_question.profile_question.question_text,
        answers: get_matched_answer_text_with_explicit_preferences(preference, mentor_profile_answers, answered_question_choices)
      }
    end
  end

  def get_matched_answer_text_with_explicit_preferences(preference, mentor_profile_answers, answered_question_choices)
    preference_profile_question = preference.role_question.profile_question
    if preference_profile_question.location?
      if mentor_profile_answers[preference_profile_question.id].present?
        mentor_location = mentor_profile_answers[preference_profile_question.id].location
        [mentor_location.full_city, mentor_location.full_state, mentor_location.full_country].select{|location| location == preference.preference_string}
      else
        []
      end
    else
      (preference.question_choices & answered_question_choices).collect(&:text)
    end
  end

  def get_visibile_match_config_profile_questions_for(user)
    mentor_match_config_question_ids = user.program.match_configs.with_label.pluck(:mentor_question_id)
    role_questions_with_email = self.program.role_questions_for(user.role_names, user: self).role_profile_questions.where(id: mentor_match_config_question_ids).includes(profile_question: [:section, {question_choices: :translations}])
    return role_questions_with_email.to_a.select{|q| q.visible_for?(self, user)}.collect(&:profile_question)
  end

  def get_active_announcements
    self.program.announcements.for_user(self).published.not_expired.ordered
  end

  def get_ordered_active_announcements
    active_announcements = self.get_active_announcements
    viewed_announcement_ids = ViewedObject.where(ref_obj_id: active_announcements.pluck(:id), ref_obj_type: "Announcement", user_id: self.id).pluck(:ref_obj_id)
    viewed_announcement_ids += active_announcements.where("announcements.updated_at < ? ", Announcement::VIEWABLE_CUTOFF_DATE.to_datetime).pluck(:id)
    viewed_announcements = active_announcements.where(id: viewed_announcement_ids)
    unviewed_announcements = active_announcements - viewed_announcements
    unviewed_announcements + viewed_announcements
  end

  def get_active_unviewed_announcements_count
    self.get_active_announcements.where("announcements.updated_at >= ? ", Announcement::VIEWABLE_CUTOFF_DATE.to_datetime).joins("LEFT OUTER JOIN viewed_objects ON announcements.id = viewed_objects.ref_obj_id AND viewed_objects.ref_obj_type = 'Announcement' AND viewed_objects.user_id = #{self.id}").where( viewed_objects: { id: nil } ).count
  end

  def handle_destroy
    program = self.program
    Matching.remove_user_later(self.id, program)
    CampaignManagement::AbstractCampaignMessage.reset_sender_id_for(self.id)
    member = Member.find_by(id: self.member_id)
    if member.present?
      if member.has_no_users?
        member.update_attributes!(state: Member::Status::DORMANT) if member.active?
        destroy_user_member_meetings
        member.destroy if program.standalone?
      else
        destroy_user_activities
        destroy_user_membership_requests
        destroy_user_member_meetings
      end
    end
  end

  def email_with_id_hash
    {
      nameEmail: self.name_with_email,
      userId: self.id,
      nameEmailForDisplay: h(self.name_with_email)
    }
  end

  def valid_favorite_users
    self.favorite_users
  end

  def get_cummulative_unviewed_posts(topic_ids)
    topic_ids = Topic.where(id: topic_ids).where("updated_at > ?", Topic::VIEWABLE_CUTOFF_DATE.to_datetime).pluck(:id)
    Post.where("posts.user_id != ? AND topic_id IN (?)", self.id, topic_ids).joins("LEFT OUTER JOIN viewed_objects ON posts.id = viewed_objects.ref_obj_id AND viewed_objects.ref_obj_type = 'Post' AND viewed_objects.user_id = #{self.id}").where( viewed_objects: { id: nil } )
  end

  def get_unviewed_posts_count_by_topic(group, topic_ids)
    return {} unless group.has_member?(self)
    self.get_cummulative_unviewed_posts(topic_ids).group(:topic_id).count
  end

  def can_see_guidance_popup?
    program = self.program
    !OneTimeFlag.has_tag?(self, OneTimeFlag::Flags::Popups::MENTEE_GUIDANCE_POPUP_TAG) && self.is_student? && self.can_view_mentors? && self.not_sent_any_meeting_or_mentoring_requests? && program.self_match_and_not_pbe?
  end

  def not_sent_any_meeting_or_mentoring_requests?
    self.sent_mentor_requests.count.zero? && self.sent_meeting_requests.count.zero?
  end

  def explicit_preferences_configured?
    program.explicit_user_preferences_enabled? && explicit_user_preferences.any?
  end

  def can_configure_explicit_preferences?
    program.explicit_user_preferences_enabled? && is_student?
  end

  # Allow user with mentor role to add the mentee role without any approval and similarly allow mentee to add mentor role.
  # If current user is admin or have third role alone, then we dont allow to add role without approval.
  def get_applicable_role_to_add_without_approval(program = self.program)
    return if self.is_admin?

    applicable_roles = RoleConstants::AUTO_APPROVAL_ROLE_MAPPING.keys
    applicable_current_roles = self.roles.includes(:permissions).where(name: applicable_roles)
    return if applicable_current_roles.blank? || (applicable_roles - applicable_current_roles.pluck(:name)).empty?

    current_role = applicable_current_roles[0]
    to_add_role_name = RoleConstants::AUTO_APPROVAL_ROLE_MAPPING[current_role.name]
    return unless to_add_role_name.present? && current_role.has_permission_name?("become_#{to_add_role_name}")

    program.roles.find_by(name: to_add_role_name)
  end

  def allowed_to_edit_max_connections_limit?(program, is_admin_view = false)
    program.only_career_based_ongoing_mentoring_enabled? && self.is_mentor? && (program.allow_mentor_update_maxlimit? || is_admin_view)
  end

  def can_view_match_report?
    self.program.can_show_match_report? && self.can_view_reports?
  end

  def roles_for_proposing_groups
    self.roles.for_mentoring.with_permission_name(RolePermission::PROPOSE_GROUPS).select{ |role| self.allow_project_requests_for_role?(role) }
  end

  def allow_to_propose_groups?
    self.roles_for_proposing_groups.any?
  end

  def allow_project_requests_for_role?(role)
    role.no_limit_on_project_requests? || self.get_memberships_of_open_or_proposed_groups_with_role(role).size < role.max_connections_limit
  end

  def get_memberships_of_open_or_proposed_groups_with_role(role)
    return self.connection_memberships.select{ |membership| membership.of_open_or_proposed_group? && membership.with_role?(role) } if self.connection_memberships.loaded?
    self.connection_memberships.of_open_or_proposed_groups.with_role(role)
  end

  def get_active_sent_project_requests_for_role(role)
    return self.sent_project_requests.select{ |project_request| project_request.active? && project_request.with_role?(role) } if self.sent_project_requests.loaded?
    self.sent_project_requests.active.with_role(role)
  end

  def can_view_preferece_based_mentor_lists?
    program.preferece_based_mentor_lists_enabled? && (can_send_mentor_request? || (program.calendar_enabled? && is_student?))
  end

  protected

  def check_state_changer_must_be_admin
    unless self.state_changer.can_manage_user_states? && self.program == self.state_changer.program
      errors.add(:state_changer, "activerecord.custom_errors.user.no_privilege".translate)
    end
  end

  def check_group_students_count_is_less_than_max_connections_limit
    errors.add(:max_connections_limit,  UserConstants::NEGATIVE_CONNECTIONS_LIMIT_ERROR_MESSAGE) if self.errors.added?(:max_connections_limit, :greater_than_or_equal_to, :count => 0)
    if (self.changes[:max_connections_limit] && !self.changes[:max_connections_limit][0].nil?) && !self.updated_by_admin
      if self.max_connections_limit < self.students.size
        errors.add(:max_connections_limit,  UserConstants::MAX_CONNECTIONS_LIMIT_ERROR_MESSAGE)
      elsif !self.new_record? && !self.can_change_connection_limit?(self.max_connections_limit)
        errors.add(:max_connections_limit, UserConstants::CAN_CHANGE_CONNECTIONS_LIMIT_ERROR_MESSAGE)
      end
    end
  end

  def check_cannot_reactivate_when_member_suspended
    if self.state_changed? && self.state_was == Status::SUSPENDED && self.member.suspended?
      errors.add(:member, "activerecord.custom_errors.user.cannot_reactivate".translate)
    end
  end

  def check_cannot_add_suspended_member_to_program
    if self.member.present? && self.member.suspended?
      customized_program_term = self.member.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase
      errors.add(:member, "activerecord.custom_errors.user.cannot_add_suspended_member".translate(program: customized_program_term))
    end
  end

  def set_last_weekly_updates_sent_time
    time_now = Time.now
    self.last_program_update_sent_time = time_now
    self.last_group_update_sent_time   = time_now
  end

  def recent(since)
    where(['users.created_at > ?', since])
  end

  def self.es_reindex_for_profile_score(role_ids)
    return if role_ids.blank?
    user_ids = RoleReference.where(role_id: role_ids, ref_obj_type: User.name).pluck(:ref_obj_id).uniq
    DelayedEsDocument.delayed_bulk_partial_update_es_documents(User, user_ids, User::ES_PARTIAL_UPDATES[:profile_score][:index_fields], User::ES_PARTIAL_UPDATES[:profile_score][:includes_list])
  end

  private

  def destroy_user_member_meetings
    member_meetings = self.member.member_meetings
    member_meetings.each do |mem_meeting|
      mem_meeting.destroy if mem_meeting.get_meeting.program == self.program
    end
  end

  def get_ordered_groups_inside_publish_circle_widget(groups)
    groups_hash_array = groups.map{|group| {object: group, pending_for: (Date.today - group.pending_at.to_date).to_i, members_count: group.members.count}}
    groups_hash_array = groups_hash_array.sort_by{|group| [-1 * group[:pending_for], -1 * group[:members_count]]}
    groups_hash_array.map{|group| group[:object]}
  end

  #To destroy the corresponding program activities for the user and destoy recent activity if
  #these are the only program activities for it
  def destroy_user_activities
    program = self.program
    recent_activities = program.recent_activities.where(:member_id => self.member.id).includes(:program_activities)
    recent_activities.each do |ra|
      ra_program_activities = ra.program_activities
      program_activities = ra_program_activities.in_program(program)
      (ra_program_activities.size == program_activities.size) ? ra.destroy : program_activities.destroy_all
    end
  end

  def destroy_user_membership_requests
    membership_requests = self.member.membership_requests
    membership_requests.each do |mem_req|
      mem_req.destroy if mem_req.program == self.program
    end
  end

  def process_match_details(details)
    match_details = []
    details.each do |detail|
      match_details << detail if (detail[0].present? && detail[1].present? && detail[2].present? && detail[2].is_a?(Array))
    end
    return match_details
  end

  def get_tags_from_profile_details(details, match_configs, mentor_profile_answers, program_questions_for_user)
    tags = []
    details.each do |detail|
      match_config = match_configs.find{|config| config.id == detail[1]}
      if match_config.present?
        mentor_q = program_questions_for_user.find{|pq| pq.id == match_config.mentor_question.profile_question_id}
        next unless mentor_q.present?
        prefix = match_config.prefix.present? ? "#{match_config.prefix} - " : ""
        answer_values = get_answer_values(mentor_profile_answers, mentor_q)
        answers = []
        if detail.last.present?
          if mentor_q.location?
            answers << "#{prefix}#{answer_values[0]}"
          else
            detail.last.compact.each do |d|
              answer_index = answer_values.find_index {|item| item.casecmp(d.to_s) == 0 }
              answers << "#{prefix}#{answer_values[answer_index]}" if answer_index.present?
            end
          end
        end
        tags << {answers: answers, question_text: mentor_q.question_text} if answers.present?
      end
    end
    tags
  end

  def get_answer_values(mentor_profile_answers, mentor_q)
    answer_values = []
    mentor_profile_answer = mentor_profile_answers[mentor_q.id]
    if mentor_profile_answer.present?
      mentor_profile_answer = mentor_profile_answer[0]
      answer_values = mentor_q.location? ? mentor_profile_answer.location.try(:city).to_s : mentor_profile_answer.answer_value(mentor_q)
      answer_values = answer_values.is_a?(String) ? [answer_values] : answer_values
    end
    answer_values
  end

  def close_pending_received_requests_or_offers(pending_objects, klass, reason)
    if pending_objects.present?
      pending_objects.each { |object| object.close!(reason) }
      if klass < AbstractRequest
        klass.delay.send_close_request_mail(pending_objects.to_a, true, false)
      else
        klass.delay.send_close_offer_mail(pending_objects.collect(&:id), true, false)
      end
    end
  end

  def get_answer_for(question, is_new_member)
    (!is_new_member && (answer = self.answer_for(question)).present?) ? answer : ProfileAnswer.new(:ref_obj_id => self.member_id, :ref_obj_type => Member.to_s, :profile_question => question)
  end

  def is_meeting_slots_more_than_the_allowed_slots?(meeting_slots, allowed_slots)
    (meeting_slots - allowed_slots) >= 0
  end

  def get_selected_connection_memberships_priority_for_digest_v2(details)
    return 0 if details[:pending_tasks].present?
    return 1 if details[:upcoming_tasks].present?
    return 2 if details[:pending_notifications].present?
    3
  end

  def digest_v2_work(experience)
    hsh = {}
    hsh[:company] = experience.company
    if experience.job_title.present?
      hsh[:key] = :experience_with_job_title
      hsh[:job_title] = experience.job_title
    else
      hsh[:key] = :experience_without_job_title
    end
    hsh
  end

  def digest_v2_get_sorted_experience_object
    # get current job, or the latest one if possible
    member.experiences.sort_by { |exp| 1e9*(exp.current_job ? 1 : 0) + 1e2*(exp.end_year.to_i) + exp.end_month.to_i }.last
  end

  def digest_v2_education(education)
    {school_name: education.school_name, key: :school_name}
  end

  def digest_v2_update_start_time(days_count)
    (Time.now - days_count.days) + DigestV2Utils::Trigger::ALLOWED_HOURS_TO_SEND_EMAILS.hours # 7 - 10 am, 3 hours bandwidth
  end

  def digest_v2_group_update_start_time
    digest_v2_update_start_time(UserConstants::DigestV2Setting::GroupUpdates.days_count[group_notification_setting])
  end

  def digest_v2_program_update_start_time
    digest_v2_update_start_time(UserConstants::DigestV2Setting::ProgramUpdates.days_count[program_notification_setting])
  end

  def has_role_visible_to?(other_user)
    self.roles.non_administrative.any? { |role| other_user.send("can_view_#{role.name.pluralize}?") }
  end

  def unsubscribe_from_obj(obj_ids, obj_class)
    self.subscriptions.where("ref_obj_id IN (?) AND ref_obj_type = ?", obj_ids ,obj_class).destroy_all
  end

  def sent_more_than_a_week?
    self.last_weekly_update_sent_time < WEEKLY_UPDATE_PERIOD.ago
  end

  def self.insert_role_references(role_reference_inserts)
    slice_size = 500
    role_reference_inserts.each_slice(slice_size) do |bulk_inserts|
      sql = "INSERT INTO role_references (ref_obj_id,ref_obj_type,role_id,created_at,updated_at) VALUES#{bulk_inserts.join(',')};"
      Role.connection.insert(sql)
    end
  end

  def self.update_role_references(program, user_ids, roles_to_add)
    role_reference_inserts = []
    created_at = Time.now
    user_class_name = User.name

    all_ids_to_update = []

    roles_to_add.each do |role|
      # take only users without this role
      user_ids_to_update = user_ids - program.all_users.where(id: user_ids).joins(:role_references).where("role_references.role_id" => role.id).pluck(:id)
      all_ids_to_update += user_ids_to_update

      if RoleConstants::MENTOR_NAME == role.name
        User.where(id: user_ids_to_update).where(max_connections_limit: nil).
          update_all(max_connections_limit: program.default_max_connections_limit)
      end

      # build collection of role-references to insert
      role_reference_inserts += user_ids_to_update.map do |id|
        "(#{id},'#{user_class_name}',#{role.id},'#{created_at.to_s(:db)}','#{created_at.to_s(:db)}')"
      end
    end

    insert_role_references(role_reference_inserts)

    all_ids_to_update.uniq
  end

  def self.promote_to_admin_role(program, user_ids, role_names_to_add)
    if program.standalone? && [RoleConstants::ADMIN_NAME] == role_names_to_add
      Member.joins(:users).where('users.id' => user_ids).update_all(admin: true)
      delay.build_admins_for_program(user_ids)
    end
  end

  def self.build_admins_for_program(user_ids)
    User.where(id: user_ids).includes(member: :programs).references(member: :programs).find_each do |user|
      (user.member.organization.programs - user.member.programs).each do |program|
        user = user.member.users.build
        user.program = program
        user.role_names = [RoleConstants::ADMIN_NAME]
      end
    end
  end

  def ra_exclude_types
    exclude_types = []

    unless program.articles_enabled?
      exclude_types += [RecentActivityConstants::Type::ARTICLE_CREATION, RecentActivityConstants::Type::ARTICLE_MARKED_AS_HELPFUL, RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION]
    end

    unless program.forums_enabled?
      exclude_types += [RecentActivityConstants::Type::FORUM_CREATION, RecentActivityConstants::Type::POST_CREATION]
    end

    unless program.qa_enabled?
      exclude_types += [RecentActivityConstants::Type::QA_QUESTION_CREATION, RecentActivityConstants::Type::QA_ANSWER_CREATION]
    end

    unless program.allow_join_now?
      exclude_types += [RecentActivityConstants::Type::CREATE_MEMBERSHIP_REQUEST]
    end

    if program.mentoring_connections_v2_enabled?
      exclude_types += (Connection::Activity::SUPPORTED_ACTIVITIES + Connection::Activity::SUPPORTED_NON_MEMBER_ACTIVITIES).uniq
    end
    exclude_types += [RecentActivityConstants::Type::MEETING_CREATED, RecentActivityConstants::Type::MEETING_UPDATED, RecentActivityConstants::Type::MEETING_DECLINED, RecentActivityConstants::Type::MEETING_ACCEPTED]
    exclude_types.uniq
  end

  def self.get_state_roles_map(user_ids, state_attr = "state")
    user_roles_scope = User.where(id: user_ids).joins(:role_references).
      select("users.id AS user_id, GROUP_CONCAT(role_references.role_id) AS role_ids, users.state AS #{state_attr}").
      group("role_references.ref_obj_id")
    ActiveRecord::Base.connection.select_all(user_roles_scope)
  end

  def construct_user_groups_map(groups, relation)
    groups.inject({}) do |user_groups_map, group|
      group.send(relation).each do |user|
        user_groups_map[user] ||= []
        user_groups_map[user] << group
      end
      user_groups_map
    end
  end
end
