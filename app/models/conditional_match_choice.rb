# == Schema Information
#
# Table name: conditional_match_choices
#
#  id                  :integer          not null, primary key
#  question_choice_id  :integer
#  profile_question_id :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#

class ConditionalMatchChoice < ActiveRecord::Base
  belongs_to :question_choice
  belongs_to :profile_question

  validates :profile_question_id, presence: true
  validates :question_choice_id, presence: true, uniqueness: { scope: [:profile_question_id] }

  validate :question_choice_belongs_to_profile_question


  def question_choice_belongs_to_profile_question
    return if question_choice.blank? || profile_question.blank?
    if question_choice.ref_obj_id != profile_question.conditional_question_id || question_choice.ref_obj_type != ProfileQuestion.name
      self.errors.add(:question_choice, "feature.profile_question.choices.label.conditional_choices.choice_conditional_question_mismatch".translate)
    end
  end
end
