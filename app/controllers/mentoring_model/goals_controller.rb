class MentoringModel::GoalsController < ApplicationController
  include ConnectionFilters
  include MentoringModelUtils

  before_action :skip_side_pane, :only => [:index]
  common_extensions
  before_action :can_edit_goal_plan?, :only => [:index]
  before_action :compute_page_controls_allowed
  before_action :checkin_base_permission, only: [:index]

  allow :exec => :can_edit_goal_plan?, :only => [:new, :create, :update, :destroy]
  before_action :fetch_goal, :only => [:update, :destroy]
  allow :exec => :restrict_altering_of_goals_from_template, only: [:update, :destroy]
  allow :exec => :check_program_has_ongoing_mentoring_enabled

  def index
    @goals = @group.mentoring_model_goals
    @cached_tasks = prepare_tasks_cache
    @required_tasks = load_required_tasks_from_cache
  end

  def new
    @new_goal = @group.mentoring_model_goals.new
    render :partial => "mentoring_model/goals/new.html.erb"
  end

  def create
    @new_goal = @group.mentoring_model_goals.create!(mentoring_model_goal_params(:create))
    track_activity_for_ei(EngagementIndex::Activity::CREATE_GOAL)
  end


  def update
    @goal.update_attributes!(mentoring_model_goal_params(:update))
  end

  def destroy
    @goal.destroy
    @goals = load_all_goals
  end

  private

  def mentoring_model_goal_params(action)
    params.require(:mentoring_model_goal).permit(MentoringModel::Goal::MASS_UPDATE_ATTRIBUTES[action])
  end

  def load_required_tasks_from_cache
    @cached_tasks.values.flatten.select(&:required?)
  end

  def load_all_goals
    @group.mentoring_model_goals.includes(goal_eager_loadables)
  end

  def prepare_tasks_cache
    tasks_cache = {}
    all_tasks = @group.mentoring_model_tasks.includes(task_eager_loadables)
    @goals.each do |goal|
      tasks_cache[goal.id] = all_tasks.select{|task| task.goal_id == goal.id}
    end
    tasks_cache
  end

  def fetch_goal
    @goal = @group.mentoring_model_goals.find(params[:id])
  end

  def skip_side_pane
    @skip_mentoring_model_goals_side_pane = true
  end

  def can_edit_goal_plan?
    @edit_goal_plan ||= (manage_mm_goals_at_end_user_level? && @page_controls_allowed)
  end

  def restrict_altering_of_goals_from_template
    !@goal.from_template?
  end

end