# == Schema Information
#
# Table name: role_questions
#
#  id                  :integer          not null, primary key
#  role_id             :integer
#  required            :boolean          default(FALSE), not null
#  private             :integer          default(1)
#  filterable          :boolean          default(TRUE)
#  profile_question_id :integer
#  created_at          :datetime
#  updated_at          :datetime
#  in_summary          :boolean          default(FALSE)
#  available_for       :integer          default(1)
#  admin_only_editable :boolean          default(FALSE)
#

class RoleQuestion < ActiveRecord::Base

  MASS_UPDATE_ATTRIBUTES = {
    :from_profile_question => [:required, :private, :filterable, :in_summary, :available_for, :admin_only_editable],
    :update => [:required, :private, :filterable, :in_summary, :available_for, :admin_only_editable]
  }
  QUESTION_FILTERABLE_ERROR = 'question_type_filterable_error'
  DEFAULT_FOR_USER_OPTIONS = {user: nil, view: true, edit: false, fetch_all: false}

  module PRIVACY_SETTING
    ALL = 1
    RESTRICTED = 2
    ADMIN_ONLY_VIEWABLE = 3
    USER_AND_ADMIN_ONLY = 4

    def self.all
      [ALL, RESTRICTED, ADMIN_ONLY_VIEWABLE, USER_AND_ADMIN_ONLY]
    end
  end

  module AVAILABLE_FOR
    BOTH = 0
    PROFILE_QUESTIONS = 1
    MEMBERSHIP_QUESTIONS = 2

    def self.all
      [BOTH, PROFILE_QUESTIONS, MEMBERSHIP_QUESTIONS]
    end

    def self.role_profile_questions
      [BOTH, PROFILE_QUESTIONS]
    end

    def self.membership_questions
      [BOTH, MEMBERSHIP_QUESTIONS]
    end
  end

  class MatchType
    # Map from <code>Question</code> to custom matching types.
    MATCH_TYPE_FOR_QUESTION_TYPE = {
      ProfileQuestion::Type::STRING => Matching::ChronusString,
      ProfileQuestion::Type::MULTI_STRING => Matching::ChronusArray,
      ProfileQuestion::Type::TEXT => Matching::ChronusText,
      ProfileQuestion::Type::SINGLE_CHOICE => Matching::ChronusArray,
      ProfileQuestion::Type::MULTI_CHOICE => Matching::ChronusArray,
      ProfileQuestion::Type::ORDERED_SINGLE_CHOICE => Matching::ChronusArray,
      ProfileQuestion::Type::EDUCATION => Matching::ChronusEducations,
      ProfileQuestion::Type::MULTI_EDUCATION => Matching::ChronusEducations,
      ProfileQuestion::Type::EXPERIENCE => Matching::ChronusExperiences,
      ProfileQuestion::Type::MULTI_EXPERIENCE => Matching::ChronusExperiences,
      ProfileQuestion::Type::LOCATION => Matching::ChronusLocation,
      ProfileQuestion::Type::ORDERED_OPTIONS => Matching::ChronusOrderedArray
    }.freeze

    SIMILAR_QUESTION_TYPE_ARRAY = [ProfileQuestion::Type::STRING, ProfileQuestion::Type::TEXT, ProfileQuestion::Type::MULTI_STRING, ProfileQuestion::Type::SINGLE_CHOICE, ProfileQuestion::Type::MULTI_CHOICE, ProfileQuestion::Type::ORDERED_SINGLE_CHOICE, ProfileQuestion::Type::ORDERED_OPTIONS].freeze

    COMPATIBILITY_MAP = {
      ProfileQuestion::Type::STRING => SIMILAR_QUESTION_TYPE_ARRAY,
      ProfileQuestion::Type::MULTI_STRING => SIMILAR_QUESTION_TYPE_ARRAY,
      ProfileQuestion::Type::TEXT => SIMILAR_QUESTION_TYPE_ARRAY,
      ProfileQuestion::Type::SINGLE_CHOICE => SIMILAR_QUESTION_TYPE_ARRAY,
      ProfileQuestion::Type::MULTI_CHOICE => SIMILAR_QUESTION_TYPE_ARRAY,
      ProfileQuestion::Type::ORDERED_SINGLE_CHOICE => SIMILAR_QUESTION_TYPE_ARRAY,
      ProfileQuestion::Type::ORDERED_OPTIONS => SIMILAR_QUESTION_TYPE_ARRAY,
      ProfileQuestion::Type::EDUCATION => [ProfileQuestion::Type::EDUCATION, ProfileQuestion::Type::MULTI_EDUCATION],
      ProfileQuestion::Type::MULTI_EDUCATION  => [ProfileQuestion::Type::EDUCATION, ProfileQuestion::Type::MULTI_EDUCATION],
      ProfileQuestion::Type::EXPERIENCE => [ProfileQuestion::Type::EXPERIENCE, ProfileQuestion::Type::MULTI_EXPERIENCE],
      ProfileQuestion::Type::MULTI_EXPERIENCE => [ProfileQuestion::Type::EXPERIENCE, ProfileQuestion::Type::MULTI_EXPERIENCE],
      ProfileQuestion::Type::LOCATION => [ProfileQuestion::Type::LOCATION]
    }.freeze

    # Returns the <code>Matching::AbstractType</code> type to use
    # for the given question type.
    def self.match_type_for(question_type)
      MATCH_TYPE_FOR_QUESTION_TYPE[question_type]
    end

    def self.compatible_match_types_for(question_type)
      COMPATIBILITY_MAP[question_type] || []
    end
  end

  has_many :privacy_settings, foreign_key: "role_question_id", class_name: "RoleQuestionPrivacySetting", inverse_of: :role_question, dependent: :destroy
  has_many :student_match_configs, foreign_key: "student_question_id", class_name: "MatchConfig"
  has_many :mentor_match_configs, foreign_key: "mentor_question_id", class_name: "MatchConfig"
  has_many :supplementary_student_matching_pairs, foreign_key: :student_role_question_id, class_name: SupplementaryMatchingPair.name, dependent: :destroy, inverse_of: :student_role_question
  has_many :supplementary_mentor_matching_pairs, foreign_key: :mentor_role_question_id, class_name: SupplementaryMatchingPair.name, dependent: :destroy, inverse_of: :mentor_role_question
  has_many :explicit_user_preferences, dependent: :destroy

  before_destroy :delete_match_configs

  publicize_ckassets assoc_name: :profile_question, attrs: [:help_text]

  belongs_to :role
  belongs_to :profile_question

  validate :check_filterable
  validates_presence_of :profile_question, :role

  validates_uniqueness_of :role_id, :scope => :profile_question_id
  validates :available_for, :presence => true, :inclusion => { :in => [RoleQuestion::AVAILABLE_FOR::BOTH, RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS, RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS] }
  validates :private, inclusion: {in: PRIVACY_SETTING.all}

  scope :required, -> { where(required: true) }
  scope :filterable, -> { where(filterable: true) }
  scope :admin_only_editable, -> { where(admin_only_editable: true) }

  # setting fetch_all option to true bypasses other options and fetches all question
  scope :for_viewing_by, Proc.new{|user, fetch_all| where(( (fetch_all) || (!user.nil? && user.is_admin?) ) ? ("") : ("role_questions.private != #{RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE}"))}
  scope :for_editing_by, Proc.new{|user, fetch_all| where(( (fetch_all) || (!user.nil? && user.is_admin?) ) ? ("") : ("role_questions.admin_only_editable = 0"))}

  scope :of_roles_with_program, Proc.new { |role_names| where(roles: { name: role_names }) }
  scope :membership_questions, -> { where(available_for: RoleQuestion::AVAILABLE_FOR.membership_questions) }
  scope :role_profile_questions, -> { where(available_for: RoleQuestion::AVAILABLE_FOR.role_profile_questions) }
  attr_accessor :skip_match_index

  [:question_text, :question_info, :question_type, :matchable, :help_text, :section].each do |attr|
    delegate attr, :to => :profile_question
  end

  def matching_questions
    MatchConfig.where("student_question_id = #{self.id} OR mentor_question_id = #{self.id}").distinct
  end

  def self.for_user(options_in = {})
    options = DEFAULT_FOR_USER_OPTIONS.merge(options_in)
    options[:view] ? (options[:edit] ? for_viewing_by(options[:user], options[:fetch_all]).for_editing_by(options[:user], options[:fetch_all]) : for_viewing_by(options[:user], options[:fetch_all])) : []
  end

  def self.for_user_from_loaded_role_questions(role_questions, options_in = {})
    options = DEFAULT_FOR_USER_OPTIONS.merge(options_in)
    user = options[:user]
    return role_questions if options[:fetch_all] || (user.present? && user.is_admin?)
    if options[:view]
      self.filter_visible_role_questions(role_questions, options[:edit])
    else
      []
    end
  end

  def self.privacy_setting_options_for(program)
    [
      {
        label: "feature.profile_customization.label.admins".translate(admins: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::ADMIN_NAME).try(:pluralized_term)),
        privacy_type: RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE, privacy_setting: {}
      },
      {
        label: "feature.profile_customization.label.user".translate,
        privacy_type: RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY, privacy_setting: {}
      }
    ] + RoleQuestionPrivacySetting.restricted_privacy_setting_options_for(program)
  end

  def self.shown_in_summary
    where(in_summary: true).includes(:privacy_settings).select(&:show_in_summary?)
  end

  def delete_match_configs
    if self.matching_questions.present?
      self.matching_questions.collect(&:delete)
      Matching.perform_program_delta_index_and_refresh_later(self.program)
    end
  end

  def refresh_role_questions_match_config_cache
    match_report_match_configs = self.matching_questions.select(&:questions_choice_based?)
    return unless match_report_match_configs.present?
    match_report_match_configs.each do |match_config|
      match_config.refresh_match_config_discrepancy_cache
    end
  end

  def program
    self.role.program
  end

  def section
    self.profile_question.section
  end

  def visible_for?(viewer, owner)
    # Show if the question is not private
    return true unless self.private?
    # Don't show if a private question has no valid viewer
    return false unless viewer.present?

    return (
      (self.restricted_to_admin_alone? ? viewer.is_admin? : owner.same_member?(viewer)) ||
      (viewer.is_admin?) ||
      (self.show_connected_members? && (owner.connected_with?(viewer) || owner.has_accepted_flash_mentoring_meeting_with?(viewer))) ||
      self.show_for_roles?(viewer.roles)
    )
  end

  #Role questions to show in the listing page depending on the viewer role
  def visible_listing_page?(viewer, owner)
    # Show if the question is not private
    return true unless self.private?
    # Don't show if a private question has no valid viewer
    return false unless viewer.present?

    return (
      (viewer.is_admin?) ||
      (self.show_connected_members? && owner.connected_with?(viewer)) ||
      self.show_for_roles?(viewer.roles)
    )
  end

  def disable_for_advanced_search?
    profile_question.name_type? || profile_question.file_type? || private?
  end

  def disable_for_users_listing?
    profile_question.name_type? || extra_private?
  end

  def private?
    !self.show_all?
  end

  #for private role questions visible only to admins and connected members
  def extra_private?
    self.private? && (!self.restricted? || !privacy_settings.collect(&:setting_type).include?(RoleQuestionPrivacySetting::SettingType::ROLE))
  end

  def show_all?
    self.private == PRIVACY_SETTING::ALL
  end

  def restricted?
    self.private == PRIVACY_SETTING::RESTRICTED
  end

  def restricted_to_admin_alone?
    self.private == PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE
  end

  def show_in_summary?
    self.in_summary && !self.extra_private?
  end

  def show_user?
    !restricted_to_admin_alone?
  end

  def show_connected_members?
    show_all? || (restricted? && self.privacy_settings.where(setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS).present?)
  end

  def show_for_roles?(roles = [])
    show_all? || (restricted? && self.privacy_settings.by_role(roles).present?)
  end

  def show_for?(type, restricted_options = {})
    show_all? || (self.private == type && (self.private != PRIVACY_SETTING::RESTRICTED || self.privacy_settings.where(:setting_type => restricted_options[:setting_type], :role_id => restricted_options[:role_id]).present?))
  end

  def membership_question?
    self.available_for.in?(RoleQuestion::AVAILABLE_FOR.membership_questions)
  end

  def role_profile_question?
    self.available_for.in?(RoleQuestion::AVAILABLE_FOR.role_profile_questions)
  end

  alias_method :publicly_accessible?, :membership_question?

  def can_be_membership_question?
    !self.admin_only_editable? && !self.restricted_to_admin_alone?
  end

  #
  # Returns whether this question is of a type that the matching module
  # understands.
  #
  def matchable_type?
    MatchType.match_type_for(self.profile_question.question_type).present?
  end

  def required?
    self.required == true
  end

 def is_compatible_for_matching_with?(other_question, matching_type)
    if matching_type == MatchConfig::MatchingType::DEFAULT
      MatchType.compatible_match_types_for(self.question_type).include?(other_question.question_type)
    else
      [self, other_question].all? { |question| question.profile_question.eligible_for_set_matching? }
    end
  end

  protected

  def check_filterable
    if self.profile_question.file_type? && self.filterable == true
      errors.add(:filterable, QUESTION_FILTERABLE_ERROR)
    end
  end

  private

  def self.filter_visible_role_questions(role_questions, editable = false)
    if editable
      role_questions.select{|role_qn| !role_qn.restricted_to_admin_alone? && !role_qn.admin_only_editable? }
    else
      role_questions.select{|role_qn| !role_qn.restricted_to_admin_alone?}
    end
  end
end
