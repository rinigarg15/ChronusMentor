# == Schema Information
#
# Table name: three_sixty_questions
#
#  id                        :integer          not null, primary key
#  three_sixty_competency_id :integer
#  title                     :text(16777215)   default(""), not null
#  question_type             :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  organization_id           :integer          not null
#

class ThreeSixty::Question < ActiveRecord::Base
  self.table_name = :three_sixty_questions

  MASS_UPDATE_ATTRIBUTES = {
    create_and_add_to_survey: [:title, :question_type],
    create: [:title, :question_type, :three_sixty_competency_id],
    update: [:title]
  }

  module Type
    RATING = 0
    TEXT = 1

    MAP = {
      RATING => "rating",
      TEXT => "text"
    }
  end

  belongs_to :competency, :foreign_key => "three_sixty_competency_id", :class_name => "ThreeSixty::Competency"
  belongs_to :organization

  has_many :survey_questions, :dependent => :destroy, :foreign_key => 'three_sixty_question_id', :class_name => 'ThreeSixty::SurveyQuestion'
  has_many :survey_answers, :through => :survey_questions, :source => :answers
  has_many :survey_assessee_question_infos, :dependent => :destroy, :foreign_key => 'three_sixty_question_id', :class_name => 'ThreeSixty::SurveyAssesseeQuestionInfo'

  validates :organization_id, :presence => true
  validates :title, :presence => true, translation_uniqueness: { scope: [:three_sixty_competency_id, :organization_id], message: Proc.new { "activerecord.custom_errors.three_sixty/question.already_exists".translate } }
  validates :question_type, :presence => true, :inclusion => { :in => Type::RATING..Type::TEXT }
  validates :three_sixty_competency_id, :presence => true, :if => Proc.new { |three_sixty_question| three_sixty_question.question_type == Type::RATING }
  validate :competency_belongs_to_organization

  translates :title

  scope :of_rating_type, -> { where("question_type = #{Type::RATING}")}
  scope :of_text_type, -> { where("question_type = #{Type::TEXT}")}

  def of_rating_type?
    self.question_type == Type::RATING
  end

  def self.question_type_as_string(question_type)
    "feature.three_sixty.question.#{Type::MAP[question_type]}".translate
  end

  private

  def competency_belongs_to_organization
    errors.add(:three_sixty_competency_id, "activerecord.custom_errors.three_sixty/question.competency_should_belong_the_organization".translate) unless self.three_sixty_competency_id.nil? || self.competency.organization_id == self.organization_id
  end
end
