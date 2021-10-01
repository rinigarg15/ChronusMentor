# == Schema Information
#
# Table name: three_sixty_survey_questions
#
#  id                               :integer          not null, primary key
#  three_sixty_survey_competency_id :integer
#  three_sixty_question_id          :integer          not null
#  position                         :integer          not null
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  three_sixty_survey_id            :integer          not null
#

class ThreeSixty::SurveyQuestion < ActiveRecord::Base
  self.table_name = :three_sixty_survey_questions

  belongs_to :survey, :foreign_key => "three_sixty_survey_id", :class_name => "ThreeSixty::Survey"
  belongs_to :survey_competency, :foreign_key => "three_sixty_survey_competency_id", :class_name => "ThreeSixty::SurveyCompetency"
  belongs_to :question, :foreign_key => 'three_sixty_question_id', :class_name => 'ThreeSixty::Question'

  has_many :answers, :dependent => :destroy, :foreign_key => "three_sixty_survey_question_id", :class_name => "ThreeSixty::SurveyAnswer"

  validates :three_sixty_survey_id, :presence => true
  validates :three_sixty_survey_competency_id, :presence => true, :if => Proc.new { |survey_question| survey_question.question.three_sixty_competency_id.present? }
  validates :three_sixty_question_id, :presence => true, :uniqueness => { :scope => [:three_sixty_survey_competency_id, :three_sixty_survey_id] }
  validates :position, :presence => true, :uniqueness => { :scope => [:three_sixty_survey_competency_id, :three_sixty_survey_id]}
  validate :survey_competency_belongs_to_survey, :survey_competency_and_question_belong_to_same_competency

  before_validation :set_default_position, :on => :create

  after_destroy :destroy_survey_competency_if_no_questions

  private

  def survey_competency_belongs_to_survey
    errors.add(:three_sixty_survey_competency_id, "activerecord.custom_errors.three_sixty/survey_question.survey_competency_should_belong_to_survey".translate) unless self.three_sixty_survey_competency_id.nil? || self.survey_competency.survey == self.survey
  end

  def survey_competency_and_question_belong_to_same_competency
    errors.add(:three_sixty_question_id, "activerecord.custom_errors.three_sixty/survey_question.question_should_belong_to_same_competency".translate) unless self.three_sixty_survey_competency_id.nil? || self.survey_competency.competency == self.question.competency
  end

  def set_default_position
    self.position = self.survey_competency.present? ? self.survey_competency.survey_questions.pluck(:position).last.to_i + 1 : self.survey.survey_oeqs.pluck(:position).last.to_i + 1
  end

  def destroy_survey_competency_if_no_questions
    self.survey_competency.destroy if self.survey_competency.present? && !self.survey_competency.survey_questions.any?
  end
end
