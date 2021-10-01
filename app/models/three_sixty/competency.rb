# == Schema Information
#
# Table name: three_sixty_competencies
#
#  id              :integer          not null, primary key
#  organization_id :integer          not null
#  title           :string(255)      not null
#  description     :text(16777215)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

class ThreeSixty::Competency < ActiveRecord::Base
  self.table_name = :three_sixty_competencies
  MASS_UPDATE_ATTRIBUTES = {
    create: [:title, :description],
    update: [:title, :description]
  }
  belongs_to :organization

  has_many :competency_infos, :dependent => :destroy, :foreign_key => 'three_sixty_competency_id', :class_name => 'ThreeSixty::SurveyAssesseeCompetencyInfo'
  has_many :questions, -> { includes([:translations]) }, :dependent => :destroy, :foreign_key => 'three_sixty_competency_id', :class_name => 'ThreeSixty::Question'
  has_many :survey_competencies, :dependent => :destroy, :foreign_key => 'three_sixty_competency_id', :class_name => 'ThreeSixty::SurveyCompetency'

  validates :organization_id, :presence => true
  validates :title, :presence => true, translation_uniqueness: { scope: :organization_id, message: Proc.new { "activerecord.custom_errors.three_sixty/competency.already_exists".translate } }

  translates :title, :description

  scope :with_questions, -> { joins(:questions).group("three_sixty_competencies.id") }
end