# == Schema Information
#
# Table name: groups
#
#  id                      :integer          not null, primary key
#  program_id              :integer
#  created_at              :datetime
#  updated_at              :datetime
#  status                  :integer          default(0)
#  termination_reason      :text(65535)
#  terminator_id           :integer
#  closed_at               :datetime
#  expiry_time             :datetime
#  termination_mode        :integer
#  last_activity_at        :datetime
#  logo_file_name          :string(255)
#  logo_content_type       :string(255)
#  name                    :string(255)
#  logo_file_size          :integer
#  logo_updated_at         :datetime
#  global                  :boolean          default(FALSE)
#  delta                   :boolean          default(FALSE)
#  last_member_activity_at :datetime
#  published_at            :datetime
#  bulk_match_id           :integer
#  creator_id              :integer
#  notes                   :text(65535)
#  mentoring_model_id      :integer
#  pending_at              :datetime
#  version                 :integer          default(1)
#  closure_reason_id       :integer
#

class Group < ActiveRecord::Base

  include GroupElasticsearchQueries
  include GroupElasticsearchSettings

  MASS_UPDATE_ATTRIBUTES = {
    create: [:name, :logo, :notes, :message, :start_date],
    update_notes: [:notes]
  }

  EXPIRY_NOTICE_SERVING_PERIOD = 2.weeks
  EXTENSION_NOTICE_SERVING_PERIOD = 1.week
  NO_ACTIVITY_INTERVAL = 30.days
  BADGE_COUNT_INTERVAL = 14
  GROUP_SURVEY_RESPONSE_COUNT = 10
  AUTO_PUBLISH_CRON_DURATION_DIFFERENCE = 13

  CONNECTION_NAME_SORT = "LOWER(CONCAT(TRIM(groups.name)))"
  DEFAULT_VISIBLE_CHOICES = 10

  NAME_TRUNCATE_LENGTH = 30

  # Possible states of the connection.
  module Status
    ACTIVE    = 0 # Atleast one member is active.
    INACTIVE  = 1 # No member is active.
    CLOSED    = 2 # Terminated.
    DRAFTED   = 3 # Not Published
    PENDING   = 4 # Currently applicable only for project based mentoring
    PROPOSED  = 5 # Currently applicable only for project based mentoring
    REJECTED  = 6 # Currently applicable only for project based mentoring
    WITHDRAWN = 7 # Currently applicable only for project based mentoring

    def self.all
      (ACTIVE..WITHDRAWN)
    end

    def self.all_published
      (ACTIVE..CLOSED)
    end

    def self.slots_availability_filter_allowed_states
      [PENDING, ACTIVE, CLOSED, REJECTED, WITHDRAWN]
    end

    ACTIVE_CRITERIA = [Status::ACTIVE, Status::INACTIVE]
    NOT_ACTIVE_CRITERIA = [Status::CLOSED, Status::DRAFTED, Status::PENDING, Status::PROPOSED, Status::REJECTED, Status::WITHDRAWN]
    NOT_PUBLISHED_CRITERIA = [Status::DRAFTED, Status::PENDING, Status::PROPOSED, Status::REJECTED, Status::WITHDRAWN]
    OPEN_CRITERIA = [Status::PENDING, Status::ACTIVE, Status::INACTIVE]
    USER_TO_BE_ACTIVATED_CRITERIA = [Status::ACTIVE, Status::INACTIVE, Status::CLOSED, Status::PENDING]
  end

  # Possible modes of group termination/rejection
  module TerminationMode
    ADMIN = 0
    INACTIVITY = 1
    EXPIRY = 2
    LEAVING = 3
    REJECTION = 4
    WITHDRAWN = 5

    def self.termination_modes_for_notification
      (ADMIN..LEAVING)
    end

    def self.all
      constants.collect{|c| const_get(c)}
    end
  end

  module BulkAction
    PUBLISH = 0
    DISCARD = 1
    REACTIVATE = 2
    TERMINATE = 3
    SET_EXPIRY_DATE = 4
    EXPORT = 5
    ASSIGN_TEMPLATE = 6
    MAKE_AVAILABLE = 7
    ACCEPT_PROPOSAL = 8
    REJECT_PROPOSAL = 9
    WITHDRAW_PROPOSAL = 10
    DUPLICATE = 11
  end

  BulkActionLimit = {
    BulkAction::DUPLICATE => 10
  }

  module View
    DETAILED = 0
    LIST = 1
  end

  module AddOption
    ADD_TASKS = 0
    NO_TASK = 1
  end

  module RemoveOption
    REMOVE_TASKS = 0
    LEAVE_TASKS_UNASSIGNED = 1
  end

  module MemberUpdateAction
    NONE = "NONE"
    ADD = "ADD"
    REMOVE = "REMOVE"
    REPLACE = "REPLACE"
  end

  module Tabs
    MESSSAGES = "cjs_message_tabs"
    TASKS = "cjs_tasks_tab"
    MEETINGS = "cjs_meetings_tab a"
    FORUMS = "cjs_forum_tabs"
  end

  acts_as_object_role_permission_authorizable

  before_destroy :set_marked_for_destroy


  ##############################################################################
  # ASSOCIATIONS
  ##############################################################################

  belongs_to_program
  belongs_to :closed_by, :foreign_key => 'terminator_id', :class_name => "User"
  belongs_to :created_by, :foreign_key => 'creator_id', :class_name => "User"
  belongs_to :closure_reason, :foreign_key => 'closure_reason_id', :class_name => "GroupClosureReason"
  belongs_to :mentoring_model

  has_attached_file :logo, GROUP_LOGO_STORAGE_OPTIONS
  has_many :group_checkins, :dependent => :destroy
  has_many :task_checkins, -> { where(checkin_ref_obj_type: MentoringModel::Task.name) }, class_name: 'GroupCheckin', foreign_key: 'group_id'
  has_many :meeting_checkins, -> { where(checkin_ref_obj_type: MemberMeeting.name) }, class_name: 'GroupCheckin', foreign_key: 'group_id'

  has_many :scraps, :as => :ref_obj, :dependent => :nullify
  has_many :meetings, :dependent => :destroy
  has_many :coaching_goals, -> {order 'created_at DESC'}, :dependent => :destroy

  has_many :confidentiality_audit_logs, -> {order "id DESC"}, :dependent => :destroy
  has_many :connection_activities,
           :dependent => :destroy,
           :class_name => "Connection::Activity"

  # RecentActivities that belong to this connection.
  has_many :activities,
           :through => :connection_activities,
           :dependent => :destroy,
           :source => :recent_activity

  has_many :memberships,
           :class_name => "Connection::Membership",
           :dependent => :destroy,
           :inverse_of => :group

  has_many :student_memberships,
           :class_name => "Connection::MenteeMembership",
           :inverse_of => :group

  has_many :mentor_memberships,
           :class_name => "Connection::MentorMembership",
           :inverse_of => :group

  has_many :custom_memberships,
           :class_name => Connection::CustomMembership.name,
           :inverse_of => :group

  has_many :members,
           :through => :memberships,
           :source => :user

  has_many :students,
           :through => :student_memberships,
           :source => :user,
           :before_add => :set_member_added

  has_many :mentors,
           :through => :mentor_memberships,
           :source => :user,
           :before_add => :set_member_added

  has_many :custom_users,
           :through => :custom_memberships,
           :source => :user

  has_many :private_notes,
           :through => :memberships

  has_many :answers,
           :class_name => "Connection::Answer",
           :dependent => :destroy

  has_many :facilitation_delivery_logs, dependent: :destroy
  belongs_to :bulk_match

  has_many :mentoring_model_tasks, -> {order("mentoring_model_tasks.milestone_id ASC, mentoring_model_tasks.position ASC").includes([:translations])}, :class_name => MentoringModel::Task.name, :dependent => :destroy
  has_many :survey_answers, dependent: :destroy
  has_many :mentoring_model_goals, -> {order("id ASC").includes([:translations])}, :dependent => :destroy, :class_name => MentoringModel::Goal.name
  has_many :mentoring_model_milestones, -> {order("mentoring_model_milestones.position ASC").includes([:translations])}, dependent: :destroy, class_name: MentoringModel::Milestone.name
  has_many :membership_settings, dependent: :destroy, class_name: Group::MembershipSetting.name
  has_many :project_requests, dependent: :destroy, inverse_of: :group
  # This association is needed for eager loading
  has_many :active_project_requests,
            -> { where(mentor_requests: {status: AbstractRequest::Status::NOT_ANSWERED}) },
           :class_name => ProjectRequest.name

  has_many :owners,
            -> { where(connection_memberships: {owner: true}) },
           :through => :memberships,
           :source => :user

  has_many :state_changes, dependent: :destroy, class_name: GroupStateChange.name
  has_many :connection_membership_state_changes, dependent: :destroy, class_name: ConnectionMembershipStateChange.name

  has_many :membership_roles, -> { distinct }, through: :memberships, source: :role
  has_many :feedback_responses, :class_name => "Feedback::Response", :dependent => :nullify
  has_many :recent_activities, :as => :ref_obj, :dependent => :destroy
  has_many :mentor_offers
  has_many :admin_messages

  has_one :forum, dependent: :destroy
  has_many :topics, through: :forum
  has_many :posts, through: :topics
  has_many :pending_notifications, as: :ref_obj, dependent: :destroy
  has_many :push_notifications, :as => :ref_obj

  ##############################################################################
  # VALIDATIONS
  ##############################################################################

  validates :program, :name, presence: true
  validate :validate_roles
  validates_presence_of :closed_at, :if => Proc.new {|group| group.closed?}
  validates :closure_reason_id, presence: true, if: Proc.new {|group| group.closed?}
  validates :pending_at, presence: true, if: Proc.new {|group| group.pending?}
  validates_presence_of :created_by, :if => Proc.new {|group| group.drafted? || group.proposed? }, on: :create
  validates_presence_of :closed_by, :closed_at, :if => Proc.new {|group| group.rejected? }
  validates :termination_reason, :closed_by, :closed_at, presence: true, if: Proc.new { |group| group.withdrawn? }
  validates_inclusion_of :status, :in => Group::Status.all

  validates_attachment_content_type :logo, :content_type => PICTURE_CONTENT_TYPES
  validates_attachment_size         :logo, less_than: AttachmentSize::END_USER_ATTACHMENT_SIZE, message: Proc.new { "flash_message.message.file_attachment_too_big".translate(file_size: AttachmentSize::END_USER_ATTACHMENT_SIZE/ONE_MEGABYTE) }
  validates :termination_mode, inclusion: {in: TerminationMode.all}, allow_nil: true
  validates :expiry_time, :presence => true, :if => Proc.new {|group| group.published?}

  validate :check_closed_by_is_admin_or_auto_termination_or_leaving
  validate :check_students_count_for_one_to_one, :on => :create
  validate :check_mentee_limit_of_mentor
  validate :check_only_one_group_for_a_student_mentor_pair
  validate :check_expiry_time_is_valid, :if => Proc.new {|group| group.published?}
  validate :max_limit_of_a_role_in_project
  validate :check_for_mentors_mentoring_mode

  # Groups comprising the student and the mentor
  scope :involving, Proc.new {|student, mentor|
    join_sql = <<-SQL
      JOIN  connection_memberships AS mentor_memberships
      ON    groups.id = mentor_memberships.group_id
            AND mentor_memberships.type = 'Connection::MentorMembership'
      JOIN  connection_memberships AS mentee_memberships
      ON    groups.id = mentee_memberships.group_id
            AND mentee_memberships.type = 'Connection::MenteeMembership'
    SQL

    joins(join_sql).where([
          "mentee_memberships.user_id = ?" +
          " AND mentor_memberships.user_id = ?" +
          " AND groups.status != ?",
        student.id, mentor.id, Status::CLOSED])
  }

  scope :with_mentor, Proc.new {|mentor|
    joins(:mentor_memberships).where(['connection_memberships.user_id = ?', mentor.id])
  }

  scope :with_student, Proc.new {|student|
    joins(:student_memberships).where(['connection_memberships.user_id = ?', student.id])
  }

  scope :with_student_ids, Proc.new {|student_ids|
    joins(:student_memberships).where(['connection_memberships.user_id IN (?)', student_ids])
  }

  # this active includes all the connecitons which are not closed. The name is misleading, but it was named so before.
  scope :published, -> { where("groups.status IN (?)", Status.all_published)}
  scope :not_published, -> { where("groups.status IN (?)", Status::NOT_PUBLISHED_CRITERIA)}
  scope :active, -> { where("groups.status IN (?)", Status::ACTIVE_CRITERIA)}
  scope :closed, -> { where(:status => Status::CLOSED)}
  scope :drafted, -> { where("groups.status = ?", Status::DRAFTED)}
  scope :pending, -> { where("groups.status = ?", Status::PENDING)}
  scope :proposed, -> { where("groups.status = ?", Status::PROPOSED)}
  scope :rejected, -> { where("groups.status = ?", Status::REJECTED)}
  scope :withdrawn, -> { where("groups.status = ?", Status::WITHDRAWN)}
  scope :pending_less_than, Proc.new{|date_time| where("groups.pending_at > ?", date_time) }
  scope :pending_more_than, Proc.new{|date_time| where("groups.pending_at < ?", date_time) }
  # could have renamed the scope as open, but open is another method on ActiveRecord::Relation
  scope :open_connections, -> { where("groups.status IN (?)", Status::OPEN_CRITERIA)}
  scope :open_or_closed, -> { where("groups.status IN (?)", Status::OPEN_CRITERIA + [Status::CLOSED])}
  scope :active_or_drafted, -> { where("groups.status IN (?)", [Status::ACTIVE, Status::INACTIVE, Status::DRAFTED])}
  scope :active_or_closed, -> { where("groups.status IN (?)", [Status::ACTIVE, Status::INACTIVE, Status::CLOSED])}
  scope :with_status, Proc.new{|statuses| where(status: statuses) }
  scope :expired, -> { where("expiry_time < ?", Time.now.utc)}
  scope :global, -> { where(:global => true)}
  scope :created_by, Proc.new {|creator| where({creator_id: creator.id}) }
  scope :closed_between, Proc.new{|start_window, end_window| where({:closed_at => start_window.utc..end_window.utc})}
  scope :with_published_at, -> { where("groups.published_at is not NULL")}
  scope :recently_available_first, -> { order("ISNULL(published_at) DESC, published_at DESC, pending_at DESC") } # Show recently pending groups first and then recently published groups. 'ISNULL(published_at) DESC' pushes groups with (published_at = nil) to top.
  scope :active_or_pending, -> { where("groups.status IN (?)", [Status::ACTIVE, Status::INACTIVE, Status::PENDING])}
  scope :reject_groups_with_ids, Proc.new{|ids| where("groups.id NOT IN (?)", (ids.empty? ? '' : ids))}
  scope :active_between, Proc.new{|start_window, end_window| where("published_at IS NOT NULL AND published_at <= ? AND (closed_at IS NULL OR closed_at > ?)", end_window, start_window)}

  # Group.global is a protected a attribute
  # attr_protected :global

  # This is to have all the old students set of the group.
  # This is used in creating and destroying tasks for added students and removed students of the group
  attr_accessor :old_members_by_role, :all_old_students, :message, :actor, :skip_observer, :member_added,
   :offered_to, :_marked_for_destroy_, :make_proposer_owner, :last_status_change, :assigned_from_match, :add_member_option, :remove_member_option, :skip_student_mentor_validation

  delegate :project_based?, :to => :program

  ############################################################
  # Elasticsearch Indexing Methods
  ############################################################

  def has_overdue_tasks
    MentoringModel::Task.where(group_id: self.id, required: true, status: MentoringModel::Task::Status::TODO).where("due_date IS NOT NULL AND due_date < ?", Time.now.to_date).count > 0
  end

  def pending_project_requests_count
    active_project_requests.count
  end

  def role_ids
    Role.where(program_id: self.program_id).pluck(:id)
  end

  def activity_count
    self.connection_activities.count
  end

  def membership_setting_total_slots
    @roles_for_mentoring_hash ||= get_roles_for_mentoring_hash
    @roles_for_mentoring_hash.keys.collect do |role_name|
      {role_name => membership_setting_total_slots_for_role(@roles_for_mentoring_hash[role_name])}
    end
  end

  def membership_setting_slots_taken
    @roles_for_mentoring_hash ||= get_roles_for_mentoring_hash
    @roles_for_mentoring_hash.keys.collect do |role_name|
      {role_name => membership_setting_slots_taken_for_role(@roles_for_mentoring_hash[role_name])}
    end
  end

  def membership_setting_slots_remaining
    @roles_for_mentoring_hash ||= get_roles_for_mentoring_hash
    @roles_for_mentoring_hash.keys.collect do |role_name|
      {role_name => (membership_setting_total_slots_for_role(@roles_for_mentoring_hash[role_name]) - membership_setting_slots_taken_for_role(@roles_for_mentoring_hash[role_name]))}
    end
  end

  def role_users_full_name
    role_hash = get_non_default_roles_for_mentoring_hash
    role_hash.keys.collect do |role_name|
      user_names = self.memberships.select{ |membership| membership.role_id == role_hash[role_name] }.collect{|membership| membership.user.name_only }.join(" ")
      {"#{role_name}_name" => user_names}
    end
  end

  ##############################################################################
  # CLASS METHODS
  ##############################################################################

  def self.create_tasks_for_added_memberships(group_id, added_memberships_ids)
    group = Group.find(group_id)
    added_memberships = group.memberships.where(:id => added_memberships_ids)
    Group::MentoringModelCloner.new(group, group.program, group.mentoring_model, added_memberships).copy_template_tasks_for_memberships if group.present?
  end

  # Checks the activity status of all connected members across all programs
  # and notifies them about inactivity.
  def self.track_inactivities
    programs = Program.where.not(inactivity_tracking_period: nil).includes(active_groups: :memberships)

    BlockExecutor.iterate_fail_safe(programs) do |program|
      BlockExecutor.iterate_fail_safe(program.active_groups) do |group|
        group.track_member_statuses
        is_group_inactive = group.memberships.all?(&:inactive?)
        group.status = is_group_inactive ? Group::Status::INACTIVE : Group::Status::ACTIVE
        group.save! if group.status_changed?

        # Terminate connection if it is inactive for more than INACTIVITY_NOTICE_PERIOD
        if is_group_inactive && program.auto_terminate?
          group_inactive_from = group.memberships.map(&:last_status_update_at).compact.max
          is_group_inactive_for_more_than_grace_period = (Time.now - group_inactive_from) > Connection::Membership::INACTIVITY_NOTICE_PERIOD
          group.auto_terminate_due_to_inactivity! if is_group_inactive_for_more_than_grace_period
        end
      end
    end
  end

  # Terminate all expired connections which are active
  def self.terminate_expired_connections
    groups = Group.expired.active.includes(:program)
    program_id_closure_reason_map = GroupClosureReason.default.completed.where(program_id: groups.pluck(:program_id)).index_by(&:program_id)
    program_id_mentoring_connection_term_map = {}

    BlockExecutor.iterate_fail_safe(groups) do |group|
      program = group.program
      closure_reason_id = program_id_closure_reason_map[program.id].id
      program_id_mentoring_connection_term_map[program.id] ||= program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase
      group.terminate!(nil, "feature.connection.content.help_text.auto_expiry_reason_v1".translate(mentoring_connection: program_id_mentoring_connection_term_map[program.id]), closure_reason_id, TerminationMode::EXPIRY)
    end
  end

  def self.active_involving_users(users)
    groups = users.collect(&:active_groups).reduce(:&)
    groups.select { |group| group.members.size == users.size }
  end

  def self.sync_with_template(group_id, locale)
    group = Group.find_by(id: group_id)
    return if group.nil?
    MentoringModelUpdater.new(group, locale).sync
  end

  def self.available_projects(role_ids)
    role_count = role_ids.size
    role_string = role_ids.join(", ")
    joins(
      <<-SQL
        LEFT JOIN group_membership_settings
        ON group_membership_settings.group_id = groups.id
        AND group_membership_settings.role_id IN (#{role_string})
      SQL
    ).
    where(group_membership_settings: { allow_join: nil }).
    group("groups.id").
    having(
      <<-SQL
        SUM(group_membership_settings.max_limit) IS NULL
        OR
        IF(
          COUNT(group_membership_settings.id) = #{role_count},
          SUM(group_membership_settings.max_limit) > (
            SELECT COUNT(connection_memberships.id) FROM connection_memberships
            WHERE connection_memberships.role_id IN (#{role_string})
            AND connection_memberships.group_id = groups.id
        ), 1)
      SQL
    )
  end

  def self.send_group_accepted_emails(group_id, message, made_proposer_owner)
    group = Group.find_by(id: group_id)
    return if group.nil?
    group.message = message
    ChronusMailer.proposed_project_accepted(group.created_by, group, made_proposer_owner).deliver_now
  end

  def self.send_group_rejected_emails(group_id)
    group = Group.find_by(id: group_id)
    return if group.nil?
    ChronusMailer.proposed_project_rejected(group.created_by, group).deliver_now
  end

  def self.send_group_withdrawn_emails(group_id)
    group = Group.find_by(id: group_id)
    return if group.nil?
    group.members.each do |member|
      unless group.terminator_id == member.id
        ChronusMailer.available_project_withdrawn(member, group).deliver_now
      end
    end
  end

  def self.send_coach_rating_notification(group_id, uuid)
    group = Group.closed.find_by(id: group_id)
    return if group.blank? || !group.program.coach_rating_enabled?

    JobLog.compute_with_uuid(group.mentors, uuid, "Sending mails to student to rate their coaches") do |mentor|
      mentor_uuid = "#{uuid}-#{mentor.id}"
      JobLog.compute_with_uuid(group.students, mentor_uuid, "Sending mails to student to rate their coaches") do |student|
        ChronusMailer.coach_rating_notification_to_student(student, mentor, group).deliver_now
      end
    end
  end

  def self.send_group_creation_notification_to_members(group_id, role_id_user_ids_map, message_from_admin, job_uuid)
    group = Group.find_by(id: group_id)
    return if group.nil? || !group.published?

    group.message = message_from_admin
    group_users = group.members
    current_role_id_user_ids_map = group.get_role_id_user_ids_map

    role_id_role_map = group.program.roles.for_mentoring.index_by(&:id)
    role_id_user_ids_map.each do |role_id, user_ids|
      role = role_id_role_map[role_id]
      if role.present?
        user_ids_of_role = current_role_id_user_ids_map[role_id] & user_ids
        users_of_role = group_users.where(id: user_ids_of_role)

        email = case role.name
        when RoleConstants::MENTOR_NAME
          :group_creation_notification_to_mentor
        when RoleConstants::STUDENT_NAME
          :group_creation_notification_to_students
        else
          :group_creation_notification_to_custom_users
        end

        JobLog.compute_with_uuid(users_of_role, job_uuid, "Group creation notification to #{role.name}") do |user_of_role|
          ChronusMailer.send(email, user_of_role, group).deliver_now
        end
      end
    end
  end

  def self.send_group_termination_notification(group_id, terminator_id, job_uuid)
    group = Group.closed.find_by(id: group_id)
    terminator = User.find_by(id: terminator_id) if terminator_id # Last mentor/mentee leaving group
    return if group.nil? # No seperate condition to check presence of terminator as the group is destroyed if terminator is removed from program.

    JobLog.compute_with_uuid(group.members, job_uuid, "Group termination notification to members") do |member|
      ChronusMailer.group_termination_notification(member, terminator, group).deliver_now
    end
  end

  def self.send_group_reactivation_mails(group_id, reactivator_id, group_user_ids, reactivation_reason, job_uuid)
    group = Group.find_by(id: group_id)
    reactivator = User.find_by(id: reactivator_id)
    return if group.nil? || group.closed?

    group.message = reactivation_reason
    group_users = group.members
    user_ids = group_users.pluck(:id) & group_user_ids
    users_to_send_mail = group_users.where(id: user_ids)

    JobLog.compute_with_uuid(users_to_send_mail, job_uuid, "Group reactivation notification to members") do |user|
      ChronusMailer.group_reactivation_notification(user, group, reactivator).deliver_now
    end
  end

  def self.auto_publish_circles
    current_time = Time.now
    program_ids = Program.where(allow_circle_start_date: true).pluck(:id)
    groups = Group.pending.where(program_id: program_ids).where.not(start_date: nil).where("start_date < ?", current_time).includes(:program, :mentors, :students, :membership_settings)
    program_id_mentoring_connection_term_map = {}
    program_id_admin_user_map = {}

    BlockExecutor.iterate_fail_safe(groups) do |group|
      if group.mentors.size > 0 && group.students.size > 0
        program = group.program
        program_id_mentoring_connection_term_map[program.id] ||= program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term
        program_id_admin_user_map[program.id] ||= program.admin_users.first
        group.publish(program_id_admin_user_map[program.id], "feature.connection.content.auto_publish_circle_message".translate(Mentoring_Connection: program_id_mentoring_connection_term_map[program.id]))
      elsif group.auto_publish_failure_mail_sent_time.nil?
        group.update_attribute(:auto_publish_failure_mail_sent_time, current_time)
        BlockExecutor.iterate_fail_safe(group.owners) do |owner|
          ChronusMailer.auto_publish_circles_failure_notification(owner, group).deliver_now
        end
      end
    end
  end

  def self.has_groups_proposed_by_role(role)
    proposed_groups = role.program.groups.proposed.includes(:created_by => :roles)
    proposed_groups.collect(&:created_by).map{|user| user.roles if user.present?}.flatten.uniq.include?(role)
  end

  def badge_counts(user)
    badge_count = {}
    member = user.member
    badge_count[:unread_message_count] = self.scraps_enabled? ? member.scrap_inbox_unread_count(self) : 0
    badge_count[:tasks_count] =  get_recent_and_upcoming_pending_tasks(user).size
    badge_count[:upcoming_meeting_count] = self.program.mentoring_connection_meeting_enabled? ? member.get_upcoming_not_responded_meetings_count(self.program, self) : 0
    badge_count[:unread_posts_count] = self.get_cummulative_unviewed_posts_count(user)
    badge_count
  end

  def get_connections_widget_milestones(milestones, user)
    recent_and_upcoming_milestone_ids = self.get_homepage_connection_widget_tasks(user).collect(&:milestone).compact.uniq.collect(&:id)
    milestones.select{|milestone|recent_and_upcoming_milestone_ids.include?(milestone.id)}
  end

  def get_homepage_connection_widget_tasks(user, options = {})
    tasks = options[:tasks] || self.mentoring_model_tasks.owned_by(user)
    overdue_tasks = tasks.overdue_in_last(BADGE_COUNT_INTERVAL.days) + tasks.upcoming(BADGE_COUNT_INTERVAL)
    overdue_tasks = tasks.overdue_before(BADGE_COUNT_INTERVAL.days).last(MentoringModel::Task::HOME_PAGE_TASKS_DEFAULT_LIMIT) if overdue_tasks.empty?
    return overdue_tasks
  end

  def get_recent_and_upcoming_pending_tasks(user)
    tasks = self.mentoring_model_tasks.owned_by(user)
    tasks.overdue_in_last(BADGE_COUNT_INTERVAL.days) + tasks.upcoming(BADGE_COUNT_INTERVAL)
  end

  def self.with_overdue_tasks
    joins(:mentoring_model_tasks).where("mentoring_model_tasks.required = ? AND mentoring_model_tasks.due_date IS NOT NULL AND
                            mentoring_model_tasks.due_date < ? AND mentoring_model_tasks.status = ?", true, Time.now.to_date, MentoringModel::Task::Status::TODO).distinct
  end

  def self.send_owner_addition_notification(receiver, group)
    ChronusMailer.group_owner_addition_notification(receiver, group).deliver_now
  end

  def self.get_rolewise_slots_details(group_ids, total_slots_needed, slots_taken_needed)
    slot_details = {}
    if total_slots_needed || slots_taken_needed
      includes_list = []
      includes_list << :membership_settings if total_slots_needed
      includes_list << :memberships if slots_taken_needed
      groups = Group.where(id: group_ids).includes(includes_list)

      if groups.present?
        program = groups.first.program
        mentoring_roles = program.roles.for_mentoring
        groups.find_each do |group|
          slot_details[group.id] = {}
          mentoring_roles.each do |role|
            total_slots = group.membership_settings.find {|mem_setting| mem_setting.role_id == role.id}.try(:max_limit) if total_slots_needed
            slots_taken = group.memberships.select {|membership| membership.role_id ==  role.id}.size if slots_taken_needed
            slot_details[group.id][role.id] = { total_slots: total_slots, slots_taken: slots_taken }
          end
        end
      end
    end
    slot_details
  end

  def self.create_group_and_membership_state_changes(group_id, timestamp, group_info, memberships_users_info)
    group = Group.find_by(id: group_id)
    return unless group.present?
    date_id = timestamp.utc.to_i/1.day.to_i
    group.state_changes.create!(group_info.merge({date_id: date_id}))
    if group_info[:from_state].present? # This means we are coming from after_update
      group.memberships.each do |membership|
        user_info = memberships_users_info[membership.id]
        if user_info.present?
          membership.create_membership_state_change(date_id, {group: group_info, user: user_info.slice(:from_state, :to_state), connection_membership: {from_state: Connection::Membership::Status::ACTIVE, to_state: Connection::Membership::Status::ACTIVE}})
          membership.create_user_state_change_on_group_state_change(date_id, {group: group_info, user: user_info})
        end
      end
    end
  end

  def closure_survey?(task)
    milestone = task.milestone
    if milestone.present?
      milestone = MentoringModel::Milestone.find(milestone.id)
    else
      return false
    end
    return (self.mentoring_model_milestones.last == milestone && milestone.mentoring_model_tasks.last == task)
  end

  def group_checkins_duration(type = nil)
    if type == MentoringModel::Task.name
      self.task_checkins.sum(:duration)
    elsif type == MemberMeeting.name
      self.meeting_checkins.sum(:duration)
    else
      self.group_checkins.sum(:duration)
    end
  end

  def touch_mentors
    mentors.update_all(updated_at: Time.now.utc)
  end

  # Sets the mentor and students and saves the connection.
  def update_members(new_mentors, new_students, actor = nil, options = {})
    self.old_members_by_role = self.members_by_role
    self.actor = actor

    begin
      ActiveRecord::Base.transaction do
        # Assigning a collection of objects to an active record collection replaces
        # the collections content by *deleting* and adding objects as appropriate.
        # So, Task and PrivatesNote belonging to the deleted Connection::Membership
        # are not dependent destroyed. So, we collect the ids of memberships to be deleted
        # before deleting and later delete the dependent tasks and private notes later
        # in the method.
        role_name_with_new_users = {}
        deleted_memberships = []
        membership_ids_to_delete_with_tasks_included = []
        membership_ids_to_delete_due_to_replace = {}
        mentor_student_roles = program.roles.where(name: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).index_by(&:name)
        options[:other_roles_hash] = (options[:other_roles_hash] || {}).merge(mentor_student_roles[RoleConstants::MENTOR_NAME] => new_mentors, mentor_student_roles[RoleConstants::STUDENT_NAME] => new_students)

        # Dissociate from bulk match if the original student-mentor pair is updated
        handle_bulk_match_association_integrity(new_students, new_mentors)

        options[:other_roles_hash].each do |role, users|
          data = update_members_by_role(role, users, actor, options)
          role_name_with_new_users[role] = data[:new_users]
          deleted_memberships.concat(data[:memberships_to_delete] || [])
          membership_ids_to_delete_with_tasks_included.concat(data[:membership_ids_to_delete_with_tasks_included] || [])
          membership_ids_to_delete_due_to_replace.merge!(data[:membership_ids_to_delete_due_to_replace] || {})
        end
        new_users_set = role_name_with_new_users.values.flatten
        new_active_member_ids = self.program.organization.members.active.where(id: new_users_set.collect(&:member_id)).pluck(:id)
        member_ids_of_deleted_memberships = deleted_memberships.collect(&:user).collect(&:member_id)
        self.save!

        # Create scrap receiver objects for newly added members
        create_scrap_receivers_for_added_members(new_active_member_ids)

        added_users = (self.reload.members - old_members_by_role.values.flatten)
        removed_users = (old_members_by_role.values.flatten - self.members)
        # V2: Create tasks from template for the newly added members of the group
        if self.published? && self.program.mentoring_connections_v2_enabled? && self.mentoring_model_id.present?
          if old_members_by_role && old_members_by_role != self.members_by_role
            added_user_ids = added_users.collect(&:id)
            if options[:new_members_with_no_default_tasks]
              added_user_ids -= options[:new_members_with_no_default_tasks]
            end
            if options[:replaced_members_list]
              user_ids_of_replacements = options[:replaced_members_list].values.compact
              added_user_ids -= user_ids_of_replacements
              new_replacement_memberships_hash = {}
              self.memberships.where(user_id: user_ids_of_replacements).collect{|m| new_replacement_memberships_hash = new_replacement_memberships_hash.merge({m.user_id => m.id})}
            end
            if added_user_ids.present?
              added_memberships_ids = self.memberships.where(user_id: added_user_ids).pluck(:id)
              Group.delay.create_tasks_for_added_memberships(self.id, added_memberships_ids)
            end
          end
        end

        # Subscribe/Unsubscribe the newly added/removed users to/from the group forum
        handle_forum_subscriptions(added_users, removed_users)

        # Accept project requests, if there are any.
        # Only students have the ability to send project_requests
        accept_project_requests!(role_name_with_new_users, actor)

        # Destroy the stale dependent object of the *deleted* connection_memberships depending on provided option.
        destroy_options = {
          membership_ids_to_delete_with_tasks_included: membership_ids_to_delete_with_tasks_included,
          membership_ids_to_delete_due_to_replace: membership_ids_to_delete_due_to_replace,
          replaced_members_list: options[:replaced_members_list],
          new_replacement_memberships_hash: new_replacement_memberships_hash
        }
        Connection::Membership.delay(queue: DjQueues::HIGH_PRIORITY).destroy_dependent_objects(self.id, deleted_memberships.collect(&:id), member_ids_of_deleted_memberships, destroy_options)
        member_ids = self.members.pluck(:member_id)
        self.meetings.each do |meeting|
          meeting.member_meetings.where.not(member_id: member_ids).destroy_all
        end
      end
    rescue ActiveRecord::RecordInvalid
      # Rescue only record errors and return false to signal failure.
      return false
    end
    return true
  end

  def add_and_remove_custom_users!(role, users, options = {})
    role_custom_memberships = custom_memberships.where(role_id: role.id)
    unless options[:disallow_removal]
      if users.present?
        destroy_connection_memberships!(role_custom_memberships.where("user_id NOT IN (?)", users.collect(&:id)))
      else
        destroy_connection_memberships!(role_custom_memberships)
      end
    end
    users.each do |user|
      if role_custom_memberships.find{|custom_membership| custom_membership.user_id == user.id }.blank?
        custom_memberships.create!(role_id: role.id, user_id: user.id)
      end
    end
  end

  # Returns whether the given user is part of the group
  def has_member?(user)
    return nil unless user
    self.memberships.of(user).exists?
  end

  # Returns the all members of the group excepting the given user.
  def get_groupees(user)
    return nil unless self.has_member?(user)
    self.members.includes(:member, :roles) - [user]
  end

  # Returns a hash of members grouped by role
  def members_by_role
    {:mentors => self.mentors.clone.to_a, :mentees => self.students.clone.to_a, other_users: self.custom_users.clone.to_a}
  end

  # Is the group about to expire
  def about_to_expire?
    (Time.now + EXPIRY_NOTICE_SERVING_PERIOD) > self.expiry_time
  end

  def days_before_expiry
    ((self.expiry_time - Time.now) / 1.day).round
  end

  def expiring_next_week?
    self.active? && (Date.today.to_datetime + EXTENSION_NOTICE_SERVING_PERIOD+1.day) > self.expiry_time && (Time.now) < self.expiry_time
  end

  # Was the group reactivated recently
  def recently_reactivated?
    reactivation_ra = RecentActivity.where(action_type: RecentActivityConstants::Type::GROUP_REACTIVATION, ref_obj_id: self.id).order("id DESC").first
    return false if reactivation_ra.nil?
    (reactivation_ra.created_at + EXTENSION_NOTICE_SERVING_PERIOD) > Time.now
  end

  # Was the expiry date of the group changed recently
  def recently_expiry_date_changed?
    exp_date_change_ra = RecentActivity.where(action_type: RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE, ref_obj_id: self.id).order("id DESC").first
    return false if exp_date_change_ra.nil?
    (exp_date_change_ra.created_at + EXTENSION_NOTICE_SERVING_PERIOD) > Time.now
  end

  # Has the group expired?
  def expired?
    self.expiry_time <= Time.now
  end

  # Should the notice message shown on the group show page?
  def show_notice?
    return false if (self.closed? && !self.expired?)

    self.about_to_expire? || self.expired? || self.recently_reactivated? || self.recently_expiry_date_changed?
  end

  # Returns whether the given user is a mentor in this connection.
  def has_mentor?(user)
    self.mentor_memberships.of(user).present?
  end

  # Returns whether the given user is a mentee in this connection.
  def has_mentee?(user)
    self.student_memberships.of(user).present?
  end

  def has_teacher?(user)
    self.custom_memberships.of(user).present?
  end

  # Returns whether this group has some scrap or task activity.
  def has_activities?
    self.activities.any?
  end

  # Activities that happened recently, limited to <i>limit</i> entries.
  # The activities should include and be a mix of all activity types
  # viz., scraps and tasks.
  def activity_feed(limit = 2)
    self.activities.for_display.limit(limit).order("id DESC")
  end

  # Returns the Connection::Membership of the +user+ in this connection.
  def membership_of(user)
    self.memberships.of(user).first
  end

  # Returns the Connection::Membership::Status of the +member+ in this connection.
  def member_status(user)
    self.membership_of(user).status
  end

  #
  # If this connection was ever reactivated by the admin, returns the last time
  # of reactivation. Returns nil otherwise.
  #
  def last_activated_at
    self.activities.of_type(RecentActivityConstants::Type::GROUP_REACTIVATION).maximum(:created_at)
  end

  # Removes upcoming meetings of closed group
  def self.remove_upcoming_meetings_of_group(group_id)
    group = Group.find_by(id: group_id)
    return unless group.present?
    current_time = Time.current
    group.meetings.each do |meeting|
      if meeting.end_time > current_time
        next_occurrence_time = meeting.schedule.next_occurrence
        if meeting.first_occurrence?(next_occurrence_time.to_s)
          Meeting.false_destroy_without_email!(meeting.id)
        elsif next_occurrence_time.present?
          meeting.update_last_occurence_time(next_occurrence_time.to_s)
        end
      end
    end
  end

  # Returns the duration for which the member is inactive.
  def inactivity_in_days(membership)
    user = membership.user
    last_activity_at = self.activities.where(:member_id => user.member_id).maximum(:created_at)
    latest_activity_date = [last_activity_at, last_activated_at, self.published_at, membership.created_at].compact.max
    period = Time.now - latest_activity_date
    (period / 1.day).to_i
  end

  # Returns whether it is time for showing connection feedback form to the user.
  #
  # False if tracking period is not set. If set, returns true if the time since
  # the user last gave the feedback for this connectin has crossed the tracking
  # period.
  #
  def time_for_feedback_from?(user)
    return false unless self.program.connection_feedback_enabled?
    # Not a member of the connection?
    return false unless has_member?(user)
    # Connection is not old enough to ask for feedback?
    return false if (Time.now - self.published_at) < self.program.inactivity_tracking_period

    # Check whether there is a feedback response by this user pertaining to this
    # connection, last updated within tracking period.
    !SurveyAnswer.exists?([
      "user_id = ? AND group_id = ? AND survey_id = ? AND created_at > ?",
      user, self, self.program.feedback_survey.try(:id), Time.now - self.program.inactivity_tracking_period])
  end

  # Returns whether this connection can be activated. True if the status is
  # neither active nor closed.
  def can_be_activated?
    self.status == Status::INACTIVE
  end

  def can_be_published?
    self.mentors.count > 0 && self.students.count > 0
  end

  # Terminates the connection as done by +admin+ with the reason
  # +termination_reason+
  def terminate!(user, termination_reason, closure_reason_id, termination_mode = Group::TerminationMode::ADMIN, status = Status::CLOSED)
    self.status             = status
    self.termination_mode   = termination_mode
    self.closure_reason_id  = closure_reason_id
    self.termination_reason = termination_reason
    self.closed_by          = user
    self.closed_at          = Time.now
    self.save!
  end

  # This takes care of both reactivation and extension of a group
  def change_expiry_date(user, new_expiry_date, reason, options = {})
    self.actor = user
    self.message = reason
    if self.closed?
      self.status = Status::ACTIVE
      self.closure_reason_id = nil if options[:clear_closure_reason]
    end

    self.expiry_time = new_expiry_date
    # Make all members active when there's reactivation or the expiry date is set to a new value.
    if self.valid?
      if options[:for_bulk_change_expiry_date].present?
        Group.delay.make_all_group_members_active(self.id, true)
      else
        membership_errors = Group.make_all_group_members_active(self.id)
        if membership_errors.present?
          self.errors.add(:base, membership_errors)
          self.errors[:base].flatten!
        end
      end
    end
    # validations for the group is already taken care in valid?
    self.errors.empty? && self.save(validate: false)
  end

  def self.make_all_group_members_active(group_id, notify_airbrake=false)
    group = Group.find_by(id: group_id)
    return if group.blank?
    errors_list = []
    group.memberships.each do |membership|
      saved, membership_errors = group.set_member_status(membership, Connection::Membership::Status::ACTIVE, return_errors: true)
      unless saved
        if notify_airbrake
          Airbrake.notify("Setting membership status failed for membership id: #{membership.id} with errors: #{membership_errors}")
        else
          errors_list << membership_errors
        end
      end
    end
    return errors_list unless notify_airbrake
    true
  end

  # Sets the connection to active state if inactive.
  def mark_active!
    if can_be_activated?
     self.status = Group::Status::ACTIVE
     self.save!
    end
  end

  def get_auto_terminate_reason_id
    self.program.auto_terminate_reason_id.nil? ?  self.program.default_closure_reasons.where(is_completed: false).first.id : self.program.auto_terminate_reason_id
  end

  # Performs system initiated termination.
  def auto_terminate_due_to_inactivity!
    return unless self.published?
    terminate!(nil, "feature.connection.content.help_text.auto_termination_reason".translate(mentoring_connection: self.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase), self.get_auto_terminate_reason_id, Group::TerminationMode::INACTIVITY)
  end

  def auto_terminated?
    closed_due_to_inactivity? || closed_due_to_expiry?
  end

  def closed_due_to_inactivity?
    self.termination_mode == Group::TerminationMode::INACTIVITY
  end

  def closed_due_to_expiry?
    self.termination_mode == Group::TerminationMode::EXPIRY
  end

  def closed_by_admin?
    self.termination_mode == Group::TerminationMode::ADMIN
  end

   def closed_by_leaving?
    self.termination_mode == Group::TerminationMode::LEAVING
  end

  def closed?
    self.status == Status::CLOSED
  end

  def open?
    Status::OPEN_CRITERIA.include?(self.status)
  end

  def open_or_closed?
    self.open? || self.closed?
  end

  def open_or_proposed?
    self.open? || self.proposed?
  end

  def active?
    Status::ACTIVE_CRITERIA.include?(self.status)
  end

  def closed_or_expired?
    closed? || expired?
  end

  def inactive?
    self.status == Status::INACTIVE
  end

  def drafted?
    self.status == Status::DRAFTED
  end

  def published?
    Status.all_published.include?(self.status)
  end

  def pending?
    self.status == Status::PENDING
  end

  def rejected?
    self.status == Status::REJECTED
  end

  def proposed?
    self.status == Status::PROPOSED
  end

  def withdrawn?
    self.status == Status::WITHDRAWN
  end

  def pending_or_active?
    self.pending? || self.active?
  end

  def single_mentee?
    self.students.size == 1
  end

  def get_mentoring_locations(current_org)
    MentoringSlot.where(member_id: current_org.members.where(id: self.members.pluck(:member_id)).pluck(:id)).where(["location IS NOT NULL AND location != ''"]).distinct.pluck(:location)
  end

  # Creates a RecentActivity for the visit by the visitor to the mentoring area.
  def mark_visit(visitor)
    # Only active group members' visits are tracked.
    return unless active? && has_member?(visitor)

    RecentActivity.create!(
      :programs => [self.program],
      :action_type  => RecentActivityConstants::Type::VISIT_MENTORING_AREA,
      :target       => RecentActivityConstants::Target::NONE,
      :ref_obj      => self,
      :member       => visitor.member
    )
    ActivityLog.log_activity(visitor, ActivityLog::Activity::MENTORING_VISIT)

  end

  # Sets the status of the membership of the +member+ to +status+.
  def set_member_status(membership, new_status, options = {})
    membership.status = new_status
    membership.last_status_update_at = Time.now
    if options[:return_errors]
      [membership.save, membership.errors.full_messages.to_sentence]
    else
      membership.save!
    end
  end

  # Updates the status of all members in this connection. Also notifies them
  # about the status change if required.
  def track_member_statuses
    tracking_period_in_days = self.program.inactivity_tracking_period_in_days
    self.memberships.select(&:active?).each do |membership|
      days_of_inactivity = inactivity_in_days(membership)
      # do not change the status of the user if the group is about to expire in 2 weeks
      if days_of_inactivity > tracking_period_in_days && (self.expiry_time - Time.now) > Connection::Membership::INACTIVITY_NOTICE_PERIOD
        self.set_member_status(membership, Connection::Membership::Status::INACTIVE)
      end
    end
  end

  def generate_and_email_mentoring_area(user, job_uuid = nil, is_super_console = false, locale = I18n.locale)
    GlobalizationUtils.run_in_locale(locale) do
      JobLog.compute_with_uuid(user, job_uuid, "Mentoring Area Export") do |user_object|
        time_stamp = DateTime.localize(Time.now, format: :pdf_timestamp)
        group_term = self.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term
        pdf_name = "#{"feature.group.label.mentoring_connection".translate(mentoring_connection: group_term)}-#{time_stamp}.pdf"
        non_member_view = !user_object.belongs_to_group?(self)
        scraps_with_attachments = self.scraps_enabled? ? self.scraps.select(&:attachment?) : []
        notes_with_attachments = non_member_view ? [] : self.private_notes.owned_by(user_object).latest_first.select(&:attachment?)

        if scraps_with_attachments.any? || notes_with_attachments.any?
          report_file_name = "#{"feature.group.label.mentoring_connection".translate(mentoring_connection: group_term)}-#{time_stamp}.zip"
          report_data = MentoringAreaExporter.generate_zip(user_object, self, non_member_view, scraps_with_attachments, notes_with_attachments, pdf_name, is_super_console)
        else
          report_file_name = pdf_name
          report_data = MentoringAreaExporter.generate_pdf(user_object, self, non_member_view, is_super_console)
        end
        ChronusMailer.mentoring_area_export(user_object, self, report_file_name, report_data).deliver_now
      end
    end
  end

  #
  # Returns the tasks for a group. If a single mentee group, returns all goals
  # as private goals of the first student. Otherwise, returns goals grouped by
  # students and group goals.
  #
  # Args: options[:for] - list of students for whom tasks should be fetched.
  #
  def fetch_tasks(options = {})
    tasks = Hash.new
    if self.single_mentee?
      # Combine private and group goals as student's goals
      s = self.students.first
      tasks[s] = {
        :active => self.tasks.active(:include => :student),
        :completed => self.tasks.completed(:include => :student)
      }
    else
      # Collect group goals
      tasks[:group] = {
        :active => self.tasks.active.for_group,
        :completed => self.tasks.completed.for_group
      }

      studs = options[:for] || []
      studs.collect { |s| tasks[s] = { :active => [], :completed => [] } }

      # Collect private goals
      self.tasks(:include => :student).for_student(studs).each do |task|
        if not task.done?
          tasks[task.student][:active] << task
        else
          tasks[task.student][:completed] << task
        end
      end
    end

    tasks
  end

  def create_ra_and_notify_mentee_about_mentoring_offer
    return unless self.published?
    RecentActivity.create!(
      :programs => [self.program],
      :ref_obj => self,
      :action_type => RecentActivityConstants::Type::MENTORING_OFFER_DIRECT_ADDITION,
      :member => self.actor.member,
      :target => RecentActivityConstants::Target::ALL,
      :message => self.offered_to.id)

    ChronusMailer.group_mentoring_offer_added_notification_to_new_mentee(self.offered_to, self, self.actor, sender: self.actor).deliver_now
  end

  def notify_group_members_about_member_update
    return unless self.published?
    (self.members - [self.actor, self.offered_to]).each do |member|
      membership = self.membership_of(member)
      membership.send_email(membership, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE)
    end
  end

  def self.create_ra_and_notify_members_about_member_update(group_id, old_members_by_role, job_uuid = nil, actor = nil, options = {})
    group = Group.find_by(id: group_id)
    return if group.blank? || group.drafted?

    old_users = old_members_by_role.values.flatten
    added_users = group.members - old_users
    removed_users = old_users - group.members
    retained_users = group.members & old_users

    JobLog.compute_with_uuid(added_users, job_uuid, "Group Member Update for Addition") do |user|
      RecentActivity.create!(
        programs: [group.program],
        ref_obj: group,
        action_type: RecentActivityConstants::Type::GROUP_MEMBER_ADDITION,
        member: user.member,
        target: RecentActivityConstants::Target::ALL
      )
      Push::Base.queued_notify(PushNotification::Type::GROUP_MEMBER_ADDED, group, user_id: user.id)
      ChronusMailer.group_member_addition_notification_to_new_member(user, group, actor, options).deliver_now
    end

    JobLog.compute_with_uuid(removed_users, job_uuid, "Group Member Update for Removal") do |user|
      RecentActivity.create!(
        programs: [group.program],
        ref_obj: group,
        action_type: RecentActivityConstants::Type::GROUP_MEMBER_REMOVAL,
        member: user.member,
        target: RecentActivityConstants::Target::ALL
      )
      ChronusMailer.group_member_removal_notification_to_removed_member(user, group, old_members_by_role, actor).deliver_now
    end

    JobLog.compute_with_uuid(retained_users, job_uuid, "Group Member Update for retained users") do |user|
      membership = group.membership_of(user)
      membership.send_email(membership, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE)
    end
  end

  # Returns the user's answer for the given question. Nil if empty
  def answer_for(question)
    self.answers.includes(:answer_choices).for_question(question).first
  end

  def update_answers(question_id_to_answer_map, from_import = false)
    questions = self.program.connection_questions.includes(question_choices: :translations)

    question_id_to_answer_map ||= {}
    question_id_to_answer_map.each_pair do |question_id, ans_val|
      question = questions.select{|q| q.id.to_s ==  question_id.to_s}[0]
      group_answer = self.answer_for(question) || self.answers.build(:question => question)
      group_answer.answer_value = {answer_text: ans_val, question: question, from_import: from_import}

      # Note that this assignment is required to satisfy the assocation in
      # MembershipAnswer
      group_answer.group = self
      unless group_answer.save
        self.errors.add(:answers, group_answer.errors.full_messages[0])
        return false
      end
    end

    return true
  end

  def update_attribute_skipping_observer(attribute, value)
    old_skip_observer_val = self.skip_observer
    self.skip_observer = true
    self.update_attribute(attribute, value)
    self.skip_observer = old_skip_observer_val
  end

  def logo_url
    if self.logo?
      self.logo.url
    else
      GroupConstants::DEFAULT_LOGO
    end
  end

  def is_terminate_action_for?(user)
    return false if self.pending?
    mentor_memberships = self.mentor_memberships
    student_memberships = self.student_memberships
    return ((mentor_memberships.size == 1 && mentor_memberships.last.user_id == user.id) ||
        (student_memberships.size == 1 && student_memberships.last.user_id == user.id))
  end

  def setting_for_role_id(role_id, with_scope = true)
    if with_scope
      self.membership_settings.where(role_id: role_id).first
    else
      self.membership_settings.find{|setting| setting.role_id == role_id}
    end
  end

  def available_roles_for_joining(role_ids, options = {})
    return unless self.project_based?
    additional_count = options[:additional_count] || 1
    self.program.roles.for_mentoring.where(id: role_ids).with_permission_name(RolePermission::SEND_PROJECT_REQUEST).select do |role|
      group_setting = self.setting_for_role_id(role.id)
      if group_setting.present?
        allowed_role = group_setting.allow_join.nil?
        allowed_role && (options[:dont_consider_slots] || has_slots?(group_setting, additional_count))
      else
        true
      end
    end
  end

  def available_roles_for_user_to_join(user)
    self.available_roles_for_joining(user.role_ids) & user.roles_for_sending_project_request
  end

  def publish(actor, message = "", allow_join = true)
    return true if self.published?
    ActiveRecord::Base.transaction do
      self.message = message

      if self.project_based? && !allow_join
        self.program.mentoring_role_ids.each { |role_id| self.membership_settings.find_or_create_by(role_id: role_id) }
        self.membership_settings.update_all(allow_join: false)
      end

      if self.expiry_time.blank?
        # This value will be overriden in the observer, when v2 is enabled.
        # Please have a look at Group::MentoringModelCloner
        expiry_time = self.get_group_expiry_time
        self.update_attribute_skipping_observer(:expiry_time, expiry_time)
      end
      self.actor = actor
      self.update_attributes!(:status => Group::Status::ACTIVE, :published_at => Time.now)
      GroupObserver.instance.after_publish(self)
    end
    return true
  end

  def get_tasks_list(includes_list = [], options = {})
    target_user = options[:target_user_type] == GroupsController::TargetUserType::ALL_MEMBERS ? nil : options[:target_user]
    sorted_mentoring_model_tasks = self.get_sorted_tasks_list(target_user, includes_list, options)
    if options[:view_mode] == MentoringModelUtils::ViewMode::SORT_BY_DUE_DATE
      due_dates_ary = sorted_mentoring_model_tasks.map(&:due_date).compact
      unless due_dates_ary.empty?
        last_hold_date = due_dates_ary.max + 1.year
        sorted_ids = sorted_mentoring_model_tasks.sort_by { |task| [(task.due_date || last_hold_date), task.position] }.map(&:id)
        sorted_mentoring_model_tasks = MentoringModel::Task.where(id: sorted_ids).order(Arel.sql("FIELD(mentoring_model_tasks.id, #{sorted_ids.join(COMMA_SEPARATOR)})") => :asc)
      end
    end
    return sorted_mentoring_model_tasks unless options[:home_page_view]
    recent_pending_and_upcoming_tasks_ids = self.get_homepage_connection_widget_tasks(target_user, tasks: sorted_mentoring_model_tasks).collect(&:id)
    sorted_mentoring_model_tasks.where(id: recent_pending_and_upcoming_tasks_ids)
  end

  def get_sorted_tasks_list(target_user, includes_list = [], options = {})
    if options[:target_user_type] ==  GroupsController::TargetUserType::UNASSIGNED
      mentoring_model_tasks.where(connection_membership_id: nil).reload.includes(includes_list)
    elsif target_user.present?
      mentoring_model_tasks.where(connection_membership_id: target_user.connection_memberships).reload.includes(includes_list)
    else
      mentoring_model_tasks.reload.includes(includes_list)
    end
  end

  def set_task_positions
    sorting_proc = Proc.new do |task|
      if task.required?
        [0, task.due_date.to_i]
      else
        [1, task.from_template? ? task.mentoring_model_task_template.position : task.created_at.to_i]
      end
    end

    tasks = self.mentoring_model_tasks
    scoping_object_id_to_tasks = tasks.group_by { |task| MentoringModel::Task.scoping_object_id(task) }
    scoping_object_id_to_tasks.each do |_, scoped_tasks|
      sorted_scoped_tasks = scoped_tasks.sort_by { |scoped_task| sorting_proc.call(scoped_task) }
      sorted_scoped_tasks.each_with_index do |sorted_scoped_task, index|
        sorted_scoped_task.skip_observer = true
        sorted_scoped_task.position = index
        sorted_scoped_task.save!
      end
    end
  end

  def set_milestones_positions
    sorting_proc = Proc.new do |milestone|
      if milestone.mentoring_model_milestone_template.present?
        [0, milestone.mentoring_model_milestone_template.position]
      else
        [1, milestone.created_at.to_i]
      end
    end

    milestones = self.mentoring_model_milestones
    sorted_milestones = milestones.sort_by { |milestone| sorting_proc.call(milestone) }

    sorted_milestones.each_with_index do |milestone, index|
      milestone.update_attribute(:position, index)
    end
  end

  def get_position_for_new_milestone
    return if !self.mentoring_model.present? || self.mentoring_model.hybrid?
    mentoring_model_milestones = self.mentoring_model_milestones
    mentoring_model_milestones.present? ? mentoring_model_milestones.last.position.to_i + 1 : 0
  end

  def set_member_added(group)
    self.member_added = true
  end

  def mentor_limit_check_needed?
    !self.project_based? && !self.closed? && (self.new_record? ||
    self.changes['status'] == [Status::DRAFTED, Status::ACTIVE] ||
    self.changes['status'] == [Status::CLOSED, Status::ACTIVE] ||
    self.member_added)
  end

  def get_group_expiry_time
    return Time.now + (self.program.mentoring_period / 1.day).days if self.program.present?
  end

  def has_future_start_date?
    self.program.allow_circle_start_date? && self.start_date.present? && (self.start_date > Time.now.end_of_day)
  end

  def has_past_start_date?(member)
    self.program.allow_circle_start_date? && self.start_date.present? && (self.start_date < Time.now + AUTO_PUBLISH_CRON_DURATION_DIFFERENCE.hours)
  end

  ### Role Based User/Member IDs ###

  def get_user_ids(role_id = nil)
    self.get_users(role_id).pluck(:id)
  end

  def get_member_ids(role_id = nil)
    self.get_users(role_id).pluck(:member_id)
  end

  def get_users(role_id = nil)
    users = self.members
    return users if role_id.nil?

    users.where(connection_memberships: { role_id: role_id } )
  end

  def get_role_id_user_ids_map
    role_id_user_ids_map = {}
    self.memberships.select(:role_id, :user_id).each do |membership|
      role_id_user_ids_map[membership.role_id] ||= []
      role_id_user_ids_map[membership.role_id] << membership.user_id
    end
    role_id_user_ids_map
  end

  def self.get_group_id_member_id_role_id_map(group_ids, role_ids = [])
    groups_scope = Group.where(id: group_ids).
      select("groups.id, connection_memberships.role_id, GROUP_CONCAT(users.member_id) as user_or_member_ids").
      joins(memberships: :user).
      group("groups.id, connection_memberships.role_id")
    groups_scope = groups_scope.where("connection_memberships.role_id IN (?)", role_ids) if role_ids.present?

    self.get_group_id_user_or_member_id_role_id_map(groups_scope)
  end

  def self.get_group_id_user_id_role_id_map(group_ids, role_ids = [])
    groups_scope = Group.where(id: group_ids).
      select("groups.id, connection_memberships.role_id, GROUP_CONCAT(connection_memberships.user_id) as user_or_member_ids").
      joins(:memberships).
      group("groups.id, connection_memberships.role_id")
    groups_scope = groups_scope.where("connection_memberships.role_id IN (?)", role_ids) if role_ids.present?

    self.get_group_id_user_or_member_id_role_id_map(groups_scope)
  end

  ### Role Based User/Member IDs ###

  def scraps_enabled?
    self.mentoring_model.blank? || self.mentoring_model.allow_messaging?
  end

  def forum_enabled?
    self.mentoring_model.try(:allow_forum?)
  end

  def meetings_enabled?(group_roles = nil)
    mentoring_model_v2_enabled = self.program.mentoring_connections_v2_enabled?
    group_roles ||= self.program.roles.with_name(RoleConstants::DEFAULT_ROLE_NAMES) if mentoring_model_v2_enabled
    mentoring_model_v2_enabled ? self.can_manage_mm_meetings?(group_roles) : self.program.mentoring_connection_meeting_enabled?
  end

  def self.get_role_based_details(groups, group_view_columns)
    program = groups.first.program
    group_ids = groups.collect(&:id)
    column_keys = group_view_columns.collect(&:column_key)
    role_id_name_hash = program.roles.select(:id, :name).inject({}) { |id_name_hash, role| id_name_hash[role.id] = role.name; id_name_hash }

    total_slots_needed = ([GroupViewColumn::Columns::Key::TOTAL_SLOTS, GroupViewColumn::Columns::Key::SLOTS_REMAINING] & column_keys).any?
    slots_taken_needed = ([GroupViewColumn::Columns::Key::SLOTS_TAKEN, GroupViewColumn::Columns::Key::SLOTS_REMAINING] & column_keys).any?
    login_activity_needed = column_keys.include?(GroupViewColumn::Columns::Key::LOGIN_ACTIVITY)
    scraps_activity_role_ids = group_view_columns.select(&:is_messaging_column?).collect(&:role_id)
    posts_activity_role_ids = group_view_columns.select(&:is_forum_column?).collect(&:role_id)

    output = {}
    output[:slot_details] = Group.get_rolewise_slots_details(group_ids, total_slots_needed, slots_taken_needed)
    output[:login_activity] = login_activity_needed ? Group.get_rolewise_login_activity(group_ids) : {}
    output[:scraps_activity] = scraps_activity_role_ids.present? ? Group.get_rolewise_scraps_activity(group_ids, scraps_activity_role_ids) : {}
    output[:posts_activity] = posts_activity_role_ids.present? ? Group.get_rolewise_posts_activity(group_ids, posts_activity_role_ids) : {}
    output[:role_id_name_hash] = role_id_name_hash
    output
  end

  ### Group Activities ###

  def login_activity(grouped = true)
    memberships = self.memberships.select(:user_id, :login_count)
    (grouped ? memberships.group(:user_id) : memberships).sum(:login_count)
  end

  def scraps_activity(role_id = nil, grouped = true, date_range = {})
    group_scraps = self.scraps
    group_scraps = group_scraps.where(sender_id: self.get_member_ids(role_id)) if role_id.present?
    group_scraps = group_scraps.created_in_date_range(date_range[:start_time]..date_range[:end_time]) if date_range[:start_time].present?
    (grouped ? group_scraps.group(:sender_id) : group_scraps).size
  end

  def posts_activity(role_id = nil, grouped = true, date_range = {})
    group_posts = self.posts
    group_posts = group_posts.where(user_id: self.get_user_ids(role_id)) if role_id.present?
    group_posts = group_posts.created_in_date_range(date_range[:start_time]..date_range[:end_time]) if date_range[:start_time].present?
    (grouped ? group_posts.group(:user_id) : group_posts).size
  end

  def survey_responses_activity(role_id = nil, date_range = {})
    survey_responses = self.survey_answers.select(["common_answers.id, common_answers.response_id, common_answers.last_answered_at, common_answers.user_id"]).includes(:answer_choices).group("common_answers.response_id, common_answers.user_id")
    survey_responses = survey_responses.where(user_id: self.get_user_ids(role_id)) if role_id.present?
    survey_responses = survey_responses.last_answered_in_date_range(date_range[:start_time]..date_range[:end_time]) if date_range[:start_time].present? && date_range[:end_time].present?
    survey_responses.present? ? survey_responses.size : 0
  end

  def meetings_activity(role_id = nil, date_range = {})
    recurrent_meetings =
      if date_range[:start_time].present?
        self.active_meetings_between_specified_dates(date_range[:start_time], date_range[:end_time])
      else
        self.past_active_meetings
      end
    meetings_data = {}
    meetings_data[:role] = 0 if role_id.present?

    member_ids = self.get_member_ids(role_id)
    recurrent_meetings.each do |rm|
      meeting = rm[:meeting]
      current_occurrence_time = rm[:current_occurrence_time]
      if role_id.present?
        if meeting.any_attending?(current_occurrence_time, member_ids)
          meetings_data[:role] += 1
        end
      else
        member_ids.each do |member_id|
          member_meeting = meeting.member_meetings.find{|mm| mm.member_id == member_id}
          if member_meeting.present? && member_meeting.get_response_object(current_occurrence_time).accepted_or_not_responded?
            meetings_data[member_id].present? ?  meetings_data[member_id]+=1 : meetings_data.merge!(member_id => 1)
          end
        end
      end
    end
    return meetings_data
  end

  def tasks_activity
    group_tasks = self.mentoring_model_tasks.status(MentoringModel::Task::Status::DONE)
    group_tasks.joins(:connection_membership).group("connection_memberships.user_id").count
  end
  
  def meetings_activity_for_all_roles
    @roles_for_mentoring_hash ||= get_roles_for_mentoring_hash
    @roles_for_mentoring_hash.collect{|key, value| {key => meetings_activity(value)[:role]}}
  end

  def get_rolewise_login_activity_for_group
    @roles_for_mentoring_hash ||= get_roles_for_mentoring_hash
    @roles_for_mentoring_hash_invert ||= @roles_for_mentoring_hash.invert
    memberships.group_by{|membership| @roles_for_mentoring_hash_invert[membership.role_id]}.collect{|key, value| {key => value.map(&:login_count).inject(:+)}}  
  end

  def get_rolewise_messages_activity_for_group
    @roles_for_mentoring_hash ||= get_roles_for_mentoring_hash
    member_id_role_id_map = memberships.includes(:user).collect{|membership| [membership.user.member_id, membership.role_id]}.to_h
    rolewise_grouped_scraps = scraps.group_by{|scrap| member_id_role_id_map[scrap.sender_id]}
    @roles_for_mentoring_hash.collect{|key, value| {key => rolewise_grouped_scraps[value].try(:size).to_i}}
  end

  def get_rolewise_posts_activity_for_group
    @roles_for_mentoring_hash ||= get_roles_for_mentoring_hash
    user_id_role_id_map = memberships.collect{|membership| [membership.user_id, membership.role_id]}.to_h
    rolewise_grouped_posts = posts.group_by{|post| user_id_role_id_map[post.user_id]}
    @roles_for_mentoring_hash.collect{|key, value| {key => rolewise_grouped_posts[value].try(:size).to_i}}
  end

  def badge_count(user)
    member = user.member
    unread_messages_count = self.scraps_enabled? ? member.scrap_inbox_unread_count(self) : 0
    tasks = self.mentoring_model_tasks.owned_by(user)
    goals_enabled = user.program.mentoring_connections_v2_enabled?
    pending_task_count = goals_enabled ? tasks.overdue_in_last(BADGE_COUNT_INTERVAL.days).size : 0
    upcoming_task_count = goals_enabled ? tasks.upcoming(BADGE_COUNT_INTERVAL).size : 0
    upcoming_meeting_count = user.program.mentoring_connection_meeting_enabled? ? member.get_upcoming_not_responded_meetings_count(self.program, self) : 0
    unread_messages_count + pending_task_count + upcoming_meeting_count + upcoming_task_count
  end

  def get_cummulative_unviewed_posts_count(user)
    return 0 if !self.forum_enabled? || self.forum.nil? || !has_member?(user)
    topic_ids = self.forum.topics.pluck(:id)
    user.get_cummulative_unviewed_posts(topic_ids).count
  end

  def past_active_meetings
    Meeting.has_attendance_more_than(Meeting.past_recurrent_meetings(self.meetings.slot_availability_meetings.includes([{:member_meetings => [:member_meeting_responses]}])), 1)
  end

  def active_meetings_between_specified_dates(start_time, end_time)
    group_meetings = self.meetings.slot_availability_meetings.between_time(start_time, end_time).includes(:member_meetings => [:member_meeting_responses])
    meetings = Meeting.recurrent_meetings(group_meetings, with_in_time: true, start_time: start_time, end_time: end_time)
    Meeting.has_attendance_more_than(meetings.flatten, 1)
  end

  def self.get_rolewise_login_activity(group_ids)
    group_id_role_id_login_count_map = {}

    connection_memberships_scope = Connection::Membership.
      select("connection_memberships.group_id, connection_memberships.role_id, SUM(connection_memberships.login_count) AS total_login_count").
      where(group_id: group_ids).
      group(:group_id, :role_id)

    connection_memberships_scope.each do |membership|
      group_id_role_id_login_count_map[membership.group_id] ||= {}
      group_id_role_id_login_count_map[membership.group_id][membership.role_id] = membership.total_login_count
      group_id_role_id_login_count_map
    end
    group_id_role_id_login_count_map
  end

  def self.get_rolewise_scraps_activity(group_ids, role_ids, date_range = nil)
    group_id_role_id_scraps_count_map = {}
    group_id_member_id_scraps_count_map = {}
    group_id_member_id_role_id_map = self.get_group_id_member_id_role_id_map(group_ids, role_ids)

    scraps_scope = Scrap.
      select("messages.ref_obj_id AS group_id, messages.sender_id AS member_id, COUNT(messages.id) AS scraps_count").
      where("ref_obj_id IN (?) AND ref_obj_type = ?", group_ids, Group.name).
      group(:ref_obj_id, :sender_id)
    scraps_scope = scraps_scope.created_in_date_range(date_range) if date_range.present?

    scraps_scope.each do |scrap|
      group_id_member_id_scraps_count_map[scrap.group_id] ||= {}
      group_id_member_id_scraps_count_map[scrap.group_id][scrap.member_id] = scrap.scraps_count
    end

    group_id_member_id_role_id_map.each do |group_id, member_id_role_id_map|
      group_id_role_id_scraps_count_map[group_id] ||= {}
      member_id_role_id_map.each do |member_id, role_id|
        group_id_role_id_scraps_count_map[group_id][role_id] ||= 0
        group_id_role_id_scraps_count_map[group_id][role_id] += group_id_member_id_scraps_count_map[group_id].try(:[], member_id).to_i
      end
    end
    group_id_role_id_scraps_count_map
  end

  def self.get_rolewise_posts_activity(group_ids, role_ids, date_range = nil)
    group_id_role_id_posts_count_map = {}
    group_id_user_id_posts_count_map = {}
    group_id_user_id_role_id_map = self.get_group_id_user_id_role_id_map(group_ids, role_ids)
    forum_id_forum_map = Forum.where(group_id: group_ids).index_by(&:id)

    posts_scope = Post.
      select("COUNT(posts.id) AS posts_count, posts.user_id, topics.forum_id").
      joins(:topic).
      where("topics.forum_id IN (?)", forum_id_forum_map.keys).
      group("topics.forum_id, posts.user_id")
    posts_scope = posts_scope.created_in_date_range(date_range) if date_range.present?

    posts_scope.each do |post|
      group_id = forum_id_forum_map[post.forum_id].group_id
      group_id_user_id_posts_count_map[group_id] ||= {}
      group_id_user_id_posts_count_map[group_id][post.user_id] = post.posts_count
    end

    group_id_user_id_role_id_map.each do |group_id, user_id_role_id_map|
      group_id_role_id_posts_count_map[group_id] ||= {}
      user_id_role_id_map.each do |user_id, role_id|
        group_id_role_id_posts_count_map[group_id][role_id] ||= 0
        group_id_role_id_posts_count_map[group_id][role_id] += group_id_user_id_posts_count_map[group_id].try(:[], user_id).to_i
      end
    end
    group_id_role_id_posts_count_map
  end

  ### Group Activities ###

  def accept_project_requests!(role_name_with_new_users, actor = nil)
    role_name_with_new_users.each do |role, users|
      active_project_requests = project_requests.active.where(sender_id: users.collect(&:id), sender_role_id: role.id)
      active_project_requests.each do |project_request|
        project_request.update_attributes!(receiver: actor, status: AbstractRequest::Status::ACCEPTED)
      end
    end
  end

  def make_proposer_owner!
    self.membership_of(self.created_by).update_attributes!(owner: true)
  end

  def self.send_email_to_admins_after_proposal(group_id, joblog_uuid)
    group = Group.find_by(id: group_id)
    return if group.nil? || !group.proposed?
    program = group.program
    recievers = program.admin_users - [group.created_by]
    JobLog.compute_with_uuid(recievers, joblog_uuid, "Sending emails to admins after project proposal") do |user|
      ChronusMailer.group_proposed_notification_to_admins(user, group, sender: group.created_by).deliver_now
    end
  end

  def unique_survey_answers(eager_load = true, date_range = nil, options = {})
    includes_list = eager_load ? [{:survey_question => :survey}, {:user => :member}, :answer_choices] : []
    survey_answers = self.survey_answers
    survey_answers = survey_answers.last_answered_in_date_range(date_range) if date_range.present?
    survey_answers = survey_answers.select("common_answers.id, common_answers.common_question_id, common_answers.user_id, common_answers.group_id, common_answers.response_id, common_answers.updated_at").order("updated_at DESC").includes(includes_list) unless options[:skip_select]
    survey_answers.to_a.uniq{|ans| ans.user_id && ans.group_id && ans.response_id}
  end

  def admin_enter_mentoring_connection?(user, is_super_console=false)
    group = Group.find_by(id: self.id)
    is_super_console || group.has_member?(user) || !group.program.admin_access_to_mentoring_area_disabled? || !group.published?
  end

  def get_mentoring_model
    self.mentoring_model || self.program.default_mentoring_model
  end

  def self.get_student_ids_mentor_ids(group_ids)
    groups = Group.where(id: group_ids).includes(:students, :mentors)
    return groups.collect do |group|
      [group.students.collect(&:id), group.mentors.collect(&:id)]
    end
  end

  def self.get_non_bulk_match_drafted_groups(student_id_mentor_id_map, mentee_to_mentor_match=true)
    student_ids = mentee_to_mentor_match ? student_id_mentor_id_map.keys : student_id_mentor_id_map.values
    drafted_groups = Group.drafted.with_student_ids(student_ids).where(bulk_match_id: nil).includes(:memberships)
    drafted_groups.inject({}) do |user_id_drafted_group_map, drafted_group|
      memberships = drafted_group.memberships
      if memberships.size == 2
        memberships = memberships.to_a.reverse if memberships[0].is_a? Connection::MentorMembership
        user_id_drafted_group_map = self.set_user_id_drafted_group_map(user_id_drafted_group_map, mentee_to_mentor_match, student_id_mentor_id_map, drafted_group, memberships) 
      end
      user_id_drafted_group_map
    end
  end

  def self.set_user_id_drafted_group_map(user_id_drafted_group_map, mentee_to_mentor_match, student_id_mentor_id_map, drafted_group, memberships)
    student_id, mentor_id = memberships.collect(&:user_id)
    if (mentee_to_mentor_match && student_id_mentor_id_map[student_id] == mentor_id) || (!mentee_to_mentor_match && student_id_mentor_id_map[mentor_id] == student_id)
      mentee_to_mentor_match ? (user_id_drafted_group_map[student_id] ||= drafted_group) : (user_id_drafted_group_map[mentor_id] ||= drafted_group)
    end
    return user_id_drafted_group_map
  end

  def name(truncate = false)
    return self[:name] unless truncate
    self[:name].truncate(NAME_TRUNCATE_LENGTH)
  end

  def initial_student_mentor_pair
    student_id = self.student_memberships.first.user_id
    mentor_id = self.mentor_memberships.first.user_id
    [student_id, mentor_id]
  end

  def self.send_group_change_expiry_date_mails(group_id, member_ids)
    group = Group.find_by(id: group_id)
    return if group.blank?
    group_members = group.members.where(id: member_ids)
    group_members.each do |member|
      membership = group.membership_of(member)
      membership.send_email(group, RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE, nil, group.message)
    end
  end

  def set_marked_for_destroy
    self._marked_for_destroy_ = true
  end

  def create_group_forum
    return if self.reload_forum.present?
    return unless self.forum_enabled?
    return unless self.open_or_closed?
    self.create_forum!(name: "group_forum_#{self.id}", program_id: self.program_id)
    handle_forum_subscriptions(self.members)
  end

  def self.es_reindex(group, options = {})
    group_ids  = Array(group).collect(&:id)
    self.reindex_project_requests(group_ids) if options[:reindex_project_request] || options.blank?
    self.reindex_users(group_ids) if options[:reindex_user] || options.blank?
    self.reindex_member(group_ids) if options[:reindex_member] || options.blank?
  end

  def self.reindex_member(group_ids)
    member_ids = Connection::Membership.where(group_id: group_ids).joins(:user).pluck(:member_id).uniq
    DelayedEsDocument.delayed_bulk_update_es_documents(Member, member_ids)
  end

  def self.reindex_project_requests(group_ids)
    project_request_ids = ProjectRequest.where(group_id: group_ids).pluck(:id)
    DelayedEsDocument.delayed_bulk_update_es_documents(ProjectRequest, project_request_ids)
  end

  def self.reindex_users(group_ids)
    user_ids = Connection::Membership.where(group_id: group_ids).pluck(:user_id).uniq
    DelayedEsDocument.delayed_bulk_update_es_documents(User, user_ids)
  end

  # A pending group reaches critical mass (i.e. can be promoted for publish) when all the below conditions are met:
  # Pending for more than 7 days
  # No pending project requests
  # > 2 users
  # One user per mentoring role
  def reached_critical_mass?
    self.project_based? &&
    self.pending? &&
    self.pending_at <= 1.week.ago &&
    self.members.size > 2 &&
    self.membership_roles.size == self.program.mentoring_role_ids.size
  end

  def can_be_reactivated_by_user?(user)
    return false unless self.closed? && user.present?

    return true if user.can_manage_or_own_group?(self)
    membership = self.memberships.of(user).first
    return false unless membership.present?
    program.has_role_permission?(membership.role.name, "reactivate_groups")
  end

  def get_user_id_role_id_hash
    self.memberships.inject({}) do |user_id_role_id_hash, membership|
      user_id_role_id_hash[membership.user_id] = membership.role_id
      user_id_role_id_hash
    end
  end

  private

  def update_members_by_role(role, new_users, actor, options = {})
    old_users = self.memberships.includes(:user).where(role_id: role.id).collect(&:user)
    return {new_users: old_users} if options[:check_actor_can_update_members] && actor.present? && !actor.can_manage_role_in_group?(self, role)
    memberships_to_delete = []
    membership_ids_to_delete_with_tasks_included = []
    membership_ids_to_delete_due_to_replace = {}
    unless options[:disallow_removal]
      (old_users - new_users).each do |user|
        memberships_to_delete << self.membership_of(user)
        membership_ids_to_delete_with_tasks_included << self.membership_of(user).id if options[:removed_members_with_tasks_removed] && options[:removed_members_with_tasks_removed].include?(user.id)
        membership_ids_to_delete_due_to_replace[user.id] = self.membership_of(user).id if options[:replaced_members_list] && options[:replaced_members_list].keys.include?(user.id)
      end
    end
    # Assign/Remove mentor and catch and rethrow any errors raised.
    # This is done since the exception is typically thrown from
    # Connection::MentorMembership model. We convert that into an error on
    # the :mentors field.
    begin
      new_users += old_users if options[:disallow_removal]
      case role.name
      when RoleConstants::MENTOR_NAME
        self.mentors = new_users
      when RoleConstants::STUDENT_NAME
        self.students = new_users
      else
        self.add_and_remove_custom_users!(role, new_users, options)
      end
    rescue ActiveRecord::RecordInvalid => exception
      self.errors.add(:base, exception.record.errors.full_messages.to_sentence) unless exception.record.is_a?(Group)
      raise exception
    end
    return {
      new_users: new_users,
      memberships_to_delete: memberships_to_delete,
      membership_ids_to_delete_with_tasks_included: membership_ids_to_delete_with_tasks_included,
      membership_ids_to_delete_due_to_replace: membership_ids_to_delete_due_to_replace
    }
  end

  def destroy_connection_memberships!(memberships)
    memberships.each do |membership|
      membership.skip_destroy_callback = true
      membership.handle_custom_members_update = true
      membership.destroy
    end
  end

  def check_mentee_limit_of_mentor
    if self.program && mentor_limit_check_needed?
      self.mentors.each do |mentor|
        next unless mentor.is_mentor?

        # Find the students of the mentor, including those from other connections.
        mentoring_group_ids = self.program.groups.active_or_drafted.where(id: mentor.connection_mentor_memberships.pluck(:group_id)).pluck(:id)
        connected_student_memberships = (Connection::MenteeMembership.where(group_id: mentoring_group_ids) + self.student_memberships).uniq

        # Now, check whether the student count is exceeding the maximum students
        # limit as requested by the mentor.
        if connected_student_memberships.size > mentor.max_connections_limit
          errors[:base] << "activerecord.custom_errors.group.mentee_limit_reached_v1".translate(mentor_name: mentor.name, mentee_limit: mentor.max_connections_limit, mentees: self.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term_downcase)
        end
      end
    end
  end

  def check_students_count_for_one_to_one
    # Return if one to many mentoring is allowed.
    return if self.program.nil? || self.program.allow_one_to_many_mentoring?

    if self.students.size > 1
      errors.add(:students, "activerecord.custom_errors.group.one_to_one_allowed".translate)
    end
  end

  # Checks whether the +closed_by+ user is an administrator and belongs to the
  # same program.
  def check_closed_by_is_admin_or_auto_termination_or_leaving
    return if self.active? || self.drafted? || self.program.allow_users_to_leave_connection?
    # Validate closed_by only when status is changed to CLOSED.
    if self.changed.include?('status') && self.status == Group::Status::CLOSED
      if (self.closed_by.nil? && !self.auto_terminated?) ||
        (self.closed_by && !(self.closed_by.admin_of?(self.program) || self.closed_by.is_owner_of?(self)))

        self.errors[:base] << "activerecord.custom_errors.group.invalid_closed_by_v1".translate(mentoring_connection: self.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)
      end
    end
  end

  # Validates that the mentor and student are connected only once.
  def check_only_one_group_for_a_student_mentor_pair
    # Nothing to check if the connection is already closed..
    return if self.closed? || self.skip_student_mentor_validation.present? || self.program.allow_multiple_groups_between_student_mentor_pair?

    # If self is an existing record, skip it while checking in the DB.
    unless self.new_record?
      condition_sql = ["groups.id != ?", self.id]
    end

    # Make sure none of the students has a mentoring connection with the mentor.
    self.students.each do |student|
      self.mentors.each do |mentor|
        groups = Group.involving(student, mentor).where(condition_sql)
        if groups.drafted.exists?
          self.errors.add(:base, "activerecord.custom_errors.group.already_drafted".translate(mentor_name: mentor.name, mentee_name: student.name, Mentor: self.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term_downcase))
          return
        elsif groups.any?
          self.errors.add(:base, "activerecord.custom_errors.group.already_mentoring_v1".translate(mentor_name: mentor.name, a_mentor: self.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).articleized_term_downcase, student_name: student.name))
          return
        end
      end
    end
  end

  def check_for_mentors_mentoring_mode
    old_mentors = self.old_members_by_role.present? ? self.old_members_by_role[:mentors] : !self.new_record? ? self.members_by_role[:mentors] : []
    if self.program.consider_mentoring_mode?
      (self.mentors - old_mentors).each do |mentor|
        if !(User::MentoringMode.ongoing_sanctioned.include?(mentor.mentoring_mode))
          self.errors.add(:base, "activerecord.custom_errors.group.mentor_has_one_time_mentoring_enabled".translate(mentor_name: mentor.name, meeting: self.program.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase, mentoring: self.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase))
        end
      end
    end
  end

  def check_expiry_time_is_valid
    return unless self.expiry_time_changed?
    begin
      #check if new_expiry_date is in time format or not
      Date.parse(expiry_time.to_s)
      self.expiry_time = self.expiry_time.to_date.end_of_day
    rescue
      self.errors.add(:base, "activerecord.custom_errors.group.invalid_expiration_date".translate)
      return false
    end
    #to check if the expiry date being set is a valid date and is greater than or equal to todays date
    if (self.expiry_time < Time.now)
      self.errors.add(:base, "activerecord.custom_errors.group.invalid_expiration_date".translate)
    end
  end

  def max_limit_of_a_role_in_project
    group_settings = self.membership_settings.with_max_limit
    group_settings.each do |group_setting|
      if group_setting.max_limit < self.memberships.select{|membership| membership.role == group_setting.role}.size
        self.errors.add(:base, "activerecord.custom_errors.group.limit_reached_for_project".translate(
          plural_role_name: self.program.term_for(CustomizedTerm::TermType::ROLE_TERM, group_setting.role.name).pluralized_term_downcase,
          singular_role_name: self.program.term_for(CustomizedTerm::TermType::ROLE_TERM, group_setting.role.name).term_downcase,
          mentoring_connection: self.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase,
          count: group_setting.max_limit)
        )
      end
    end
  end

  def validate_roles
    if self.published?
      self.errors.add(:base, "activerecord.custom_errors.can_not_be_blank".translate(Objects: self.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term)) if self.mentors.blank?
      self.errors.add(:base, "activerecord.custom_errors.can_not_be_blank".translate(Objects: self.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term)) if self.students.blank?
    end
  end

  def self.get_group_id_user_or_member_id_role_id_map(groups_scope)
    group_id_user_or_member_id_role_id_map = {}

    groups_scope.each do |group|
      group_id_user_or_member_id_role_id_map[group.id] ||= {}
      user_or_member_ids = group.user_or_member_ids.split(",").collect(&:to_i)
      user_or_member_ids.each { |user_or_member_id| group_id_user_or_member_id_role_id_map[group.id][user_or_member_id] = group.role_id }
    end
    group_id_user_or_member_id_role_id_map
  end

  def handle_bulk_match_association_integrity(new_students, new_mentors)
    return if self.bulk_match_id.blank?

    initial_student_id, initial_mentor_id = self.initial_student_mentor_pair
    is_student_retained = new_students.collect(&:id).include? initial_student_id
    is_mentor_retained = new_mentors.collect(&:id).include? initial_mentor_id
    if !is_student_retained || !is_mentor_retained
      self.bulk_match_id = nil
    end
  end

  def create_scrap_receivers_for_added_members(added_member_ids)
    return if added_member_ids.blank?

    self.scraps.each do |scrap|
      receiver_ids = (scrap.receiver_ids + added_member_ids).flatten.uniq - [scrap.sender_id]
      scrap.receiver_ids = receiver_ids
      scrap.save!
      scrap.message_receivers.update_all("abstract_message_receivers.message_root_id = #{scrap.root_id}")
    end
  end

  def handle_forum_subscriptions(users_to_subscribe = [], users_to_unsubscribe = [])
    return if self.forum.blank?

    current_subscribers = self.forum.subscribers
    users_to_subscribe.each do |user|
      self.forum.subscribe_user(user)
      self.topics.each { |topic| topic.subscribe_user(user) }
    end
    (current_subscribers & users_to_unsubscribe).each do |user|
      self.forum.unsubscribe_user(user)
      self.topics.each { |topic| topic.unsubscribe_user(user) }
    end
  end

  def membership_setting_total_slots_for_role(role_id)
    self.membership_settings.find{|setting| setting.role_id == role_id}.try(:max_limit) || Group::MembershipSetting::MaxLimit::DEFAULT_MAXIMUM
  end

  def membership_setting_slots_taken_for_role(role_id)
    self.memberships.select{|setting| setting.role_id == role_id}.size
  end

  def get_roles_for_mentoring_hash
    roles_hash = {}
    Role.where(program_id: self.program_id).for_mentoring.pluck(:id, :name).each do |role|
      roles_hash[role[1]] = role[0]
    end
    roles_hash
  end

  def get_non_default_roles_for_mentoring_hash
    roles_hash = {}
    Role.where(program_id: self.program_id).for_mentoring.non_default.pluck(:id, :name).each do |role|
      roles_hash[role[1]] = role[0]
    end
    roles_hash
  end

  def has_slots?(group_setting, additional_count)
    max_limit = group_setting.max_limit
    if max_limit.present?
      max_limit >= (additional_count + self.memberships.select{ |membership| membership.role_id == group_setting.role_id }.size)
    else
      true
    end
  end
end
