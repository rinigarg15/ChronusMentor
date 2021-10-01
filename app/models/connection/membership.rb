# == Schema Information
#
# Table name: connection_memberships
#
#  id                                 :integer          not null, primary key
#  group_id                           :integer          not null
#  user_id                            :integer          not null
#  created_at                         :datetime
#  updated_at                         :datetime
#  status                             :integer          default(0), not null
#  type                               :string(255)
#  last_status_update_at              :datetime
#  api_token                          :string(255)
#  notification_setting               :integer          default(0)
#  last_update_sent_time              :datetime         default(Tue, 26 Feb 2013 06:23:49 UTC +00:00)
#  login_count                        :integer          default(0)
#  role_id                            :integer
#  owner                              :boolean          default(FALSE)
#  last_applied_task_filter           :string(255)
#

class Connection::Membership < ActiveRecord::Base
  self.table_name = 'connection_memberships'

  #Donot change where serialize is defined.
  serialize :last_applied_task_filter

  MEMBERSHIP_TYPE_HASH = {
    RoleConstants::STUDENT_NAME => Connection::MenteeMembership.name,
    RoleConstants::MENTOR_NAME  => Connection::MentorMembership.name
  }

  INACTIVITY_NOTICE_PERIOD = 2.weeks

  # Possible member states in the connection.
  module Status
    ACTIVE                = 0 # Some activity within the tracking period.
    INACTIVE              = 2 # No activity for more than tracking period.

    def self.all
      [ACTIVE, INACTIVE]
    end
  end

  module SendMessage
    ALL = 'all'
    OWNER = 'owner'
  end

  ##############################################################################
  # CALLBACKS
  ##############################################################################

  before_validation :set_api_token, :set_role, :on => :create

  after_create  :reindex_es
  after_update  :notify_about_change, :reindex_es
  before_destroy :fix_mentoring_model_tasks
  after_destroy :reindex_es, :cleanup_mentoring_model_tasks

  ##############################################################################
  # ASSOCIATIONS
  ##############################################################################

  belongs_to :group, touch: true
  belongs_to :user
  belongs_to :role

  has_many :private_notes,
           :class_name => "Connection::PrivateNote",
           :foreign_key => 'ref_obj_id',
           :dependent => :destroy

  has_many :coaching_goals,
           :foreign_key => 'connection_membership_id',
           :dependent => :destroy

  has_many :pending_notifications,
           :as => :ref_obj_creator,
           :dependent => :destroy

  has_many :pending_notification_references, as: :ref_obj, class_name: "PendingNotification", dependent: :destroy

  has_many :mentoring_model_tasks,
           :class_name => "MentoringModel::Task",
           :foreign_key => 'connection_membership_id'

  has_many :state_changes,
           :class_name => ConnectionMembershipStateChange.name,
           :foreign_key => 'connection_membership_id'

  has_many :job_logs, as: :ref_obj, dependent: :destroy

  has_many :mentoring_model_activities, class_name: "MentoringModel::Activity", :foreign_key => 'connection_membership_id'
  # Memberships of the given user.
  scope :of, ->(user) { where({:user_id => user.id})}

  scope :of_active_criteria_groups, -> {joins(:group).where("groups.status in (?)", Group::Status::ACTIVE_CRITERIA)}

  scope :of_open_or_proposed_groups, -> {joins(:group).where("groups.status IN (?)", Group::Status::OPEN_CRITERIA + [Group::Status::PROPOSED])}

  scope :with_role, ->(role) { where(role_id: role.id) }

  attr_accessor :leave_connection_callback, :leaving_reason, :skip_destroy_callback, :_marked_for_destroy_, :handle_custom_members_update, :created_for_sales_demo
  ##############################################################################
  # VALIDATIONS
  ##############################################################################

  validates :group, :user, :role_id, :status, :api_token, presence: true
  validates_uniqueness_of :api_token
  validates_inclusion_of  :status, :in => Status.all
  validate :check_user_and_group_belong_to_same_program
  validate :check_for_mentoring
  validate :last_applied_task_filter_view_mode_inclusion
  validate :check_user_exists_in_group, on: :create

  def self.recent(since)
    where(['connection_memberships.created_at > ?', since])
  end

  def inactive?
    self.status == Status::INACTIVE
  end

  def active?
    self.status == Status::ACTIVE
  end

  def user_info
    self.last_applied_task_filter[:user_info]
  end

  def view_mode
    return unless self.last_applied_task_filter.present?
    self.last_applied_task_filter[:view_mode].to_i if self.last_applied_task_filter[:view_mode].present?
  end

  def handle_reply_via_email(email_params)
    if self.user.active?
      if self.group.active?
        msg = email_params[:content]
        scrap = self.group.scraps.new
        scrap.subject = msg.split(". ").first.truncate(250)
        scrap.content = msg
        scrap.sender = self.user.member
        scrap.program = self.group.program
        self.group.get_groupees(self.user).each {|receiving_user| scrap.receivers << receiving_user.member}
        scrap.posted_via_email = true
        scrap.save!
        return true
      else
        ChronusMailer.posting_in_mentoring_area_failure(self.user, self.group, email_params[:subject], email_params[:content]).deliver_now
      end
    end
    return false
  end

  def self.destroy_notes_and_recent_activities(group_id, connection_membership_ids_array, member_ids_of_deleted_memberships)
    # destroying notes and recent activities
    Connection::PrivateNote.where(ref_obj_id: connection_membership_ids_array).destroy_all
    RecentActivity.destroy_all_belonging_to_connection_memberships(group_id, member_ids_of_deleted_memberships)
  end

  def self.unassign_tasks_for_deleted_memberships(membership_ids)
    mentoring_model_tasks = MentoringModel::Task.where(connection_membership_id: membership_ids)
    mentoring_model_tasks.where(from_template: true).update_all(unassigned_from_template: true)
    mentoring_model_tasks.update_all(connection_membership_id: nil)
  end

  def self.destroy_pending_tasks_for_deleted_memberships(membership_ids)
    mentoring_model_tasks = MentoringModel::Task.where(connection_membership_id: membership_ids)
    mentoring_model_tasks.where(:status => MentoringModel::Task::Status::TODO).destroy_all
    Connection::Membership.unassign_completed_tasks_for_removed_or_replaced_members(mentoring_model_tasks)
  end

  def self.reassign_pending_tasks_for_replaced_memberships(options)
    mentoring_model_tasks_for_replaced_members = MentoringModel::Task.where(connection_membership_id: options[:membership_ids_to_delete_due_to_replace].values.compact)
    options[:membership_ids_to_delete_due_to_replace].each do |replaced_member_id, connection_membership_id|
      mentoring_model_tasks = mentoring_model_tasks_for_replaced_members.where(:connection_membership_id => connection_membership_id)
      if !mentoring_model_tasks.blank?
        replacement_member_id = options[:replaced_members_list][replaced_member_id]
        new_connection_membership_id = options[:new_replacement_memberships_hash][replacement_member_id]
        mentoring_model_tasks.where(:status => MentoringModel::Task::Status::TODO).update_all(connection_membership_id: new_connection_membership_id)
        Connection::Membership.unassign_completed_tasks_for_removed_or_replaced_members(mentoring_model_tasks)
      end
    end
  end

  def self.unassign_completed_tasks_for_removed_or_replaced_members(mentoring_model_tasks)
    mentoring_model_tasks.where(:status => MentoringModel::Task::Status::DONE, :from_template => true).update_all(unassigned_from_template: true)
    mentoring_model_tasks.where(:status => MentoringModel::Task::Status::DONE).update_all(connection_membership_id: nil)
  end

  def self.destroy_dependent_objects(group_id, connection_membership_ids_array, member_ids_of_deleted_memberships, options={})
    # Destroying notes and recent activities
    Connection::Membership.destroy_notes_and_recent_activities(group_id, connection_membership_ids_array, member_ids_of_deleted_memberships)

    # Handling removal of tasks for deleted memberships

    membership_ids_for_leaving_tasks_unassigned = connection_membership_ids_array
    membership_ids_for_leaving_tasks_unassigned -= options[:membership_ids_to_delete_with_tasks_included] if options[:membership_ids_to_delete_with_tasks_included]
    membership_ids_for_leaving_tasks_unassigned -= options[:membership_ids_to_delete_due_to_replace].values.compact if options[:membership_ids_to_delete_due_to_replace]

    # Mark all the tasks unassigned for members removed via option of leaving tasks unassigned.
    Connection::Membership.unassign_tasks_for_deleted_memberships(membership_ids_for_leaving_tasks_unassigned) if membership_ids_for_leaving_tasks_unassigned.any?

    # Destroy all Pending and unassign the completed tasks for member removed via option of removing the pending tasks.
    Connection::Membership.destroy_pending_tasks_for_deleted_memberships(options[:membership_ids_to_delete_with_tasks_included]) if options[:membership_ids_to_delete_with_tasks_included]

    # Reassigning tasks for replaced members of the group
    if options[:membership_ids_to_delete_due_to_replace] && options[:new_replacement_memberships_hash] && options[:replaced_members_list]
      Connection::Membership.reassign_pending_tasks_for_replaced_memberships(options)
    end
  end

  def self.user_ids_in_groups(group_ids, program, type_or_role)
    group_ids = program.groups.where(id: group_ids).pluck(:id)
    type_or_role ||= SendMessage::ALL
    memberships =
      case type_or_role
      when SendMessage::ALL
        self
      when SendMessage::OWNER
        self.where(owner: true)
      else
        role = program.find_role(type_or_role)
        self.where(role_id: role.id)
      end
    memberships.where(group_id: group_ids).pluck("DISTINCT user_id")
  end

  # Sends the email right away if notification setting is all,
  # otherwise creates a pending notification.
  #
  # If opts[:send_now] is set, delivers email right away, even if notification
  # setting is not MentoringAreaConstants::NotifySetting::INDIVIDUAL
  #
  def send_email(object, action_type, initiator = nil, message = nil, opts = {})
    if object.is_a?(Topic)
      ChronusMailer.group_conversation_creation_notification(self.user, object, sender: object.user).deliver_now
    end
    PendingNotification.create!(
      ref_obj_creator: self,
      ref_obj: object,
      program: self.group.program,
      action_type: action_type,
      initiator: initiator,
      message: message)
  end

  def increment_login_count
    self.update_column(:login_count, self.login_count + 1)
  end

  def update_role!(role)
    self.role = role
    self.type = MEMBERSHIP_TYPE_HASH[role.name] || Connection::CustomMembership.name
    self.save!
  end

  def create_membership_state_change(date_id, info_hash)
    return if self.created_for_sales_demo
    membership_state_change = self.state_changes.new(date_id: date_id, group_id: self.group_id, user_id: self.user_id, role_id: self.role_id)
    membership_state_change.set_info(info_hash)
    membership_state_change.save!
  end

  def create_user_state_change_on_group_state_change(date_id, user_group_info)
    user_info = user_group_info[:user]
    group_info = user_group_info[:group]
    # No need to add user state change when both group from and to state belong to active criteria or when both dont
    return unless (group_info[:from_state].present? && (Group::Status::ACTIVE_CRITERIA.include?(group_info[:from_state]) ^ Group::Status::ACTIVE_CRITERIA.include?(group_info[:to_state])))
    info = {}
    info[:state] = {from: user_info[:from_state], to: user_info[:to_state]}
    info[:role] = {from: user_info[:role_ids], to: user_info[:role_ids]}
    from_role = user_info[:role_ids_in_active_groups]
    # Do not change user[:role_ids_in_active_groups] to only unique elements
    to_role = Array.new(from_role)
    role_id_to_remove = self.role_id

    if Group::Status::ACTIVE_CRITERIA.include?(group_info[:to_state])
      from_role.delete_at(from_role.index(role_id_to_remove))
    elsif Group::Status::ACTIVE_CRITERIA.include?(group_info[:from_state])
      from_role << role_id_to_remove
    end
    connection_membership_info = {role: {from_role: from_role.uniq, to_role: to_role.uniq}}

    transition = user.state_transitions.new(date_id: date_id)
    transition.set_info(info)
    transition.set_connection_membership_info(connection_membership_info)
    transition.save!
  end

  def create_user_state_change_on_connection_membership_change(date_id, user_group_membership_info)
    return if self.created_for_sales_demo
    user_info = user_group_membership_info[:user]
    group_info = user_group_membership_info[:group]
    membership_info = user_group_membership_info[:connection_membership]
    return unless Group::Status::ACTIVE_CRITERIA.include?(group_info[:state])
    info = {}
    info[:state] = {from: user_info[:from_state], to: user_info[:to_state]}
    info[:role] = {from: user_info[:role_ids], to: user_info[:role_ids]}
    from_role = user_info[:role_ids_in_active_groups]
    to_role = Array.new(from_role)
    role_id_to_remove = self.role_id

    if membership_info[:from_state].nil?
      from_role.delete_at(from_role.index(role_id_to_remove))
    elsif membership_info[:to_state].nil?
      to_role.delete_at(to_role.index(role_id_to_remove))
    end
    connection_membership_info = {role: {from_role: from_role.uniq, to_role: to_role.uniq}}
    transition = user.state_transitions.new(date_id: date_id)
    transition.set_info(info)
    transition.set_connection_membership_info(connection_membership_info)
    transition.save!
  end

  def track_connection_membership_status_change(date_id, group_state, user_state, cm_state_change)
    return if self.created_for_sales_demo
    info = {
      group: {from_state: group_state, to_state: group_state},
      user: {from_state: user_state, to_state: user_state},
      connection_membership: cm_state_change
    }
    self.create_membership_state_change(date_id, info)
  end

  def get_last_outstanding_survey_task
    oldest_overdue_survey_task = self.group.mentoring_model.mentoring_model_task_templates.of_engagement_survey_type.collect(&:mentoring_model_tasks).flatten.select{|task| task.connection_membership_id == self.id && task.overdue?}.sort_by(&:due_date).first if self.group.mentoring_model.present?
    return oldest_overdue_survey_task
  end

  def target_user_type
    if last_applied_task_filter.present? && [GroupsController::TargetUserType::ALL_MEMBERS, GroupsController::TargetUserType::UNASSIGNED].include?(self.user_info)
      self.user_info
    elsif self.target_user_id.present?
      GroupsController::TargetUserType::INDIVIDUAL
    end
  end

  def target_user_id
    return unless self.last_applied_task_filter
    target_user_membership = self.group.memberships.find_by(user_id: self.user_info.to_i) 
    target_user_membership.user_id if target_user_membership.present?
  end

  #On changing this function, please change the scope "of_open_or_proposed_groups" also.
  def of_open_or_proposed_group?
    self.group.open_or_proposed?
  end

  def with_role?(role)
    self.role == role
  end

  private

  def check_user_exists_in_group
    existing_membership = group.present? && group.memberships.find_by(user: user)
    if existing_membership.present?
      errors.add(:base, "activerecord.custom_errors.membership.existing_user".translate(user_name: self.user.name(name_only: true), new_role: self.role.customized_term.term, mentoring_connection: self.group.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase, existing_role: existing_membership.role.customized_term.term))
    end
  end

  def check_for_mentoring
    if self.role && !self.role.for_mentoring?
      program = self.group.program
      errors.add(:base, "activerecord.custom_errors.membership.cannot_be_used_for_mentoring".translate(custom_role_name: role.customized_term.term, connections: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term))
    end
  end

  # Checks whether the user and the connection belong to the same program.
  def check_user_and_group_belong_to_same_program
    if self.user && self.group && self.user.program != self.group.program
      errors.add(:user, "activerecord.custom_errors.membership.not_belong_to_program".translate)
    end
  end

  def notify_about_change
    if self.saved_changes[:status] == [Status::ACTIVE, Status::INACTIVE]
      if self.group.program.auto_terminate?
        ChronusMailer.group_inactivity_notification_with_auto_terminate(self.user, self.group).deliver_now
      else
        Push::Base.queued_notify(PushNotification::Type::GROUP_INACTIVITY, self.group, {user_id: self.user.id})
        ChronusMailer.group_inactivity_notification(self.user, self.group).deliver_now
      end
    end
  end

  def set_api_token
    self.api_token = secure_digest(Time.now, (1..10).map{ rand.to_s })
  end

  def secure_digest(*args)
    Digest::MD5.hexdigest(args.flatten.join('--'))
  end

  def cleanup_mentoring_model_tasks
    unless self.handle_custom_members_update
      self.mentoring_model_tasks.update_all(:connection_membership_id => nil)
    end
  end

  def set_role
    self.role_id = get_role_for_membership(self) if self.role_id.blank?
  end

  def get_role_for_membership(connection_membership)
    program = connection_membership.group.try(:program)
    return if program.nil?
    roles = program.roles.for_mentoring.select([:id, :name]).group_by(&:name)
    case connection_membership.type
    when Connection::MentorMembership.name
      roles[RoleConstants::MENTOR_NAME].first.id
    when Connection::MenteeMembership.name
      roles[RoleConstants::STUDENT_NAME].first.id
    end
  end

  def fix_mentoring_model_tasks
    mentoring_model_tasks.where(from_template: true).update_all(unassigned_from_template: true)
  end

  def subscribed_topic_ids
    self.user.subscriptions.
      where(ref_obj_type: Topic.name, ref_obj_id: self.group.topic_ids).pluck(:ref_obj_id)
  end

  def last_applied_task_filter_view_mode_inclusion
    if self.view_mode.present? && !MentoringModelUtils::ViewMode.all.include?(self.view_mode)
      errors.add(:last_applied_task_filter, "activerecord.custom_errors.membership.invalid_view_mode".translate)
    end
  end

  def self.es_reindex(connection_membership, options = {})
    group_ids = Array(connection_membership).collect(&:group_id)
    DelayedEsDocument.delayed_bulk_update_es_documents(Group, group_ids.uniq) if options[:reindex_group] || options.blank?
    if options[:reindex_user] || options.blank?
      user_ids = Connection::Membership.where(group_id: group_ids).pluck(:user_id)
      user_ids += Array(connection_membership).collect(&:user_id)
      DelayedEsDocument.delayed_bulk_update_es_documents(User, user_ids.uniq)
    end
  end

  def reindex_es
    # This is to make sure the users are indexed and are listed in corresponding filters after getting connected
    if self.group.members # We are using all members because active_mentor_connection_count of a mentor is dependent on mentee connections being created for a mentor
      self.class.es_reindex(self, reindex_user: true, reindex_group: true)
    else
      self.class.es_reindex(self, reindex_group: true)
    end
  end

end