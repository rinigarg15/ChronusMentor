# == Schema Information
#
# Table name: match_configs
#
#  id                            :integer          not null, primary key
#  mentor_question_id            :integer
#  student_question_id           :integer
#  program_id                    :integer
#  weight                        :float(24)        default(1.0), not null
#  created_at                    :datetime
#  updated_at                    :datetime
#  threshold                     :float(24)        default(0.0)
#  operator                      :string(255)      default("lt"), not null
#  matching_type                 :integer          default(0)
#  matching_details_for_display  :text(65535)
#  matching_details_for_matching :text(65535)
#

class MatchConfig < ActiveRecord::Base
  module Operator
    def self.gt
      'gt'
    end
    def self.lt
      'lt'
    end
    def self.all
      [gt, lt]
    end
  end

  module MatchingType
    DEFAULT = 0
    SET_MATCHING  = 1
  end
  MUTLTISET_SEPARATOR = "!---!"

  belongs_to_program
  belongs_to :student_question, :class_name => 'RoleQuestion', :foreign_key => 'student_question_id'
  belongs_to :mentor_question, :class_name => 'RoleQuestion', :foreign_key => 'mentor_question_id'
  has_one :match_config_discrepancy_cache, dependent: :destroy

  scope :with_label, -> {where(show_match_label: true)}

  validates :operator, presence: true, inclusion: { in: Operator.all }
  validates :program, :presence => true
  validates :student_question, :mentor_question, :presence => true
  validates_uniqueness_of :student_question_id,
    :scope => [:mentor_question_id, :program_id]
  validates :matching_type, inclusion: {in: [MatchingType::DEFAULT, MatchingType::SET_MATCHING]}
  validate :check_matching_type
  validate :check_fields

  validate :check_questions_are_of_matchable_type
  validate :check_compatibility

  attr_accessor :skip_matching_indexing

  #-----------------------------------------------------------------------------
  # CALLBACKS
  #-----------------------------------------------------------------------------

  after_save    :update_match_indexes
  before_save   :reset_match_label
  after_destroy :update_match_indexes

  serialize  :matching_details_for_display
  serialize  :matching_details_for_matching

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:mentor_question_id, :student_question_id, :matching_type, :operator, :threshold, :weight, :show_match_label, :prefix],
    :update => [:mentor_question_id, :student_question_id, :matching_type, :operator, :threshold, :weight, :show_match_label, :prefix]
  }

  def student_profile_question
    student_question.profile_question
  end

  def mentor_profile_question
    mentor_question.profile_question
  end

  def label
    "feature.bulk_match.content.field_mapping".translate
  end

  # Updates matching indices for all users of the program.
  def update_match_indexes
    return if self.skip_matching_indexing.present?   
    Matching.perform_program_delta_index_and_refresh_later(self.program)
  end

  def reset_match_label
    can_have_match_label = (self.student_question.profile_question.eligible_for_set_matching? && self.mentor_question.profile_question.eligible_for_set_matching?) || (self.student_question.profile_question.location? && self.mentor_question.profile_question.location?)
    if !can_have_match_label
      self.show_match_label = false
      self.prefix = ""
    end
  end

  def questions_choice_based?
    student_profile_question = self.student_question.profile_question
    mentor_profile_question = self.mentor_question.profile_question
    mentor_profile_question.with_question_choices? && student_profile_question.with_question_choices?
  end

  def refresh_match_config_discrepancy_cache
    top_discrepancy = MatchReport::Sections::SectionClasses[MatchReport::Sections::MentorDistribution].constantize.new(self.program, {match_config: self}).calculate_data_discrepancy.first(MatchReport::MentorDistribution::CATEGORIES_SIZE)
    match_config_discrepancy_cache = MatchConfigDiscrepancyCache.find_or_initialize_by(match_config_id: self.id)
    match_config_discrepancy_cache.update_attributes!(top_discrepancy: top_discrepancy)
    match_config_discrepancy_cache
  end

  def can_create_match_config_discrepancy_cache?
    self.program.can_have_match_report? && self.questions_choice_based?
  end

  def update_match_config_discrepancy_cache?
    (self.saved_change_to_mentor_question_id? || self.saved_change_to_student_question_id? || self.saved_change_to_matching_details_for_display?) && self.can_create_match_config_discrepancy_cache?
  end

  def get_mentor_location_or_questions_choices_for(mentee)
    user_profile_answers = mentee.profile_answers.index_by(&:profile_question_id)
    if mentor_profile_question.location?
      location_answer = user_profile_answers[student_profile_question.id].location
      return location_answer.full_city if location_answer.present? && location_answer.reliable?
    else
      answered_question_choices = student_profile_question.get_answered_question_choices_for_user(user_profile_answers[student_profile_question.id])
      return get_mentor_question_choices_matching_with(answered_question_choices)
    end
  end

  def get_mentor_question_choices_matching_with(answered_question_choices)
    mentor_profile_question_choices = mentor_profile_question.question_choices
    if self.matching_type == MatchConfig::MatchingType::SET_MATCHING
      profile_answer_text_array = []
      answered_question_choices.each do |question_choice|
        profile_answer_text_array << self.matching_details_for_matching[question_choice.text.downcase]
      end
      mentor_profile_question_choices.where(text: profile_answer_text_array.compact.flatten)
    else
      mentor_profile_question_choices.where(text: answered_question_choices.collect(&:text))
    end
  end

  def self.get_match_configs_of_filterable_mentor_questions_for_mentee(mentee, program)
    user_profile_answers = mentee.profile_answers
    mentor_role_question_ids = program.get_valid_role_questions_for_explicit_preferences.pluck(:id)
    student_role_question_ids = program.role_questions.where(profile_question_id: user_profile_answers.pluck(:profile_question_id).uniq).pluck(:id)
    MatchConfig.where("weight > ?", 0).where(mentor_question_id: mentor_role_question_ids, student_question_id: student_role_question_ids, threshold: 0, operator: MatchConfig::Operator.lt).includes(mentor_question: [profile_question: [question_choices: :translations]], student_question: [profile_question: [question_choices: :translations]])
  end

  private

  def check_matching_type
    if self.matching_details_for_display.present?
      unless (self.matching_type == MatchingType::SET_MATCHING)
        self.errors.add(:match_config, "activerecord.custom_errors.match_config.matching_type_not_set".translate)
      end
    end
  end

  # Checks whether both the questions belong to the program.
  def check_fields
    if self.program && self.mentor_question && self.student_question
      # The two questions must be comparable with each other and the program.
      unless self.mentor_question.program.comparable_with?(self.student_question.program) &&
          self.mentor_question.program.comparable_with?(self.program) &&
          self.student_question.program.comparable_with?(self.program)

        self.errors.add(:program, "activerecord.custom_errors.match_config.invalid_fields".translate)
      end
    end
  end

  #
  # Checks whether the student and mentor questions are of matchable type.
  #
  def check_questions_are_of_matchable_type
    if self.student_question && !self.student_question.matchable_type?
      self.errors.add(:student_question, "activerecord.custom_errors.match_config.unmatchable_question".translate)
    end

    if self.mentor_question && !self.mentor_question.matchable_type?
      self.errors.add(:mentor_question, "activerecord.custom_errors.match_config.unmatchable_question".translate)
    end
  end

  def check_compatibility
    if self.mentor_question.present? && self.student_question.present?
      unless self.mentor_question.is_compatible_for_matching_with?(self.student_question, self.matching_type)
        self.errors.add(:base, "activerecord.custom_errors.answer.invalid_question_choice".translate)
      end
    end
  end

end
