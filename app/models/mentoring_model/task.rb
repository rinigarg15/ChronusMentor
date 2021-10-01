# == Schema Information
#
# Table name: mentoring_model_tasks
#
#  id                               :integer          not null, primary key
#  connection_membership_id         :integer
#  group_id                         :integer
#  milestone_id                     :integer
#  goal_id                          :integer
#  required                         :boolean
#  title                            :string(255)
#  description                      :text(16777215)
#  due_date                         :datetime
#  status                           :integer
#  position                         :integer
#  action_item_type                 :integer
#  from_template                    :boolean          default(FALSE)
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  completed_date                   :date
#  mentoring_model_task_template_id :integer
#  unassigned_from_template         :boolean          default(FALSE)
#  action_item_id                   :integer
#  due_date_altered                 :boolean
#  completed_by                     :integer
#  template_version                 :integer
#

class MentoringModel::Task < ActiveRecord::Base

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:connection_membership_id, :required, :title, :description, :due_date, :status, :action_item_type, :action_item_id, :position, :goal_id, :milestone_id],
    :update => [:connection_membership_id, :required, :title, :description, :due_date, :status, :action_item_type, :action_item_id, :position, :goal_id, :milestone_id],
    :update_assignee_or_due_date => [:required, :goal_id, :milestone_id],
    :from_template => [:connection_membership_id]
  }

  # Modules and constants
  module Status
    TODO = 0
    DONE = 1

    def self.all
      [TODO, DONE]
    end
  end

  module Section
    OVERDUE = 0
    UPCOMING = 1
    REMAINING = 2
    COMPLETE = 3

    def self.all
      [OVERDUE, UPCOMING, REMAINING, COMPLETE]
    end
  end

  module StatusFilter
    COMPLETED = 0
    NOT_COMPLETED = 1
    OVERDUE = 2
  end

  TITLE_TRUNCATE_LENGTH = 80
  SIDEPANE_TITLE_TRUNCATE_LENGTH = 40
  SPAN_OF_DAYS_FOR_UPCOMING_TASKS = 15
  HOME_PAGE_TASKS_DEFAULT_LIMIT = 3

  sanitize_attributes_content :description
  # Validations
  validates :group_id, :title, presence: true
  validates :required, inclusion: { in: [true, false] }
  validates :status, inclusion: { in: Status.all }
  validates :from_template, presence: true, if: :unassigned_from_template?
  # due_date_validation is skipped only during group creation but immediately validated at next step. Don't skip the same for granted.
  validates :due_date, presence: true, if: ->(task){ task.required? && !task.skip_due_date_validation }
  validates :template_version, numericality: { only_integer: true, greater_than: 0 }, if: :from_template?

  # Associations
  belongs_to :connection_membership, foreign_key: "connection_membership_id", class_name: Connection::Membership.name
  belongs_to :completed_by_user, foreign_key: "completed_by", class_name: User.name
  belongs_to :group
  belongs_to :mentoring_model_goal, foreign_key: "goal_id", class_name: MentoringModel::Goal.name
  belongs_to :milestone, class_name: MentoringModel::Milestone.name
  belongs_to :mentoring_model_task_template, class_name: MentoringModel::TaskTemplate.name
  has_many :comments, class_name: MentoringModel::Task::Comment.name, foreign_key: "mentoring_model_task_id", dependent: :destroy
  has_many :checkins, as: :checkin_ref_obj, class_name:  GroupCheckin.name, foreign_key: "checkin_ref_obj_id", dependent: :destroy
  has_many :survey_answers, foreign_key: "task_id", dependent: :nullify
  has_many :pending_notifications, as: :ref_obj

  has_many :campaign_jobs,  :as => :abstract_object, :class_name => "CampaignManagement::SurveyCampaignMessageJob"
  has_one :campaign_status, :as => :abstract_object, :class_name => "CampaignManagement::SurveyCampaignStatus"

  translates :title, :description

  # Accessors
  attr_accessor :skip_update_positions, :skip_observer, :skip_due_date_validation, :perform_delta, :updated_from_connection, :skip_es_indexing

  # Scopes
  scope :completed_in_date_range, Proc.new {|date_range| where(:completed_date => date_range)}
  scope :required_and_owned_by_user, Proc.new {|user| required.owned_by(user)}
  scope :for_the_survey_id, Proc.new {|survey_id|  where(:action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY , :action_item_id => survey_id)}
  scope :of_engagement_survey_type, -> {where(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY)}
  scope :of_groups_with_ids, Proc.new {|group_ids|  where(group_id: group_ids)}

  alias_attribute :due_date_for_campaigns, :due_date

  # Class methods

  class << self
    def update_positions(tasks, changed_task)
      if changed_task.due_date
        tasks -= [changed_task]
        index = 0
        tasks.each{ |task| task.due_date && (task.due_date > changed_task.due_date) ? break : index += 1 }
        insert_and_update_postions(tasks, index, changed_task)
      elsif changed_task.position.nil?
        tasks -= [changed_task]
        index = tasks.size
        insert_and_update_postions(tasks, index, changed_task)
      end
    end

    def scoping_object(task)
      task.milestone || task.group
    end

    def scoping_object_id(task)
      task.milestone_id.present? ? "milestone#{task.milestone_id}" : "group#{task.group_id}"
    end

    def overdue
      where("`mentoring_model_tasks`.`due_date` IS NOT NULL AND `mentoring_model_tasks`.`due_date` < ? AND `mentoring_model_tasks`.`status` != ?",
        Time.now.utc.to_date.at_beginning_of_day, Status::DONE)
    end

    def overdue_in_last(time_duration)
      where("`mentoring_model_tasks`.`due_date` IS NOT NULL AND `mentoring_model_tasks`.`due_date` < ? AND `mentoring_model_tasks`.`status` != ? AND `mentoring_model_tasks`.`due_date` >= ?",
        Time.now.utc.to_date.at_beginning_of_day, Status::DONE, Time.now.utc.to_date.at_beginning_of_day - time_duration)
    end

    def overdue_before(time_duration)
      where("`mentoring_model_tasks`.`due_date` IS NOT NULL AND `mentoring_model_tasks`.`due_date` < ? AND `mentoring_model_tasks`.`status` != ?", Time.now.utc.to_date.at_beginning_of_day - time_duration, Status::DONE)
    end

    def due_date_in(start_date, end_date)
      where("`mentoring_model_tasks`.`due_date` IS NOT NULL AND `mentoring_model_tasks`.`due_date` < ? AND `mentoring_model_tasks`.`due_date` >= ?", end_date, start_date)
    end

    def pending
      status(Status::TODO).where("due_date IS NULL OR due_date > ?", Time.now.utc.to_date.at_beginning_of_day)
    end

    def status(state)
      where(status: state)
    end

    def upcoming(span_of_days = SPAN_OF_DAYS_FOR_UPCOMING_TASKS)
      where("`mentoring_model_tasks`.`due_date` IS NOT NULL AND `mentoring_model_tasks`.`due_date` >= ? AND `mentoring_model_tasks`.`due_date` < ? AND `mentoring_model_tasks`.`status` != ?",
        Time.now.utc.to_date.at_beginning_of_day, Time.now.utc.to_date.at_beginning_of_day + span_of_days.days, Status::DONE)
    end

    def completed(span_of_days)
      where("`mentoring_model_tasks`.`completed_date` IS NOT NULL AND `mentoring_model_tasks`.`completed_date` >= ? AND `mentoring_model_tasks`.`status` = ?",
        Time.now.utc.to_date.at_beginning_of_day - span_of_days.days, Status::DONE)
    end

    def completed_or_upcoming_or_overdue_in_last(span_of_days, time_duration)
      current_utc_time = Time.now.utc
      where("(`mentoring_model_tasks`.`completed_date` IS NOT NULL AND `mentoring_model_tasks`.`completed_date` >= ? AND `mentoring_model_tasks`.`status` = ?) OR (`mentoring_model_tasks`.`due_date` IS NOT NULL AND `mentoring_model_tasks`.`status` != ? AND ((`mentoring_model_tasks`.`due_date` < ? AND `mentoring_model_tasks`.`due_date` >= ?) OR ( `mentoring_model_tasks`.`due_date` >= ? AND `mentoring_model_tasks`.`due_date` < ?)))", current_utc_time.to_date.at_beginning_of_day - span_of_days.days, Status::DONE, Status::DONE, current_utc_time, current_utc_time - time_duration, current_utc_time.to_date.at_beginning_of_day, current_utc_time.to_date.at_beginning_of_day + span_of_days.days)
    end

    def required
      where("`mentoring_model_tasks`.`required` = ?", true)
    end

    def owned_by(user)
      joins(:connection_membership).where("`connection_memberships`.`user_id` = ?", user.id)
    end

    def from_template
      where(from_template: true)
    end

    def assigned
      where("connection_membership_id IS NOT NULL")
    end

    def get_complete_tasks(tasks)
      tasks.select(&:done?)
    end

    def get_pending_tasks(tasks)
      tasks.select(&:pending?)
    end

    def get_overdue_tasks(tasks)
      tasks.select(&:overdue?)
    end

    def get_upcoming_tasks(tasks)
      tasks.select(&:upcoming?)
    end

    def get_other_pending_tasks(tasks)
      overdue_tasks = get_overdue_tasks(tasks)
      upcoming_tasks = get_upcoming_tasks(tasks)
      complete_tasks = get_complete_tasks(tasks)
      tasks - (complete_tasks + overdue_tasks + upcoming_tasks)
    end

    def owned_by_users_with_ids(user_ids)
      joins(:connection_membership).where("connection_memberships.user_id IN (?)", user_ids).pluck(:id).uniq
    end

    def es_reindex(task)
      DelayedEsDocument.do_delta_indexing(Group, Array(task), :group_id)
    end

    private

    def insert_and_update_postions(tasks, index_to_insert, changed_task)
      tasks.insert(index_to_insert, changed_task).each_with_index do |task, index|
        task.position = index
        task.save!
      end
    end
  end

  # Instance methods

  def group_checkins_duration
    self.checkins.sum(:duration)
  end

  def comments_and_checkins
    comments_and_checkins = self.comments.recent.includes(sender: :profile_picture)
    if self.group.program.contract_management_enabled?
      checkins = self.checkins.includes(user: [member: :profile_picture])
      comments_and_checkins =  comments_and_checkins + checkins
    end
    comments_and_checkins.sort_by(&:created_at)
  end

  def unassigned?
    connection_membership.nil?
  end

  def user
    connection_membership && connection_membership.user
  end

  def is_owned_by?(curr_user)
    user.try(:id) == curr_user.id
  end

  def is_meeting_action_item?
    action_item_type == MentoringModel::TaskTemplate::ActionItem::MEETING
  end

  def is_goal_action_item?
    action_item_type == MentoringModel::TaskTemplate::ActionItem::GOAL
  end

  def is_engagement_survey_action_item?
    action_item_type == MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY
  end

  #TODO: Convert action_item into a polymorphic association & remove this function
  def action_item
    MentoringModel::TaskTemplate::ActionItem.action_item_name(action_item_type).find_by(id: action_item_id)
  end

  def done?
    status == Status::DONE
  end

  def todo?
    status == Status::TODO
  end

  def pending?
    todo? && !overdue?
  end

  def optional?
    !required?
  end

  def completed_within?(number_of_days = 1.week)
    done? && completed_date && completed_date > number_of_days.ago.to_date
  end

  # WARNING : should be used carefully for negative checking cases
  def overdue?
    required? && todo? && due_date && due_date < Time.now.utc.to_date.at_beginning_of_day
  end

  def upcoming?(span_of_days = SPAN_OF_DAYS_FOR_UPCOMING_TASKS)
    required? && todo? && due_date && due_date >= Time.now.utc.to_date.at_beginning_of_day && due_date < Time.now.utc.to_date.at_beginning_of_day + span_of_days.days
  end

  def due_date_coming_after?(number_of_days)
    due_date && due_date >= (Time.now.utc.to_date.at_beginning_of_day + number_of_days.days)
  end

  def custom_entry?
    !self.from_template?
  end

  def parent_template
    self.mentoring_model_task_template
  end

  def allow_checkin?(user)
    (self.user == user) && !self.is_meeting_action_item?
  end

  def can_send_campaign_email?
    user.present? && todo?
  end
end
