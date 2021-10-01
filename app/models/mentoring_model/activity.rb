# == Schema Information
#
# Table name: mentoring_model_activities
#
#  id                       :integer          not null, primary key
#  ref_obj_id               :integer
#  ref_obj_type             :string(255)
#  progress_value           :float(24)
#  message                  :text(65535)
#  connection_membership_id :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  member_id                :integer
#

class MentoringModel::Activity < ActiveRecord::Base
  START_PROGRESS_VALUE = 0
  END_PROGRESS_VALUE = 100

  belongs_to :ref_obj, :polymorphic => true
  belongs_to :connection_membership,
             :foreign_key => 'connection_membership_id',
             :class_name => 'Connection::Membership'
  belongs_to :member

  validates :ref_obj, :presence => true
  validates :connection_membership, :member_id, :presence => true
  validates :progress_value, :numericality => { :greater_than_or_equal_to => MentoringModel::Activity::START_PROGRESS_VALUE, :less_than_or_equal_to => MentoringModel::Activity::END_PROGRESS_VALUE }, :allow_nil => true

  delegate :user, :to => :connection_membership

  def self.recent
    order("id desc")
  end
end
