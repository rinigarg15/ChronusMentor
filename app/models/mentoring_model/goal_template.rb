# == Schema Information
#
# Table name: mentoring_model_goal_templates
#
#  id                 :integer          not null, primary key
#  title              :string(255)
#  description        :text(16777215)
#  mentoring_model_id :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#

class MentoringModel::GoalTemplate < ActiveRecord::Base

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:title, :description],
    :update => [:title, :description]
  }

  belongs_to :mentoring_model
  has_many :task_templates
  has_many :mentoring_model_goals, class_name: MentoringModel::Goal.name, foreign_key: :mentoring_model_goal_template_id

  translates :title, :description
  has_paper_trail on: [:update], class_name: 'ChronusVersion'

  validates :title, :mentoring_model_id, presence: true

  attr_accessor :skip_increment_version_and_sync_trigger

  def version_number
    versions.size + 1
  end
end