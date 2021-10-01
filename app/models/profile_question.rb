# == Schema Information
#
# Table name: profile_questions
#
#  id                      :integer          not null, primary key
#  organization_id         :integer
#  question_text           :text(16777215)
#  question_type           :integer
#  question_info           :text(16777215)
#  position                :integer
#  section_id              :integer
#  help_text               :text(16777215)
#  profile_answers_count   :integer          default(0)
#  created_at              :datetime
#  updated_at              :datetime
#  allow_other_option      :boolean          default(FALSE)
#  options_count           :integer
#  conditional_question_id :integer
#  conditional_match_text  :string(255)
#  text_only_option        :boolean          default(FALSE)
#

class ProfileQuestion < ActiveRecord::Base

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:question_text, :question_type, :help_text, :allow_other_option, :options_count, :conditional_question_id, :text_only_option],
    :update => [:question_text, :question_type, :help_text, :allow_other_option, :options_count, :conditional_question_id, :text_only_option]
  }


  acts_as_list :scope => :section_id

  module Type
    STRING        = 0
    TEXT          = 1
    SINGLE_CHOICE = 2
    MULTI_CHOICE  = 3
    RATING_SCALE  = 4
    FILE          = 5
    MULTI_STRING  = 6
    ORDERED_SINGLE_CHOICE = 7
    LOCATION      = 8
    EXPERIENCE    = 9
    MULTI_EXPERIENCE = 10
    EDUCATION     = 11
    MULTI_EDUCATION = 12
    EMAIL = 13
    SKYPE_ID = 14
    ORDERED_OPTIONS = 15
    NAME = 16
    PUBLICATION = 17
    MULTI_PUBLICATION = 18
    MANAGER = 19
    DATE = 20

    def self.all
      [STRING, TEXT, MULTI_STRING, SINGLE_CHOICE, MULTI_CHOICE, RATING_SCALE, FILE,
       LOCATION, EXPERIENCE, MULTI_EXPERIENCE, EDUCATION, MULTI_EDUCATION, EMAIL, SKYPE_ID, ORDERED_OPTIONS, NAME,
       PUBLICATION, MULTI_PUBLICATION, MANAGER, DATE
      ]
    end

    def self.choice_based_types
      [SINGLE_CHOICE, MULTI_CHOICE, RATING_SCALE, ORDERED_OPTIONS, ORDERED_SINGLE_CHOICE]
    end

    def self.set_matching_types
      [Type::SINGLE_CHOICE, Type::MULTI_CHOICE, Type::ORDERED_OPTIONS]
    end
  end

  #Applicable for profile questions export and import actions
  module ImportExportConstants
    ExportConstants = {ToInclude: [RoleExporter.name, SectionExporter.name], ToSkip: [MatchConfigExporter.name, CustomizedTermExporter.name, RolePermissionExporter.name]}
    ImportConstants = {ToInclude: [RoleImporter.name, SectionImporter.name], ToSkip: [MatchConfigImporter.name, CustomizedTermImporter.name, RolePermissionImporter.name, PermissionImporter.name]}
  end

  sanitize_attributes_content :help_text
  has_many :profile_answers, :dependent => :destroy
  has_many :role_questions, :dependent => :destroy
  has_many :roles, :through => :role_questions
  has_many :diversity_reports, dependent: :destroy
  has_many :admin_view_columns, :dependent => :destroy
  has_many :group_view_columns, :dependent => :destroy
  has_many :survey_response_columns, :dependent => :destroy
  has_many :question_choices, -> { includes(:translations) }, dependent: :destroy, as: :ref_obj
  has_many :default_question_choices, -> { where(is_other: false).includes(:translations)}, dependent: :destroy, as: :ref_obj, class_name: QuestionChoice.name
  has_many :conditional_match_choices, dependent: :destroy
  has_many :conditional_question_choices, -> { includes(:translations)}, through: :conditional_match_choices, source: :question_choice
  has_many :user_search_activities, dependent: :nullify

  belongs_to :section
  belongs_to :organization
  belongs_to :conditional_question, :class_name => "ProfileQuestion"
  has_many   :dependent_questions, :foreign_key => "conditional_question_id", :class_name => "ProfileQuestion", :dependent => :nullify
  has_many   :preference_based_mentor_lists, dependent: :destroy

  default_scope {includes(:translations)}
  scope :except_email_and_name_question, -> { where.not(question_type: [Type::EMAIL, Type::NAME]) }
  scope :default_questions, -> { where(question_type: [Type::EMAIL, Type::NAME]) }
  scope :email_question, -> { where(question_type: Type::EMAIL) }
  scope :name_question, -> { where(question_type: Type::NAME) }
  scope :skype_question, -> { where(question_type: Type::SKYPE_ID) }
  scope :except_skype_question, -> { where.not(question_type: Type::SKYPE_ID) }
  scope :with_answers, -> { where("profile_answers_count > 0") }

  scope :education_experience_publication_questions, -> { where(question_type: [Type::EDUCATION, Type::MULTI_EDUCATION, Type::EXPERIENCE, Type::MULTI_EXPERIENCE, Type::PUBLICATION, Type::MULTI_PUBLICATION]) }
  scope :experience_questions, -> { where(question_type: [Type::EXPERIENCE, Type::MULTI_EXPERIENCE]) }
  scope :location_questions, -> { where(question_type: Type::LOCATION) }
  scope :manager_questions, -> { where(question_type: Type::MANAGER) }
  scope :multi_field_questions, -> { where(question_type: [Type::EDUCATION, Type::MULTI_EDUCATION, Type::EXPERIENCE, Type::MULTI_EXPERIENCE, Type::PUBLICATION, Type::MULTI_PUBLICATION, Type::MANAGER]) }
  scope :date_questions, -> { where(question_type: Type::DATE) }

  scope :for_role_ids, Proc.new{|role_ids| joins(:role_questions).where({:role_questions => {:role_id => role_ids}})}
  scope :role_profile_questions_with_role_ids, Proc.new{|role_ids| joins(:role_questions).where({:role_questions => {:role_id => role_ids, :available_for => [RoleQuestion::AVAILABLE_FOR::BOTH, RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS]}})}
  
  publicize_ckassets attrs: [:help_text]

  validates_presence_of :section, :organization, :question_text, :question_type
  validates_inclusion_of :question_type, :in => Type.all
  validates :options_count, numericality: { only_integer: true, greater_than: 0 }, if: :ordered_options_type?
  validate :validate_location_count, :validate_manager_count
  validate :validate_text_only_type
  validate :validate_feature_dependency

  accepts_nested_attributes_for :question_choices

  translates :question_text, :help_text, :conditional_match_text, :question_info

  include QuestionChoiceExtensions
  include ChoicesUpdateHandler::ProfileQuestion
  include DateTranslationHelper

  def programs
    self.role_questions.collect(&:program).flatten.uniq
  end

  # Returns whether the question is choice based i.e., either Type::SINGLE_CHOICE
  # or Type::MULTI_CHOICE
  def choice_based?
    [Type::SINGLE_CHOICE, Type::MULTI_CHOICE, Type::RATING_SCALE, Type::ORDERED_SINGLE_CHOICE].include?(self.question_type)
  end

  def publicly_accessible?
    role_questions.any? { |role_question| role_question.publicly_accessible? }
  end

  def with_question_choices?
    choice_based? || ordered_options_type?
  end

  def eligible_for_set_matching?
    [Type::SINGLE_CHOICE, Type::MULTI_CHOICE, Type::ORDERED_OPTIONS].include?(self.question_type)
  end

  def select_type?
    [Type::SINGLE_CHOICE, Type::MULTI_CHOICE, Type::ORDERED_OPTIONS].include?(self.question_type)
  end

  def education?
    [Type::EDUCATION, Type::MULTI_EDUCATION].include?(self.question_type)
  end

  def experience?
    [Type::EXPERIENCE, Type::MULTI_EXPERIENCE].include?(self.question_type)
  end

  def publication?
    [Type::PUBLICATION, Type::MULTI_PUBLICATION].include?(self.question_type)
  end

  def manager?
    self.question_type == Type::MANAGER
  end

  def location?
    self.question_type == Type::LOCATION
  end

  def date?
    question_type == Type::DATE
  end

  def ordered_options_type?
    self.question_type == Type::ORDERED_OPTIONS
  end

  def text_type?
    [Type::STRING, Type::MULTI_STRING].include?(self.question_type)
  end

  def multi_string?
    self.question_type == Type::MULTI_STRING
  end

  def text_question?
    self.question_type == Type::TEXT
  end

  def text_only_allowed?
    self.text_type? && self.text_only_option?
  end

  def conditional?
    self.conditional_question_id.present?
  end

  def multi_education?
    self.question_type == Type::MULTI_EDUCATION
  end

  def multi_experience?
    self.question_type == Type::MULTI_EXPERIENCE
  end

  def multi_publication?
    self.question_type == Type::MULTI_PUBLICATION
  end

  def multi_education_or_experience_or_publication?
    self.multi_education? || self.multi_experience? || self.multi_publication?
  end

  def eligible_for_explicit_preferences?
    [Type::SINGLE_CHOICE, Type::MULTI_CHOICE, Type::ORDERED_OPTIONS, Type::ORDERED_SINGLE_CHOICE, Type::RATING_SCALE, Type::LOCATION].include?(self.question_type)
  end

  def education_or_experience_or_publication?
    self.education? || self.experience? || self.publication?
  end

  def handle_choices_update
    case self.question_type
    when ProfileQuestion::Type::SINGLE_CHOICE
      self.compact_single_choice_answer_choices(self.profile_answers)
    when ProfileQuestion::Type::MULTI_CHOICE
      self.compact_multi_choice_answer_choices(self.profile_answers)
    when ProfileQuestion::Type::ORDERED_OPTIONS
      self.compact_multi_choice_answer_choices(self.profile_answers, self.options_count)
    end
  end

  def handle_ordered_options_to_choice_type_conversion
    case self.question_type
    when ProfileQuestion::Type::SINGLE_CHOICE
      self.compact_answers_for_ordered_options_to_single_choice_conversion(self.profile_answers)
    when ProfileQuestion::Type::MULTI_CHOICE
      self.compact_answers_for_ordered_options_to_multi_choice_conversion(self.profile_answers)
    end
  end

  def file_type?
    self.question_type == Type::FILE
  end

  def email_type?
    self.question_type == Type::EMAIL
  end

  def skype_id_type?
    self.question_type == Type::SKYPE_ID
  end

  def choice_or_select_type?
    self.choice_based? || self.ordered_options_type?
  end

  def multi_choice_type?
    self.question_type == Type::MULTI_CHOICE
  end

  def single_choice_type?
    self.question_type == Type::SINGLE_CHOICE
  end

  def single_option_choice_based?
    single_choice_type?
  end

  def name_type?
    self.question_type == Type::NAME
  end

  def default_type?
    self.email_type? || self.name_type?
  end

  def non_default_type?
    !default_type?
  end

  def can_split_by_multiline_separator?
    self.multi_string? || self.education? || self.experience? || self.publication? || self.manager?
  end

  def membership_only?
    self.role_questions.present? && (self.role_questions.where(:available_for => RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS).size == self.role_questions.size)
  end

  def required_for(program, role)
    role =  (role == 'mentor_student') ? ([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]) : role
    #TODO #CareerDev - Multiple Role Hardcoding
    required = program.role_questions_for(role).required.where({:profile_question_id => self.id}).any?
    return required
  end

  def private_for(program, role)
    role =  (role == 'mentor_student') ? ([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]) : role
    #TODO #CareerDev - Multiple Role Hardcoding
    private_q = program.role_questions_for(role, fetch_all: true).where({:profile_question_id => self.id}).select{|q| q.private?}.any?
    return private_q
  end

  def need_to_be_admin_to_edit?(user)
    self.role_questions.admin_only_editable.where(role_id: user.role_ids).exists?
  end

  def editable_by?(editor, profile_user)
    editor.is_admin? || !self.need_to_be_admin_to_edit?(profile_user)
  end

  def has_dependent_questions?
    self.dependent_questions.any?
  end

  def is_question_single_or_multi_choice?
    (self.question_type == ProfileQuestion::Type::SINGLE_CHOICE) || (self.question_type == ProfileQuestion::Type::MULTI_CHOICE)
  end

  def conditional_text_matches?(all_answers)
    return true unless self.conditional_question_id
    conditional_question_answer = all_answers[self.conditional_question_id][0] if all_answers[self.conditional_question_id].present?
    return conditional_answer_matches_any_of_conditional_choices?(conditional_question_answer)
  end

  def conditional_question_applicable?(member)
    conditional_text_matches?(member.profile_answers.where(profile_question_id: conditional_question_id).group_by(&:profile_question_id))
  end

  def get_dependent_questions_tree_answers(member)
    member.profile_answers.where(profile_question_id: dependent_questions_tree).group_by(&:profile_question_id)
  end

  def handled_after_check_for_conditional_question_applicability?(member)
    return false unless conditional_question_id # saves queries
    not_applicable = !conditional_question_applicable?(member) # not applicable child question case => remove further dependence
    remove_dependent_tree_answers(get_dependent_questions_tree_answers(member)) if not_applicable
    not_applicable
  end

  def update_dependent_questions(member)
    if has_dependent_questions?
      dependent_answers = get_dependent_questions_tree_answers(member)
      dependent_questions.each do |dependent_question|
        dependent_question.remove_dependent_tree_answers(dependent_answers) unless dependent_question.conditional_text_matches?(dependent_answers)
      end
    end
  end

  def dependent_questions_subtree
    dependent_questions = self.dependent_questions.to_a
    return [] if dependent_questions.empty?
    children_questions = dependent_questions.collect(&:dependent_questions).flatten
    while !children_questions.empty? do
      dependent_questions << children_questions
      children_questions = children_questions.collect(&:dependent_questions).flatten
    end
    return dependent_questions.flatten.collect(&:id)
  end

  def dependent_questions_tree
    ([self.id] + self.dependent_questions_subtree)
  end

  def remove_dependent_tree_answers(all_answers)
    dependent_question_ids = self.dependent_questions_tree
    dependent_question_ids.each do |q_id|
      if all_answers[q_id]
        answer = all_answers[q_id][0]
        answer.destroy
      end
    end
  end

  def conditional_answer_matches_any_of_conditional_choices?(conditional_question_answer_or_answer_text)
    return false if conditional_question_answer_or_answer_text.blank? || (conditional_question_answer_or_answer_text.is_a?(ProfileAnswer) && conditional_question_answer_or_answer_text.answer_text.blank?)
    return true if (match_choices = self.conditional_text_choices).blank?
    answer_value = conditional_question_answer_or_answer_text.is_a?(ProfileAnswer) ? conditional_question_answer_or_answer_text.answer_value : conditional_question_answer_or_answer_text.split(",").map(&:strip).reject(&:blank?)
    return ([answer_value].flatten.compact.collect{|i| i.strip.upcase} & match_choices.collect{|i| i.strip.upcase}).any?
  end

  def conditional_text_choices
    self.conditional_question_choices.collect(&:text)
  end

  def self.sort_listing_page_filters(questions)
    return questions.sort_by { |a| [a.section.position, [a.position, a.id]] }
  end

  def self.skype_text
    "feature.profile_question.skype.help_text_html_v2".translate
  end

  def populate_profile_question_attributes
    q_attributes = self.attributes
    q_attributes["question_text"] = self.question_text
    q_attributes["help_text"] = self.help_text
    return q_attributes
  end

  def has_match_configs?(program = nil)
    role_questions_with_match_configs(program && program.id).any?
  end

  def role_questions_with_match_configs(program_id = nil)
    program_id_or_ids = program_id || organization.program_ids
    role_questions_ids_with_match_configs = MatchConfig.where(program_id: program_id_or_ids).pluck(:student_question_id, :mentor_question_id).flatten.compact
    RoleQuestion.connection.select_all(role_questions.where(id: role_questions_ids_with_match_configs).select([:id,:role_id]))
  end

  def format_profile_answer(answer, options = {})
    # file
    if self.file_type?
      if answer.present? && !answer.unanswered?
        options[:csv] ? answer.attachment_file_name : [answer.attachment_file_name, answer.attachment.url]
      else
        nil
      end
    # date
    elsif self.date?
      date_answer_text = valid_date?(answer.try(:answer_text), get_date: true)
      DateTime.localize(date_answer_text.presence, format: :full_display_no_time).to_s
    # education
    elsif self.education?
      (answer.present? && !answer.unanswered? ? answer.educations : []).map do |education|
        Education.export_column_names.map { |field, _| education[field] }
      end
    # experience
    elsif self.experience?
      (answer.present? && !answer.unanswered? ? answer.experiences : []).map do |experience|
        Experience.export_column_names.map { |field, _| experience[field] }
      end
    # publication
    elsif self.publication?
      (answer.present? && !answer.unanswered? ? answer.publications : []).map do |publication|
        Publication.export_column_names.map { |field, _| field == :date ? publication.send('formatted_' + field.to_s) : publication[field] }
      end
    # manager
    elsif self.manager?
      return [] if answer.blank? || answer.unanswered?
      manager = answer.manager
      Manager.export_column_names.map { |field, _| manager[field] }
    elsif self.choice_or_select_type? && !answer.nil?
      # question_choices are eager loaded in answer.profile_question.
      answer.selected_choices_to_str(answer.profile_question)
    elsif self.location?
      ret = case options[:scope]
      when AdminViewColumn::ScopedProfileQuestion::Location::CITY
        answer.try(:location).try(:city)
      when AdminViewColumn::ScopedProfileQuestion::Location::STATE
        answer.try(:location).try(:state)
      when AdminViewColumn::ScopedProfileQuestion::Location::COUNTRY
        answer.try(:location).try(:country)
      else options[:city_only]
        answer.try(:answer_text)
      end
      ret.to_s.strip
    # all others
    else
      answer.try(:answer_text).to_s.strip
    end
  end

  def format_profile_answer_for_xls(answer)
    if answer.present? && !answer.unanswered? && (self.education? || self.experience? || self.publication? || self.manager?)
      answer.try(:answer_text).to_s.strip 
    else
      format_profile_answer(answer, csv: true)
    end
  end

  def mandatory_for_any_roles_in?(roles)
    role_questions.required.where(role_id: roles.map(&:id)).exists?
  end

  def question_text_with_mandatory_mark(roles)
    "#{question_text}#{(mandatory_for_any_roles_in?(roles) ? " *" : "")}"
  end

  def update_conditional_match_choices!(conditional_match_choices_list)
    return true if cleanup_conditional_match_choices

    question_choice_ids = self.conditional_question.question_choices.where(id: conditional_match_choices_list).distinct.pluck(:id)
    existing_conditional_match_choices_list = self.conditional_match_choices.pluck(:question_choice_id)
    to_be_deleted_match_choice_ids = existing_conditional_match_choices_list - question_choice_ids
    self.conditional_match_choices.where(question_choice_id: to_be_deleted_match_choice_ids).destroy_all
    reindex_pq = to_be_deleted_match_choice_ids.present?
    question_choice_ids.each do |question_choice_id|
      next if question_choice_id.in?(existing_conditional_match_choices_list)
      save_conditional_match_choice!(question_choice_id)
      reindex_pq ||= true
    end
    ProfileQuestion.delay.delayed_es_reindex(self.id) if reindex_pq
    return true
  end

  def cleanup_conditional_match_choices
    return false if self.conditional_question.present?
    reindex_pq = self.conditional_match_choices.any?
    self.conditional_match_choices.destroy_all
    ProfileQuestion.delay.delayed_es_reindex(self.id) if reindex_pq
    return true
  end

  def part_of_sftp_feed?(organization)
    sftp_profile_questions = organization.feed_import_configuration.try(:get_config_options).try(:[], :imported_profile_question_texts)
    sftp_profile_questions.try(:include?, question_text) || part_of_reverse_sftp_feed?(organization)
  end

  def linkedin_importable?
    self.experience?
  end

  def self.delayed_es_reindex(profile_question_id)
    role_ids = RoleQuestion.where(profile_question_id: profile_question_id).pluck(:role_id).uniq
    User.es_reindex_for_profile_score(role_ids)
  end

  def get_answered_question_choices_for_user(user_profile_answer)
    profile_question_choices = self.question_choices
    answered_question_choice_ids = AnswerChoice.where(ref_obj_id: user_profile_answer.id, ref_obj_type: ProfileAnswer).pluck(:question_choice_id)
    profile_question_choices.where(id: answered_question_choice_ids)
  end

  private

  def part_of_reverse_sftp_feed?(organization)
    feed_exporter = organization.feed_exporter
    return false unless feed_exporter.present?
    sftp_profile_questions = feed_exporter.feed_exporter_configurations.map{|configuration| configuration.get_config_options[:profile_question_texts]}.flatten.compact
    sftp_profile_questions.try(:include?, question_text)
  end

  def save_conditional_match_choice!(question_choice_id)
    match_choice = self.conditional_match_choices.new(question_choice_id: question_choice_id)
    begin
      match_choice.save!
    rescue ActiveRecord::RecordInvalid => e
      self.errors.add(:conditional_match_choices, match_choice.errors.full_messages.to_sentence)
      raise e
    end
  end

  def validate_location_count
    return unless self.location?
    organization = self.organization
    loc_ques = organization.profile_questions.location_questions.first
    #User can update the question fields of the same location question
    if loc_ques.present? && loc_ques!=self
      errors[:base] << "activerecord.custom_errors.profile_question.location_error".translate
    end
  end

  def validate_manager_count
    return unless self.manager?
    manager_ques = self.organization.profile_questions.manager_questions.first
    errors[:base] << "activerecord.custom_errors.profile_question.manager_error".translate if manager_ques.present? && manager_ques != self
  end

  def validate_text_only_type
    errors[:question_type] << "activerecord.custom_errors.profile_question.not_text_only".translate if !self.text_type? && self.text_only_option?
  end

  def validate_feature_dependency
    if self.manager? && !self.organization.manager_enabled?
      errors[:base] << "activerecord.custom_errors.profile_question.manager_feature_error".translate
    end
  end

  

end