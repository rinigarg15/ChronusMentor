# == Schema Information
#
# Table name: three_sixty_survey_reviewer_groups
#
#  id                            :integer          not null, primary key
#  three_sixty_survey_id         :integer          not null
#  three_sixty_reviewer_group_id :integer          not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#

class ThreeSixty::SurveyReviewerGroup < ActiveRecord::Base
  self.table_name = :three_sixty_survey_reviewer_groups

  belongs_to :reviewer_group, :foreign_key => "three_sixty_reviewer_group_id", :class_name => "ThreeSixty::ReviewerGroup"
  belongs_to :survey, :foreign_key => "three_sixty_survey_id", :class_name => "ThreeSixty::Survey"

  has_many :reviewers, :dependent => :destroy, :foreign_key => 'three_sixty_survey_reviewer_group_id', :class_name => 'ThreeSixty::SurveyReviewer'

  validates :three_sixty_survey_id, :presence => true
  validates :three_sixty_reviewer_group_id, :presence => true, :uniqueness => { :scope => :three_sixty_survey_id }

  validate :survey_and_reviewer_group_belong_to_same_organization

  scope :excluding_self_type, ->{ joins(:reviewer_group).where("three_sixty_reviewer_groups.name != ?", ThreeSixty::ReviewerGroup::DefaultName::SELF) }

  delegate :name, :to => :reviewer_group

  private

  def survey_and_reviewer_group_belong_to_same_organization
    errors.add(:three_sixty_reviewer_group_id, "activerecord.custom_errors.three_sixty/survey_reviewer_group.reviewer_group_should_belong_to_same_organization_as_survey".translate) unless self.reviewer_group.organization == self.survey.organization
  end
end
