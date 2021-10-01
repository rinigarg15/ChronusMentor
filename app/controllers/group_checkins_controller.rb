class GroupCheckinsController < ApplicationController
  include MentoringModelUtils

  before_action :fetch_group_and_task, except: :index
  before_action :set_report_category, only: :index
  allow exec: :checkin_access, except: [:show, :index]

  # Check permissions to view reports.
  allow :user => :can_view_reports? , only: [:index]

  module DateRangeOptions
    MONTH_TO_DATE = "month_to_date"
    CUSTOM = "custom"

    def self.presets
      [MONTH_TO_DATE]
    end
  end

  def create
    checkin = @task.checkins.new(checkin_params(:create))
    checkin.title = @task.title
    checkin.date = get_en_datetime_str(params[:group_checkin][:date])
    checkin.group = @group
    checkin.user = @current_user
    checkin.program = @current_program
    checkin.duration = calculate_duration
    checkin.save!

    @comments_and_checkins = @task.comments_and_checkins
    @new_checkin = @task.checkins.new
    @new_comment = @task.comments.new
  end

  def show
    @checkin = @task.checkins.find(params[:id])
    checkin_access
  end

  def index
    @skip_rounded_white_box_for_content = true
    process_date_formats(params)
    @presenter = GenericKendoPresenter.new(GroupCheckin, GenericKendoPresenterConfigs::CheckinGrid.get_config(GroupCheckin.where(program_id: @current_program.id)),params)
    checkin_durations = @presenter.filtered_scope.group(:checkin_ref_obj_type).sum(:duration)
    meeting_hours = checkin_durations[MemberMeeting.name] / 60.0 rescue 0
    task_hours = checkin_durations[MentoringModel::Task.name] / 60.0 rescue 0
    total_checkin_hours = meeting_hours + task_hours
    @task_checkin_details = {
      meetings: _Meetings,
      meetings_hours:  meeting_hours,
      task_hours: task_hours,
      total_hours: total_checkin_hours
    }
    @group_checkins = @presenter.list
    @total_count = @presenter.total_count
    respond_to do |format|
      format.html
      format.json
      format.csv {
        headers['Content-Disposition'] = "attachment; filename=Group_Stats.csv"
        headers['Content-Type'] ||= "application/octet-stream"
        headers['Pragma'] = "public"
        headers['Cache-Control'] = "private"
      }
    end
  end

  def destroy
    @checkin = @task.checkins.find(params[:id])
    @checkin.destroy
    @comments_and_checkins = @task.comments_and_checkins
  end

  def edit
    @checkin = @task.checkins.find(params[:id])
  end

  def update
    @checkin = @task.checkins.find(params[:id])
    new_parameters = checkin_params(:update)
    new_parameters = new_parameters.merge(duration: calculate_duration)
    @checkin.update_attributes(new_parameters)
    @checkin.save!
  end

  private

  def checkin_params(action)
    params[:group_checkin].present? ? params[:group_checkin].permit(GroupCheckin::MASS_UPDATE_ATTRIBUTES[action]) : {}
  end

  def calculate_duration
    hours = params[:group_checkin].delete(:hours)
    minutes = params[:group_checkin].delete(:minutes)
    hours.to_i * 60 + minutes.to_i
  end

  def fetch_group_and_task
    @group = @current_program.groups.find(params[:group_id])
    @task = @group.mentoring_model_tasks.find(params[:task_id])
  end

  def process_date_formats(params)
    if params[:filter].present? and (params[:filter] != "null") and params[:filter][:filters]
      params[:filter][:filters].each do |key, value|
        if value[:field] == "date"
          value[:start_date] = get_en_datetime_str(value[:start_date])
          value[:end_date] = get_en_datetime_str(value[:end_date])
        end
      end
    end
  end
end