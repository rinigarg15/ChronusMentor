# == Schema Information
#
# Table name: three_sixty_survey_assessee_competency_infos
#
#  id                             :integer          not null, primary key
#  three_sixty_survey_assessee_id :integer          not null
#  three_sixty_competency_id      :integer          not null
#  three_sixty_reviewer_group_id  :integer          not null
#  average_value                  :float(24)        default(0.0), not null
#  answer_count                   :integer          default(0), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#

class ThreeSixty::SurveyAssesseeCompetencyInfo < ActiveRecord::Base
  self.table_name = :three_sixty_survey_assessee_competency_infos

  has_many :related_competency_infos, :class_name => 'ThreeSixty::SurveyAssesseeCompetencyInfo', :foreign_key => :three_sixty_competency_id, :primary_key => :three_sixty_competency_id

  belongs_to :survey_assessee, :foreign_key => "three_sixty_survey_assessee_id", :class_name => 'ThreeSixty::SurveyAssessee'
  belongs_to :reviewer_group, :foreign_key => "three_sixty_reviewer_group_id", :class_name => 'ThreeSixty::ReviewerGroup'
  belongs_to :competency, :foreign_key => "three_sixty_competency_id", :class_name => 'ThreeSixty::Competency'

  validates :three_sixty_survey_assessee_id, :average_value, :answer_count, :presence => true
  validates :three_sixty_competency_id, :presence => true, :uniqueness => { :scope => [:three_sixty_survey_assessee_id, :three_sixty_reviewer_group_id] }

end
