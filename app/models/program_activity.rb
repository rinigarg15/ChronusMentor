# == Schema Information
#
# Table name: program_activities
#
#  id          :integer          not null, primary key
#  program_id  :integer          not null
#  activity_id :integer          not null
#  created_at  :datetime
#  updated_at  :datetime
#

#
# Represents an instance of an activity in a program.
#
class ProgramActivity < ActiveRecord::Base

  ##############################################################################
  # ASSOCIATIONS
  ##############################################################################

  belongs_to :activity,
             :class_name => 'RecentActivity',
             :foreign_key => 'activity_id'

  belongs_to :program

  scope :in_program, ->(program) {
    where({:program_id => program})
  }

  ##############################################################################
  # VALIDATIONS
  ##############################################################################

  validate :check_program_has_the_activity_member

  ##############################################################################
  # INSTANCE METHODS
  ##############################################################################

  # Returns the +User+ by combining the +program+ and the +user+ in the activity.
  def user
    if self.activity && self.program && self.activity.member
      self.activity.member.user_in_program(self.program)
    end
  end

  private

  # Validates that the actor (member) of the activity is part of the +program+
  def check_program_has_the_activity_member
    return unless self.activity

    if self.activity.member && !self.user
      self.errors.add(:program, "activerecord.custom_errors.program.invalid_user".translate)
    end
  end
end
