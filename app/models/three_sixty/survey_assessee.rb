# == Schema Information
#
# Table name: three_sixty_survey_assessees
#
#  id                    :integer          not null, primary key
#  three_sixty_survey_id :integer          not null
#  member_id             :integer          not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  delta                 :boolean          default(FALSE)
#

class ThreeSixty::SurveyAssessee < ActiveRecord::Base
  NO_OF_FIRST_USERS = 3
  self.table_name = :three_sixty_survey_assessees

  include ThreeSixtySurveyAssesseeElasticsearchSettings
  include ThreeSixtySurveyElasticsearchQueries

  belongs_to :survey, :foreign_key => "three_sixty_survey_id", :class_name => "ThreeSixty::Survey"
  belongs_to :assessee, :foreign_key => "member_id", :class_name => 'Member'

  has_many :reviewers, :dependent => :destroy, :foreign_key => 'three_sixty_survey_assessee_id', :class_name => 'ThreeSixty::SurveyReviewer'
  has_many :survey_assessee_question_infos, :dependent => :destroy, :foreign_key => 'three_sixty_survey_assessee_id', :class_name => 'ThreeSixty::SurveyAssesseeQuestionInfo'
  has_many :survey_assessee_competency_infos, :dependent => :destroy, :foreign_key => 'three_sixty_survey_assessee_id', :class_name => 'ThreeSixty::SurveyAssesseeCompetencyInfo'
  has_many :job_logs, :as => :loggable_object
  has_many :job_log_references, :as => :ref_obj, class_name: "JobLog"

  validates :three_sixty_survey_id, :presence => true
  validates :member_id, :presence => { :message => Proc.new { "activerecord.custom_errors.three_sixty/survey_assessee.cant_be_blank".translate } }, :uniqueness => { :scope => :three_sixty_survey_id, :message => Proc.new { "activerecord.custom_errors.three_sixty/survey_assessee.already_exists".translate } }

  validate :survey_and_member_belong_to_same_organization, :survey_and_member_belong_to_same_program

  delegate :name, :to => :assessee

  scope :accessible, -> { joins(:survey).where("(three_sixty_surveys.expiry_date IS NULL || three_sixty_surveys.expiry_date >= ?) && three_sixty_surveys.state = ?", Time.now.utc, ThreeSixty::Survey::PUBLISHED) }
  scope :for_member, ->(member) { where("member_id = ?", member.id)}

  def self_reviewer
    self.reviewers.for_self.first
  end

  def create_self_reviewer!
    assessee = self.assessee
    self.reviewers.create!(:name => assessee.name, :email => assessee.email, :survey_reviewer_group => self.survey.survey_reviewer_group_for_self)
  end

  def notify
    return if self.self_reviewer.invite_sent?
    self.self_reviewer.update_attribute(:invite_sent, true)
    self.assessee.send_email(self.survey, RecentActivityConstants::Type::THREE_SIXTY_SURVEY_ASSESSEE_NOTIFICATION) 
  end

  def notify_pending_reviewers
    JobLog.compute_with_historical_data(self.reviewers.with_pending_invites, self, RecentActivityConstants::Type::THREE_SIXTY_SURVEY_REVIEWER_NOTIFICATION) do |reviewer|
      reviewer.notify
    end
  end

  def is_for?(member)
    self.assessee == member
  end

  def threshold_met?
    reviewers_count = self.reviewers.joins(:survey_reviewer_group => :reviewer_group).group("three_sixty_reviewer_groups.id").count
    self.survey.reviewer_groups.each do |reviewer_group|
      return false if (reviewers_count[reviewer_group.id]||0) < reviewer_group.threshold
    end
    return true
  end

  def average_reviewer_group_answer_values
    self.reviewers.joins(:answers => [:survey_question => :question]).select("three_sixty_questions.id AS question_id, three_sixty_survey_reviewers.three_sixty_survey_reviewer_group_id, AVG(three_sixty_survey_answers.answer_value) AS avg_value").where("three_sixty_questions.question_type = #{ThreeSixty::Question::Type::RATING}").group("three_sixty_questions.id, three_sixty_survey_reviewers.three_sixty_survey_reviewer_group_id").group_by{ |avg| [avg.question_id, avg.three_sixty_survey_reviewer_group_id] }
  end

  def average_competency_reviewer_group_answer_values
    self.reviewers.joins(:answers => [:survey_question => :question]).select("three_sixty_questions.three_sixty_competency_id AS competency_id, three_sixty_survey_reviewers.three_sixty_survey_reviewer_group_id, AVG(three_sixty_survey_answers.answer_value) AS avg_value").where("three_sixty_questions.question_type = #{ThreeSixty::Question::Type::RATING}").group("three_sixty_questions.three_sixty_competency_id, three_sixty_survey_reviewers.three_sixty_survey_reviewer_group_id").group_by{ |avg| [avg.competency_id, avg.three_sixty_survey_reviewer_group_id] }
  end

  def competency_percentiles
    self.survey_assessee_competency_infos.joins(:related_competency_infos).
    where("three_sixty_survey_assessee_competency_infos.three_sixty_reviewer_group_id = related_competency_infos_three_sixty_survey_assessee_competency_infos.three_sixty_reviewer_group_id").
    select("100*SUM(three_sixty_survey_assessee_competency_infos.average_value >= related_competency_infos_three_sixty_survey_assessee_competency_infos.average_value)/COUNT(*) AS percentile, three_sixty_survey_assessee_competency_infos.three_sixty_competency_id, three_sixty_survey_assessee_competency_infos.three_sixty_reviewer_group_id").
    group("three_sixty_survey_assessee_competency_infos.three_sixty_competency_id,three_sixty_survey_assessee_competency_infos.three_sixty_reviewer_group_id").
    group_by(&:three_sixty_competency_id)
  end

  def question_percentiles
    self.survey_assessee_question_infos.joins(:related_question_infos).
      where("three_sixty_survey_assessee_question_infos.three_sixty_reviewer_group_id = related_question_infos_three_sixty_survey_assessee_question_infos.three_sixty_reviewer_group_id").
      select("100*SUM(three_sixty_survey_assessee_question_infos.average_value >= related_question_infos_three_sixty_survey_assessee_question_infos.average_value)/COUNT(*) AS percentile, three_sixty_survey_assessee_question_infos.three_sixty_question_id, three_sixty_survey_assessee_question_infos.three_sixty_reviewer_group_id").
      group("three_sixty_survey_assessee_question_infos.three_sixty_reviewer_group_id, three_sixty_survey_assessee_question_infos.three_sixty_question_id").
      group_by(&:three_sixty_question_id)
  end

  # ELASTICSEARCH INDEX METHODS

  def expires
    self.survey.expiry_date
  end

  def issued
    self.survey.issue_date
  end

  def state
    self.survey.state
  end

  def organization_id
    self.survey.organization_id
  end

  def program_id
    self.survey.program_id
  end

  def title
    self.survey.title
  end

  def participant
    self.assessee.name(name_only: true)
  end


  private

  def survey_and_member_belong_to_same_organization
    return unless self.assessee
    errors.add(:member_id, "activerecord.custom_errors.three_sixty/survey_assessee.assessee_should_belong_to_same_organization_as_survey".translate) unless self.assessee.organization == self.survey.organization
  end

  def survey_and_member_belong_to_same_program
    return unless self.assessee && self.survey && self.survey.program
    errors.add(:member_id, "activerecord.custom_errors.three_sixty/survey_assessee.assessee_should_belong_to_same_program_as_survey".translate) unless self.assessee.programs.include?(self.survey.program)
  end
end
