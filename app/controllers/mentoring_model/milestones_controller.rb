class MentoringModel::MilestonesController < ApplicationController
  include ConnectionFilters
  include MentoringModelUtils

  before_action :fetch_group, :fetch_current_connection_membership
  before_action :set_target_user_and_type
  before_action :checkin_base_permission, only: [:fetch_tasks]
  allow exec: :check_action_access, except: [:fetch_completed_milestones, :fetch_tasks]
  allow exec: :check_group_active, except: [:fetch_completed_milestones, :fetch_tasks]
  allow exec: :manage_mm_milestones_at_end_user_level?, except: [:fetch_completed_milestones, :fetch_tasks]
  before_action :fetch_milestone, except: [:new, :create, :fetch_completed_milestones]
  allow exec: :restrict_from_template, except: [:new, :create, :fetch_completed_milestones, :fetch_tasks]

  before_action :compute_page_controls_allowed
  before_action :compute_surveys_controls_allowed, only: [:fetch_tasks]
  before_action :set_view_mode
  allow :exec => :check_program_has_ongoing_mentoring_enabled, except: [:fetch_completed_milestones, :fetch_tasks]

  def new
    @milestone = @group.mentoring_model_milestones.new
  end

  def create
    position = @group.get_position_for_new_milestone
    params[:mentoring_model_milestone].merge!(position: position)

    @milestone = @group.mentoring_model_milestones.create!(mentoring_model_milestone_params(:create))
    track_activity_for_ei(EngagementIndex::Activity::CREATE_MILESTONE)
    render "create.js.erb"
  end

  def edit
  end

  def update
    @milestone.update_attributes!(mentoring_model_milestone_params(:update))
    @completed = @group.mentoring_model_milestones.completed.pluck(:id).include?(@milestone.id)
    render "update.js.erb"
  end

  def destroy
    @milestone.destroy
  end

  def fetch_tasks
    @home_page_view = params[:home_page_view].to_s.to_boolean
    mentoring_plan_objects = @group.get_tasks_list(task_eager_loadables, milestones_enabled: true, milestones: @group.mentoring_model_milestones, view_mode: @view_mode, target_user: @target_user, target_user_type: @target_user_type, home_page_view: @home_page_view)

    @mentoring_model_tasks = {}
    @mentoring_model_tasks[@milestone.id] = mentoring_plan_objects.select{|plan_object| plan_object.milestone_id == @milestone.id}
    @milestone_link_id = params[:milestone_link_id]
  end

  def fetch_completed_milestones
    @completed_milestones_link_id = params[:completed_milestones_link_id]
    @completed_mentoring_model_milestones = @group.mentoring_model_milestones.where(:id => params[:completed_mentoring_model_milestone_ids])
    @mentoring_model_milestone_ids_to_expand = @completed_mentoring_model_milestones.with_incomplete_optional_tasks.pluck(:id)
  end

  private

  def set_target_user_and_type
    get_target_user_for_v2(@group, params)
    update_target_user_type(@group, params)
  end

  def mentoring_model_milestone_params(action)
    params.require(:mentoring_model_milestone).permit(MentoringModel::Milestone::MASS_UPDATE_ATTRIBUTES[action])
  end

  def restrict_from_template
    !@milestone.from_template?
  end

  def fetch_milestone
    @milestone = @group.mentoring_model_milestones.find(params[:id])
  end
end