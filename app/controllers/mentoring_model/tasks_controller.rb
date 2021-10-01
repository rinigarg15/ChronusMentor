class MentoringModel::TasksController < ApplicationController
  include ConnectionFilters
  include MentoringModelUtils

  before_action :fetch_group, :fetch_current_connection_membership
  # Admin or members allowed for index and show.
  allow :exec => :check_member_or_admin, :only => [:index, :show]

  # Only members allowed for actions other than index and show.
  allow :exec => :check_action_access, :except => [:index, :show, :fetch_section_tasks]

  allow :exec => :check_group_active, :except => [:index, :show, :fetch_section_tasks]
  
  before_action :prepare_template, :only => [:index]

  before_action :fetch_task, only: [:edit, :update, :destroy, :set_status, :update_positions, :edit_assignee_or_due_date, :update_assignee_or_due_date, :show]
  before_action :checkin_base_permission, only: [:create, :update, :fetch_section_tasks]
  before_action :fetch_goals, only: [:update_positions]
  before_action :compute_page_controls_allowed, :compute_surveys_controls_allowed
  before_action :set_view_mode
  before_action :set_target_user_and_type, only: [:new, :create, :update, :destroy, :update_positions, :fetch_section_tasks, :update_assignee_or_due_date]

  allow exec: :check_access, except: [:set_status, :setup_meeting]
  allow exec: :restrict_altering_of_tasks_from_template, only: [:edit, :update, :destroy]
  allow exec: :check_for_task_owner, only: [:set_status]
  allow exec: :can_create_mm_meetings?, only: [:setup_meeting]
  allow exec: :is_optional_task?, only: [:update_positions]
  allow exec: :alter_due_date_or_assignee?, only: [:edit_assignee_or_due_date, :update_assignee_or_due_date]
  allow :exec => :check_program_has_ongoing_mentoring_enabled

  def new
    goal_specific_task
    if params[:milestone_id].present?
      allow! exec: Proc.new{ manage_mm_milestones_at_admin_level?(@group) || manage_mm_milestones_at_end_user_level?  }
      @milestone = @group.mentoring_model_milestones.select(:id).find(params[:milestone_id])
    end
    @goals_to_associate ||= fetch_goals
    @task = @group.mentoring_model_tasks.new(
      status: MentoringModel::Task::Status::TODO,
      required: false,
      goal_id: @related_goal.try(:id),
      milestone_id: @milestone.try(:id)
    )
  end

  def create
    @created_tasks = handle_bulk_create(@group, mentoring_model_task_params(:create), current_user)
    track_activity_for_ei(EngagementIndex::Activity::CREATE_TASK)
    @task = @created_tasks.last
    MentoringModel::Task.update_positions(MentoringModel::Task.scoping_object(@task).mentoring_model_tasks, @task)
    @all_tasks = fetch_hashed_tasks
    fetch_associated_goal_and_tasks
  end

  def edit
    goal_specific_task
    @goals_to_associate ||= fetch_goals
  end

  def update
    task_params = mentoring_model_task_params(:update)
    assign_user_and_sanitization_version(@task)
    update_related_actions(task_params)
  end

  def edit_assignee_or_due_date
    goal_specific_task
    @unassigned = unassigned?
    @alter_due_date = alter_due_date?
  end

  def update_assignee_or_due_date
    task_params = update_assignee_or_due_date_attributes
    update_related_actions(task_params)
  end

  def destroy
    @task.destroy
    @all_tasks = get_all_mentoring_model_task_list_items(@group, {}, get_all_tasks)
    @all_tasks = fetch_hashed_tasks
    fetch_associated_goal_and_tasks
  end

  def set_status
    set_task_status!(params[:completed])
    fetch_associated_goal_and_tasks(nil, false)
    if manage_mm_milestones_at_admin_level?(@group) || manage_mm_milestones_at_end_user_level?
      @mentoring_model_milestones = @group.mentoring_model_milestones
    end
  end

  def setup_meeting
    @as_popup = params[:as_popup].present?
    @milestone_id = params[:milestone_id]
    @task_id_present = (params[:id].present? && (params[:id].to_i > 0))
    @task_id = params[:id] if @task_id_present
    @meeting_id = params[:meeting_id]
    @current_occurrence_time = params[:current_occurrence_time]
    @new_meeting = @meeting_id ? @group.meetings.find(@meeting_id.split("_").first) : @group.meetings.new
  end

  def fetch_section_tasks
    all_tasks = get_all_mentoring_model_task_list_items(@group, target_user: @target_user, target_user_type: @target_user_type)
    @zero_upcoming_tasks = false
    if params[:section_type] == MentoringModel::Task::Section::COMPLETE.to_s
      @section_tasks = MentoringModel::Task.get_complete_tasks(all_tasks)
    elsif params[:section_type] == MentoringModel::Task::Section::OVERDUE.to_s
      @section_tasks = MentoringModel::Task.get_overdue_tasks(all_tasks)
    elsif params[:section_type] == MentoringModel::Task::Section::UPCOMING.to_s
      @section_tasks = MentoringModel::Task.get_upcoming_tasks(all_tasks)
      @zero_upcoming_tasks = @section_tasks.blank?
    elsif params[:section_type] == MentoringModel::Task::Section::REMAINING.to_s
      @section_tasks = MentoringModel::Task.get_other_pending_tasks(all_tasks)
    end
    @section_type = params[:section_type]
    @list_id = params[:list_id]
    @empty_list_id = params[:empty_list_id]
  end

  def update_positions
    allow! :exec => lambda{ view_by_milestones? }
    ids_in_order = params[:mentoring_model_task].map(&:to_i)
    tasks = MentoringModel::Task.scoping_object(@task).mentoring_model_tasks.find(ids_in_order).index_by(&:id).slice(*ids_in_order).values
    MentoringModel::Task.transaction do
      tasks.each_with_index do |task, position|
        task.position = position
        task.skip_update_positions = true
        task.save!
      end
    end
    @all_tasks = get_all_mentoring_model_task_list_items(@group, {}, get_all_tasks)
    @all_tasks = fetch_hashed_tasks
    render action: :create
  end

  def show
    @comments_and_checkins = @task.comments_and_checkins
    @comment = @task.comments.new
    @checkin = @task.checkins.new
    @can_checkin_access = checkin_access
    @notify_checked = @group.members.count <= 2 if @group.active?
    @home_page_view = params[:home_page_view].to_s.to_boolean
  end

  private

  def handle_bulk_create(group, attributes, user)
    connection_membership_ids = get_connection_membership_ids_to_assign(attributes.delete(:connection_membership_id))
    created_tasks = []
    first_task = nil
    connection_membership_ids.each do |connection_membership_id|
      task = group.mentoring_model_tasks.new(attributes.merge(connection_membership_id: connection_membership_id))
      assign_user_and_sanitization_version(task)
      if first_task
        task.position = first_task.position
        task.skip_update_positions = true
      end
      task.save!
      first_task ||= task
      created_tasks << task
      task.connection_membership.send_email(task, RecentActivityConstants::Type::MENTORING_MODEL_TASK_CREATION, user) if task.user != user
    end
    created_tasks
  end

  def get_connection_membership_ids_to_assign(connection_membership_ids_key)
    if connection_membership_ids_key == MentoringModel::TasksHelper::FOR_ALL_USERS
      @group.memberships.pluck(:id)
    elsif connection_membership_ids_key.match(/#{MentoringModel::TasksHelper::FOR_ALL_ROLE_ID}/)
      role_id = connection_membership_ids_key.match(/#{MentoringModel::TasksHelper::FOR_ALL_ROLE_ID}(.*)/)[1]
      @group.memberships.where(role_id: role_id).pluck(:id)
    else
      [connection_membership_ids_key]
    end
  end

  def set_target_user_and_type
    get_target_user_for_v2(@group, params)
    update_target_user_type(@group, params)
  end

  def update_related_actions(task_params)
    existing_goal = @task.mentoring_model_goal
    @previous_goal = existing_goal if existing_goal.try(:id).to_s != task_params[:goal_id]
    @task.perform_delta = true
    @task.updated_from_connection = true if @task.from_template?
    @task.update_attributes!(task_params)
    @all_tasks = fetch_hashed_tasks
    fetch_associated_goal_and_tasks(@previous_goal)
    render action: :create
  end

  def fetch_hashed_tasks
    all_items = get_all_tasks
    if @from_milestone && view_by_milestones?
      @mentoring_model_milestones = @group.mentoring_model_milestones
      tasks_hash = {}
      @mentoring_model_milestones.each do |milestone|
        tasks_hash[milestone.id] = all_items.select{|task| task.milestone_id == milestone.id }
      end
      return tasks_hash
    else
      return get_all_mentoring_model_task_list_items(@group, {}, all_items)
    end
  end

  def fetch_associated_goal_and_tasks(previous_goal = nil, prepare_cache = true)
    if manage_mm_goals_at_admin_level?(@group) || manage_mm_goals_at_end_user_level?(@group)
      @associated_goal = @task.mentoring_model_goal
      @required_tasks = @associated_goal.present? ? @group.mentoring_model_tasks.required.where(goal_id: @associated_goal.id) : []
      @previous_required_tasks = previous_goal.present? ? @group.mentoring_model_tasks.required.where(goal_id: previous_goal.id) : []
      @goals_cache = @group.mentoring_model_goals.pluck(:id) if prepare_cache
    end
  end

  def goal_specific_task
    if params[:goal_id] && (manage_mm_goals_at_admin_level?(@group) || manage_mm_goals_at_end_user_level?)
      @related_goal = @group.mentoring_model_goals.select(:id).find(params[:goal_id])
      @goals_to_associate = []
      @goal_specific_task = true
    end
  end

  def is_optional_task?
    @task.optional?
  end

  def fetch_goal
    @goal ||= @group.mentoring_model_goals.find(params[:mentoring_model_task][:goal_id])
  end

  def fetch_goals
    mentoring_model = @group.get_mentoring_model
    @group.mentoring_model_goals.select(:id) if !mentoring_model.manual_progress_goals? && (manage_mm_goals_at_admin_level?(@group) || manage_mm_goals_at_end_user_level?)
  end

  def can_create_mm_meetings?
    manage_mm_meetings_at_end_user_level?(@group)
  end

  def check_for_task_owner
    @task.user.nil? || @task.user == current_user
  end

  def get_all_tasks
    if @from_milestone = (!params[:from_goals].present? && @task.milestone_id.present?)
      @group.get_tasks_list(task_eager_loadables, milestones_enabled: true, milestones: [@task.milestone], view_mode: @view_mode, target_user: @target_user, target_user_type: @target_user_type)
    else
      params[:from_goals].present? ? fetch_goal.mentoring_model_tasks.includes(task_eager_loadables) : @group.get_tasks_list(task_eager_loadables, view_mode: @view_mode, target_user: @target_user, target_user_type: @target_user_type)
    end
  end

  def fetch_task
    @task = @group.mentoring_model_tasks.find(params[:id])
  end

  def update_assignee_or_due_date_attributes
    task_params = mentoring_model_task_permitted_params(:update_assignee_or_due_date)
    if task_params[:required].eql?("false")
      task_params.merge!(due_date: nil)
    elsif task_params[:required].eql?("true") && alter_due_date?
      task_params.merge!(due_date: params[:mentoring_model_task][:due_date])
    end
    task_params.merge!(connection_membership_id: params[:mentoring_model_task][:connection_membership_id]) if unassigned? && params[:mentoring_model_task][:connection_membership_id].present?
    task_params
  end

  def mentoring_model_task_params(action)
    params[:mentoring_model_task][:due_date] = nil if params[:mentoring_model_task][:required].eql?("false")
    params[:mentoring_model_task][:due_date] = get_en_datetime_str(params[:mentoring_model_task][:due_date]) if params[:mentoring_model_task][:due_date].present?
    params[:mentoring_model_task][:title] = "feature.mentoring_model.label.default_connection_task_title".translate if params[:mentoring_model_task][:title].blank?
    if @task.present? && @task.from_template?
      mentoring_model_task_permitted_params(:from_template)
    elsif params[:mentoring_model_task][:due_date].present?
      mentoring_model_task_permitted_params(action).merge(due_date: Time.zone.parse(params[:mentoring_model_task][:due_date]))
    else
      mentoring_model_task_permitted_params(action).merge(due_date: nil, goal_id: nil)
    end
  end

  def mentoring_model_task_permitted_params(action)
    params.require(:mentoring_model_task).permit(MentoringModel::Task::MASS_UPDATE_ATTRIBUTES[action])
  end

  def check_access
    manage_mm_tasks_at_end_user_level?(@group)
  end

  def restrict_altering_of_tasks_from_template
    @task.user.nil? || !@task.from_template?
  end

  def unassigned?
    @task.unassigned_from_template?
  end

  def alter_due_date?
    @task.from_template? && allow_due_date_edit?(@task.group)
  end

  def alter_due_date_or_assignee?
    unassigned? || alter_due_date?
  end
end