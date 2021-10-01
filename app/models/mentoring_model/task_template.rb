# == Schema Information
#
# Table name: mentoring_model_task_templates
#
#  id                    :integer          not null, primary key
#  mentoring_model_id    :integer
#  milestone_template_id :integer
#  goal_template_id      :integer
#  required              :boolean          default(FALSE)
#  title                 :string(255)
#  description           :text(16777215)
#  duration              :integer
#  associated_id         :integer
#  action_item_type      :integer
#  position              :integer
#  role_id               :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  specific_date         :datetime
#  action_item_id        :integer
#

class MentoringModel::TaskTemplate < ActiveRecord::Base

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:title, :description, :required, :duration, :associated_id, :role_id, :action_item_type, :action_item_id, :goal_template_id, :milestone_template_id, :specific_date],
    :update => [:title, :description, :required, :duration, :associated_id, :role_id, :action_item_type, :action_item_id, :goal_template_id, :milestone_template_id, :specific_date]
  }

  # Constants
  TITLE_TRUNCATE_LENGTH = 70
  PREVIOUS_TITLE_TRUNCATE_LENGTH = 50

  sanitize_attributes_content :description
  # Associations
  belongs_to :mentoring_model
  belongs_to :milestone_template
  belongs_to :goal_template
  belongs_to :role
  belongs_to :associated_task, foreign_key: :associated_id, class_name: MentoringModel::TaskTemplate.name

  has_many :task_templates, foreign_key: "associated_id", class_name: "MentoringModel::TaskTemplate"
  has_many :mentoring_model_tasks, class_name: MentoringModel::Task.name, foreign_key: :mentoring_model_task_template_id

  attr_accessor :skip_survey_validations, :due_date, :skip_due_date_computation, :skip_associated_id_filling, :skip_observer, :skip_increment_version_and_sync_trigger

  # Validations
  validates :mentoring_model_id, :title, :duration, presence: true
  validates :required, inclusion: { in: [true, false] }
  validate  :duration_or_specific_date_presence, if: :required?
  validates :duration, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, unless: :required?
  validate  :validate_surveys, :if => :is_engagement_survey_action_item?
  validates_presence_of :action_item_id, :if => :is_engagement_survey_action_item?, :message => Proc.new { "activerecord.custom_errors.task_template.survey_cannot_be_blank_in_engagement_survey_task".translate } 
  validate  :specific_date_is_blank, unless: :required?

  translates :title, :description
  has_paper_trail on: [:update], class_name: 'ChronusVersion'

  # Date Assigner
  module DueDateType
    PREDECESSOR = "predecessor"
    SPECIFIC_DATE = "specificDate"
  end
  # Class modules
  module ActionItem
    DEFAULT = 0
    MEETING = 1
    GOAL    = 2
    ENGAGEMENT_SURVEY = 4

    class << self
      def text_to_translate
        {
          DEFAULT => "common_text.prompt_text.Select",
          MEETING => "feature.mentoring_model.label.setup_meeting",
          GOAL    => "feature.mentoring_model.label.create_goal_plan",
          ENGAGEMENT_SURVEY => "feature.mentoring_model.label.take_a_survey"
        }
      end

      def action_item_name(action_item_type)
        {
            DEFAULT => nil,
            MEETING => Meeting,
            GOAL => MentoringModel::Goal,
            ENGAGEMENT_SURVEY => EngagementSurvey
          }[action_item_type]
      end

      def all
        [DEFAULT, MEETING, GOAL, ENGAGEMENT_SURVEY]
      end
    end
  end

  # Scopes
  scope :required, -> { where(required: true) }
  scope :non_specific_date_templates, -> { where(specific_date: nil) }
  scope :of_engagement_survey_type, -> { where(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY) }
  scope :with_specific_due_dates , -> { where("specific_date IS NOT NULL")}

  # Class methods
  def self.compute_due_dates(task_templates, options = {})
    queue = [task_templates.select{|tt| tt.associated_id.nil? }.each{|tt| tt.due_date = 0 }]
    visited = {}
    until queue.empty?
      list = queue.shift
      list.each do |template|
        unless visited[template.id]
          template.due_date += (template.specific_date.blank? ? template.duration : (template.specific_date.to_i - 1e15))
          queue << task_templates.select{|tt| tt.associated_id == template.id }.each do |tt|
            tt.due_date = template.due_date
          end
        end
        visited[template.id] = true
      end
    end
    unless options[:skip_positions]
      return update_due_positions(task_templates)
    else
      return task_templates
    end
  end

  # This will just update the positions
  # This method requires due_date attr_accessor to be set
  def self.update_due_positions(task_templates)
    task_templates.sort_by{|tt| [tt.due_date || 0, tt.position || 0, tt.required? ? 0 : 1] }.each_with_index do |template, index|
      template.position = index
      template.skip_due_date_computation = true
      template.skip_increment_version_and_sync_trigger = true
      template.save! if template.changed?
    end
  end

  def self.scoping_object(task_template)
    task_template.milestone_template ||  task_template.mentoring_model
  end

  def self.filter_sub_tasks(task_template, task_templates)
    task_templates - MentoringModel::TaskTemplate.sub_tasks(task_template, task_templates)
  end

  def self.sub_tasks(task_template, task_templates)
    if task_template.new_record?
      []
    else
      sub_task_ids = []
      queue = task_templates.select{|tt| tt.associated_id == task_template.id}
      until queue.empty?
        item = queue.shift
        next if sub_task_ids.include?(item.id)
        sub_task_ids << item.id
        task_templates.each{|tt| queue << tt if tt.associated_id == item.id}
      end
      task_templates.select{|tt| sub_task_ids.include?(tt.id)}
    end
  end

  def self.action_item_list(program)
    {
      MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY => EngagementSurvey.where(program_id: program)
    }
  end

  def update_task_template_positions
    mentoring_model = self.mentoring_model
    all_task_templates = mentoring_model.mentoring_model_task_templates
    options = { skip_positions: self.milestone_template_id.present? }
    task_templates = all_task_templates.dup
    task_templates_with_dues = MentoringModel::TaskTemplate.compute_due_dates(task_templates, options)
    if options[:skip_positions]
      milestone_template_ids = all_task_templates.collect(&:milestone_template_id)
      milestone_template_ids.each do |milestone_template_id|
        all_task_templates = task_templates_with_dues.select{|t| t.milestone_template_id == milestone_template_id }
        MentoringModel::TaskTemplate.update_due_positions(all_task_templates)
      end
    end
  end

  # Instance methods
  #TODO:  DRY these functions, same in mentoring_model/task.rb

  def get_action_item_list
    MentoringModel::TaskTemplate.action_item_list(mentoring_model.program_id)[action_item_type]
  end

  def is_meeting_action_item?
    action_item_type == ActionItem::MEETING
  end

  def is_create_goal_action_item?
    action_item_type == ActionItem::GOAL
  end

  def is_engagement_survey_action_item?
    action_item_type == ActionItem::ENGAGEMENT_SURVEY
  end

  def action_item
    MentoringModel::TaskTemplate::ActionItem.action_item_name(action_item_type).find_by(id: action_item_id)
  end

  def optional?
    !required?
  end

  def version_number
    versions.size + 1
  end

  private

  def duration_or_specific_date_presence
    unless (self.duration && self.duration > 0) || self.specific_date.present?
      self.errors[:base] << "activerecord.custom_errors.task_template.duration_or_specific_date_presence".translate
    end
  end

  def specific_date_is_blank
    unless self.specific_date.blank?
      self.errors[:base] << "activerecord.custom_errors.task_template.specific_date_is_blank".translate
    end
  end

  def validate_surveys
    return true if self.skip_survey_validations
    if !get_action_item_list.include?(self.action_item) 
      self.errors[:base] << "activerecord.custom_errors.task_template.survey_invalid".translate
    end
  end
end
