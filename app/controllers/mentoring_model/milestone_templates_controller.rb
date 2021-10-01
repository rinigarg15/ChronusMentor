class MentoringModel::MilestoneTemplatesController < ApplicationController
  include MentoringModelUtils
  
  before_action :fetch_mentoring_model
  allow exec: :manage_mm_milestones_at_admin_level?

  before_action :find_milestone_template, :except => [:new, :create, :reorder_milestones, :validate_milestones_order]
  allow :exec => :check_program_has_ongoing_mentoring_enabled

  before_action :get_current_milestone_chronological_ordering, only: [:validate_milestones_order]

  def new
    @milestone_template = @mentoring_model.mentoring_model_milestone_templates.new
  end

  def create
    position = get_position_for_new_milestone(params[:insert_milestone_after], params[:milestone_position])
    params[:mentoring_model_milestone_template].merge!(position: position)
    @mentoring_model.increment_positions_for_milestone_templates_with_or_after_position(position)

    @milestone_template = @mentoring_model.mentoring_model_milestone_templates.create!(mentoring_model_milestone_template_params(:create))

    @previous_position_template_id, @next_position_template_id = @mentoring_model.get_previous_and_next_position_milestone_template_ids(@milestone_template.id) if @mentoring_model.reload.mentoring_model_milestone_templates.size > 1
  end

  def edit
  end

  def update
    @milestone_template.update_attributes!(mentoring_model_milestone_template_params(:update))
    @milestone_task_templates = fetch_appropriate_task_templates(@milestone_template)
  end

  def destroy
    @milestone_template.destroy
    @all_task_templates = fetch_appropriate_task_templates
  end

  def validate_milestones_order
    show_warning = false

    if @should_check_milestone_order
      new_position_by_milestone_id_hash = get_position_by_milestone_id_hash

      updated_first_and_last_required_task_in_milestones_list = get_updated_first_and_last_required_task_in_milestones_list_after_milestone_reordering(@current_first_and_last_required_task_in_milestones_list, new_position_by_milestone_id_hash)

      show_warning = !validate_milestone_order(updated_first_and_last_required_task_in_milestones_list)
    end

    render :json => {:show_warning => show_warning, :ongoing_connections_present => (@mentoring_model.active_groups.size > 0)}
  end

  def reorder_milestones
    new_position_by_milestone_id_hash = get_position_by_milestone_id_hash

    @mentoring_model.mentoring_model_milestone_templates.each do |milestone_template|
      milestone_template.position = new_position_by_milestone_id_hash[milestone_template.id]
      milestone_template.skip_increment_version_and_sync_trigger = true
      milestone_template.save
    end

    @mentoring_model.increment_version_and_trigger_sync

    head :ok
  end

  private

  def get_position_by_milestone_id_hash
    new_milestone_order = params[:new_milestone_order]
    new_position_by_milestone_id_hash = {}
    new_milestone_order.each_with_index do |milestone_id, index|
      new_position_by_milestone_id_hash[milestone_id.to_i] = index
    end
    return new_position_by_milestone_id_hash
  end

  def get_position_for_new_milestone(insert_milestone_after, milestone_position)
    if (insert_milestone_after.blank? && milestone_position.blank?) || (milestone_position.to_i == MentoringModelsHelper::MilestonePosition::AS_FIRST_MILESTONE)
      return MentoringModel::MilestoneTemplate::POSITION_FOR_FIRST_MILESTONE
    else
      return insert_milestone_after.to_i + 1
    end
  end

  def mentoring_model_milestone_template_params(action)
    params.require(:mentoring_model_milestone_template).permit(MentoringModel::MilestoneTemplate::MASS_UPDATE_ATTRIBUTES[action])
  end

  def find_milestone_template
    @milestone_template = @mentoring_model.mentoring_model_milestone_templates.find(params[:id])
  end

end