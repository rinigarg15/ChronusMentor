# == Schema Information
#
# Table name: mentoring_model_milestone_templates
#
#  id                 :integer          not null, primary key
#  title              :string(255)
#  description        :text(16777215)
#  mentoring_model_id :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  position           :integer
#

class MentoringModel::MilestoneTemplate < ActiveRecord::Base
  POSITION_FOR_FIRST_MILESTONE = 0

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:title, :description, :position],
    :update => [:title, :description]
  }

  belongs_to :mentoring_model

  # Intentionally named the has_many association as mentoring_model_task_templates instead of the conventionally
  # accepted task_templates, as we can access the method mentoring_model_task_templates with 
  # mentoring_model object or milestone_template object
  has_many :mentoring_model_task_templates, -> { order "mentoring_model_task_templates.position ASC" }, dependent: :destroy, class_name: MentoringModel::TaskTemplate.name

  has_many :mentoring_model_facilitation_templates, class_name: MentoringModel::FacilitationTemplate.name, dependent: :destroy

  has_many :mentoring_model_milestones, class_name: MentoringModel::Milestone.name, foreign_key: :mentoring_model_milestone_template_id

  translates :title, :description
  has_paper_trail on: [:update], class_name: 'ChronusVersion'

  validates :title, :mentoring_model_id, presence: true

  attr_accessor :start_date, :skip_increment_version_and_sync_trigger

  def update_start_dates
    program = mentoring_model.program
    program_admin_role = program.roles.with_name(RoleConstants::ADMIN_NAME)
    sorted_task_templates_list = mentoring_model.can_manage_mm_tasks?(program_admin_role) ? MentoringModel::TaskTemplate.compute_due_dates(mentoring_model.mentoring_model_task_templates.where("required = (?) AND specific_date is NULL", true), skip_positions: true).sort_by{|x| [x.due_date, x.position]} : []
    sorted_task_templates_list.select!{|obj| obj.milestone_template_id == id }
    sorted_facilitation_templates_list = mentoring_model.can_manage_mm_messages?(program_admin_role) ? MentoringModel::FacilitationTemplate.compute_due_dates(mentoring_model_facilitation_templates.where("specific_date is NULL")).sort_by{|x| [x.due_date]} : []
    default_high_date_value, default_low_date_value = [1000000, -1000000]
    @start_date = [
      sorted_task_templates_list.empty? ? default_high_date_value : sorted_task_templates_list[0].due_date,
      sorted_facilitation_templates_list.empty? ? default_high_date_value : sorted_facilitation_templates_list[0].due_date
    ].min
    @start_date = 0 if @start_date == default_high_date_value
    @start_date
  end

  def version_number
    versions.size + 1
  end
end
