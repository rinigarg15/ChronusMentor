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

# A question inside a survey.
class SurveyQuestion < CommonQuestion

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:question_text, :question_type, :help_text, :required, :matrix_setting, :allow_other_option, :condition],
    :update => [:question_text, :question_type, :help_text, :required, :matrix_setting, :allow_other_option, :condition]
  }

  module Condition
    ALWAYS = 0
    COMPLETED = 1
    CANCELLED = 2

    def self.all
      [ALWAYS, COMPLETED, CANCELLED]
    end

    def self.completed_conditions
      [ALWAYS, COMPLETED]
    end

    def self.cancelled_conditions
      [ALWAYS, CANCELLED]
    end
  end

  acts_as_list scope: :survey_id

  # ASSOCIATIONS ---------------------------------------------------------------
  belongs_to :survey
  has_many :survey_answers, :foreign_key => 'common_question_id'
  has_many :question_choices, -> { includes(:translations) }, dependent: :destroy, as: :ref_obj
  has_many :survey_response_columns, :dependent => :destroy

  has_many :rating_questions, -> {order(:matrix_position) }, :class_name => "SurveyQuestion", :foreign_key => "matrix_question_id", :dependent => :destroy, :autosave => true
  has_many :associated_answers, through: :rating_questions, source: :survey_answers
  belongs_to :matrix_question, :class_name => "SurveyQuestion"

  # SCOPES ---------------------------------------------------------------------
  scope :positive_outcome_configured, -> { where.not(positive_outcome_options: nil)}

  # attr_protected :survey
  attr_accessor :_marked_for_destroy_, :new_matrix_rating_questions_texts, :row_choices_for_matrix_question, :skip_column_creation
  before_validation :make_condition_and_required_consistant
  before_save :remove_matrix_rating_questions_marked_for_destroy
  after_save :remove_matrix_rating_questions_unless_is_a_matrix_question

  # VALIDATIONS ----------------------------------------------------------------
  validates :condition, presence: true, inclusion: Condition.all, :if => Proc.new { |q| q.survey.meeting_feedback_survey? }
  validate :check_survey_belongs_to_program
  validates_presence_of :survey
  validate :matrix_question_should_have_rating_question

  # Translations ----------------------------------------------------------------
  ANSWERS_LIMIT_IN_REPORT = 10

  # INSTANCE METHODS -----------------------------------------------------------

  def question_text_for_display
    is_part_of_matrix_question? ? "#{matrix_question.question_text} - #{question_text}" : question_text
  end

  def kendo_column_field
    "answers#{id}"
  end

  def positive_choices(for_management_report=false)
    ((for_management_report ? positive_outcome_options_management_report : positive_outcome_options) || "").split(SEPERATOR).uniq
  end

  def create_survey_response_column
    return if is_part_of_matrix_question? || self.skip_column_creation
    survey = self.survey
    survey_response_columns = survey.survey_response_columns
    position = survey_response_columns.size > 0 ? survey_response_columns.collect(&:position).max + 1 : 0
    survey.survey_response_columns.create!(:survey_question_id => self.id, :position => position, :ref_obj_type => SurveyResponseColumn::ColumnType::SURVEY)
  end

  def create_survey_question(question_choice_params = {}, rating_question_params = nil)
    ActiveRecord::Base.transaction do
      rating_questions_texts_with_index = process_rating_question_texts(rating_question_params || {})
      self.new_matrix_rating_questions_texts = rating_questions_texts_with_index.keys
      rating_questions_texts_with_index.each do |text, index|
        build_rating_question(text, index)
      end
      self.save! && self.update_question_choices!(question_choice_params)
      forced_ranking_validness
    end
  end

  def update_survey_question(params, rating_question_params = {}, question_choice_params = {})
    ActiveRecord::Base.transaction do
      self.question_type = params.delete(:question_type).to_i
      self.build_or_update_matrix_rating_questions(rating_question_params)
      self.update_attributes!(params) && self.update_question_choices!(question_choice_params)
      forced_ranking_validness
    end
  end

  def build_or_update_matrix_rating_questions(rating_question_params)
    return unless self.matrix_question_type?
    rating_questions_texts_with_index = process_rating_question_texts(rating_question_params)
    rating_questions_texts = rating_questions_texts_with_index.keys
    self.new_matrix_rating_questions_texts = rating_questions_texts
    if rating_questions_texts.blank?
      errors[:rating_questions] << "activerecord.custom_errors.common_question.rating_questions_not_present".translate
      raise ActiveRecord::RecordInvalid.new(self)
    end
    rating_questions_texts_dup = rating_questions_texts.dup

    delete_removed_rating_questions(rating_questions_texts)
    update_existing_rating_question_translations(rating_questions_texts_dup, rating_questions_texts_with_index)
    create_new_matrix_rating_questions(rating_questions_texts_dup, rating_questions_texts_with_index)
  end

  def can_be_shown?(member_meeting_id)
    return true if !survey.meeting_feedback_survey? || show_always?
    member_meeting = MemberMeeting.find(member_meeting_id)
    (member_meeting.meeting.completed? && show_only_if_meeting_completed?) || (member_meeting.meeting.cancelled? && show_only_if_meeting_cancelled?)
  end

  def for_completed?
    show_always? || show_only_if_meeting_completed?
  end

  def for_cancelled?
    show_always? || show_only_if_meeting_cancelled?
  end

  def tied_to_dashboard?
    self.positive_outcome_options_management_report.present? || (self.matrix_question_type? && self.rating_questions.any?(&:positive_outcome_options_management_report))
  end

  def tied_to_positive_outcomes_report?
    self.positive_outcome_options.present? || (self.matrix_question_type? && self.rating_questions.any?(&:positive_outcome_options))
  end

  private

  def process_row_choices_for_matrix_question
    return {} unless self.row_choices_for_matrix_question.present?
    ordered_rating_questions = {}
    self.row_choices_for_matrix_question.split(",").each_with_index do |text, position|
      ordered_rating_questions[text] = position
    end
    ordered_rating_questions
  end

  def process_rating_question_texts(rating_question_params)
    return process_row_choices_for_matrix_question unless rating_question_params.present?
    row_questions_hash = rating_question_params[:existing_rows_attributes][0]
    new_order = rating_question_params[:rows][:new_order].split(",")
    ordered_rating_questions = {}
    row_questions_hash.each do |id, question_text_hash|
      position = new_order.index(id)
      question_text = question_text_hash["text"].strip
      next if position.blank? || question_text.blank?
      ordered_rating_questions[question_text] = position
    end
    ordered_rating_questions.sort_by{|_text, position| position}.to_h
  end

  def delete_removed_rating_questions(rating_questions_texts)
    self.rating_questions.each do |rating_question|
      translation = rating_question.translations.find{|a| a.locale == ::Globalize.locale}
      rating_question._marked_for_destroy_ = translation && !rating_questions_texts.include?(translation.question_text)
    end
  end

  def update_existing_rating_question_translations(texts, rating_questions_texts_with_index)
    rating_questions = self.rating_questions
    rating_questions.each do |rating_question|
      next if rating_question._marked_for_destroy_ || texts.empty?
      translation = rating_question.translations.find{|a| a.locale == ::Globalize.locale}
      if translation.present?
        texts.delete(translation.question_text)
      else
        rating_question.question_text = texts.shift
      end
      rating_question.matrix_position = rating_questions_texts_with_index[rating_question.question_text]
    end
  end

  def create_new_matrix_rating_questions(texts, rating_questions_texts_with_index)
    texts.each do |text|
      build_rating_question(text, rating_questions_texts_with_index[text])
    end
  end

  def build_rating_question(question_text, index)
    rq = self.rating_questions.new(program: self.program, question_text: question_text, question_type: CommonQuestion::Type::RATING_SCALE, required: self.required, matrix_position: index, condition: self.condition)
    rq.survey = self.survey
  end

  # self.survey should belong to self.program
  def check_survey_belongs_to_program
    return unless self.survey && self.program

    unless self.survey.program == self.program
      self.errors.add(:survey, "activerecord.custom_errors.survey.not_belong_to_program".translate)
    end
  end

  def remove_matrix_rating_questions_marked_for_destroy
    if self.matrix_question_type?
      self.rating_questions.each do |rating_question|
        rating_question.destroy if rating_question._marked_for_destroy_
      end
    end
    true
  end

  def make_condition_and_required_consistant
    if self.matrix_question_type?
      self.rating_questions.each do |rating_question|
        rating_question.required = self.required
        rating_question.condition = self.condition
      end
    end
    true
  end

  def matrix_rating_questions_texts_count
    new_matrix_rating_questions_texts.present? ? new_matrix_rating_questions_texts.size : rating_questions.count
  end

  def forced_ranking_validness
    if self.matrix_question_type? && self.matrix_setting == MatrixSetting::FORCED_RANKING
      if self.reload.default_choice_records.size < matrix_rating_questions_texts_count
        errors[:matrix_setting] << "activerecord.custom_errors.common_question.invalid_choices_count_error".translate
        raise ActiveRecord::RecordInvalid.new(self)
      end
    end
  end

  def matrix_question_should_have_rating_question
    return unless self.matrix_question_type?
    errors[:rating_questions] << "activerecord.custom_errors.common_question.rating_questions_not_present".translate unless self.rating_questions.present?
  end

  def remove_matrix_rating_questions_unless_is_a_matrix_question
    self.rating_questions.destroy_all unless matrix_question_type?
  end

  def show_always?
    condition == Condition::ALWAYS
  end

  def show_only_if_meeting_completed?
    condition == Condition::COMPLETED
  end

  def show_only_if_meeting_cancelled?
    condition == Condition::CANCELLED
  end
end
