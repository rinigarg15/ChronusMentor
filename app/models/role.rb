# == Schema Information
#
# Table name: roles
#
#  id                          :integer          not null, primary key
#  name                        :string(255)      not null
#  program_id                  :integer
#  created_at                  :datetime
#  updated_at                  :datetime
#  default                     :integer
#  join_directly               :boolean
#  membership_request          :boolean
#  invitation                  :boolean
#  join_directly_only_with_sso :boolean
#  administrative              :boolean          default(FALSE)
#  for_mentoring               :boolean          default(FALSE)
#  description                 :text(65535)
#  eligibility_rules           :boolean
#  eligibility_message         :text(65535)
#  can_be_added_by_owners      :boolean          default(FALSE)
#  slot_config                 :integer
#

class Role < ActiveRecord::Base
  # Format that the role names should be of.
  NAME_FORMAT = /^([a-z]|_)+$/

  PROGRAM_JOIN_OPTIONS = [:membership_request, :join_directly, :join_directly_only_with_sso]

  # ASSOCIATIONS
  # ============================================================================
  belongs_to_program_or_organization
  sanitize_attributes_content :description

  # VALIDATIONS
  # ============================================================================
  validates_presence_of :name, :program
  validates_uniqueness_of :program_id, :scope => [:name]
  # This will make sure the for_mentoring flag is true for mentor and mentees
  validates :for_mentoring, presence: true, if: Proc.new{|role| RoleConstants::MENTORING_ROLES.include?(role.name) }
  validates :slot_config, inclusion: { in: RoleConstants::SlotConfig.all }, allow_nil: true
  validate :check_name_is_of_valid_format
  validate :unique_non_invite_join_setting
  validates :default, inclusion: { in: RoleConstants::Default.all }, allow_nil: true
  validates :max_connections_limit, numericality: { greater_than: 0, only_integer: true }, allow_nil: true

  has_many :role_permissions, :dependent => :destroy
  has_many :permissions, :through => :role_permissions
  has_many :object_role_permissions, :dependent => :destroy

  has_many :role_references, :dependent => :destroy

  # Role assocation of type 'User'
  has_many :users,  :through => :role_references,
                    :source => :ref_obj,
                    :source_type => 'User'

  has_many :role_questions, :dependent => :destroy
  has_many :role_resources, :dependent => :destroy

  has_many :mentoring_model_task_templates, :class_name => "MentoringModel::TaskTemplate", :dependent => :destroy
  has_many :group_settings, dependent: :destroy, class_name: Group::MembershipSetting.name
  has_many :connection_memberships, dependent: :destroy, class_name: Connection::Membership.name

  has_one :customized_term, :as => :ref_obj, :dependent => :destroy
  has_one :admin_view, :dependent => :destroy
  has_many :project_requests, class_name: ProjectRequest.name,  :foreign_key => "sender_role_id"
  has_many :role_question_privacy_settings
  has_many :connection_membership_state_changes
  has_many :group_view_columns
  has_many :survey_answers, foreign_key: "connection_membership_role_id", dependent: :nullify

  translates :description, :eligibility_message

  # Roles with the given name.
  scope :with_name, Proc.new {|role_name|
    where({:name => role_name})
  }

  scope :allowing_membership_request, -> { where(:membership_request => true)}
  scope :allowing_join_with_criteria, -> { where(eligibility_rules: true)}
  scope :allowing_join_directly_only_with_sso, -> { where(:join_directly_only_with_sso => true)}
  scope :allowing_join_directly, -> { where(:join_directly => true)}
  scope :allowing_join_directly_or_join_directly_only_with_sso, -> { where("join_directly = ? OR join_directly_only_with_sso = ?", true, true)}
  scope :allowing_join_now, -> { where("join_directly = ? OR membership_request = ? OR join_directly_only_with_sso = ? OR eligibility_rules = ?", true, true, true, true)}
  scope :allowing_invitation, -> { where(:invitation => true)}
  scope :default, -> { where("roles.default IS NOT NULL")}
  scope :non_default, -> { where(default: nil)}
  scope :administrative, -> { where(administrative: true)}
  scope :non_administrative, -> { where(administrative: false)}
  scope :of_member, Proc.new {|member| joins(:users).where("users.member_id = ?", member.id)}
  scope :with_permission_name, Proc.new {|permission_name| joins(:permissions).where("permissions.name = ?", permission_name)}
  scope :for_mentoring, -> { where(for_mentoring: true)}
  scope :for_mentoring_models, -> { where("for_mentoring = ? OR roles.name = ?", true, RoleConstants::ADMIN_NAME)}

  attr_accessor :base_term

  # Gettor for permission names
  def permission_names
    self.permissions.collect(&:name)
  end

  # Returns true if permission_names include *perm_name
  def has_permission_name?(perm_name)
    self.permission_names.include?(perm_name)
  end

  # Gettor for permission names
  def permission_names=(perm_names)
    self.permissions = Permission.where(name: perm_names)
  end

  def remove_permission(permission_name)
    if self.permission_names.include?(permission_name)
      self.permission_names -= [permission_name]
    end
  end

  def add_permission(permission_name)
    unless self.permission_names.include?(permission_name)
      self.permission_names += [permission_name]
    end
  end

  def can_invite_role?(role_name)
    self.has_permission_name?("invite_#{role_name.pluralize}")
  end

  def needs_approval_to_create_circle?
    !self.has_permission_name?(RolePermission::CREATE_PROJECT_WITHOUT_APPROVAL)
  end

  def update_role_join_settings!(join_settings)
    self.join_directly_only_with_sso = join_settings.include?(RoleConstants::JoinSetting::JOIN_DIRECTLY_ONLY_WITH_SSO)
    self.join_directly = join_settings.include?(RoleConstants::JoinSetting::JOIN_DIRECTLY)
    self.eligibility_rules = join_settings.include?(RoleConstants::JoinSetting::ELIGIBILITY_RULES)
    self.membership_request = join_settings.include?(RoleConstants::JoinSetting::MEMBERSHIP_REQUEST)
    self.save!
  end

  def can_be_shown_in_join_now?
    self.membership_request? || self.join_directly? || self.join_directly_only_with_sso?
  end

  def can_show_apply_to_join_ticked?(program)
    self.membership_request? || self.join_directly?  || self.join_directly_only_with_sso?  || (self.eligibility_rules? && program.membership_eligibility_rules_enabled?)
  end

  def mentor?
    self.name == RoleConstants::MENTOR_NAME
  end

  def mentee?
    self.name == RoleConstants::STUDENT_NAME
  end

  def admin?
    self.name == RoleConstants::ADMIN_NAME
  end

  def is_default?
    self.default.present?
  end

  def slot_config_required?
    self.slot_config == RoleConstants::SlotConfig::REQUIRED
  end

  def slot_config_optional?
    self.slot_config == RoleConstants::SlotConfig::OPTIONAL
  end

  def slot_config_enabled?
    self.slot_config.present?
  end

  def set_default_customized_term
    return if self.customized_term.present?
    self.build_customized_term.save_term((get_term_at_org_creation || RoleConstants::DEFAULT_CUSTOMIZED_TERMS_MAPPING[self.name] || self.name.humanize), CustomizedTerm::TermType::ROLE_TERM)
  end

  def get_term_at_org_creation
    self.base_term.presence
  end

  # Return the translation term of a role
  # Eg. student => mentee
  # mentor => mentor
  def self.get_role_translation_term(role_name)
    RoleConstants::ROLE_DISPLAY_NAME_MAPPING[role_name].presence || role_name
  end

  def self.get_signup_options(program, roles)
    organization = program.organization
    auth_configs = AuthConfig.classify(organization.auth_configs)
    auth_configs_to_show = []

    roles.each do |role|
      if role.join_directly_only_with_sso? && auth_configs[:custom].present?
        auth_configs_to_show << auth_configs[:custom]
      else
        return organization.auth_configs
      end
    end
    auth_configs_to_show.flatten.uniq
  end

  # Returns true if any role_question for the role in admin view is not admin_editable_only  
  def can_member_modify_eligibility_details?
    admin_view = self.admin_view
    return true if admin_view.nil?
    profile_hash = admin_view.filter_params_hash[:profile]
    profile_questions_hash = profile_hash[:questions]
    profile_questions_hash.values.each do |prof_hash|
      profile_question = self.program.organization.profile_questions.find(prof_hash[:question])
      role_question = profile_question.role_questions.find_by(role_id: self.id)
      return true if !(role_question.nil? || role_question.admin_only_editable?) 
    end
    return false
  end

  #TODO #CareerDev - Followup and create defaults as part of portal observer
  def add_default_questions_for
    role_program = self.program
    profile_questions = ProfileQuestion.where(organization_id: role_program.organization.id).default_questions
    profile_questions.each do |profile_question|
      profile_question.role_questions.create!(
        role_id: self.id,
        required: true,
        filterable: true,
        in_summary: false,
        available_for: RoleQuestion::AVAILABLE_FOR::BOTH,
        private: RoleQuestion::PRIVACY_SETTING::ALL 
      )
    end
  end

  def role_name
    name
  end

  def populate_description_with_default_value_if_nil(locales)
    custom_terms = self.program.return_custom_term_hash
    locales.each do |locale|
      translation = self.translations.find_or_initialize_by(locale: locale)
      translation.description = "feature.membership_request.content.role_description.#{self.name}_description".translate(custom_terms.merge(locale: locale, :default => "")) if translation.description.nil?
      translation.save!
    end
  end

  def self.populate_content_for_language(org, locale)
    org.programs.each do |prog|
      prog.roles_without_admin_role.each do |role|
        role.populate_description_with_default_value_if_nil([locale])
      end
    end
  end

  def can_be_removed?
    !(self.role_references.exists? || self.editable_associated_admin_views.present?)
  end

  def editable_associated_admin_views
    get_associated_org_level_admin_views + get_associated_program_level_admin_views
  end

  #-----------------------------------------------------------------------------
  # PRODUCT DASHBOARD METHODS - START
  #-----------------------------------------------------------------------------

  def allowed_enrollment_options
    ret = [:join_directly, :membership_request, :join_directly_only_with_sso, :eligibility_rules].select{ |opt| send(opt) }
    ret = [:invitation] if ret.blank?
    ret
  end

  #-----------------------------------------------------------------------------
  # PRODUCT DASHBOARD METHODS - END
  #-----------------------------------------------------------------------------

  def self.es_reindex(role, options = {})
    program_ids = Array(role).collect(&:program_id)
    reindex_group(program_ids, options)
    reindex_user(role, options)
    reindex_article(program_ids, options)
    reindex_qa_question(program_ids, options)
  end

  def no_limit_on_project_requests?
    self.max_connections_limit.nil?
  end

  private

  def get_associated_program_level_admin_views
    associated_admin_views = []
    self.program.admin_views.where(default_view: [nil, AdminView::EDITABLE_DEFAULT_VIEWS].flatten).each do |admin_view|
      associated_admin_views << admin_view if is_role_part_of_admin_view_filter?(admin_view)
    end
    associated_admin_views
  end

  def get_associated_org_level_admin_views
    self.program.organization.admin_views.select do |admin_view|
      [admin_view.filter_params_hash[:program_roles]].flatten.compact.map(&:to_i).include?(self.id)
    end
  end

  def is_role_part_of_admin_view_filter?(admin_view)
    yaml_params = admin_view.filter_params_hash
    return unless yaml_params[:roles_and_status].present?
    role_filters = yaml_params[:roles_and_status].select { |key, _| key.match(/role_filter/) }
    return true if role_filters.present? && role_filters.values.any? { |filter| filter[:roles].present? && filter[:roles].include?(self.name) }
  end

  def self.reindex_group(program_ids, options)
    return unless(options[:reindex_group] || options.blank?)
    group_ids = Group.where(program_id: program_ids).pluck(:id)
    DelayedEsDocument.delayed_bulk_update_es_documents(Group, group_ids)
  end

  def self.reindex_user(role, options)
    return unless(options[:reindex_user] || options.blank?)
    user_ids = RoleReference.where(role_id: Array(role).collect(&:id), ref_obj_type: User.name).pluck(:ref_obj_id)
    DelayedEsDocument.delayed_bulk_update_es_documents(User, user_ids)
  end

  def self.reindex_article(program_ids, options)
    return unless(options[:reindex_article] || options.blank?)
    article_ids = Article.get_article_ids_published_in_program(program_ids)
    DelayedEsDocument.delayed_bulk_update_es_documents(Article, article_ids)
  end

  def self.reindex_qa_question(program_ids, options)
    return unless(options[:reindex_qa_question] || options.blank?)
    qa_question_ids = QaQuestion.where(program_id: program_ids).pluck(:id)
    DelayedEsDocument.delayed_bulk_update_es_documents(QaQuestion, qa_question_ids)
  end

  # Checks whether the role name is of proper format.
  def check_name_is_of_valid_format
    if self.name !~ NAME_FORMAT
      self.errors.add(:name, "activerecord.custom_errors.role.invalid".translate)
    end
  end

  def unique_non_invite_join_setting
    if ((self.join_directly_only_with_sso && self.join_directly) || (self.join_directly && self.membership_request) || (self.membership_request && self.join_directly_only_with_sso))
      self.errors.add(:join_directly, "activerecord.custom_errors.role.invalid_join_now".translate) if self.join_directly
      self.errors.add(:join_directly_only_with_sso, "activerecord.custom_errors.role.invalid_join_now".translate) if self.join_directly_only_with_sso
      self.errors.add(:membership_request, "activerecord.custom_errors.role.invalid_join_now".translate) if self.membership_request
    end
  end
end
