# == Schema Information
#
# Table name: three_sixty_survey_competencies
#
#  id                        :integer          not null, primary key
#  three_sixty_survey_id     :integer          not null
#  three_sixty_competency_id :integer          not null
#  position                  :integer          not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#

class ThreeSixty::SurveyCompetency < ActiveRecord::Base
  self.table_name = :three_sixty_survey_competencies

  belongs_to :survey, :foreign_key => "three_sixty_survey_id", :class_name => "ThreeSixty::Survey"
  belongs_to :competency, :foreign_key => 'three_sixty_competency_id', :class_name => 'ThreeSixty::Competency'

  has_many :survey_questions, -> {order :position}, :dependent => :destroy, :foreign_key => 'three_sixty_survey_competency_id', :class_name => 'ThreeSixty::SurveyQuestion'
  has_many :questions, :through => :survey_questions

  validates :three_sixty_survey_id, :presence => true
  validates :three_sixty_competency_id, :presence => true, :uniqueness => { :scope => :three_sixty_survey_id }
  validates :position, :presence => true, :uniqueness => { :scope => :three_sixty_survey_id }

  validate :survey_and_competency_belong_to_same_organization

  before_validation :set_default_position, :on => :create

  delegate :title, :to => :competency

  def add_questions(question_ids)
    questions = self.competency.questions.where("three_sixty_questions.id" => question_ids)
    questions.each do |question|
      self.survey_questions.create(:survey => self.survey, :question => question)
    end
  end

  private

  def survey_and_competency_belong_to_same_organization
    errors.add(:three_sixty_competency_id, "activerecord.custom_errors.three_sixty/survey_competency.competency_should_belong_to_same_organization_as_survey".translate) unless self.competency.organization == self.survey.organization
  end

  def set_default_position
    self.position = self.survey.survey_competencies.pluck(:position).last.to_i + 1
  end
end
