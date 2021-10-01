# == Schema Information
#
# Table name: three_sixty_surveys
#
#  id                      :integer          not null, primary key
#  organization_id         :integer          not null
#  title                   :string(255)      not null
#  description             :text(16777215)
#  state                   :string(255)
#  expiry_date             :date
#  issue_date              :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  delta                   :boolean          default(FALSE)
#  program_id              :integer
#  reviewers_addition_type :integer          default(0), not null
#

class ThreeSixty::Survey < ActiveRecord::Base
  self.table_name = :three_sixty_surveys

  include ThreeSixtySurveyElasticsearchSettings
  include ThreeSixtySurveyElasticsearchQueries

  MASS_UPDATE_ATTRIBUTES = {
    handle_survey_create_or_update: [:title, :expiry_date, :reviewers_addition_type]
  }
  PUBLISHED = "published"
  DRAFTED = "drafted"

  SURVEY_SHOW = "survey_show"
  MY_SURVEYS = "my_surveys"
  include AASM

  class View
    SETTINGS = 0
    QUESTIONS = 1
    PREVIEW  = 2
    ASSESSEES = 3

    def self.all
      [SETTINGS, QUESTIONS, PREVIEW, ASSESSEES]      
    end
  end

  module ReviewersAdditionType
    ADMIN_ONLY = 0
    ASSESSEE_ONLY = 1
  end

  belongs_to :organization
  belongs_to :program

  has_many :survey_competencies, -> {order :position}, :dependent => :destroy, :foreign_key => 'three_sixty_survey_id', :class_name => 'ThreeSixty::SurveyCompetency'
  has_many :competencies, :through => :survey_competencies
  has_many :survey_questions, :dependent => :destroy, :foreign_key => 'three_sixty_survey_id', :class_name => "ThreeSixty::SurveyQuestion"
  has_many :survey_oeqs, -> {order(:position).where("three_sixty_survey_questions.three_sixty_survey_competency_id IS NULL")}, :foreign_key => 'three_sixty_survey_id', :class_name => "ThreeSixty::SurveyQuestion"
  has_many :questions, :through => :survey_questions
  has_many :open_ended_questions, :through => :survey_oeqs, :source => :question
  has_many :answers, :through => :survey_questions

  has_many :survey_assessees, :dependent => :destroy, :foreign_key => 'three_sixty_survey_id', :class_name => 'ThreeSixty::SurveyAssessee'
  has_many :assessees, :through => :survey_assessees

  has_many :survey_reviewer_groups, :dependent => :destroy, :foreign_key => 'three_sixty_survey_id', :class_name => 'ThreeSixty::SurveyReviewerGroup'
  has_many :reviewer_groups, :through => :survey_reviewer_groups
  has_many :reviewers, :through => :survey_reviewer_groups
  has_many :job_logs, :as => :loggable_object

  validates :organization_id,  :presence => true
  validates :title, :presence => true, :uniqueness => { :scope => :organization_id,  message: "feature.language.validator.unique_error".translate(attribute: "title") }
  validates :reviewers_addition_type, :presence => true, :inclusion => { :in => ReviewersAdditionType::ADMIN_ONLY..ReviewersAdditionType::ASSESSEE_ONLY }
  validate :expiry_date_not_in_past
  validate :program_belongs_to_organizaion

  aasm :column => :state do
    state :drafted, :initial => true
    state :published

    event :publish do
      transitions :from => :drafted, :to => :published, :after => :set_issue_date, :guard => :can_be_published?
    end
  end

  def add_competency(competency)
    survey_competency = self.survey_competencies.create(:competency => competency)
    if survey_competency.valid?
      competency.questions.each do |question|
        survey_competency.survey_questions.create(:question => question, :survey => self)
      end
    end
    return survey_competency
  end

  def add_question(question)
    survey_competency = self.survey_competencies.find_or_create_by(three_sixty_competency_id: question.competency.id) if question.competency.present?
    self.survey_questions.create(:survey_competency => survey_competency, :question => question)
  end

  def notify_assessees
    return unless self.published?

    JobLog.compute_with_historical_data(self.survey_assessees, self, RecentActivityConstants::Type::THREE_SIXTY_SURVEY_ASSESSEE_NOTIFICATION) do |survey_assessee|
      survey_assessee.notify
    end
  end

  def notify_reviewers
    return unless (self.published? && self.only_admin_can_add_reviewers?)

    JobLog.compute_with_historical_data(self.reviewers.except_self, self, RecentActivityConstants::Type::THREE_SIXTY_SURVEY_REVIEWER_NOTIFICATION) do |reviewer|
      reviewer.notify
    end
  end

  def not_expired?
    !self.expiry_date.present? || self.expiry_date >= Time.now.utc.to_date
  end

  def created
    self.created_at
  end

  def survey_reviewer_group_for_self
    self.survey_reviewer_groups.joins(:reviewer_group).where("three_sixty_reviewer_groups.name = ?", ThreeSixty::ReviewerGroup::DefaultName::SELF).first
  end

  def create_default_reviewer_group
    self.reviewer_groups << self.organization.three_sixty_reviewer_groups.of_self_type.first
  end

  def add_reviewer_groups(reviewer_group_names)
    reviewer_group_names << self.organization.three_sixty_reviewer_groups.of_self_type.collect(&:name).first
    reviewer_groups = self.organization.three_sixty_reviewer_groups.select{|rg| reviewer_group_names.include?(rg.name)}
    self.survey_reviewer_groups.where("three_sixty_reviewer_group_id NOT in (?)", reviewer_groups.collect(&:id)).destroy_all
    self.reviewer_groups = reviewer_groups
  end

  def only_admin_can_add_reviewers?
    self.reviewers_addition_type == ReviewersAdditionType::ADMIN_ONLY
  end

  def only_assessee_can_add_reviewers?
    self.reviewers_addition_type == ReviewersAdditionType::ASSESSEE_ONLY
  end

  def self.es_reindex(survey)
    survey_assessee_ids = ThreeSixty::SurveyAssessee.where(three_sixty_survey_id: Array(survey).collect(&:id)).pluck(:id)
    DelayedEsDocument.delayed_bulk_update_es_documents(ThreeSixty::SurveyAssessee, survey_assessee_ids)
  end

  private

  def expiry_date_not_in_past
    self.errors.add(:expiry_date, "activerecord.custom_errors.three_sixty/survey.validate_expiry_date".translate) if self.expiry_date.present? && self.expiry_date < Time.now.utc.to_date
  end

  def can_be_published?
    self.not_expired? && self.survey_questions.present? && self.survey_assessees.present? && self.survey_reviewer_groups.size > 1
  end

  def set_issue_date
    self.update_attribute(:issue_date, Time.now)
  end

  def program_belongs_to_organizaion
    return unless self.program_id.present?
    self.errors.add(:program, "activerecord.custom_errors.three_sixty/survey.program_should_belong_to_organization".translate) unless self.organization && self.organization.programs.pluck(:id).include?(self.program_id)
  end

end
