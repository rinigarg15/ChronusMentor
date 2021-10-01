class EngagementIndexController < ApplicationController
  skip_before_action :require_program
  skip_before_action :login_required_in_program

  before_action :login_required_in_organization
  before_action :login_required_at_current_level

  def track_activity
    track_activity_for_ei(params[:activity], context_place: params[:src], context_object: params[:description])
    head :ok
  end
end