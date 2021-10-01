# == Schema Information
#
# Table name: common_questions
#
#  id                       :integer          not null, primary key
#  program_id               :integer
#  question_text            :text(65535)
#  question_type            :integer
#  question_info            :text(65535)
#  position                 :integer
#  created_at               :datetime
#  updated_at               :datetime
#  required                 :boolean          default(FALSE), not null
#  help_text                :text(65535)
#  type                     :string(255)
#  survey_id                :integer
#  common_answers_count     :integer          default(0)
#  feedback_form_id         :integer
#  allow_other_option       :boolean          default(FALSE)
#  is_admin_only            :boolean
#  question_mode            :integer
#  positive_outcome_options :text(65535)
#  matrix_question_id       :integer
#  matrix_position          :integer
#  matrix_setting           :integer
#  condition                :integer          default(0)
#

# Base model for all question-answer related model pairs
class CommonQuestion < ActiveRecord::Base
  belongs_to_program

  has_many :default_question_choices, -> { where(is_other: false).includes(:translations)}, dependent: :destroy, as: :ref_obj, class_name: QuestionChoice.name
  has_many :common_answers, :dependent => :destroy
  has_many :question_choices, -> { includes(:translations) }, dependent: :destroy, as: :ref_obj
  has_many :default_question_choices, -> { where(is_other: false).includes(:translations)}, dependent: :destroy, as: :ref_obj, class_name: QuestionChoice.name

  # Type of question that decides the nature of answer.
  #XXX Check aplication.js CustomizeQuestions.checkMultipeChoice method
  class Type
    STRING        = 0
    TEXT          = 1
    SINGLE_CHOICE = 2
    MULTI_CHOICE  = 3
    RATING_SCALE  = 4
    FILE          = 5
    MULTI_STRING  = 6
    MATRIX_RATING = 7

    def self.all
      [STRING, TEXT, MULTI_STRING, SINGLE_CHOICE, MULTI_CHOICE, RATING_SCALE, FILE, MATRIX_RATING]
    end

    def self.filterable
      [STRING, TEXT, MULTI_STRING, SINGLE_CHOICE, MULTI_CHOICE, RATING_SCALE]
    end

    def self.renderable_as_text
      [STRING, TEXT, SINGLE_CHOICE, RATING_SCALE]
    end

    def self.renderable_as_list
      [MULTI_STRING, MULTI_CHOICE]
    end

    def self.checkbox_filterable
      [SINGLE_CHOICE, MULTI_CHOICE, RATING_SCALE]
    end

    def self.choice_based_types
      [SINGLE_CHOICE, MULTI_CHOICE, RATING_SCALE, MATRIX_RATING]
    end
  end

  # The responses of Effectiveness and Connectivity moded feedback survey questions are presented in health report.
  module Mode
    EFFECTIVENESS = 0
    CONNECTIVITY = 1
  end

  # this is used for settings other than mandatory like forced ranking in case of matrix rating question.
  module MatrixSetting
    NONE = 0
    FORCED_RANKING = 1

    def self.all
      [NONE, FORCED_RANKING]
    end
  end

  # VALIDATIONS

  validates_presence_of :program, :question_text, :question_type
  validates_inclusion_of :question_type, :in => Type.all
  validates_presence_of :matrix_position, :if => Proc.new { |q| q.is_part_of_matrix_question? }
  validates_inclusion_of :matrix_setting, :in => MatrixSetting.all, :allow_nil => true
  validates :question_mode, inclusion: {in: [Mode::EFFECTIVENESS, Mode::CONNECTIVITY]}, allow_nil: true

  translates :question_text, :help_text, :question_info

  scope :with_answers, -> { where("common_answers_count > 0") }
  scope :required, -> { where( :required => true )}
  scope :filterable, -> { where("common_questions.question_type IN (?)", Type.filterable)}
  scope :admin_only, ->(flag) { where(is_admin_only: flag) }
  scope :non_editable, -> {where("common_questions.question_mode IN (?)", [Mode::EFFECTIVENESS, Mode::CONNECTIVITY])}
  scope :matrix_questions, -> { where("common_questions.question_type = (?)", Type::MATRIX_RATING) }
  scope :not_matrix_questions, -> { where("common_questions.question_type != (?)", Type::MATRIX_RATING) }
  scope :matrix_rating_questions, -> { where("common_questions.matrix_question_id IS NOT NULL") }

  include QuestionChoiceExtensions
  include ChoicesUpdateHandler::Common
  # INSTANCE METHODS

  # Returns whether the question is choice based i.e., either Type::SINGLE_CHOICE
  # or Type::MULTI_CHOICE
  def choice_based?
    [Type::SINGLE_CHOICE, Type::MULTI_CHOICE, Type::RATING_SCALE, Type::MATRIX_RATING].include?(self.question_type)
  end

  def single_option_choice_based?
    [Type::SINGLE_CHOICE, Type::RATING_SCALE].include?(self.question_type)
  end

  def choice_but_not_matrix_type?
    [Type::SINGLE_CHOICE, Type::MULTI_CHOICE, Type::RATING_SCALE].include?(self.question_type)
  end

  # This function is added just to maintain consistency with the profile question model. This function can be used in the options globalization helper
  def choice_or_select_type?
    self.choice_based?
  end

  # Upon a question change, go thru the choice values for answers and compact them by deleting non-existent choices, cleaning up empty answers etc.
  def handle_choices_update
    case self.question_type
    when CommonQuestion::Type::SINGLE_CHOICE
      self.compact_single_choice_answer_choices(self.common_answers)
    when CommonQuestion::Type::RATING_SCALE
      self.compact_single_choice_answer_choices(self.common_answers, true)
    when CommonQuestion::Type::MULTI_CHOICE
      self.compact_multi_choice_answer_choices(self.common_answers)
    end
  end

  def file_type?
    self.question_type == CommonQuestion::Type::FILE
  end

  def text_type?
    self.question_type == CommonQuestion::Type::TEXT
  end

  def select_type?
    [Type::SINGLE_CHOICE, Type::MULTI_CHOICE].include?(self.question_type)
  end

  def matrix_question_type?
    self.question_type == CommonQuestion::Type::MATRIX_RATING
  end

  def rating_type?
    self.question_type == CommonQuestion::Type::RATING_SCALE
  end

  def is_part_of_matrix_question?
    self.matrix_question_id.present?
  end

  def non_editable?
    [Mode::EFFECTIVENESS, Mode::CONNECTIVITY].include?(self.question_mode)
  end

  def in_health_report?
    self.type == SurveyQuestion.name && self.survey.is_feedback_survey? && self.non_editable?
  end

  def matrix_rating_question_texts
    return [] unless self.matrix_question_type?
    self.rating_questions.order(:matrix_position).collect(&:question_text)
  end

  def matrix_rating_question_records
    if self.rating_questions.loaded?
      self.rating_questions.sort_by{|rq| rq.matrix_position || 0}
    else
      self.rating_questions.order(:matrix_position)
    end
  end

  def multi_choice_type?
    self.question_type == CommonQuestion::Type::MULTI_CHOICE
  end

  def single_choice_type?
    self.question_type == CommonQuestion::Type::SINGLE_CHOICE
  end

end
