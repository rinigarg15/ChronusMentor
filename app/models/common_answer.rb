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

class CommonAnswer < ActiveRecord::Base

  MULTILINE_SEPERATOR = "\n "

  include AnswerChoiceQuery

  belongs_to :common_question
  counter_culture :common_question
  belongs_to :user
  has_attached_file :attachment, COMMON_ANSWER_ATTACHMENT_STORAGE_OPTIONS
  # If answer choices are empty, then corresponding common answer also should be destroyed in answer choice observer. So to avoid circular dependency, dependent: :delete_all is used instead of dependent: :destroy
  has_many :answer_choices, as: :ref_obj, dependent: :delete_all, validate: false, autosave: true

  before_post_process :transliterate_file_name


  validates_presence_of :common_question
  validates_presence_of :user, :if => :check_user_presence?
  validate :check_if_answer_is_valid, :unless => Proc.new { |q| q.common_question.present? && q.common_question.allow_other_option? }
  validate :check_answer_presence
  validates_attachment_size :attachment, less_than: AttachmentSize::END_USER_ATTACHMENT_SIZE, :message => Proc.new { "flash_message.message.file_attachment_too_big".translate(file_size: AttachmentSize::END_USER_ATTACHMENT_SIZE/ONE_MEGABYTE) }
  validates_attachment_content_type :attachment, :content_type => DEFAULT_ALLOWED_FILE_UPLOAD_TYPES, :message => Proc.new { "flash_message.message.file_attachment_invalid".translate }

  # Fetch answers for the given question.
  scope :for_question, Proc.new{ |common_question| where({ common_question_id: common_question.id }) }
  scope :for_question_ids, Proc.new { |question_ids| where(common_question_id: question_ids) if question_ids.present? }
  scope :answered, -> { joins(:common_question).where('(common_questions.question_type = ? AND attachment_updated_at IS NOT NULL)' +
    ' OR (common_questions.question_type != ? AND answer_text != \'\')',
    CommonQuestion::Type::FILE, CommonQuestion::Type::FILE) }

	# Return the parts of this answer as an array
  def answer_value(common_question = nil)
    common_question ||= self.common_question
    if common_question.choice_based?
      # A multi choice question should have an array of choices
      answer_value_for_choice_or_select_type(common_question)
    elsif common_question.question_type == CommonQuestion::Type::FILE
      self.attachment
    elsif common_question.question_type == CommonQuestion::Type::MULTI_STRING
      (self.answer_text || "").split(MULTILINE_SEPERATOR)
    else
      self.answer_text
    end
  end

  def answer_value=(value)
    common_question, from_import, value = get_options_from_value(value)
    # For multi choice question, convert  MULTI CHOICE QUESTION SHOULD HAVE AN ARRAY OF CHOICES
    if common_question.choice_based?
      create_or_delete_answer_choices(value, common_question, from_import)
    elsif common_question.question_type == CommonQuestion::Type::FILE
      self.attachment = value
    elsif common_question.question_type == CommonQuestion::Type::MULTI_STRING && value.is_a?(Array)
      self.answer_text = value.collect(&:strip).reject(&:blank?).join(MULTILINE_SEPERATOR)
    else
      self.answer_text = value
    end
  end

  # Returns whether the answer is provided or not.
  def unanswered?
    if self.common_question.question_type == CommonQuestion::Type::FILE
      !self.attachment?
    elsif self.common_question.choice_based?
      self.answer_choices.empty? || self.answer_choices.all?(&:marked_for_destruction?)
    else
      self.answer_text.blank?
    end
  end

  def for_question?(question)
    self.common_question_id == question.id
  end

  def self.update_or_destroy_answer_text(question_choice, is_destroy = false)
    common_answers = question_choice.common_answers.includes({common_question: [question_choices: :translations]}, :answer_choices)
    is_choice_based = question_choice.ref_obj.choice_or_select_type?
    reindex_answer_ids = common_answers.collect do |ans|
      CommonAnswer.update_answer_text(ans, question_choice, is_destroy, is_choice_based)
      skip_reindex = CommonAnswer.destroy_answer_choices(ans, question_choice, is_destroy)
      skip_reindex ? nil : ans.id
    end
    reindex_answer_ids.compact!
    if reindex_answer_ids.any? && question_choice.ref_obj.is_a?(SurveyQuestion)
      DelayedEsDocument.delayed_bulk_update_es_documents(SurveyAnswer, reindex_answer_ids)
    end
  end

  def selected_choices_to_str_for_view(question = get_question)
    choices = self.answer_value(question)
    return choices if choices.is_a?(String)
    if choices.is_a?(Array)
      return choices.join_by_separator(SEPERATOR) if question.choice_or_select_type?
      return choices.join(SEPERATOR)
    end
  end

  private
  # Override ActiveRecord::Base#create_or_update to handle empty answer
  # save for an *optional* question.
  #
  # While attempting to save to empty answer for an optional question,
  # * If create, do not save the record. Just return true as though the save
  # succeeded.
  # * If update, destroy the answer.
  #
  def create_or_update(*args, &block)
    if self.common_question && (!self.common_question.required? || self.is_draft?) && self.unanswered?
      self.destroy unless self.new_record?
      return true
    else
      super
    end
  end

  def check_if_answer_is_valid
    if self.invalid_choice.present?
      errors.add(:answer_text, "activerecord.custom_errors.answer.invalid_choice".translate)
    end
  end

  def required_question?
    self.common_question && self.common_question.required?
  end

  # Check presence of either <i>answer_text</i> or <i>attachment</i> based on
  # the question type.
  def check_answer_presence
    if required_question? && self.unanswered? && !self.is_draft?
      if self.common_question.question_type == CommonQuestion::Type::FILE
        key = :attachment
      else
        key = :answer_text
      end

      self.errors.add(key, "activerecord.custom_errors.answer.blank".translate)
      return false
    end
  end

  # Returns whether to check for the presence of 'user' association.
  # Override in the sub-models if user validation should not be done.
  def check_user_presence?
    true
  end

  def get_attachment_data(source_ans)
    t = Tempfile.new(source_ans.attachment_file_name)
    t.puts source_ans.attachment.content
    t.close
    open(t.path)
  end
end
