# == Schema Information
#
# Table name: mentoring_model_milestones
#
#  id                                    :integer          not null, primary key
#  title                                 :string(255)
#  description                           :text(16777215)
#  from_template                         :boolean          default(FALSE)
#  group_id                              :integer          not null
#  created_at                            :datetime         not null
#  updated_at                            :datetime         not null
#  mentoring_model_milestone_template_id :integer
#  template_version                      :integer
#  position                              :integer
#

class MentoringModel::Milestone < ActiveRecord::Base
  self.table_name = "mentoring_model_milestones"

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:title, :description, :position],
    :update => [:title, :description]
  }

  belongs_to :group
  belongs_to :mentoring_model_milestone_template, class_name: MentoringModel::MilestoneTemplate.name
  has_many   :mentoring_model_tasks, -> { order "mentoring_model_tasks.position ASC" }, dependent: :destroy, class_name: MentoringModel::Task.name
  translates :title, :description

  validates :title, :group, presence: true
  validates :template_version, numericality: { only_integer: true, greater_than: 0 }, if: :from_template?

  after_save :reindex_followups
  after_destroy :reindex_followups

  MINIMUM_COMPLETED_MILESTONES_UNDER_BAR = 1

  scope :positioned_before, Proc.new { |position| where("position IS NULL OR position < ?", position) }

  class << self
    def overdue
      joins(:mentoring_model_tasks).where(mentoring_model_tasks: {
        required: true, status: MentoringModel::Task::Status::TODO
      }).where("mentoring_model_tasks.due_date < ?", Date.today.at_beginning_of_day).distinct
    end

    def current
      joins(:mentoring_model_tasks).where(mentoring_model_tasks: {
        required: true, status: MentoringModel::Task::Status::TODO
      }).where("mentoring_model_tasks.due_date >= ?", Date.today.at_beginning_of_day).distinct
    end

    def pending
      joins(:mentoring_model_tasks).where(mentoring_model_tasks: {
        required: true, status: MentoringModel::Task::Status::TODO
      }).where("mentoring_model_tasks.due_date >= ?", Date.today.at_beginning_of_day).distinct.where(
        <<-SQL
          mentoring_model_milestones.id NOT IN
          (
            SELECT DISTINCT mentoring_model_milestones.id
            FROM mentoring_model_milestones
            INNER JOIN mentoring_model_tasks 
            ON mentoring_model_tasks.milestone_id = mentoring_model_milestones.id
            WHERE mentoring_model_tasks.required = 1
            AND mentoring_model_tasks.status = #{MentoringModel::Task::Status::TODO}
            AND mentoring_model_tasks.due_date < '#{Date.today.at_beginning_of_day.to_s(:db)}'
          )
        SQL
      )
    end

    def completed
      where(
        <<-SQL
          mentoring_model_milestones.id NOT IN
          (
            SELECT DISTINCT mentoring_model_milestones.id
            FROM mentoring_model_milestones
            INNER JOIN mentoring_model_tasks
            ON mentoring_model_milestones.id = mentoring_model_tasks.milestone_id
            AND mentoring_model_tasks.required = 1
            AND mentoring_model_tasks.status = #{MentoringModel::Task::Status::TODO}
          )  
        SQL
      )  
    end

    def with_incomplete_optional_tasks
      joins(:mentoring_model_tasks).where(mentoring_model_tasks: {
        required: false, status: MentoringModel::Task::Status::TODO
      }).distinct
    end

    def from_template
      where(from_template: true)
    end

    def es_reindex(milestone)
      group_ids = Array(milestone).collect(&:group_id).uniq
      reindex_group(group_ids)
    end

    def reindex_group(group_ids)
      DelayedEsDocument.delayed_bulk_update_es_documents(Group, group_ids)
    end
  end

  def custom_entry?
    !self.from_template?
  end

  def reindex_followups
    MentoringModel::Milestone.es_reindex(self)
  end

  def parent_template
    self.mentoring_model_milestone_template
  end

  def group_checkins_duration
    GroupCheckin.joins(task: :milestone).where('`mentoring_model_milestones`.`id`=?', self.id).sum(:duration)
  end
end
