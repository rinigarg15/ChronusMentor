# == Schema Information
#
# Table name: mentoring_models
#
#  id                   :integer          not null, primary key
#  title                :string(255)
#  description          :text(16777215)
#  default              :boolean          default(FALSE)
#  program_id           :integer
#  mentoring_period     :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  version              :integer          default(1)
#  should_sync          :boolean
#  mentoring_model_type :string(255)      default("base")
#  allow_due_date_edit  :boolean          default(FALSE)
#  goal_progress_type   :integer          default(0)
#

class MentoringModel < ActiveRecord::Base
  DEFAULT_VERSION = 1
  module Type
    BASE = :base
    HYBRID = :hybrid
  end

  include MentoringPeriodUtils
  prepend MentoringModelWithHybridTemplates
  acts_as_object_role_permission_authorizable

  MASS_UPDATE_ATTRIBUTES = {
    create: [:title, :description, :mentoring_model_type],
    update: [:title, :description],
    create_template_objects: [:allow_due_date_edit, :allow_messaging, :allow_forum, :forum_help_text]
  }

  module GoalProgressType
    AUTO = 0
    MANUAL = 1
  end

  # This callback cannot be in the observer.
  # This needs to be placed before the has_many depenedent: :destroy
  before_destroy :disassociate_drafted_groups
  before_destroy :templates_cleanup

  belongs_to_program
  has_many :mentoring_model_task_templates, -> { order("mentoring_model_task_templates.milestone_template_id ASC, mentoring_model_task_templates.position ASC").includes([:translations])}, class_name: MentoringModel::TaskTemplate.name
  has_many :mentoring_model_goal_templates, -> { order("mentoring_model_goal_templates.id ASC").includes([:translations]) }, class_name: MentoringModel::GoalTemplate.name
  has_many :mentoring_model_milestone_templates, -> { order("mentoring_model_milestone_templates.position ASC").includes([:translations]) }, class_name: MentoringModel::MilestoneTemplate.name
  has_many :mentoring_model_facilitation_templates, -> { order("mentoring_model_facilitation_templates.send_on ASC").includes([:translations]) }, class_name: MentoringModel::FacilitationTemplate.name
  has_many :groups, dependent: :nullify
  has_many :active_groups, -> { where("groups.status NOT IN (?)", Group::Status::NOT_ACTIVE_CRITERIA) },
           class_name: Group.name

  has_many :child_links, class_name: MentoringModel::Link.name, foreign_key: :parent_template_id, dependent: :destroy, inverse_of: :parent_template
  has_many :children, class_name: MentoringModel.name, through: :child_links, source: :child_template
  has_many :parent_links, class_name: MentoringModel::Link.name, foreign_key: :child_template_id, dependent: :destroy, inverse_of: :child_template
  has_many :parents, class_name: MentoringModel.name, through: :parent_links, source: :parent_template

  translates :title, :description, :forum_help_text

  validates :title, :program_id, :mentoring_period, :goal_progress_type, presence: true
  validates :mentoring_period, numericality: { greater_than: 0 }
  validates :title, translation_uniqueness: {scope: :program_id, case_sensitive: false}

  validates :default, uniqueness: {scope: :program_id}, if: :default?
  validates :allow_messaging, :allow_forum, inclusion: { in: [true, false] }

  validate :check_disabling_of_messaging, :check_disabling_of_forum, on: :update

  scope :default, -> { where(default: true)}
  scope :with_manual_goals, -> { where(goal_progress_type: GoalProgressType::MANUAL)}

  attr_accessor :skip_default_permissions, :prevent_default_setting

  class << self
    def trigger_sync(mentoring_model_id, locale)
      mentoring_model = MentoringModel.find_by(id: mentoring_model_id)
      return if mentoring_model.nil? || (!mentoring_model.should_sync?)
      mentoring_model.groups.active.where("version < ?", mentoring_model.version).select([:id, :version]).each do |group|
        Group.delay.sync_with_template(group.id, locale)
      end
    end

    def es_reindex(mentoring_model)
      group_ids = Array(mentoring_model).collect(&:group_ids).flatten.uniq
      reindex_group(group_ids)
    end
  end

  # Revisit for hybrid of hybrid support
  def can_update_duration?
    if hybrid?
      !(has_ongoing_connections?) || new_record?
    elsif base?
      !(has_ongoing_related_connections?)
    end
  end

  def can_update_features?
    (!(has_ongoing_connections?)) && (!(parents.exists?))
  end

  def increment_version
    ActiveRecord::Base.transaction do
      self.version = (self.version || DEFAULT_VERSION) + 1
      self.save!
    end
  end

  def increment_version_and_trigger_sync
    increment_version
    MentoringModel.delay.trigger_sync(self.id, I18n.locale)
    parents.each do |parent|
      parent.increment_version_and_trigger_sync
    end
  end

  def has_ongoing_connections?
    groups.active.exists?
  end

  def has_ongoing_related_connections?
    Group.where(id: all_associated_group_ids).active.exists?
  end

  def manual_progress_goals?
    self.goal_progress_type == GoalProgressType::MANUAL
  end

  # This method will fetch the group ids of those groups which are either directly or
  # indirectly linked (thourgh hybrid templates) with this mentoring model
  def all_associated_group_ids(visited_in = [])
    visited = visited_in.clone
    return [] if visited.include?(id)
    visited << id
    group_ids = groups.pluck(:id)
    parents.each do |parent|
      group_ids += parent.all_associated_group_ids(visited)
    end
    children.each do |child|
      group_ids += child.all_associated_group_ids(visited)
    end
    group_ids.uniq.clone
  end

  def hybrid?
    (mentoring_model_type.to_sym == Type::HYBRID)
  end

  def base?
    (mentoring_model_type.to_sym == Type::BASE)
  end

  def base_templates
    descendants.select(&:base?)
  end

  # Revisit for hybrid of hybrid support
  def descendants
    children.map do |child|
      [child.descendants, child]
    end.flatten
  end

  def other_templates_to_associate
    program.mentoring_models.where(mentoring_model_type: :base)
  end

  # this will be helpful check whether two mentoring models have same feature set
  def features_signature
    roles = program.roles.select([:id, :name, :for_mentoring]).for_mentoring_models.group_by(&:name)
    admin_role = roles[RoleConstants::ADMIN_NAME].first
    other_roles = roles.values.flatten.select{|role| role.for_mentoring? }
    signature = self.goal_progress_type.to_s
    object_to_check = hybrid? ? base_templates[0] : self
    ObjectPermission::MentoringModel::ADMIN_PERMISSIONS.each do |permission|
      signature += (object_to_check.send("can_#{permission}?", admin_role) ? "1" : "0")
    end
    ObjectPermission::MentoringModel::OTHER_USER_PERMISSIONS.each do |permission|
      signature += (object_to_check.send("can_#{permission}?", other_roles) ? "1" : "0")
    end
    signature
  end

  def update_permissions!
    first_base_template = base_templates.first
    self.copy_object_role_permissions_from!(first_base_template, roles: self.program.roles.select([:id, :name]).for_mentoring_models)
  end

  def get_task_options_array
    roles_hash = program.roles.includes(:customized_term).inject({nil => Proc.new{"feature.mentoring_model.label.unassigned_capitalized".translate}.call}){|hash, role| hash[role.id] = role.customized_term.term;hash}
    grouped_tasks = mentoring_model_task_templates.includes(:milestone_template).group_by(&:milestone_template)
    options_array = []
    return build_task_array(grouped_tasks.values.flatten, roles_hash) if grouped_tasks.size == 1
    grouped_tasks.each do |milestone, tasks|
      options_array << { text: tooltip_double_escape(milestone.try(:title)||Proc.new{"display_string.Others".translate}.call), children: build_task_array(tasks, roles_hash) }
    end
    return options_array
  end

  def increment_positions_for_milestone_templates_with_or_after_position(position)
    milestone_templates = self.mentoring_model_milestone_templates.where("id IS NOT NULL AND position >= ?", position)
    milestone_templates.each do |template|
      template.position += 1
      template.skip_increment_version_and_sync_trigger = true
      template.save(validate: false)
    end
  end

  def get_previous_and_next_position_milestone_template_ids(milestone_template_id)
    milestone_template_ids = self.mentoring_model_milestone_templates.pluck(:id)
    index_of_current_template = milestone_template_ids.index(milestone_template_id)

    prev_template_id = milestone_template_ids[index_of_current_template-1] if index_of_current_template > 0
    next_template_id = milestone_template_ids[index_of_current_template+1] if index_of_current_template < milestone_template_ids.size-1

    return prev_template_id, next_template_id
  end

  def impacts_group_forum?(group)
    group.forum_enabled? && !self.allow_forum? && group.topics.exists?
  end

  def impacts_group_messaging?(group)
    group.scraps_enabled? && !self.allow_messaging? && group.scraps.exists?
  end

  def populate_default_forum_help_text
    return unless self.forum_help_text.nil?

    languages = self.program.get_organization.enabled_organization_languages_including_english
    languages.collect(&:language_name).each do |language_name|
      GlobalizationUtils.run_in_locale(language_name.to_sym) do
        help_texts = ["feature.mentoring_model.content.default_forum_help_text.message_1".translate]
        help_texts << "feature.mentoring_model.content.default_forum_help_text.message_2".translate
        self.forum_help_text = help_texts.join(" ")
      end
    end
  end

  def can_disable_messaging?
    self.groups.open_or_closed.empty?
  end
  alias_method :can_disable_forum?, :can_disable_messaging?

  private

  def self.reindex_group(group_ids)
    DelayedEsDocument.delayed_bulk_update_es_documents(Group, group_ids)
  end

  def build_task_array(tasks, roles_hash)
    tasks.map{|task| {id: task.id, text: tooltip_double_escape(task.title), role: roles_hash[task.role_id]}}
  end

  def fetch_items_in_order(klass, ids)
    arel = klass.where(id: ids)
    arel = arel.order(Arel.sql("FIELD(id, #{ids.join(COMMA_SEPARATOR)})") => :asc) if ids.present?
    arel
  end

  def cumulate_start_dates(linked_milestone_templates)
    linked_milestone_templates.group_by(&:mentoring_model_id).each_value do |milestone_templates|
      initial_start_date = 0
      milestone_templates.each do |milestone|
        initial_start_date += [milestone.start_date - initial_start_date, 0].max
        milestone.start_date = initial_start_date
      end
    end
  end

  def disassociate_drafted_groups
    default_mentoring_model = self.program.default_mentoring_model
    if default_mentoring_model.present? && default_mentoring_model != self
      self.groups.drafted.each do |group|
        group.skip_observer = true
        group.mentoring_model_id = default_mentoring_model.id
        group.save!
      end
    end
  end

  def templates_cleanup
    if self.base?
      self.mentoring_model_task_templates.destroy_all
      self.mentoring_model_goal_templates.destroy_all
      self.mentoring_model_milestone_templates.destroy_all
      self.mentoring_model_facilitation_templates.destroy_all
    end
  end

  def check_disabling_of_messaging
    if self.allow_messaging_changed? && !self.allow_messaging? && !self.can_disable_messaging?
      base_error_message, translation_options = get_content_for_disabling_of_messaging_forum_violations
      self.errors.add(:base, "#{base_error_message} #{"feature.mentoring_model.information.disabled_messaging_tooltip".translate(translation_options)}")
    end
  end

  def check_disabling_of_forum
    if self.allow_forum_changed? && !self.allow_forum? && !self.can_disable_forum?
      base_error_message, translation_options = get_content_for_disabling_of_messaging_forum_violations
      self.errors.add(:base, "#{base_error_message} #{"feature.mentoring_model.information.disabled_forum_tooltip".translate(translation_options)}")
    end
  end

  def get_content_for_disabling_of_messaging_forum_violations
    mentoring_connection_term = self.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
    translation_options = {
      mentoring_connection: mentoring_connection_term.term_downcase,
      mentoring_connections: mentoring_connection_term.pluralized_term_downcase
    }
    ["feature.mentoring_model.information.ongoing_closed_groups_tooltip".translate(translation_options), translation_options]
  end
end