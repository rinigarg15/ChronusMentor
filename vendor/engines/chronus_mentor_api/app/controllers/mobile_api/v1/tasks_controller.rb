class MobileApi::V1::TasksController < MobileApi::V1::MentoringAreaController
  include MentoringModelUtils
  before_action :prohibit_writes, only: [:new, :create, :edit, :update, :edit_due_date_assignee, :update_due_date_assignee, :destroy, :set_status]
  before_action :set_can_show_tasks, :set_connection_membership
  before_action :fetch_task, only: [:show, :edit, :update, :destroy, :set_status, :edit_due_date_assignee, :update_due_date_assignee]
  before_action :can_create_edit, only: [:new, :create, :edit, :update, :destroy]
  before_action :can_change_template_task, only: [:update_due_date_assignee, :edit_due_date_assignee]

  def index
    @tasks = @group.mentoring_model_tasks.includes({connection_membership: {user: {member: :profile_picture}}}, :comments)
    @goals, @milestones = associated_goals_and_milestones
    render_success("tasks/index")
  end

  def show
    @comments = @task.comments.includes(:sender)
    render_success("tasks/show")
  end

  def new
    @connection_memberships = @group.memberships.includes(user: :member)
    @goals, @milestones = associated_goals_and_milestones
    render_success("tasks/new")
  end

  def create
    @task = @group.mentoring_model_tasks.create!(
      mentoring_model_task_params.merge(
        status: MentoringModel::Task::Status::TODO,
        from_template: false
      )
    )
    render_success("tasks/create")
  end

  def edit
    perform_edit_actions
  end

  def update
    @task.update_attributes!(mentoring_model_task_params)
    render_success("tasks/update")
  end

  def edit_due_date_assignee
    perform_edit_actions
  end

  def update_due_date_assignee
    update_params = []
    update_params << :due_date if allow_due_date_edit?(@group)
    update_params << :connection_membership_id if @task.unassigned_from_template?
    @task.update_attributes!(params.slice(*update_params))
    render_success("tasks/update")
  end

  def destroy
    @task.destroy
    render_success("tasks/destroy")
  end

  def set_status
    set_task_status!(params[:completed])
    @tasks = @group.mentoring_model_tasks.includes({connection_membership: :user}, :comments)
    @comments = @task.comments.includes(:sender)
    params[:source] == "show" ? render_success("tasks/show") : render_success("tasks/index")
  end

  private

  def perform_edit_actions
    @goals, @milestones = associated_goals_and_milestones
    @connection_memberships = @group.memberships.includes(user: :member)
    render_success("tasks/edit")
  end

  def mentoring_model_task_params
    unless params.has_key?(:goal_id)
      params[:goal_id] = nil # This will set goal-id of task to nil
    end

    if params[:required].to_s != "true"
      params[:due_date] = nil 
      params[:goal_id] = nil
    end
    params[:title] = "feature.mentoring_model.label.default_connection_task_title".translate if params[:title].blank?
    params[:action_item_type] = MentoringModel::TaskTemplate::ActionItem::DEFAULT if params[:action_item_type].blank?
    params[:connection_membership_id] = @connection_membership.id if params[:connection_membership_id].blank?
    params.to_h.pick(:connection_membership_id, :required, :title, :description, :due_date, :action_item_type, :milestone_id, :goal_id)
  end

  def can_change_template_task
    unless @task.from_template? && @group.can_manage_mm_tasks?([@connection_membership.role]) && (@task.unassigned_from_template? || allow_due_date_edit?(@group))
      render_errors({cannot_modify_template_tasks: true}, 403)
    end
  end

  def can_create_edit
    unless @group.can_manage_mm_tasks?([@connection_membership.role]) && (!@task || !@task.from_template?)
      render_errors({cannot_modify_tasks: true}, 403)
    end
  end

  def set_can_show_tasks
    unless current_program.mentoring_connections_v2_enabled? && @group.can_manage_mm_tasks?(@group.membership_roles)
      render_errors({can_show_tasks: false}, 403)
    end
  end

  def fetch_task
    @task = @group.mentoring_model_tasks.find(params[:id])
  end

  def associated_goals_and_milestones
    goals = []
    milestones = []
    mentoring_model_roles = current_program.roles.for_mentoring_models
    goals = @group.mentoring_model_goals if @group.can_manage_mm_goals?(mentoring_model_roles)
    milestones = @group.mentoring_model_milestones if @group.can_manage_mm_milestones?(mentoring_model_roles)
    [goals, milestones]
  end
end