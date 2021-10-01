# == Schema Information
#
# Table name: coaching_goal_activities
#
#  id               :integer          not null, primary key
#  coaching_goal_id :integer          not null
#  progress_value   :float(24)
#  message          :text(16777215)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class CoachingGoalActivity < ActiveRecord::Base
  START_PROGRESS_VALUE = 0
  END_PROGRESS_VALUE = 100

  attr_accessor :initiator

  has_many :recent_activities, :as => :ref_obj, :dependent => :destroy
  has_many :pending_notifications,
           :as => :ref_obj,
           :dependent => :destroy

  belongs_to :coaching_goal

  validates :coaching_goal, :presence => true

  validates :message, :presence => true, :if => lambda{ progress_value.blank? }
  validates :progress_value, :presence => true, :if => lambda{ message.blank? } 


  def self.recent
    order("created_at DESC")
  end
end
