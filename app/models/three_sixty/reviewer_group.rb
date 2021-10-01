# == Schema Information
#
# Table name: three_sixty_reviewer_groups
#
#  id              :integer          not null, primary key
#  organization_id :integer          not null
#  name            :string(255)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  threshold       :integer          not null
#

class ThreeSixty::ReviewerGroup < ActiveRecord::Base
  self.table_name = :three_sixty_reviewer_groups
  MASS_UPDATE_ATTRIBUTES = {
    create: [:name, :threshold],
    update: [:name, :threshold]
  }

  class DefaultName
    SELF = "Self"
    LINE_MANAGER = "Line Manager"
    PEER = "Peer"
    DIRECT_REPORT = "Direct Report"
    OTHER = "Other"

    def self.all
      [SELF, LINE_MANAGER, PEER, DIRECT_REPORT, OTHER]
    end
  end

  DefaultThreshold = {
    DefaultName::SELF => 0,
    DefaultName::LINE_MANAGER => 1,
    DefaultName::PEER => 3,
    DefaultName::DIRECT_REPORT => 3,
    DefaultName::OTHER => 0
  }

  belongs_to :organization

  has_many :survey_reviewer_groups, :dependent => :destroy, :foreign_key => 'three_sixty_reviewer_group_id', :class_name => 'ThreeSixty::SurveyReviewerGroup'
  has_many :survey_assessee_question_infos, :dependent => :destroy, :foreign_key => 'three_sixty_reviewer_group_id', :class_name => 'ThreeSixty::SurveyAssesseeQuestionInfo'
  has_many :survey_assessee_competency_infos, :dependent => :destroy, :foreign_key => 'three_sixty_reviewer_group_id', :class_name => 'ThreeSixty::SurveyAssesseeCompetencyInfo'

  validates :organization_id, :presence => true
  validates :name, :presence => true, :uniqueness => {scope: :organization_id,  message: "feature.language.validator.unique_error".translate(attribute: "name")}
  validates :threshold, :presence => true, :numericality => { :greater_than_or_equal_to => 0 }

  scope :excluding_self_type, -> { where("three_sixty_reviewer_groups.name != ?", DefaultName::SELF)}
  scope :of_self_type, -> { where("three_sixty_reviewer_groups.name = ?", DefaultName::SELF)}

  def self.create_default_review_groups_for_organization!(organization)
    DefaultName.all.each do |name|
      organization.three_sixty_reviewer_groups.create!(:name => name, :threshold => DefaultThreshold[name])
    end
  end

  def is_for_self?
    self.name == DefaultName::SELF
  end

  def error_for_display
    if self.errors[:name].present? && self.errors[:threshold].present?
      "feature.three_sixty.settings.reviewer_group.name_and_threshold_error_message".translate
    elsif self.errors[:name].present?
      "feature.three_sixty.settings.reviewer_group.add_error_message".translate
    elsif self.errors[:threshold].present?
      "feature.three_sixty.settings.reviewer_group.threshold_error_message".translate
    end
  end
end
