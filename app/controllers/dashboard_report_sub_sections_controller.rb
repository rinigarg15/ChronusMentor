class DashboardReportSubSectionsController < ApplicationController
  allow user: :can_view_reports?

  before_action :set_tile, only: [:tile_settings, :update_tile_settings]

  def tile_settings
    @questions_data = current_program.get_positive_outcomes_questions_array(true) if @tile == DashboardReportSubSection::Tile::ENGAGEMENTS
    @date_range = params[:date_range]
    @date_range_preset = params[:date_range_preset]
  end

  def update_tile_settings
    enabled_reports = params[:dashboard_reports]||[]
    set_management_report_postive_outcomes_options
    current_program.get_reports_available_for_section(@tile).each do |report_type|
      sub_setting = params[:report_sub_settings][report_type].presence if params[:report_sub_settings].present?
      current_program.enable_dashboard_report!(report_type, enabled_reports.include?(report_type), sub_setting)
    end
    filters = params[:filters].permit!.to_h if params[:filters].present?
    redirect_to management_report_async_loading_path(remote: true, tile: @tile, filters: filters)
  end

  def scroll_survey_responses
    current_page_index = params[:next_page_index].to_i
    start_date, end_date = ReportsFilterService.get_report_date_range(params, ReportsController::ManagementReportConstants::DEFAULT_LIMIT.ago)
    start_time = start_date.beginning_of_day.in_time_zone(Time.zone)
    end_time = end_date.end_of_day.in_time_zone(Time.zone)
    date_range = start_time..end_time
    @survey_responses = current_program.get_engagements_survey_responses_data(date_range, current_page_index)[:survey_responses]
    @next_page_index = @survey_responses.next_page
  end

  private

  def set_tile
    @tile = params[:tile]
  end

  def set_management_report_postive_outcomes_options
    return unless params[:positive_outcomes_options_array].present?
    page_data = Hash[params[:positive_outcomes_options_array].values.map{|block| [block[:id].to_i, (block[:selected] || []).join(CommonQuestion::SEPERATOR)]}]

    current_program.update_positive_outcomes_options!(page_data, true)
  end
end