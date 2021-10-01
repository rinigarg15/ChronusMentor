class Report::AlertsController < ApplicationController

  include Report::SectionsControllerUtils

  allow user: :can_view_reports? # checks for user permission exist

  before_action :fetch_section_and_tile, except: [:get_options]
  before_action :fetch_metric, except: [:get_options]
  before_action :fetch_alert, only: [:edit, :update, :destroy]

  def new
    @alert = @metric.alerts.new
    render :partial => "new"
  end

  def create
    @alert = @metric.alerts.create!(alert_params(:create))
    @sections = current_program.report_sections
  end

  def edit
    render :partial => "edit"
  end

  def update
    @alert.update_attributes!(alert_params(:update))
    @sections = current_program.report_sections
  end

  def destroy
    @alert.destroy
    @sections = current_program.report_sections
  end

  def get_options
    @filter_name = params[:filter_name]
    @view = current_program.abstract_views.find(params[:view_id])
    @index = params[:index]
  end

  private

  def fetch_section_and_tile
    @section = current_program.report_sections.find(params[:section_id])
    @tile = @section.tile
  end

  def fetch_metric
    @metric = @section.metrics.find(params[:metric_id])
  end

  def fetch_alert
    @alert = current_program.report_alerts.find(params[:id])
  end

  def alert_params(action)
    alert_params = params.require(:report_alert).permit(Report::Alert::MASS_UPDATE_ATTRIBUTES[action])
    return alert_params if params[:report_alert][:filter_params].blank?

    alert_params.merge!(filter_params: permit_internal_attributes(params[:report_alert][:filter_params], [:name, :operator, :value]))
  end
end