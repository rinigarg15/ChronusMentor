class DiversityReportsController < ApplicationController
  include GlobalReportsControllerCommon

  skip_before_action :require_program, :login_required_in_program
  before_action :set_diversity_report, only: [:show, :edit, :update, :destroy]

  allow exec: :can_access_global_reports?

  helper_method :selectable_profile_questions

  def show
    @start_date, @end_date = ReportsFilterService.get_report_date_range(params, ReportsFilterService.program_created_date(@current_organization))
  end

  def new
    @diversity_report = @current_organization.diversity_reports.new({
      admin_view: @current_organization.admin_views.find_by(default_view: AbstractView::DefaultType::ALL_MEMBERS),
      profile_question: selectable_profile_questions.first,
      comparison_type: DiversityReport::ComparisonType::TIME_PERIOD
    })
  end

  def edit
  end

  def create
    @diversity_report = @current_organization.diversity_reports.create!(diversity_report_params)
  end

  def update
    @diversity_report.update(diversity_report_params)
  end

  def destroy
    @diversity_report.destroy
  end

  def selectable_profile_questions
    @__selectable_profile_questions ||= @current_organization.profile_questions.select(&:with_question_choices?)
  end

  private

  def set_diversity_report
    @diversity_report = @current_organization.diversity_reports.find(params[:id])
  end

  def diversity_report_params
    params.require(:diversity_report).permit(:admin_view_id, :profile_question_id, :comparison_type, :name)
  end
end
