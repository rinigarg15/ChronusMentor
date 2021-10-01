# == Schema Information
#
# Table name: feedback_forms
#
#  id         :integer          not null, primary key
#  program_id :integer          not null
#  created_at :datetime
#  updated_at :datetime
#  form_type  :integer
#

# Feedback form shown to mentee to rate their mentors in an engagement.
class Feedback::Form < ActiveRecord::Base
  self.table_name = :feedback_forms
  
  module Type
    COACH_RATING = 1
  end
  ##############################################################################
  # ASSOCIATIONS
  ##############################################################################

  belongs_to_program

  # Questions are sorted by their position.
  has_many :questions,
            -> { order("position ASC") },
           :class_name => "Feedback::Question",
           :foreign_key => 'feedback_form_id',
           :dependent => :destroy

  has_many :responses,
           :class_name => "Feedback::Response",
           :foreign_key => 'feedback_form_id',
           :dependent => :destroy

  # All answers for this feedback. Includes student answers.
  has_many :answers,
           :through => :questions,
           :class_name => "Feedback::Answer"

  ##############################################################################
  # VALIDATIONS
  ##############################################################################

  validates_presence_of :program
  validates :form_type, :presence => true, :uniqueness => {:scope => :program_id }, :inclusion => {:in => Type::COACH_RATING..Type::COACH_RATING}

  #-----------------------------------------------------------------------------
  # SCOPES
  #-----------------------------------------------------------------------------
  
  scope :of_type, Proc.new{|type| where({:form_type => type}) }
end