class CoachingGoalsController < ApplicationController
  ACTIVITIES_PER_PAGE = 20
  include ConnectionFilters
  include MentoringModelUtils
  
  before_action :skip_side_pane, :only => [:index]

  before_action :fetch_group, :fetch_current_connection_membership

  allow :exec => :check_member_or_admin, :only => [:index, :show, :more_activities]

  allow :exec => :check_action_access, :except => [:index, :show, :more_activities]

  allow :exec => :check_group_active, :except => [:index, :show, :more_activities]

  before_action :prepare_template, :only => [:index, :show]

  before_action :compute_page_controls_allowed

  before_action :fetch_coaching_goal, :except => [:index, :create]

  def index
    @coaching_goal = @group.coaching_goals.new
    @group_coaching_goals = @group.coaching_goals.includes(:coaching_goal_activities).
      paginate(:page => params[:page] || 1, :per_page => PER_PAGE)
  end

  def create
    coaching_goal_params = get_coaching_goal_params(:create)
    coaching_goal_params[:due_date] = get_en_datetime_str(coaching_goal_params[:due_date]) if coaching_goal_params[:due_date].present?
    @coaching_goal = @group.coaching_goals.new(coaching_goal_params)
    @coaching_goal.creator = @current_user
    @coaching_goal.save!

    @group_coaching_goals = @group.coaching_goals.paginate(:page => params[:page] || 1, :per_page => PER_PAGE)

    progress_value = params[:progress_slider].to_i
    if progress_value != CoachingGoalActivity::START_PROGRESS_VALUE
      @coaching_goal_activity = @coaching_goal.update_progress(@current_connection_membership, 
        progress_value, nil)
    end
    @is_save_view = params[:view_goal].present?

    unless request.xhr?
      if @is_save_view
        redirect_to group_coaching_goal_path(@group, @coaching_goal)
      else
        flash[:notice] = "flash_message.coaching_goals_flash.created".translate
        redirect_to group_path(@group)
      end
    end
  end

  def show
    @coaching_goal_activity = @coaching_goal.coaching_goal_activities.new
    get_coaching_goal_activities_with_offset
  end

  def edit
  end

  def update
    coaching_goal_params = get_coaching_goal_params(:update)
    coaching_goal_params[:due_date] = get_en_datetime_str(coaching_goal_params[:due_date]) if coaching_goal_params[:due_date].present?
    @coaching_goal.attributes = coaching_goal_params
    due_date_changed = @coaching_goal.due_date_changed?
    @coaching_goal.updating_user = @current_user
    @coaching_goal.save!
    @recent_activity = @coaching_goal.recent_activities.last if due_date_changed
  end

  def destroy
    @coaching_goal.destroy
    flash[:notice] = "flash_message.coaching_goals_flash.deleted".translate
    redirect_to group_coaching_goals_path
  end

  def more_activities
    get_coaching_goal_activities_with_offset
  end

  private

  def get_coaching_goal_params(action)
    params[:coaching_goal].present? ? params[:coaching_goal].permit(CoachingGoal::MASS_UPDATE_ATTRIBUTES[action]) : {}
  end

  def get_coaching_goal_activities_with_offset
    @offset_id = params[:offset_id].to_i    
    activities_per_page = CoachingGoalsController::ACTIVITIES_PER_PAGE

    recent_activities = RecentActivity.where("(ref_obj_type = ? AND ref_obj_id in (?)) OR (ref_obj_type = ? AND ref_obj_id in (?))", 
      CoachingGoal.to_s, [@coaching_goal.id], CoachingGoalActivity.to_s, @coaching_goal.coaching_goal_activities.pluck(:id)
    )
    @coaching_goal_activities = recent_activities.for_display.latest_first.fetch_with_offset(
      activities_per_page, @offset_id, {}
    ).to_a

    @new_offset_id = @offset_id + activities_per_page
  end

  def fetch_coaching_goal
    @coaching_goal = @group.coaching_goals.find(params[:id])
  end

  def skip_side_pane
    @skip_coaching_goals_side_pane = true
  end

end
