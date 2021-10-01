class MentoringModel::GoalTemplatesController < ApplicationController
  include MentoringModelUtils

  before_action :set_bulk_dj_priority
  before_action :fetch_mentoring_model
  allow exec: :manage_mm_goals_at_admin_level?
  before_action :find_goal_template, :except => [:new, :create]
  allow :exec => :check_program_has_ongoing_mentoring_enabled

  def new
    @new_goal_template = @mentoring_model.mentoring_model_goal_templates.new
    render :partial => "mentoring_model/goal_templates/new.html.erb"
  end

  def create
    @new_goal_template = @mentoring_model.mentoring_model_goal_templates.new(mentoring_model_goal_template_params(:create))
    @new_goal_template.save
  end

  def update
    @goal_template.update_attributes!(mentoring_model_goal_template_params(:update))
  end

  def destroy
    @goal_template.destroy
    @goal_template_count = @mentoring_model.mentoring_model_goal_templates.count
    @task_templates = fetch_appropriate_task_templates
    fetch_goal_templates
  end

  private

  def mentoring_model_goal_template_params(action)
    params.require(:mentoring_model_goal_template).permit(MentoringModel::GoalTemplate::MASS_UPDATE_ATTRIBUTES[action])
  end

  def find_goal_template
    @goal_template = @mentoring_model.mentoring_model_goal_templates.find(params[:id])
  end

  def fetch_goal_templates
    @goal_templates = @mentoring_model.mentoring_model_goal_templates.select(:id)
  end

end