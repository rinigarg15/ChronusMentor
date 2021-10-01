# == Schema Information
#
# Table name: group_view_columns
#
#  id                     :integer          not null, primary key
#  group_view_id          :integer
#  profile_question_id    :integer
#  column_key             :text(16777215)
#  position               :integer
#  connection_question_id :integer
#  ref_obj_type           :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  role_id                :integer
#

class GroupViewColumn < ActiveRecord::Base
  ROLES_SEPARATOR = ", "
  COLUMN_SPLITTER = ":"

  # Column of the type.
  module ColumnType
    NONE  = 0
    GROUP = 1
    USER  = 2

    def self.all
      (NONE..USER)
    end
  end

  module Columns
    module Key
      NAME = "name"
      MEMBERS = "members"
      NOTES = "notes"
      ACTIVE_SINCE = "Active_since"
      LAST_ACTIVITY = "Last_activity"
      EXPIRES_ON = "Expires_on"
      CLOSED_BY = "Closed_by"
      CLOSED_ON = "Closed_on"
      REASON = "Reason"
      CREATED_BY = "Created_by"
      DRAFTED_SINCE = "Drafted_since"
      AVAILABLE_SINCE = "Available_since"
      PENDING_REQUESTS_COUNT = "Pending_requests"
      GOALS_STATUS_V2 = "goals_status_v2"
      TASKS_OVERDUE_STATUS_V2 = "tasks_overdue_status_v2"
      TASKS_PENDING_STATUS_V2 = "tasks_pending_status_v2"
      TASKS_COMPLETED_STATUS_V2 = "tasks_completed_status_v2"
      MILESTONES_OVERDUE_STATUS_V2 = "milestones_overdue_status_v2"
      MILESTONES_PENDING_STATUS_V2 = "milestones_pending_status_v2"
      MILESTONES_COMPLETED_STATUS_V2 = "milestones_completed_status_v2"
      MENTORING_MODEL_TEMPLATES = "mentoring_model_templates_v1"
      MEETINGS_ACTIVITY = "meetings_activity"
      MESSAGES_ACTIVITY = "messages_activity"
      POSTS_ACTIVITY = "posts_activity"
      LOGIN_ACTIVITY = "login_activity"
      PROPOSED_BY = "proposed_by"
      PROPOSED_AT = "proposed_at"
      REJECTED_BY = "rejected_by"
      REJECTED_AT = "rejected_at"
      WITHDRAWN_BY = "withdrawn_by"
      WITHDRAWN_AT = "withdrawn_at"
      SURVEY_RESPONSES = "survey_responses"
      TOTAL_SLOTS = 'total_slots'
      SLOTS_TAKEN = 'slots_taken'
      SLOTS_REMAINING = 'slots_remaining'
      START_DATE = 'start_date'
    end

    module Unsortable
      NOTES = "notes"
      REASON = "Reason"
      GOALS_STATUS_V2 = "goals_status_v2"

      def self.all
        [
          NOTES, REASON, GOALS_STATUS_V2
        ]
      end
    end

    module Defaults
      COMMON_DEFAULTS = [
        Key::NAME,
        Key::MEMBERS,
        Key::NOTES
      ]

      COLUMNS_TO_IGNORE_MAP = {
        Group::Status::DRAFTED => [
          Key::CLOSED_BY,
          Key::CLOSED_ON,
          Key::REASON,
          Key::ACTIVE_SINCE,
          Key::LAST_ACTIVITY,
          Key::EXPIRES_ON,
          Key::AVAILABLE_SINCE,
          Key::PENDING_REQUESTS_COUNT,
          Key::GOALS_STATUS_V2,
          Key::TASKS_OVERDUE_STATUS_V2,
          Key::TASKS_PENDING_STATUS_V2,
          Key::TASKS_COMPLETED_STATUS_V2,
          Key::MILESTONES_OVERDUE_STATUS_V2,
          Key::MILESTONES_PENDING_STATUS_V2,
          Key::MILESTONES_COMPLETED_STATUS_V2,
          Key::MEETINGS_ACTIVITY,
          Key::MESSAGES_ACTIVITY,
          Key::POSTS_ACTIVITY,
          Key::LOGIN_ACTIVITY,
          Key::REJECTED_BY,
          Key::REJECTED_AT,
          Key::PROPOSED_BY,
          Key::PROPOSED_AT,
          Key::SURVEY_RESPONSES,
          Key::WITHDRAWN_BY,
          Key::WITHDRAWN_AT,
          Key::TOTAL_SLOTS,
          Key::SLOTS_TAKEN,
          Key::SLOTS_REMAINING
        ],
        Group::Status::PENDING => [
          Key::CLOSED_BY,
          Key::CLOSED_ON,
          Key::REASON,
          Key::ACTIVE_SINCE,
          Key::LAST_ACTIVITY,
          Key::EXPIRES_ON,
          Key::GOALS_STATUS_V2,
          Key::TASKS_OVERDUE_STATUS_V2,
          Key::TASKS_PENDING_STATUS_V2,
          Key::TASKS_COMPLETED_STATUS_V2,
          Key::MILESTONES_OVERDUE_STATUS_V2,
          Key::MILESTONES_PENDING_STATUS_V2,
          Key::MILESTONES_COMPLETED_STATUS_V2,
          Key::MEETINGS_ACTIVITY,
          Key::MESSAGES_ACTIVITY,
          Key::POSTS_ACTIVITY,
          Key::LOGIN_ACTIVITY,
          Key::CREATED_BY,
          Key::DRAFTED_SINCE,
          Key::REJECTED_BY,
          Key::REJECTED_AT,
          Key::SURVEY_RESPONSES,
          Key::WITHDRAWN_BY,
          Key::WITHDRAWN_AT
        ],
        Group::Status::CLOSED => [
          Key::EXPIRES_ON,
          Key::CREATED_BY,
          Key::DRAFTED_SINCE,
          Key::AVAILABLE_SINCE,
          Key::PENDING_REQUESTS_COUNT,
          Key::REJECTED_BY,
          Key::REJECTED_AT,
          Key::WITHDRAWN_BY,
          Key::WITHDRAWN_AT,
          Key::START_DATE
        ],
        Group::Status::PROPOSED => [
          Key::ACTIVE_SINCE,
          Key::LAST_ACTIVITY,
          Key::CLOSED_BY,
          Key::CLOSED_ON,
          Key::REASON,
          Key::GOALS_STATUS_V2,
          Key::TASKS_OVERDUE_STATUS_V2,
          Key::TASKS_PENDING_STATUS_V2,
          Key::TASKS_COMPLETED_STATUS_V2,
          Key::MILESTONES_OVERDUE_STATUS_V2,
          Key::MILESTONES_PENDING_STATUS_V2,
          Key::MILESTONES_COMPLETED_STATUS_V2,
          Key::MEETINGS_ACTIVITY,
          Key::MESSAGES_ACTIVITY,
          Key::POSTS_ACTIVITY,
          Key::LOGIN_ACTIVITY,
          Key::EXPIRES_ON,
          Key::CREATED_BY,
          Key::DRAFTED_SINCE,
          Key::REJECTED_BY,
          Key::REJECTED_AT,
          Key::PENDING_REQUESTS_COUNT,
          Key::MENTORING_MODEL_TEMPLATES,
          Key::AVAILABLE_SINCE,
          Key::SURVEY_RESPONSES,
          Key::WITHDRAWN_BY,
          Key::WITHDRAWN_AT,
          Key::TOTAL_SLOTS,
          Key::SLOTS_TAKEN,
          Key::SLOTS_REMAINING
        ],
        Group::Status::REJECTED => [
          Key::ACTIVE_SINCE,
          Key::LAST_ACTIVITY,
          Key::CLOSED_BY,
          Key::CLOSED_ON,
          Key::REASON,
          Key::GOALS_STATUS_V2,
          Key::TASKS_OVERDUE_STATUS_V2,
          Key::TASKS_PENDING_STATUS_V2,
          Key::TASKS_COMPLETED_STATUS_V2,
          Key::MILESTONES_OVERDUE_STATUS_V2,
          Key::MILESTONES_PENDING_STATUS_V2,
          Key::MILESTONES_COMPLETED_STATUS_V2,
          Key::MEETINGS_ACTIVITY,
          Key::MESSAGES_ACTIVITY,
          Key::POSTS_ACTIVITY,
          Key::LOGIN_ACTIVITY,
          Key::EXPIRES_ON,
          Key::CREATED_BY,
          Key::DRAFTED_SINCE,
          Key::AVAILABLE_SINCE,
          Key::PENDING_REQUESTS_COUNT,
          Key::MENTORING_MODEL_TEMPLATES,
          Key::SURVEY_RESPONSES,
          Key::WITHDRAWN_BY,
          Key::WITHDRAWN_AT,
          Key::START_DATE
        ],
        Group::Status::WITHDRAWN => [
          Key::ACTIVE_SINCE,
          Key::LAST_ACTIVITY,
          Key::CLOSED_BY,
          Key::CLOSED_ON,
          Key::REASON,
          Key::GOALS_STATUS_V2,
          Key::TASKS_OVERDUE_STATUS_V2,
          Key::TASKS_PENDING_STATUS_V2,
          Key::TASKS_COMPLETED_STATUS_V2,
          Key::MILESTONES_OVERDUE_STATUS_V2,
          Key::MILESTONES_PENDING_STATUS_V2,
          Key::MILESTONES_COMPLETED_STATUS_V2,
          Key::MEETINGS_ACTIVITY,
          Key::MESSAGES_ACTIVITY,
          Key::POSTS_ACTIVITY,
          Key::LOGIN_ACTIVITY,
          Key::EXPIRES_ON,
          Key::CREATED_BY,
          Key::DRAFTED_SINCE,
          Key::REJECTED_BY,
          Key::REJECTED_AT,
          Key::PENDING_REQUESTS_COUNT,
          Key::MENTORING_MODEL_TEMPLATES,
          Key::AVAILABLE_SINCE,
          Key::SURVEY_RESPONSES,
          Key::PROPOSED_BY,
          Key::PROPOSED_AT,
          Key::START_DATE
        ],
        Group::Status::ACTIVE => [
          Key::CLOSED_BY,
          Key::CLOSED_ON,
          Key::REASON,
          Key::CREATED_BY,
          Key::DRAFTED_SINCE,
          Key::AVAILABLE_SINCE,
          Key::PENDING_REQUESTS_COUNT,
          Key::REJECTED_BY,
          Key::REJECTED_AT,
          Key::WITHDRAWN_BY,
          Key::WITHDRAWN_AT,
          Key::START_DATE
        ]
      }

      DRAFTED_DEFAULTS = [
        Key::CREATED_BY,
        Key::DRAFTED_SINCE
      ]

      PROPOSED_REJECTED_DEFAULTS = [
        Key::PROPOSED_BY,
        Key::PROPOSED_AT,
        Key::REJECTED_BY,
        Key::REJECTED_AT
      ]

      WITHDRAWN_DEFAULTS = [
        Key::WITHDRAWN_BY,
        Key::WITHDRAWN_AT
      ]

      MENTORING_MODEL_V2_DEFAULTS = [
        Key::GOALS_STATUS_V2,
        Key::TASKS_OVERDUE_STATUS_V2,
        Key::TASKS_PENDING_STATUS_V2,
        Key::TASKS_COMPLETED_STATUS_V2,
        Key::MILESTONES_OVERDUE_STATUS_V2,
        Key::MILESTONES_PENDING_STATUS_V2,
        Key::MILESTONES_COMPLETED_STATUS_V2,
        Key::SURVEY_RESPONSES
      ]

      MULTIPLE_TEMPLATES_DEFAULTS = [
        Key::MENTORING_MODEL_TEMPLATES
      ]

      GROUP_MESSAGING_DEFAULTS = [
        Key::MESSAGES_ACTIVITY
      ]

      GROUP_FORUM_DEFAULTS = [
        Key::POSTS_ACTIVITY
      ]

      GROUP_MEETINGS_DEFAULTS = [
        Key::MEETINGS_ACTIVITY
      ]

      PROJECT_SLOT_COLUMNS = [
        Key::TOTAL_SLOTS,
        Key::SLOTS_TAKEN,
        Key::SLOTS_REMAINING
      ]

      PROJECT_BASED_COLUMNS = [
        Key::START_DATE
      ]

      ROLE_BASED_COLUMNS = [
        Key::MEMBERS,
        Key::MEETINGS_ACTIVITY,
        Key::MESSAGES_ACTIVITY,
        Key::POSTS_ACTIVITY,
        Key::LOGIN_ACTIVITY,
        Key::TOTAL_SLOTS,
        Key::SLOTS_TAKEN,
        Key::SLOTS_REMAINING
      ]

      def self.get_key_for_customized_view(key)
        case key
        when "Active_since"
          "Started_on"
        when "Expires_on"
          "Closes_on"
        when "Expires_in"
          "Closes_in"
        else
          key
        end
      end

      def self.title(key, program, options = {})
        # mentoring connection term will use program level custom term if present.
        role_custom_term = program.roles.for_mentoring.find(options[:role_id]).customized_term.term if options[:role_id].present?
        translate_options = {
          meetings_name: program.term_for(CustomizedTerm::TermType::MEETING_TERM).pluralized_term,
          Mentoring_Connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term
        }
        translate_options.merge!(role_name: role_custom_term) if role_custom_term.present?
        "feature.connection.content.#{get_key_for_customized_view(key)}".translate(translate_options)
      end

      def self.all
        Columns::Key.constants.collect { |key| Columns::Key.const_get(key) }
      end

      def self.has?(key_string)
        self.all.include?(key_string)
      end
    end
  end

  module ForRole
    MENTOR = 0
    MENTEE = 1
  end

  belongs_to :group_view
  belongs_to :profile_question
  belongs_to :connection_question, class_name: "Connection::Question"
  belongs_to :role

  validates :group_view, presence: true
  validates :ref_obj_type, inclusion: {in: ColumnType.all}, allow_nil: true

  validates :role_id, presence: true, :if => Proc.new { |column| Columns::Defaults::ROLE_BASED_COLUMNS.include?(column.column_key) }

  validates :column_key,
    :presence => true,
    :uniqueness => {:scope => [:group_view_id, :role_id]},
    :inclusion => { :in => Columns::Defaults.all },
    :if => Proc.new { |column| column.profile_question_id.blank? && column.connection_question_id.blank? }

  validates :profile_question_id,
    :presence => true,
    :uniqueness => {:scope => [:group_view_id, :role_id]},
    :if => Proc.new { |column| column.column_key.blank? && column.connection_question_id.blank? }

  validates :connection_question_id,
    :presence => true,
    :uniqueness => {:scope => :group_view_id},
    :if => Proc.new { |column| column.column_key.blank? && column.profile_question_id.blank? }

  scope :default, -> { where(ref_obj_type: ColumnType::NONE) }
  scope :group_questions, -> { where(ref_obj_type: ColumnType::GROUP) }
  scope :user_questions, -> { where(ref_obj_type: ColumnType::USER) }
  scope :role_questions, -> (role_id) { where(ref_obj_type: ColumnType::USER, role_id: role_id) }

  def key
    self.column_key || (self.profile_question_id.present? ? self.profile_question_id.to_s : self.connection_question_id.to_s)
  end

  def sorting_key(roles_hsh = {})
    if (Columns::Defaults::ROLE_BASED_COLUMNS - Columns::Unsortable.all).include?(column_key)
      role = (roles_hsh[role_id] || Role.find(role_id))
      role_name = role.name
      case column_key
      when Columns::Key::TOTAL_SLOTS
        "membership_setting_total_slots.#{role_name}"
      when Columns::Key::SLOTS_TAKEN
        "membership_setting_slots_taken.#{role_name}"
      when Columns::Key::SLOTS_REMAINING
        "membership_setting_slots_remaining.#{role_name}"
      when Columns::Key::MEETINGS_ACTIVITY
        "meetings_activity_for_all_roles.#{role_name}"
      when Columns::Key::LOGIN_ACTIVITY
        "get_rolewise_login_activity_for_group.#{role_name}"
      when Columns::Key::MESSAGES_ACTIVITY
        "get_rolewise_messages_activity_for_group.#{role_name}"
      when Columns::Key::POSTS_ACTIVITY
        "get_rolewise_posts_activity_for_group.#{role_name}"
      when Columns::Key::MEMBERS
        role_user_sorting_key(role, role_name)
      end
    else
      column_key
    end
  end

  def get_title(roles_hsh)
    case self.ref_obj_type
    when ColumnType::NONE
      key = [self.column_key, self.role_id].compact.join(GroupViewColumn::COLUMN_SPLITTER)
      GroupViewColumn.get_default_title(key, self.group_view.program)
    when ColumnType::USER
      "#{roles_hsh[role_id].customized_term.term} - #{self.profile_question.question_text}"
    when ColumnType::GROUP
      self.connection_question.question_text
    end
  end

  def is_group_question?
    self.ref_obj_type == ColumnType::GROUP
  end

  def is_default_question?
    self.ref_obj_type == ColumnType::NONE
  end

  def is_user_question?
    self.ref_obj_type == ColumnType::USER
  end

  def is_sortable?
    self.is_default_question? && Columns::Unsortable.all.exclude?(self.key)
  end

  def is_messaging_column?
    self.column_key.in? GroupViewColumn::Columns::Defaults::GROUP_MESSAGING_DEFAULTS
  end

  def is_forum_column?
    self.column_key.in? GroupViewColumn::Columns::Defaults::GROUP_FORUM_DEFAULTS
  end

  def self.get_default_title(key, program)
    key, role_id = key.split(GroupViewColumn::COLUMN_SPLITTER)
    case key
    when Columns::Key::NAME
      "feature.connection.header.connection_name".translate(Mentoring_Connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term)
    when Columns::Key::MEMBERS
      customized_role_term = program.roles.find(role_id).customized_term
      program.allow_one_to_many_mentoring? ? customized_role_term.pluralized_term : customized_role_term.term
    else
      Columns::Defaults.title(key, program, role_id: role_id)
    end
  end

  def self.find_object(column_object_array, key, ref_obj_type, options)
    case ref_obj_type
    when ColumnType::NONE
      column_object_array.find { |column| column.column_key == key && column.role_id.to_i == options[:role_id].to_i }
    when ColumnType::USER
      column_object_array.find { |column| column.profile_question_id == key.to_i && column.role_id == options[:role_id].to_i }
    when ColumnType::GROUP
      column_object_array.find { |column| column.connection_question_id == key.to_i }
    end
  end

  def self.get_invalid_column_keys(tab_number)
    Columns::Defaults::COLUMNS_TO_IGNORE_MAP[tab_number]
  end

  private

  def role_user_sorting_key(role, role_name)
    if role.mentor?
      "mentors.name_only.sort"
    elsif role.mentee?
      "students.name_only.sort"
    else
      "role_users_full_name.#{role_name}_name"
    end
  end
end