# == Schema Information
#
# Table name: common_answers
#
#  id                      :integer          not null, primary key
#  user_id                 :integer
#  common_question_id      :integer
#  answer_text             :text(65535)
#  created_at              :datetime
#  updated_at              :datetime
#  type                    :string(255)
#  attachment_file_name    :string(255)
#  attachment_content_type :string(255)
#  attachment_file_size    :integer
#  attachment_updated_at   :datetime
#  feedback_response_id    :integer
#  group_id                :integer
#  survey_id               :integer
#  task_id                 :integer
#  response_id             :integer
#  member_meeting_id       :integer
#  meeting_occurrence_time :datetime
#  last_answered_at        :datetime
#  delta                   :boolean          default(FALSE)
#  is_draft                :boolean          default(FALSE)
#

class SurveyAnswer < CommonAnswer
  include SurveyAnswerElasticsearchSettings
  include SurveyAnswerElasticsearchQueries

  SCROLL_SURVEY_ANSWER_LIMIT = 180

  # ASSOCIATIONS ---------------------------------------------------------------
  # Use the same 'common_question_id' that is used by base CommonAnswer model.
  belongs_to :survey_question, :foreign_key => 'common_question_id'
  belongs_to :task, :class_name => "MentoringModel::Task", :foreign_key => "task_id"
  belongs_to :member_meeting
  belongs_to :group
  belongs_to :associated_survey, class_name: "Survey", foreign_key: "survey_id"
  belongs_to :role, foreign_key: "connection_membership_role_id"

  # VALIDATIONS ----------------------------------------------------------------

  validates_presence_of :survey_question
  validate :check_answerer
  validate :check_survey_is_not_overdue
  validates :last_answered_at, presence: true

  # User can have only one answer for a question
  validates_uniqueness_of :user_id, :scope => [:response_id, :common_question_id]

  default_scope Proc.new{where(is_draft: false)}
  scope :with_response_ids_in, Proc.new{|ids| where("response_id IN (?)", ids) unless ids.nil?}
  scope :last_answered, Proc.new{|time| where("last_answered_at > ?", time)}
  scope :drafted, -> {unscope(where: :is_draft).where(is_draft: true)}
  scope :for_user, Proc.new{|user| where(user_id: user.id)}
  scope :last_answered_in_date_range, Proc.new { |date_range| where(last_answered_at: date_range) }

  def self.es_reindex(survey_answer)
    group_ids = Array(survey_answer).collect(&:group_id).reject(&:nil?)
    reindex_group(group_ids)
  end

  def survey
    self.survey_question.survey if self.survey_question
  end

  def answer_text_sortable
    answer_text
  end

  private

  # Panic if a only-admin user attempts to take part in the survey.
  def check_answerer
    if self.user && self.user.is_admin_only?
      self.errors.add(:user, "activerecord.custom_errors.survey.cannot_participate".translate)
    end
  end

  def self.reindex_group(group_ids)
    DelayedEsDocument.delayed_bulk_update_es_documents(Group, group_ids)
  end

  # Make sure the survey due date has not passed.
  def check_survey_is_not_overdue
    if self.survey_question && self.survey_question.survey.program_survey? && self.survey_question.survey.overdue?
      self.errors[:base] << "activerecord.custom_errors.survey.survey_expired".translate
    end
  end
end
