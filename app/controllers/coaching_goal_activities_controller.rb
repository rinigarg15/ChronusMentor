class CoachingGoalActivitiesController < ApplicationController
  include ConnectionFilters

  before_action :fetch_group, :fetch_current_connection_membership

  allow :exec => :check_member_or_admin

  allow :exec => :check_action_access

  allow :exec => :check_group_active

  before_action :compute_page_controls_allowed

  before_action :fetch_coaching_goal

  def new
    @is_show_page = (params[:is_show_page] == "true")
    @coaching_goal_activity = @coaching_goal.coaching_goal_activities.new
    render :partial => "coaching_goal_activities/new_coaching_goal_activity_form.html"
  end

  def create
    @from_coaching_goals_show = (params[:is_show_page] == "true")
    @is_message_post = params[:refresh_ra].present?
    progress_value = (@is_message_post ? nil : params[:progress_slider].to_i)
    @coaching_goal_activity = @coaching_goal.update_progress(@current_connection_membership, 
      progress_value, params[:coaching_goal_activity] && params[:coaching_goal_activity][:message].presence)
    @recent_activity = @coaching_goal_activity.recent_activities.last
    compute_coaching_goals_side_pane
  end

  private

  def fetch_coaching_goal
    @coaching_goal = @group.coaching_goals.find(params[:coaching_goal_id])
  end
end
