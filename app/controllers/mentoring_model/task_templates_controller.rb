class MentoringModel::TaskTemplatesController < ApplicationController
  include MentoringModelUtils

  before_action :set_bulk_dj_priority
  before_action :fetch_mentoring_model
  before_action :fetch_task_template, only: [:destroy, :edit, :update, :update_positions]
  before_action :fetch_templates_to_associate, only: [:new, :edit]
  before_action :handle_milestone_template_id, only: [:new, :create, :update]
  before_action :get_current_milestone_chronological_ordering, only: [:check_chronological_order_is_maintained]

  allow user: :is_admin?
  allow exec: :manage_mm_tasks_at_admin_level?
  allow exec: :is_optional_task?, only: [:update_positions]
  allow exec: :check_program_has_ongoing_mentoring_enabled

  def new
    @milestone_template = @mentoring_model.mentoring_model_milestone_templates.select(:id).find_by(id: @milestone_template_id)
    @task_template = @mentoring_model.mentoring_model_task_templates.new(duration: 7, milestone_template_id: @milestone_template.try(:id))
    @task_template.action_item_type = get_action_item_type
    @allowed_roles = get_allowed_roles
    @task_templates_to_associate = required_task_templates(@milestone_template)
    @task_template.associated_id = @task_templates_to_associate.last.try(:id)
    @task_template.action_item_id = params[:action_item_id].presence
    @action_items_to_associate = @task_template.get_action_item_list if manage_mm_engagement_surveys_at_admin_level?
    render_task_template_form
  end

  def create
    @task_template = @mentoring_model.mentoring_model_task_templates.new
    assign_user_and_sanitization_version(@task_template)
    run_skipping_increment_version_and_sync_trigger(@task_template) do
      @task_template.update_attributes!(mentoring_model_task_template_params(:create))
    end
    @all_task_templates = existing_task_templates(MentoringModel::TaskTemplate.scoping_object(@task_template))
    render "create", format: :js, :handlers => [:erb]
  end

  def edit
    @task_templates_to_associate = required_task_templates(@task_template.milestone_template) - [@task_template]
    @allowed_roles = get_allowed_roles
    @action_items_to_associate = @task_template.get_action_item_list if manage_mm_engagement_surveys_at_admin_level?
    render_task_template_form(edit_view: true)
  end

  def update
    assign_user_and_sanitization_version(@task_template)
    run_skipping_increment_version_and_sync_trigger(@task_template) do
      @task_template.update_attributes!(mentoring_model_task_template_params(:update))
    end
    @all_task_templates = fetch_appropriate_task_templates
    render "update", format: :js, :handlers => [:erb]
  end

  def destroy
    run_skipping_increment_version_and_sync_trigger(@task_template) do
      @task_template.destroy
    end
    @all_task_templates = fetch_appropriate_task_templates
  end

  def update_positions
    ids_in_order = params[:mentoring_model_task_template].map(&:to_i)
    task_templates = MentoringModel::TaskTemplate.scoping_object(@task_template).mentoring_model_task_templates.find(ids_in_order).index_by(&:id).slice(*ids_in_order).values
    index = task_templates.map(&:id).index(@task_template.id)
    task_templates[index].associated_id = task_templates[0...index].reverse.find(&:required).try(:id)
    fill_position_in_given_order_with_skip_observer_position_update(task_templates)
    @mentoring_model.increment_version_and_trigger_sync
    head :ok
  end

  def check_chronological_order_is_maintained
    show_warning = false

    if @should_check_milestone_order
      selected_params = mentoring_model_task_template_params(:create)
      due_date = get_new_task_template_due_date(@mentoring_model, selected_params)

      milestone_template = @mentoring_model.mentoring_model_milestone_templates.find_by(id: selected_params[:milestone_template_id])

      updated_first_and_last_required_task_in_milestones_list = get_updated_first_and_last_required_task_in_milestones_list(@current_first_and_last_required_task_in_milestones_list, milestone_template.position, due_date)

      show_warning = !validate_milestone_order(updated_first_and_last_required_task_in_milestones_list)
    end

    render :json => {:show_warning => show_warning}
  end

  private

  def run_skipping_increment_version_and_sync_trigger(task_template)
    task_template.skip_increment_version_and_sync_trigger = true
    yield
    task_template.mentoring_model.increment_version_and_trigger_sync
  end

  def handle_milestone_template_id
    @milestone_template_id = params[:milestone_template_id] || params[:mentoring_model_task_template].try(:[], :milestone_template_id)
    if @milestone_template_id.present? ^ manage_mm_milestones_at_admin_level?
      redirect_ajax mentoring_model_path(@mentoring_model)
    end
  end

  def fill_position_in_given_order_with_skip_observer_position_update(task_templates)
    task_templates.each_with_index do |task_template, position|
      task_template.position = position
      task_template.skip_due_date_computation = true
      task_template.skip_increment_version_and_sync_trigger = true
      task_template.save!
    end
  end

  def is_optional_task?
    @task_template.optional?
  end

  def fetch_task_template
    @task_template = @mentoring_model.mentoring_model_task_templates.find(params[:id])
  end

  def mentoring_model_task_template_params(action)
    # We need to check validity of params to safe-guard against false assignment.
    check_validity_of_params
    if (params[:mentoring_model_task_template][:date_assigner] == MentoringModel::TaskTemplate::DueDateType::SPECIFIC_DATE) && (params[:mentoring_model_task_template][:required] == "1")
      selected_params = mentoring_model_task_template_permitted_params(action)
      selected_params[:specific_date] = get_en_datetime_str(selected_params[:specific_date])
      selected_params[:duration] = 0
      selected_params[:associated_id] = nil
    else
      selected_params = mentoring_model_task_template_permitted_params(action)
      selected_params[:specific_date] = nil
    end
    unless selected_params[:title].present?
      selected_params[:title] = case selected_params[:action_item_type].try(:to_i)
      when MentoringModel::TaskTemplate::ActionItem::MEETING
        "feature.mentoring_model.label.default_meeting_title".translate
      when MentoringModel::TaskTemplate::ActionItem::GOAL
        "feature.mentoring_model.label.default_goal_title".translate
      when MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY
        @current_program.surveys.of_engagement_type.find_by(id: selected_params[:action_item_id]).try(:name)
      else
        "feature.mentoring_model.label.default_task_title_v1".translate
      end
    end
    selected_params[:required] = selected_params[:required].eql?('1')
    selected_params[:goal_template_id] = nil unless selected_params[:required]
    selected_params[:role_id] = nil if selected_params[:role_id].blank?
    if selected_params[:duration].present? && params[:duration_id_input].present?
      selected_params[:duration] = (params[:duration_id_input].to_i * selected_params[:duration].to_i).to_s
    end
    selected_params
  end

  def mentoring_model_task_template_permitted_params(action)
    params.require(:mentoring_model_task_template).permit(MentoringModel::TaskTemplate::MASS_UPDATE_ATTRIBUTES[action])
  end

  def check_validity_of_params
    @mentoring_model.mentoring_model_goal_templates.find(params[:mentoring_model_task_template][:goal_template_id]) if params[:mentoring_model_task_template][:goal_template_id].present?
    @mentoring_model.mentoring_model_milestone_templates.find(params[:mentoring_model_task_template][:milestone_template_id]) if params[:mentoring_model_task_template][:milestone_template_id].present?
    get_allowed_roles.find(params[:mentoring_model_task_template][:role_id]) if params[:mentoring_model_task_template][:role_id].present?
  end

  def required_task_templates(milestone_template)
    required_task_templates = @mentoring_model.mentoring_model_task_templates.non_specific_date_templates.select(:id, :milestone_template_id, :associated_id, :role_id).required.to_a
    if milestone_template.present?
      required_task_templates.reject!{|task_template| task_template.milestone_template_id > milestone_template.id}
    end
    MentoringModel::TaskTemplate.filter_sub_tasks(@task_template, required_task_templates)
  end

  def fetch_templates_to_associate
    @goal_templates_to_associate = @mentoring_model.mentoring_model_goal_templates if !@mentoring_model.manual_progress_goals? && manage_mm_goals_at_admin_level?
    @milestone_templates_to_associate = @mentoring_model.mentoring_model_milestone_templates if manage_mm_milestones_at_admin_level?
  end

  def existing_task_templates(object)
    get_task_and_facilitation_templates_merged_list(object)
  end

  def get_allowed_roles
    current_program.roles.for_mentoring
  end

  def render_task_template_form(local_params = {})
    render(partial: "mentoring_model/task_templates/task_template_progressive_form.html", locals: {
      task_template: @task_template,
      task_templates_to_associate: @task_templates_to_associate,
      goal_templates_to_associate: @goal_templates_to_associate,
      milestone_templates_to_associate: @milestone_templates_to_associate,
      action_items_to_associate: @action_items_to_associate,
      allowed_roles: @allowed_roles,
      as_ajax: true,
      edit_view: false
    }.merge(local_params), format: :js, layout: false)
  end

  def get_action_item_type
    if params[:setup_meeting]
      MentoringModel::TaskTemplate::ActionItem::MEETING
    elsif params[:create_goal]
      MentoringModel::TaskTemplate::ActionItem::GOAL
    elsif params[:new_survey]
      MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY
    else
      MentoringModel::TaskTemplate::ActionItem::DEFAULT
    end
  end

end
