# == Schema Information
#
# Table name: coaching_goals
#
#  id                       :integer          not null, primary key
#  title                    :string(255)
#  description              :text(16777215)
#  due_date                 :date
#  group_id                 :integer          not null
#  connection_membership_id :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#

class CoachingGoal < ActiveRecord::Base

  attr_accessor :updating_user, :creator

  has_many :coaching_goal_activities, :dependent => :destroy
  has_many :recent_activities, :as => :ref_obj, :dependent => :destroy
  has_many :pending_notifications,
           :as => :ref_obj,
           :dependent => :destroy
  
  belongs_to :group

  ##########Not being used anywhere right now################
  belongs_to :student_membership,
             :foreign_key => 'connection_membership_id',
             :class_name => "Connection::MenteeMembership"
  ############################################################

  validates :title, :group, :presence => true

  MASS_UPDATE_ATTRIBUTES = {
   :create => [:title, :description, :due_date],
   :update => [:title, :description, :due_date]
  }

  def completed?
    self.completed_percentage == CoachingGoalActivity::END_PROGRESS_VALUE
  end

  def in_progress?
    !overdue? && !completed?
  end

  def overdue?
    due_date.present? && (due_date < Time.now.utc.to_date) && !completed?
  end

  def completed_percentage
    coaching_goal_activity = self.coaching_goal_activities.where("progress_value IS NOT NULL").recent.first
    (coaching_goal_activity && coaching_goal_activity.progress_value.to_i) || CoachingGoalActivity::START_PROGRESS_VALUE
  end

  def last_coaching_goal_activity
    self.coaching_goal_activities.recent.first
  end

  def update_progress(membership, progress_value, message)
    coaching_goal_activity = self.coaching_goal_activities.new({
      :progress_value => progress_value && get_slider_value(self, progress_value),
      :message => message
    })
    coaching_goal_activity.initiator = membership.user
    coaching_goal_activity.save!
    coaching_goal_activity
  end

  private

  def get_slider_value(coaching_goal, slider_value)
    coaching_goal.completed_percentage == slider_value ? nil : slider_value
  end
end
