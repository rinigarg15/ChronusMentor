class ProgressStatusesController < ApplicationController
  skip_before_action :login_required_in_program, :require_program
  before_action :login_required_in_organization

  def show
    progress_status = ProgressStatus.find(params[:id])
    render :json => [{:success => true, :percentage => progress_status.percentage, :completed => progress_status.completed?}].to_json
  end
end