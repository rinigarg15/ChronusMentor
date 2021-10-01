# == Schema Information
#
# Table name: profile_answers
#
#  id                      :integer          not null, primary key
#  profile_question_id     :integer
#  attachment_file_name    :string(255)
#  answer_text             :text(16777215)
#  attachment_content_type :string(255)
#  attachment_file_size    :integer
#  attachment_updated_at   :datetime
#  location_id             :integer
#  created_at              :datetime
#  updated_at              :datetime
#  ref_obj_id              :integer          not null
#  ref_obj_type            :string(255)      not null
#  processed               :boolean          default(FALSE)
#  zencoder_output_id      :string(255)
#  not_applicable          :boolean          default(FALSE)
#

class ProfileAnswer < ActiveRecord::Base
  has_paper_trail on: [:update], class_name: 'ChronusVersion'

  include ChronusS3Utils
  include AnswerChoiceQuery
  include DateTranslationHelper

  MASS_UPDATE_ATTRIBUTES = {
    manager: [:first_name, :last_name, :email],
    experience: [:job_title, :start_year, :end_year, :company, :start_month, :end_month, :current_job],
    education: [:school_name, :degree, :major, :graduation_year],
    publication: [:title, :publisher, :url, :authors, :description, :day, :month, :year]
  }

  MULTILINE_SEPERATOR = "\n "

  module PRIORITY
    EXISTING = 0
    IMPORTED = 1
  end

  TEMP_BASE_PATH = 'data/question_files'

  attr_accessor :user_or_membership_request, :skip_observer, :priority, :temp_file_code, :temp_file_name

  belongs_to :profile_question
  belongs_to :location
  counter_culture :location
  belongs_to :ref_obj, :polymorphic => true

  has_many :educations, -> {order "graduation_year DESC"}, :dependent => :destroy, :validate => false
  has_many :experiences, -> {order "current_job DESC, end_year DESC, end_month DESC"}, :dependent => :destroy, :validate => false
  has_many :publications, -> {order "created_at DESC"}, :dependent => :destroy, :validate => false
  has_one :manager, :dependent => :destroy, :inverse_of => :profile_answer, :validate => false
  has_one :date_answer, as: :ref_obj, dependent: :destroy
  has_attached_file :attachment, PROFILE_ANSWER_ATTACHMENT_STORAGE_OPTIONS
  # If answer choices are empty, then corresponding profile answer also should be destroyed in answer choice observer. So to avoid circular dependency, dependent: :delete_all is used instead of dependent: :destroy
  has_many :answer_choices, as: :ref_obj, dependent: :destroy, validate: false, autosave: true

  before_post_process :transliterate_file_name

  validates :profile_question, presence: true
  validates :ref_obj, presence: true
  validates :ref_obj_type, inclusion: { in: [Member.name] }
  validates :profile_question_id, uniqueness: { scope: [:ref_obj_id, :ref_obj_type] }

  validate :check_if_answer_is_valid, :unless => Proc.new { |q| q.profile_question.present? && q.profile_question.allow_other_option? }
  validate :check_text_only_answer, :if => Proc.new { |q| q.profile_question.present? && q.profile_question.text_only_allowed? }
  validate :check_educations_must_be_valid, :check_experiences_must_be_valid, :check_publication_must_be_valid, :check_manager_must_be_valid,  :if => :profile_question
  validate :check_answer_presence, :unless => :not_applicable?
  validate :check_date_must_be_valid, if: Proc.new { |profile_answer| profile_answer.profile_question && !profile_answer.not_applicable}

  validates_attachment_size :attachment, less_than: AttachmentSize::END_USER_ATTACHMENT_SIZE, if: Proc.new { |pa| pa.attachment? }, message: Proc.new { "flash_message.message.file_attachment_too_big".translate(file_size: AttachmentSize::END_USER_ATTACHMENT_SIZE/ONE_MEGABYTE) }
  validates_attachment_content_type :attachment, content_type: DEFAULT_ALLOWED_FILE_UPLOAD_TYPES, message: Proc.new { "flash_message.message.file_attachment_invalid".translate }

  # Fetch answers for the given question.
  scope :for_question, Proc.new{|profile_question| where(profile_question_id: Array(profile_question).map(&:id))}
  scope :member_answers, -> { where(:ref_obj_type => 'Member')}
  scope :answered, -> { joins(:profile_question).joins("LEFT OUTER JOIN answer_choices ON answer_choices.ref_obj_id = profile_answers.id AND answer_choices.ref_obj_type = 'ProfileAnswer'").where([
    '(profile_questions.question_type = ? AND attachment_updated_at IS NOT NULL)' +
    ' OR (profile_questions.question_type NOT IN (?) AND answer_text != \'\')' +
    ' OR (profile_questions.question_type IN (?) AND answer_choices.ref_obj_id IS NOT NULL AND answer_choices.ref_obj_type = ?)',
    ProfileQuestion::Type::FILE, [ProfileQuestion::Type::FILE] + ProfileQuestion::Type.choice_based_types, ProfileQuestion::Type.choice_based_types, ProfileAnswer.name]).distinct }
  scope :not_applicable, -> { where(:not_applicable => true)}

	# Return the parts of this answer as an array
  def answer_value(profile_question = nil)
    #Just to optimize perf
    profile_question = profile_question || self.profile_question
    if profile_question.choice_or_select_type?
      answer_value_for_choice_or_select_type(profile_question)
    elsif profile_question.file_type?
      self.attachment
    elsif profile_question.can_split_by_multiline_separator?
      answer_value_split_by_multiline_separator(profile_question)
    else
      self.answer_text
    end
  end

  def answer_value=(value)
    profile_question, from_import, value = get_options_from_value(value)
    if profile_question.choice_or_select_type?
      create_or_delete_answer_choices(value, profile_question, from_import)
    elsif profile_question.file_type?
      self.attachment = value
    elsif profile_question.question_type == ProfileQuestion::Type::MULTI_STRING
      set_answer_text_for_multi_string(value)
    else
      set_answer_text_for_profile_fields(profile_question, value)
    end
  end

  # Returns whether the answer is provided or not.
  def unanswered?
    if self.profile_question.file_type?
      !self.attachment?
    elsif self.profile_question.location?
      !self.location.present?
    elsif self.profile_question.default_type?
      false
    elsif self.profile_question.choice_or_select_type?
      self.answer_choices.empty? || self.answer_choices.all?(&:marked_for_destruction?)
    else
      check_unanswered_for_profile_fields?
    end
  end

  def for_question?(question)
    self.profile_question_id == question.id
  end

  def copy_answer_from!(source_ans)
    #membership answer belongs to common question only
    if source_ans.common_question.question_type == ProfileQuestion::Type::FILE
      self.attachment = get_attachment_data(source_ans)
      self.attachment_file_name = source_ans.attachment_file_name
    else
      self.answer_text = source_ans.answer_text
    end
    self.save!
  end

  def save_answer!(question, answer_text, user_or_membership_request = nil, options = {})
    self.answer_value = {answer_text: answer_text, question: question, from_import: options[:from_import]}
    self.user_or_membership_request = user_or_membership_request if user_or_membership_request.present?
    handle_location_answer(question, answer_text)
    handle_date_answer(question, answer_text)
    self.save!
  end

  def present_for(obj)
    return obj.program.role_questions_for(obj.role_names).where(:profile_question_id => self.profile_question_id).any?
  end

  def handle_existing_education_answers(existing_education_attributes, commit_to_db = true)
    existing_education_attributes ||= {}
    self.educations.reject(&:new_record?).each do |education|
      attributes = existing_education_attributes[education.id.to_s]
      save_or_destroy_existing_profile_fields(education, attributes, commit_to_db, {permitted_param_key: :education, required_attributes: [:school_name]})
    end
  end

  def destroy
    answer_choices.each do |answer_choice|
      answer_choice.skip_parent_destroy = true
    end
    super
  end

  def build_new_education_answers(new_education_attributes, commit_to_db = true)
    build_new_profile_fields(new_education_attributes, commit_to_db, {permitted_param_key: :education, required_attributes: [:school_name]})
  end

  def handle_existing_experience_answers(existing_experience_attributes, commit_to_db = true)
    existing_experience_attributes ||= {}
    self.experiences.reject(&:new_record?).each do |experience|
      attributes = existing_experience_attributes[experience.id.to_s]
      save_or_destroy_existing_profile_fields(experience, attributes, commit_to_db, {permitted_param_key: :experience, required_attributes: [:company]})
    end
  end

  def build_new_experience_answers(new_experience_attributes, commit_to_db = true)
    build_new_profile_fields(new_experience_attributes, commit_to_db, {permitted_param_key: :experience, required_attributes: [:company]})
  end

  def handle_existing_publication_answers(existing_publication_attributes, commit_to_db = true)
    existing_publication_attributes ||= {}
    self.publications.reject(&:new_record?).each do |publication|
      attributes = existing_publication_attributes[publication.id.to_s]
      save_or_destroy_existing_profile_fields(publication, attributes, commit_to_db, {permitted_param_key: :publication, required_attributes: [:title]})
    end
  end

  def build_new_publication_answers(new_publication_attributes, commit_to_db = true)
    build_new_profile_fields(new_publication_attributes, commit_to_db, {permitted_param_key: :publication, required_attributes: [:title]})
  end

  def handle_existing_manager_answers(existing_manager_attributes, commit_to_db = true)
    existing_manager_attributes ||= {}
    manager_answer = self.manager
    if manager_answer && !manager_answer.new_record?
      attributes = existing_manager_attributes[manager_answer.id.to_s]
      save_or_destroy_existing_profile_fields(manager_answer, attributes, commit_to_db, {permitted_param_key: :manager, required_attributes: [:first_name, :last_name, :email]})
    end
  end

  def build_new_manager_answers(new_manager_attributes, commit_to_db = true)
    build_new_profile_fields(new_manager_attributes, commit_to_db, {permitted_param_key: :manager, required_attributes: [:first_name, :last_name, :email]})
  end

  def handle_location_answer(question, answer_text)
    if question.location?
      self.location = Location.find_or_create_by_full_address(answer_text)
    end
  end

  def handle_date_answer(question, answer_text)
    if question.date?
      translated_answer_text = get_datetime_str_in_en(answer_text)
      date = valid_date?(translated_answer_text, get_date: true)
      if date.present?
        find_or_initialize_date_answer(date)
        self.answer_text = date.strftime("date.formats.full_display_no_time".translate)
      end
    end
  end

  def assign_file_name_and_code(file_name, file_code)
    self.temp_file_name = file_name
    self.temp_file_code = file_code
  end

  def self.es_reindex(profile_answer)
    member_ids = Array(profile_answer).select{|pa| pa.ref_obj_type == Member.name }.collect(&:ref_obj_id)
    user_ids = User.where(member_id: member_ids).pluck(:id)
    DelayedEsDocument.delayed_bulk_update_es_documents(User, user_ids)
  end

  def self.update_or_destroy_answer_text(question_choice, is_destroy = false)
    profile_answers = question_choice.profile_answers.includes({profile_question: [question_choices: :translations]}, :answer_choices)
    is_choice_based = question_choice.ref_obj.choice_or_select_type?
    reindex_profile_answers = profile_answers.collect do |ans|
      ProfileAnswer.update_answer_text(ans, question_choice, is_destroy, is_choice_based)
      skip_reindex = ProfileAnswer.destroy_answer_choices(ans, question_choice, is_destroy)
      skip_reindex ? nil : ans
    end
    reindex_profile_answers.compact!
    ProfileAnswer.es_reindex(reindex_profile_answers) if reindex_profile_answers.any? && is_choice_based
  end

  private

  def build_new_profile_fields(new_attributes, commit_to_db, options)
    new_attributes.to_a.each do |new_attribute|
      next if !(new_attribute.is_a?(Hash) || new_attribute.is_a?(ActionController::Parameters)) || (commit_to_db && options[:required_attributes].collect {|key| new_attribute[key]}.any?(&:blank?))
      new_object = get_new_profile_field_object(permitted_params(new_attribute, options[:permitted_param_key]), options[:permitted_param_key])
      new_object.profile_answer = self
    end
  end

  def get_new_profile_field_object(attributes, key)
    case key
    when :manager
      self.build_manager(attributes)
    when :experience
      self.experiences.build(attributes)
    when :publication
      self.publications.build(attributes)
    when :education
      self.educations.build(attributes)
    end
  end

  def save_or_destroy_existing_profile_fields(object, attributes, commit_to_db, options)
    unless commit_to_db
      object.attributes = permitted_params(attributes, options[:permitted_param_key])
    else
      if attributes && options[:required_attributes].collect {|key| attributes[key]}.all?(&:present?)
        object.attributes = permitted_params(attributes, options[:permitted_param_key])
        object.save
      else
        object.destroy
      end
    end
  end

  def check_unanswered_for_profile_fields?
    if self.profile_question.education?
      self.educations.empty?
    elsif self.profile_question.experience?
      self.experiences.empty?
    elsif self.profile_question.publication?
      self.publications.empty?
    elsif self.profile_question.manager?
      !self.manager.present?
    else
      self.answer_text.blank?
    end
  end

  def answer_value_split_by_multiline_separator(profile_question)
    answer = (self.answer_text || "").split(MULTILINE_SEPERATOR)
    return answer if profile_question.multi_string?
    return answer.collect{|val| val.split(SEPERATOR)}
  end

  def set_answer_text_for_profile_fields(profile_question, value)
    if profile_question.education?
      set_answer_text_for_education(value)
    elsif profile_question.experience?
      set_answer_text_for_experience(value)
    elsif profile_question.publication?
      set_answer_text_for_publication(value)
    else
      self.answer_text = value
    end
  end

  def set_answer_text_for_multi_string(value)
    answer =  unless value.is_a?(Array)
                value
              else
                value.collect(&:strip).reject(&:blank?).join(MULTILINE_SEPERATOR)
              end
    self.answer_text = answer
  end

  def set_answer_text_for_education(value)
    answer =  unless value.is_a?(Array)
                value
              else
                value.reject(&:blank?).collect do |edu|
                  [edu.school_name, edu.degree, edu.major].join(SEPERATOR)
                end.join(MULTILINE_SEPERATOR)
              end
    self.answer_text = answer
  end

  def set_answer_text_for_experience(value)
    answer =  unless value.is_a?(Array)
                value
              else
                value.reject(&:blank?).collect do |exp|
                  [exp.job_title, exp.company].join(SEPERATOR)
                end.join(MULTILINE_SEPERATOR)
              end
    self.answer_text = answer
  end

  def set_answer_text_for_publication(value)
    answer =  unless value.is_a?(Array)
                value
              else
                value.reject(&:blank?).collect do |pub|
                  [pub.title, pub.publisher, pub.url, pub.authors, pub.description].join(SEPERATOR)
                end.join(MULTILINE_SEPERATOR)
              end
    self.answer_text = answer
  end

  def permitted_params(params, action)
    return params unless params.is_a?(ActionController::Parameters)
    params.permit(MASS_UPDATE_ATTRIBUTES[action])
  end

  # Override ActiveRecord::Base#create_or_update to handle empty answer
  # save for an *optional* question.
  #
  # While attempting to save to empty answer for an optional question,
  # * If create, do not save the record. Just return true as though the save
  # succeeded.
  # * If update, destroy the answer.
  #
  def create_or_update(*args, &block)
    if can_destroy_profile_answer?
      self.destroy unless self.new_record?
      return true
    else
      # Disable partial writes for new records so that unsaved attributes are preserved
      ProfileAnswer.partial_writes = !self.new_record?
      super
    end
  end

  def can_destroy_profile_answer?
    self.profile_question && !required_question? && self.unanswered? && !self.not_applicable?
  end

  def check_if_answer_is_valid
    if self.invalid_choice.present?
      self.errors.add(:answer_text, "activerecord.custom_errors.answer.invalid_choice".translate)
    end
  end

  def check_text_only_answer
    errors.add(:answer_text, 'activerecord.custom_errors.profile_answer.contains_digits'.translate) if answer_text =~ /\d/
  end

  def required_question?
    return false if self.profile_question.nil?
    return false if self.user_or_membership_request.nil?
    return required_for(self.user_or_membership_request)
  end

  def required_for(user_or_membership_request)
    role_questions = user_or_membership_request.program.role_questions_for(user_or_membership_request.role_names)
    return role_questions.required.where(profile_question_id: self.profile_question_id).exists?
  end

  # Check presence of either <i>answer_text</i> or <i>attachment</i> based on
  # the question type.
  def check_answer_presence
    if required_question? && self.unanswered?
      key =
      if self.profile_question.file_type?
        :attachment
      elsif self.profile_question.location?
        :location
      else
        error_key_for_profile_fields
      end

      self.errors.add(key, "activerecord.custom_errors.answer.blank".translate)
      return false
    end
  end

  def error_key_for_profile_fields
    if self.profile_question.education?
      :educations
    elsif self.profile_question.experience?
      :experiences
    elsif self.profile_question.publication?
      :publications
    elsif self.profile_question.manager?
      :manager
    else
      :answer_text
    end
  end

  def get_attachment_data(source_ans)
    t = Tempfile.new(source_ans.attachment_file_name)
    t.puts source_ans.attachment.content
    t.close
    open(t.path)
  end

  def check_educations_must_be_valid
    # Custom error message for educations
    if self.profile_question.education?
      self.educations.each do |education|
        errors[:base] << "activerecord.custom_errors.member.invalid_educations".translate unless education.valid?
      end
    end
  end

  def check_experiences_must_be_valid
    # Custom error message for educations
    if self.profile_question.experience?
      self.experiences.each do |experience|
        errors[:base] << "activerecord.custom_errors.member.invalid_experiences".translate unless experience.valid?
      end
    end
  end

  def check_publication_must_be_valid
    # Custom error message for publications
    if self.profile_question.publication?
      self.publications.each do |publication|
        errors[:base] << "activerecord.custom_errors.member.invalid_publications".translate unless publication.valid?
      end
    end
  end

  def check_date_must_be_valid
    if self.profile_question.date?
      ans_text = get_datetime_str_in_en(answer_text)
      errors[:base] << "activerecord.custom_errors.member.invalid_date_answer".translate unless (valid_date?(ans_text) || ans_text.blank?)
    end
  end

  def check_manager_must_be_valid
    # Custom error message for manager
    errors[:base] << "activerecord.custom_errors.member.invalid_manager".translate if self.profile_question.manager? && self.manager && !self.manager.valid?
  end

  def find_or_initialize_date_answer(date)
    if date_answer.present?
      self.date_answer.answer = date
      self.date_answer.save
    else
      self.build_date_answer(answer: date, ref_obj: self)
    end
  end

end
