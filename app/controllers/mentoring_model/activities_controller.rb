class MentoringModel::ActivitiesController < ApplicationController
  include ConnectionFilters
  include MentoringModelUtils

  before_action :fetch_group, :fetch_current_connection_membership

  allow :exec => :check_member_or_admin
  allow :exec => :check_action_access
  allow :exec => :has_permission_to_update_progress

  before_action :fetch_goal

  def new
    @goal_activity = @goal.goal_activities.new
    render :partial => "mentoring_model/goals/activities/new_mentoring_model_goal_activity_form"
  end

  def create
    progress_value = params[:progress_slider].present? ? params[:progress_slider].to_i : nil
    @goal_activity = @goal.goal_activities.new(progress_value: progress_value, connection_membership: @current_connection_membership, message: params[:mentoring_model_activity][:message])
    @goal_activity.member_id = @current_connection_membership.user.member_id
    @goal_activity.save!
    render "mentoring_model/goals/activities/create"
  end

  private

  def fetch_goal
    @goal = @group.mentoring_model_goals.find(params[:goal_id])
  end

  def has_permission_to_update_progress
    params[:progress_slider].present? ? current_user.can_update_goal_progress?(@group) : true
  end
end