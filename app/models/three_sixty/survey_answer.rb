# == Schema Information
#
# Table name: three_sixty_survey_answers
#
#  id                             :integer          not null, primary key
#  three_sixty_survey_question_id :integer          not null
#  three_sixty_survey_reviewer_id :integer          not null
#  answer_text                    :text(16777215)
#  answer_value                   :integer
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#

class ThreeSixty::SurveyAnswer < ActiveRecord::Base
  self.table_name = :three_sixty_survey_answers
  
  belongs_to :survey_question, :foreign_key => "three_sixty_survey_question_id", :class_name => "ThreeSixty::SurveyQuestion"
  belongs_to :survey_reviewer, :foreign_key => "three_sixty_survey_reviewer_id", :class_name => "ThreeSixty::SurveyReviewer"

  validates :three_sixty_survey_question_id, :three_sixty_survey_reviewer_id, :presence => true
  validates :three_sixty_survey_question_id, :uniqueness => { :scope => :three_sixty_survey_reviewer_id }
  validate :answer_text_or_value_present

  scope :of_rating_type, -> { joins(:survey_question => :question).where("three_sixty_questions.question_type = #{ThreeSixty::Question::Type::RATING}")}
  scope :of_text_type, -> { joins(:survey_question => :question).where("three_sixty_questions.question_type = #{ThreeSixty::Question::Type::TEXT}")}

  delegate :question, :to => :survey_question
  delegate :survey_assessee, :to => :survey_reviewer

  def answer_text_or_value_present
    errors.add(:answer, "activerecord.custom_errors.three_sixty/survey_answer.no_answer".translate) unless self.answer_text || self.answer_value
  end

  def handle_destroy
    return unless self.question.of_rating_type?
    update_question_info_after_destroy
    update_competency_info_after_destroy
  end

  def get_question_info(reviewer_group=nil)
    question.survey_assessee_question_infos.find_by(three_sixty_survey_assessee_id: self.survey_assessee.id, three_sixty_reviewer_group_id: reviewer_group.try(:id)||0)
  end

  def get_competency_info(reviewer_group=nil)
    competency = question.competency
    competency.competency_infos.find_or_initialize_by(three_sixty_survey_assessee_id: survey_assessee.id, three_sixty_reviewer_group_id:  reviewer_group.try(:id)||0, three_sixty_competency_id:  competency.id)
  end

  private

  def update_question_info_after_destroy
    # For updating/destroying question info for all evaluators
    question_info = self.get_question_info
    update_question_info_on_answer_destroy(question_info)

    # For updating/destroying question info for the particular reviewer group
    question_info_for_reviewer_group = self.get_question_info(self.survey_reviewer.reviewer_group)
    update_question_info_on_answer_destroy(question_info_for_reviewer_group)
  end

  def update_competency_info_after_destroy
    # For updating competency info for all evaluators
    competency_info = self.get_competency_info
    update_competency_info_on_answer_destroy(competency_info)

    # For updating competency info for the particular reviewer group
    competency_info = self.get_competency_info(self.survey_reviewer.reviewer_group)
    update_competency_info_on_answer_destroy(competency_info)
  end

  def update_question_info_on_answer_destroy(question_info)
    new_answer_count = question_info.answer_count - 1
    new_average_rating = ((question_info.average_value * question_info.answer_count) - self.answer_value)/new_answer_count
    new_answer_count > 0 ? question_info.update_attributes!(:average_value => new_average_rating, :answer_count => new_answer_count) : question_info.destroy
  end

  def update_competency_info_on_answer_destroy(competency_info)
    new_answer_count = competency_info.answer_count - 1
    if new_answer_count > 0
      new_average_rating = ((competency_info.average_value * competency_info.answer_count) - self.answer_value)/new_answer_count
      competency_info.update_attributes!(:average_value => new_average_rating, :answer_count => new_answer_count)
    else
      competency_info.destroy
    end
  end

end
