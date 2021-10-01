class Report::MetricsController < ApplicationController
  include Report::SectionsControllerUtils

  allow user: :can_view_reports? # checks for user permission exist

  before_action :fetch_sections
  before_action :get_section_and_tile, only: [:new, :create, :edit, :update, :destroy]
  before_action :get_metric, only: [:edit, :update, :destroy]
  before_action :set_available_abstract_views, except: [:destroy]

  def new
    @metric = @section.metrics.new
    render :partial => "new"
  end

  def create
    position = @section.metrics.maximum(:position).to_i + 1
    @metric = @section.metrics.new(metric_params(:create).merge(position: position))
    @metric.save!
  end

  def edit
    render :partial => "edit"
  end

  def update
    @metric.update_attributes(metric_params(:update))
  end

  def destroy
    @metric.destroy
  end

  private

  def fetch_sections
    @sections = current_program.report_sections
    @sections = @sections.non_ongoing_mentoring_related if !current_program.ongoing_mentoring_enabled?
  end

  def get_section_and_tile
    @section = @sections.find(params[:section_id])
    @tile = @section.tile
  end

  def get_metric
    @metric = @section.metrics.find(params[:id])
  end

  def set_available_abstract_views
    available_view_for_edit = current_program.abstract_views.without_metrics
    available_view_for_edit = available_view_for_edit.without_ongoing_mentoring_style unless check_program_has_ongoing_mentoring_enabled
    available_view_for_edit = available_view_for_edit.to_a
    available_view_for_edit << @metric.abstract_view if @metric && @metric.abstract_view_id.present?
    hsh = available_view_for_edit.group_by(&:class)
    @subview_optgroups = hsh.keys.sort_by {|view| AbstractView::DefaultOrder::WEIGHTS["#{view}"]}

    subview_to_remove = []
    @subview_optgroups.each do |klass|
      if klass.respond_to?(:is_accessible?) ? klass.is_accessible?(program) : true
        klass.sub_view_display_name = "feature.reports.label.optgroup_label_#{klass.name.underscore}".translate(:Mentoring_Connection => _Mentoring_Connection, :Meeting => _Meeting,  :Program => _Program, :Mentor => _Mentor)
        klass.available_sub_views_for_current_program = hsh[klass]
      else
        subview_to_remove << klass
      end
    end
    @subview_optgroups -= subview_to_remove 
  end

  def metric_params(action)
    params.require(:report_metric).permit(Report::Metric::MASS_UPDATE_ATTRIBUTES[action])
  end
end