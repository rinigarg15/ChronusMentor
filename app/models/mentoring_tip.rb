# == Schema Information
#
# Table name: mentoring_tips
#
#  id         :integer          not null, primary key
#  message    :text(65535)
#  enabled    :boolean          default(TRUE)
#  program_id :integer
#  created_at :datetime
#  updated_at :datetime
#

class MentoringTip < ActiveRecord::Base

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:enabled, :message],
    :update => [:enabled, :message]
  }
  acts_as_role_based
  belongs_to_program

  validates_presence_of :program, :message
  validates_length_of :message, :maximum => 350, :allow_blank => false, :allow_nil => false
  scope :enabled, -> { where(:enabled => true)}
end
