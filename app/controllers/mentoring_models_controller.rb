class MentoringModelsController < ApplicationController
  include MentoringModelUtils
  include ConnectionFilters::CommonInclusions

  before_action :require_super_user, only: [
    :create_template_objects, :setup, :upload_from_templates,
    :new, :create, :apply
  ]
  before_action :setup_mentoring_model, only: [
    :destroy, :show, :create_template_objects, :upload_from_templates, :setup,
    :make_default, :export_csv, :view, :update_duration, :duplicate_new, :duplicate_create,
    :edit, :update, :apply
  ]
  before_action :initialize_back_link, only: [:setup, :show, :new, :edit]
  before_action :mentoring_model_set_should_sync_warn, only: [:edit, :show]
  before_action :create_dummy_group_and_assing_mm, only: [:preview]
  before_action :fetch_group, :only => [:fetch_tasks], unless: :is_preview?
  before_action :render_edit_mentoring_model , only: [:setup, :show], if: :is_hybrid_mentoring_model?

  allow :user => :is_admin?, :except => [:fetch_tasks]
  allow :exec => :check_program_has_ongoing_mentoring_enabled
  allow :exec => :check_access_to_show_tasks_in_preview, :only => [:fetch_tasks]
  allow :exec => :can_view_ongoing_mentoring_related_page?, :only => [:fetch_tasks]

  def index
    @mentoring_models = current_program.mentoring_models.includes(:object_role_permissions)
    @object_permissions = ObjectPermission.where(name: ObjectPermission::MentoringModel::PERMISSIONS)
    @default_roles = current_program.roles.for_mentoring_models.select([:name, :id, :for_mentoring])
  end

  def new
    @mentoring_model_titles = current_program.mentoring_models.select([:id]).collect(&:title).collect(&:downcase)
    @mentoring_model = current_program.mentoring_models.new(mentoring_period: Program::DEFAULT_MENTORING_PERIOD)
    @mentoring_model.mentoring_model_type = MentoringModel::Type::HYBRID if params[:hybrid] && current_program.hybrid_templates_enabled?
  end

  def create
    @mentoring_model = current_program.mentoring_models.new(mentoring_model_permitted_params(:create).merge(default: false))
    set_mentoring_model_mentoring_period!
    @mentoring_model.save!
    update_children_permission_and_progress_type if @mentoring_model.hybrid?
    redirect_to_appropriate_edit_url
  end

  def edit
    render_edit_mentoring_model
  end

  def update
    @mentoring_model.hybrid? ? update_hybrid_model : update_base_model
  end

  def view
    @back_link = {
      label: "feature.multiple_templates.header.multiple_templates_title_v1".translate(Mentoring_Connection: _Mentoring_Connection),
      link: mentoring_models_path
    } if params[:from_mentoring_models].present?
    @read_only = true
    @no_wizard_view = true
    instantiate_template_data
  end

  def show
    instantiate_template_data
  end

  def create_template_objects
    @mentoring_model.update_attributes(mentoring_model_permitted_params(:create_template_objects))
    unless @mentoring_model.valid?
      flash[:error] = @mentoring_model.errors.full_messages.to_sentence.presence
      redirect_to setup_mentoring_model_path(@mentoring_model) and return
    end

    if @mentoring_model.can_update_features?
      admin_permissions = params[:permissions][:admin]
      users_permissions = params[:permissions][:users]

      goal_progress_type = params[:permissions].delete(:goal_progress_type).to_i
      @mentoring_model.update_attributes!(goal_progress_type: goal_progress_type) if admin_permissions[ObjectPermission::MentoringModel::GOAL].to_i == 1

      hold_milestones_permission_at_admin_level = manage_mm_milestones_at_admin_level?
      hold_goals_permission_at_admin_level = manage_mm_goals_at_admin_level?
      hold_tasks_permission_at_admin_level = manage_mm_tasks_at_admin_level?
      hold_messages_permission_at_admin_level = manage_mm_messages_at_admin_level?
      hold_meetings_permission_at_user_level = manage_mm_meetings_at_end_user_level?(@mentoring_model)
      hold_engagement_surveys_permission_at_admin_level = manage_mm_engagement_surveys_at_admin_level?

      ActiveRecord::Base.transaction do
        ObjectPermission::MentoringModel::PERMISSIONS.each do |permission|
          @mentoring_model.send("#{admin_permissions[permission].to_i == 1 ? 'allow' : 'deny'}_#{permission}!", get_roles_from_hash(:admin))
          @mentoring_model.send("#{users_permissions[permission].to_i == 1 ? 'allow' : 'deny'}_#{permission}!", get_roles_from_hash(:users))
        end

        @mentoring_model.mentoring_model_milestone_templates.destroy_all if hold_milestones_permission_at_admin_level && (admin_permissions[ObjectPermission::MentoringModel::MILESTONE].to_i == 0)
        @mentoring_model.mentoring_model_goal_templates.destroy_all if hold_goals_permission_at_admin_level && (admin_permissions[ObjectPermission::MentoringModel::GOAL].to_i == 0)
        @mentoring_model.mentoring_model_facilitation_templates.destroy_all if hold_messages_permission_at_admin_level && (admin_permissions[ObjectPermission::MentoringModel::FACILITATION_MESSAGE].to_i == 0)
        @mentoring_model.mentoring_model_task_templates.destroy_all if hold_tasks_permission_at_admin_level && (admin_permissions[ObjectPermission::MentoringModel::TASK].to_i == 0)
        build_default_milestone if !hold_milestones_permission_at_admin_level && (admin_permissions[ObjectPermission::MentoringModel::MILESTONE].to_i == 1)
        transform_meeting_templates if hold_meetings_permission_at_user_level &&(users_permissions[ObjectPermission::MentoringModel::MEETING].to_i == 0)
        @mentoring_model.mentoring_model_task_templates.of_engagement_survey_type.destroy_all if hold_engagement_surveys_permission_at_admin_level && (admin_permissions[ObjectPermission::MentoringModel::ENGAGEMENT_SURVEY].to_i == 0)
      end
    end
    redirect_to(params[:set_up_and_continue_later].present? ? mentoring_models_path : mentoring_model_path(@mentoring_model))
  end

  def setup
    @open_upload_form = params[:uploaded_successfully] == "false"
    @admin_hash = {}
    @users_hash = {}

    ObjectPermission::MentoringModel::ADMIN_PERMISSIONS.each do |permission|
      @admin_hash[permission] = @mentoring_model.send("can_#{permission}?", get_roles_from_hash(:admin))
    end
    ObjectPermission::MentoringModel::OTHER_USER_PERMISSIONS.each do |permission|
      @users_hash[permission] = @mentoring_model.send("can_#{permission}?", get_roles_from_hash(:users))
    end

    @mentoring_model_data_entities = {
      ObjectPermission::MentoringModel::MILESTONE => @mentoring_model.mentoring_model_milestone_templates.count,
      ObjectPermission::MentoringModel::GOAL => @mentoring_model.mentoring_model_goal_templates.count,
      ObjectPermission::MentoringModel::TASK => @mentoring_model.mentoring_model_task_templates.count,
      ObjectPermission::MentoringModel::FACILITATION_MESSAGE => @mentoring_model.mentoring_model_facilitation_templates.count,
      ObjectPermission::MentoringModel::MEETING => @mentoring_model.mentoring_model_task_templates.where(action_item_type: MentoringModel::TaskTemplate::ActionItem::MEETING).count,
      ObjectPermission::MentoringModel::ENGAGEMENT_SURVEY => @mentoring_model.mentoring_model_task_templates.of_engagement_survey_type.count
    }
  end

  def upload_from_templates
    allow! exec: -> { @mentoring_model.can_update_features? }
    stream = params[:mentoring_model] && params[:mentoring_model][:template]
    succeeded = stream.present? && (importer = MentoringModel::Importer.new(@mentoring_model, File.read(stream.path, encoding: UTF8_BOM_ENCODING))).import.successful?
    flash[succeeded ? :notice : :error] = succeeded ? "flash_message.mentoring_model.csv_upload_successfully_v2".translate(:mentoring_connection => _mentoring_connection) : stream.present? ? "flash_message.mentoring_model.csv_upload_failed_v2".translate(message: importer.error_message_key.translate, mentoring_connection: _mentoring_connection) : "feature.mentoring_model.description.error_file_absent".translate
    redirect_to setup_mentoring_model_path(@mentoring_model, uploaded_successfully: succeeded)
  end

  def make_default
    default_mentoring_model = current_program.default_mentoring_model
    MentoringModel.transaction do
      default_mentoring_model.update_attributes!(default: false)
      @mentoring_model.reload.update_attributes!(default: true)
    end
    render json: {mentoring_model_id: default_mentoring_model.id, mentoring_model_title: h(default_mentoring_model.title)}
  end

  def destroy
    allow! exec: Proc.new{ !@mentoring_model.default? && !@mentoring_model.active_groups.exists? }
    drafted_groups_count = @mentoring_model.groups.drafted.count
    default_mentoring_model = current_program.default_mentoring_model
    # The drafted connections which have the mentoring model/template applied will be reverted to the default template
    # The code/logic for this is in the before_destroy callback in mentoring_model.rb
    @mentoring_model.destroy
    if params[:from_view].present?
      flash[:notice] = "flash_message.mentoring_model.deleted_v1".translate(Mentoring_Connection: _Mentoring_Connection)
      render json: {redirect_url: mentoring_models_path, from_view: true}
    else
      render json: {
        drafted_groups_text: "#{default_mentoring_model.groups.drafted.count} #{"feature.multiple_templates.labels.draft_mentoring_connections_html".translate}".html_safe,
        mentoring_model_id: default_mentoring_model.id,
        from_view: false
      }
    end
  end

  def export_csv
    csv_file_name = "feature.mentoring_model.label.csv_export_report_name".translate(title: @mentoring_model.title.to_html_id, date: DateTime.localize(Time.current, format: :csv_timestamp))
    send_csv MentoringModel::Exporter.new.export(@mentoring_model, nil),
      :disposition => "attachment; filename=#{csv_file_name}.csv"
  end

  def update_duration
    allow! exec: -> { @mentoring_model.can_update_duration? }
    mentoring_model_params = params[:mentoring_model]
    @mentoring_model.set_mentoring_period(
      mentoring_model_params[:mentoring_period_unit], mentoring_model_params[:mentoring_period_value]
    )
    @mentoring_model.save!
  end

  # The below actions, duplicate_new and duplicate_create, are actually there to build the duplicate templates feature.
  # These should not be mistaken to be the "duplicate" actions of the new/create :)
  def duplicate_new
    @mentoring_model_titles = current_program.mentoring_models.select([:id]).collect(&:title).collect(&:downcase)
  end

  def duplicate_create
    mentoring_model_cloner = MentoringModel::Cloner.new(@mentoring_model, params[:mentoring_model][:title])
    @new_mentoring_model = mentoring_model_cloner.clone_objects!
    redirect_to edit_mentoring_model_path(@new_mentoring_model)
  end

  def preview
    @mentoring_model = @group.mentoring_model
    @milestones = @group.mentoring_model.mentoring_model_milestone_templates
    @mentoring_model_tasks = compute_actual_date_and_sort_by_due_date(MentoringModel::TaskTemplate.compute_due_dates(@group.mentoring_model.mentoring_model_task_templates))
  end

  def fetch_tasks
    allow! :exec => lambda{@group.pending?} unless is_preview?
    if is_preview?
      mentoring_model = current_program.mentoring_models.find(params[:id])
      @preview_mentoring_template = true 
      @preview_role_id = params["role"].to_i
    end
    mentoring_model ||= @current_program.groups.find(params[:group_id]).mentoring_model
    @milestone = mentoring_model.mentoring_model_milestone_templates.find(params[:milestone_template_id])
    @milestone_items = if is_preview?
      compute_actual_date_and_sort_by_due_date(MentoringModel::TaskTemplate.compute_due_dates(mentoring_model.mentoring_model_task_templates)).select{|task| task.milestone_template_id == @milestone.id}
    else
      @milestone.mentoring_model_task_templates
    end
  end

  private

  def mentoring_model_permitted_params(action)
    params.require(:mentoring_model).permit(MentoringModel::MASS_UPDATE_ATTRIBUTES[action])
  end

  def set_mentoring_model_mentoring_period!
    if params[:mentoring_model][:mentoring_period_unit] && params[:mentoring_model][:mentoring_period_value]
      @mentoring_model.set_mentoring_period(params[:mentoring_model][:mentoring_period_unit], params[:mentoring_model][:mentoring_period_value])
    else
      @mentoring_model.mentoring_period = Program::DEFAULT_MENTORING_PERIOD
    end
  end

  def update_base_model
    @mentoring_model.update_attributes!(mentoring_model_permitted_params(:update))
    redirect_to_appropriate_edit_url
  end

  def update_hybrid_model
    @mentoring_model.update_attributes!(mentoring_model_permitted_params(:update))
    @mentoring_model.set_mentoring_period(params[:mentoring_model][:mentoring_period_unit], params[:mentoring_model][:mentoring_period_value]) if params[:mentoring_model][:mentoring_period_unit] && params[:mentoring_model][:mentoring_period_value]
    update_children_permission_and_progress_type if @mentoring_model.save!
    redirect_to_appropriate_edit_url
  end

  def update_children_permission_and_progress_type
    @mentoring_model.child_ids = params[:mentoring_model][:child_ids].uniq if params[:mentoring_model][:child_ids]
    @mentoring_model.update_permissions!
    @mentoring_model.update_attribute(:goal_progress_type, @mentoring_model.children.first.goal_progress_type)
  end

  def mentoring_model_set_should_sync_warn
    set_should_sync_warn(@mentoring_model)
  end

  def render_edit_mentoring_model
    @mentoring_model_titles = current_program.mentoring_models.where.not(id: @mentoring_model.id).select([:id]).collect(&:title).collect(&:downcase)
    render action: :new and return
  end

  def redirect_to_appropriate_edit_url
    redirect_url =
      if @mentoring_model.hybrid?
        view_mentoring_model_path(@mentoring_model, from_mentoring_models: true)
      elsif params[:set_up_and_continue_later].present?
        mentoring_models_path
      elsif super_console?
        setup_mentoring_model_path(@mentoring_model)
      else
        mentoring_model_path(@mentoring_model)
      end
    redirect_to redirect_url
  end

  def setup_mentoring_model
    @mentoring_model = current_program.mentoring_models.find(params[:id])
    @should_sync_warn = ((@mentoring_model.should_sync || false) && (@mentoring_model.has_ongoing_related_connections?))
    @ongoing_connections_count = current_program.groups.where(id: @mentoring_model.all_associated_group_ids).active.count
    @connections_getting_reordered_count = @mentoring_model.active_groups.size
  end

  def instantiate_milestone_template_data
    @mentoring_model_milestone_templates = @mentoring_model.mentoring_model_milestone_templates
  end

  def instantiate_goal_template_data
    @all_goal_templates = @mentoring_model.mentoring_model_goal_templates
  end

  def instantiate_task_template_data
    @mentoring_model_task_templates = get_task_and_facilitation_templates_merged_list(@mentoring_model)
  end

  def get_roles_from_hash(user)
    @roles_hash ||= current_program.roles.select([:id, :name, :for_mentoring]).for_mentoring_models.group_by(&:name)
    @admin_role ||= @roles_hash[RoleConstants::ADMIN_NAME].first
    @other_roles ||= @roles_hash.values.flatten.select{|role| role.for_mentoring? }
    user == :admin ? @admin_role : @other_roles
  end

  def build_default_milestone
    task_templates_without_associated_milestone = @mentoring_model.mentoring_model_task_templates.where(milestone_template_id: nil)
    facilitation_templates_without_associated_milestone = @mentoring_model.mentoring_model_facilitation_templates.where(milestone_template_id: nil)
    if task_templates_without_associated_milestone.present? || facilitation_templates_without_associated_milestone.present?
      default_milestone_template = @mentoring_model.mentoring_model_milestone_templates.create!(title: "feature.mentoring_model.label.default_milestone".translate, position: MentoringModel::MilestoneTemplate::POSITION_FOR_FIRST_MILESTONE)
      task_templates_without_associated_milestone.each do |task_template|
        task_template.update_attributes!(milestone_template_id: default_milestone_template.id)
      end
      facilitation_templates_without_associated_milestone.each do |facilitation_template|
        facilitation_template.update_attributes!(milestone_template_id: default_milestone_template.id)
      end
    end
  end

  def transform_meeting_templates
    @mentoring_model.mentoring_model_task_templates.where(action_item_type: MentoringModel::TaskTemplate::ActionItem::MEETING).update_all(action_item_type: MentoringModel::TaskTemplate::ActionItem::DEFAULT)
  end

  def instantiate_template_data
    instantiate_goal_template_data if manage_mm_goals_at_admin_level?

    if manage_mm_milestones_at_admin_level?
      instantiate_milestone_template_data
      @mentoring_model_task_templates = ActiveSupport::OrderedHash.new
      get_task_and_facilitation_templates_merged_list(@mentoring_model).each do |task_template|
        (@mentoring_model_task_templates[task_template.milestone_template_id] ||= []) << task_template
      end
    elsif manage_mm_tasks_at_admin_level? || manage_mm_messages_at_admin_level?
      instantiate_task_template_data
    end
  end

  def initialize_back_link
    @back_link = {
      label: "feature.multiple_templates.header.multiple_templates_title_v1".translate(Mentoring_Connection: _Mentoring_Connection),
      link: mentoring_models_path
    }
  end

  def create_dummy_group_and_assing_mm
    # don't assign program, mentor or mentee for this group as it shouldn't be saved in db
    mentoring_model = current_program.mentoring_models.find(params[:id])
    @group = Group.new(mentoring_model: mentoring_model)
    Group::MentoringModelCloner.new(@group, current_program, @group.mentoring_model).copy_mentoring_model_objects(skip_save: true) if current_program.mentoring_connections_v2_enabled?
  end

  def check_access_to_show_tasks_in_preview
    return true if is_preview?
    access_to_show_profile(@group)
  end

  def is_preview?
    params[:preview].to_s.to_boolean
  end

  def is_hybrid_mentoring_model?
    @mentoring_model.hybrid?
  end

  def fetch_group
    @group = @current_program.groups.find(params[:group_id])
  end

  def compute_actual_date_and_sort_by_due_date(milestone_items)
    milestone_items.each do |milestone_item|
      if milestone_item.required?
        milestone_item.due_date = milestone_item.specific_date.nil? ? Time.current + milestone_item.due_date.days : milestone_item.specific_date
      else
        milestone_item.due_date = nil
      end
    end
    milestone_items = milestone_items.select(&:due_date).sort_by{|milestone_item| [milestone_item.due_date, milestone_item.position]} + milestone_items.reject(&:due_date).sort_by{|milestone_item| [milestone_item.position]}
  end
end