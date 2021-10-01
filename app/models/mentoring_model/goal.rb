# == Schema Information
#
# Table name: mentoring_model_goals
#
#  id                               :integer          not null, primary key
#  title                            :string(255)
#  description                      :text(16777215)
#  status                           :integer          default(0)
#  from_template                    :boolean          default(FALSE)
#  group_id                         :integer          not null
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  mentoring_model_goal_template_id :integer
#  template_version                 :integer
#

class MentoringModel::Goal < ActiveRecord::Base
  self.table_name = "mentoring_model_goals"

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:title, :description],
    :update => [:title, :description]
  }

  belongs_to :group
  belongs_to :mentoring_model_goal_template, class_name: MentoringModel::GoalTemplate.name
  has_many   :mentoring_model_tasks, 
              -> {order("mentoring_model_tasks.milestone_id ASC, mentoring_model_tasks.position ASC")},
             :dependent  => :destroy, 
             :class_name => 'MentoringModel::Task'
  translates :title, :description

  has_many   :goal_activities,
             :class_name => 'MentoringModel::Activity',
             :as => :ref_obj,
             :dependent => :destroy

  has_one    :latest_activity,
              -> { where("mentoring_model_activities.progress_value IS NOT NULL").order("mentoring_model_activities.id DESC") },
             :class_name => 'MentoringModel::Activity',
             :as => :ref_obj

  validates :title, :group, presence: true
  validates :template_version, numericality: { only_integer: true, greater_than: 0 }, if: :from_template?

  class << self
    def from_template
      where(from_template: true)
    end
  end

  def completion_percentage(required_tasks = [])
    if self.manual_progress_goal?
      goal_activity = self.latest_activity
      return goal_activity.present? ? goal_activity.progress_value.to_i : MentoringModel::Activity::START_PROGRESS_VALUE
    else
      associated_tasks = required_tasks.collect{|task| task.status if task.goal_id == self.id }.compact
      associated_task_count = associated_tasks.size
      completed_task_count = associated_tasks.count(MentoringModel::Task::Status::DONE)
      return associated_task_count.zero? ? associated_task_count : ((completed_task_count * 100)/associated_task_count)
    end
  end

  def custom_entry?
    !self.from_template?
  end

  def parent_template
    self.mentoring_model_goal_template
  end

  def get_time_taken_to_reach_lastest_progress_in_days
    # this function is only for manual type goal, will have to update if task based goal
    last_activity = self.latest_activity.try(:created_at)
    last_activity.present? ? (((last_activity - self.group.published_at)/1.day).to_i) + 1 : 0
  end

  def manual_progress_goal?
    mentoring_model = self.group.get_mentoring_model
    return mentoring_model.manual_progress_goals?
  end
end
