module MentoringModelUtils
  UPCOMING_TASK_CUTOFF_COUNT = 5
  UPCOMING_TASK_DUEDATE_THRESHOLD = 7

  module ViewMode
    SORT_BY_MILESTONES = 1
    SORT_BY_DUE_DATE = 2

    def self.all
      [SORT_BY_MILESTONES, SORT_BY_DUE_DATE]
    end
  end

  def self.included(controller)
    ## This is because this is used as a mixin in ActionControllers and also ActiveRecord classes/
    if controller.respond_to? :helper_method
      controller.helper_method :manage_mm_tasks_at_admin_level?, :manage_mm_tasks_at_end_user_level?,
                               :manage_mm_goals_at_admin_level?, :manage_mm_goals_at_end_user_level?,
                               :manage_mm_milestones_at_admin_level?, :manage_mm_milestones_at_end_user_level?,
                               :manage_mm_meetings_at_end_user_level?, :manage_mm_messages_at_admin_level?,
                               :task_eager_loadables, :task_template_eager_loadables, :goal_eager_loadables,
                               :view_by_milestones?, :view_by_due_date?, :manage_mm_engagement_surveys_at_admin_level?,
                               :allow_due_date_edit?
    end
  end

  def manage_mm_tasks_at_admin_level?(object = @mentoring_model)
    update_cache_and_return(:@can_manage_mm_tasks_at_admin_level) do
      object.can_manage_mm_tasks?(admin_role)
    end
  end

  def manage_mm_tasks_at_end_user_level?(group)
    update_cache_and_return(:@can_manage_mm_tasks_at_end_user_level) do
      group.can_manage_mm_tasks?(end_user_roles)
    end
  end

  def manage_mm_meetings_at_end_user_level?(object)
    update_cache_and_return(:@can_manage_mm_meetings_at_end_user_level) do
      object.can_manage_mm_meetings?(end_user_roles)
    end
  end

  def manage_mm_messages_at_admin_level?
    update_cache_and_return(:@can_manage_mm_messages_at_admin_level) do
      @mentoring_model.can_manage_mm_messages?(admin_role)
    end
  end

  def manage_mm_goals_at_admin_level?(object = @mentoring_model)
    update_cache_and_return(:@can_manage_mm_goals_at_admin_level) do
      object.can_manage_mm_goals?(admin_role)
    end
  end

  def manage_mm_goals_at_end_user_level?(object = @group)
    update_cache_and_return(:@can_manage_mm_goals_at_end_user_level) do
      object.can_manage_mm_goals?(end_user_roles)
    end
  end

  def manage_mm_milestones_at_admin_level?(object = @mentoring_model)
    update_cache_and_return(:@can_manage_mm_milestones_at_admin_level) do
      object.can_manage_mm_milestones?(admin_role)
    end
  end

  def manage_mm_milestones_at_end_user_level?
    update_cache_and_return(:@can_manage_mm_milestones_at_end_user_level) do
      @group.can_manage_mm_milestones?(end_user_roles)
    end
  end

  def manage_mm_engagement_surveys_at_admin_level?(object = @mentoring_model)
    update_cache_and_return(:@can_manage_mm_engagement_surveys_at_admin_level) do
      object.can_manage_mm_engagement_surveys?(admin_role)
    end
  end

  def allow_due_date_edit?(object = @group)
    update_cache_and_return(:@can_edit_due_date) do
      object.mentoring_model.try(:allow_due_date_edit)
    end
  end


  def facilitation_template_eager_loadables
    [:roles, :mentoring_model => :program]
  end

  def task_template_eager_loadables
    [:associated_task, :goal_template, :role]
  end

  def milestone_templates_eager_loadables
    [mentoring_model_task_templates: task_template_eager_loadables]
  end

  def task_eager_loadables
    [:mentoring_model_goal, :comments, connection_membership: [user: [member: [:profile_picture]]]]
  end

  def goal_eager_loadables
    [mentoring_model_tasks: task_eager_loadables]
  end

  def milestone_eager_loadables
    [mentoring_model_tasks: task_eager_loadables]
  end

  def get_all_mentoring_model_task_list_items(group, options = {}, tasks = nil)
    all_items = tasks || group.get_tasks_list(task_eager_loadables, view_mode: @view_mode, home_page_view: @home_page_view, target_user: options[:target_user], target_user_type: options[:target_user_type])
    all_items
  end

  def fetch_appropriate_task_templates(scope = @mentoring_model)
    if manage_mm_milestones_at_admin_level?
      milestone_templates = scope.is_a?(MentoringModel) ? scope.mentoring_model_milestone_templates : [scope]
      task_templates = ActiveSupport::OrderedHash.new
      milestone_templates.each do |milestone_template|
        task_templates[milestone_template.id] = []
      end
      get_task_and_facilitation_templates_merged_list(scope).each do |task_template|
        (task_templates[task_template.milestone_template_id] ||= []) << task_template
      end
    else
      task_templates = get_task_and_facilitation_templates_merged_list(scope)
    end
    task_templates
  end

  # scope can be mentoring_model or facilitation template
  def get_task_and_facilitation_templates_merged_list(scope)
    is_mentoring_model = scope.is_a?(MentoringModel)
    mentoring_model = is_mentoring_model ? scope : scope.mentoring_model
    program = mentoring_model.program
    program_admin_role = program.roles.with_name(RoleConstants::ADMIN_NAME)
    sorted_task_templates_list = mentoring_model.can_manage_mm_tasks?(program_admin_role) ? MentoringModel::TaskTemplate.compute_due_dates(
        mentoring_model.mentoring_model_task_templates.includes(task_template_eager_loadables),
        skip_positions: true ).sort_by{|x| [x.due_date, x.position]} : []
    sorted_task_templates_list.select!{|obj| obj.milestone_template_id.eql?(scope.id) } unless is_mentoring_model
    sorted_facilitation_templates_list = mentoring_model.can_manage_mm_messages?(program_admin_role) ? MentoringModel::FacilitationTemplate.compute_due_dates(scope.mentoring_model_facilitation_templates.includes(facilitation_template_eager_loadables)).sort_by{|x| [x.due_date]} : []
    # merging by time
    template_objects = []
    total_items = sorted_task_templates_list.size + sorted_facilitation_templates_list.size
    total_items.times do
      if sorted_task_templates_list.empty?
        template_objects += sorted_facilitation_templates_list
        break
      elsif sorted_facilitation_templates_list.empty?
        template_objects += sorted_task_templates_list
        break
      else
        if sorted_task_templates_list[0].due_date.present? && (sorted_task_templates_list[0].due_date < sorted_facilitation_templates_list[0].due_date)
          template_objects << sorted_task_templates_list.shift
        else
          template_objects << sorted_facilitation_templates_list.shift
        end
      end
    end
    template_objects
  end

  # will return list of [milestone_position, first_task_due_date, last_task_due_date]
  def get_first_and_last_required_task_in_milestones_list(mentoring_model)
    milestone_templates = mentoring_model.mentoring_model_milestone_templates
    return [] if milestone_templates.empty?

    list_with_milestone_position = []

    milestone_templates.each do |milestone_template|
      sorted_task_templates = get_task_and_facilitation_templates_merged_list(milestone_template)
      required_sorted_task_templates = sorted_task_templates.select{|template| !template.is_a?(MentoringModel::FacilitationTemplate) && template.required?}

      if required_sorted_task_templates.present?
        list_with_milestone_position << [milestone_template.position, required_sorted_task_templates.first.due_date, required_sorted_task_templates.last.due_date]
      end
    end

    list_with_milestone_position
  end

  def get_updated_first_and_last_required_task_in_milestones_list(required_tasks_list_with_milestone_position, task_milestone_position, task_due_date)
    existing_milestone_entry = required_tasks_list_with_milestone_position.find{|milestone_entry| milestone_entry[0] == task_milestone_position}

    if existing_milestone_entry.present?
      milestone_index = required_tasks_list_with_milestone_position.index(existing_milestone_entry)
      required_tasks_list_with_milestone_position[milestone_index][1] = task_due_date if task_due_date < required_tasks_list_with_milestone_position[milestone_index][1]
      required_tasks_list_with_milestone_position[milestone_index][2] = task_due_date if task_due_date > required_tasks_list_with_milestone_position[milestone_index][2]
    else
      new_milestone_entry = [task_milestone_position, task_due_date, task_due_date]
      required_tasks_list_with_milestone_position << new_milestone_entry
      required_tasks_list_with_milestone_position.sort_by!{|milestone_entry| milestone_entry.first}
    end

    return required_tasks_list_with_milestone_position
  end

  def get_updated_first_and_last_required_task_in_milestones_list_after_milestone_reordering(required_tasks_list_with_milestone_position, new_position_by_milestone_id_hash)
    current_milestone_id_by_position_hash = {}
    updated_first_and_last_task_list_with_milestone_position = []

    @mentoring_model.mentoring_model_milestone_templates.each do |milestone_template|
      current_milestone_id_by_position_hash[milestone_template.position] = milestone_template.id
    end

    required_tasks_list_with_milestone_position.each do |milestone_entry|
      new_position = new_position_by_milestone_id_hash[current_milestone_id_by_position_hash[milestone_entry[0]]]
      updated_first_and_last_task_list_with_milestone_position << [new_position, milestone_entry[1], milestone_entry[2]]
    end

    updated_first_and_last_task_list_with_milestone_position.sort_by!{|milestone_entry| milestone_entry.first}

    return updated_first_and_last_task_list_with_milestone_position
  end

  def validate_milestone_order(required_tasks_list_with_milestone_position)
    return true if required_tasks_list_with_milestone_position.size <= 1

    is_order_valid = true

    required_tasks_list_with_milestone_position.each_cons(2) do |task_pair|
      is_order_valid = is_order_valid && is_chronologically_valid_task_pair?(task_pair.first, task_pair.last)
    end

    return is_order_valid
  end

  def get_new_task_template_due_date(mentoring_model, selected_params)
    if selected_params[:specific_date].present?
      due_date = selected_params[:specific_date].to_datetime.change(offset: Time.current.in_time_zone(wob_member.get_valid_time_zone).strftime("%z")).to_i - 1e15
    else
      task_templates = mentoring_model.mentoring_model_task_templates.non_specific_date_templates.required
      task_templates_with_due_dates = MentoringModel::TaskTemplate.compute_due_dates(task_templates, {:skip_positions => true})
      associated_template = task_templates_with_due_dates.find{|template| template.id == selected_params[:associated_id].to_i}
      due_date = associated_template.present? ? associated_template.due_date + selected_params[:duration].to_i : selected_params[:duration].to_i
    end

    return due_date
  end

  def set_should_sync_warn(mentoring_model)
    @should_sync_warn = ((mentoring_model.should_sync || false) && (mentoring_model.has_ongoing_related_connections?))
    @ongoing_connections_count = Group.where(id: mentoring_model.all_associated_group_ids).active.count
  end

  def set_view_mode
    @view_mode = if MentoringModelUtils::ViewMode.all.include?(params[:view_mode].to_i)
      params[:view_mode].to_i
    elsif @is_member_view && @current_connection_membership.view_mode.present?
      @current_connection_membership.view_mode
    else
      # set default value
      MentoringModelUtils::ViewMode::SORT_BY_MILESTONES
    end
  end

  def view_by_milestones?
    @view_mode == MentoringModelUtils::ViewMode::SORT_BY_MILESTONES
  end

  def view_by_due_date?
    @view_mode == MentoringModelUtils::ViewMode::SORT_BY_DUE_DATE
  end

  def set_task_status!(completed)
    if completed == 'true'
      @task.status = MentoringModel::Task::Status::DONE
      @task.completed_date = Date.today
      @task.completed_by = @current_user.id
    else
      @task.status = MentoringModel::Task::Status::TODO
      @task.completed_date = nil
      @task.completed_by = nil
    end
    @task.perform_delta = true
    if @task.save && completed == 'true'
      track_activity_for_ei(EngagementIndex::Activity::COMPLETE_TASK)
    end
  end

  def checkin_access
    @can_checkin_access = checkin_base_permission && @task.allow_checkin?(current_user)
    @can_checkin_access
  end

  def checkin_base_permission
    @checkin_base_permission = current_program.contract_management_enabled? && @group.active? && !@group.expired? && @group.has_mentor?(current_user)
  end

  def can_destroy_task_comment?
    wob_member == @comment.sender
  end

  def self.copy_translatable_attributes(from_obj, to_obj, columns, options = {})
    to_obj.translations.destroy_all
    from_obj.translations.each do |translation|
      locale = translation.locale
      Globalize.with_locale(locale) do
        columns.each do |column|
          to_obj.send("#{column}=", translation.send("#{column}"))
        end
      end
    end
    to_obj.save! unless options[:skip_save]
  end

  def filter_for_target_user_type(group, plan_objects, params_arg)
    update_target_user_type(group, params_arg)
    filtered_plan_objects = []
    if @target_user_type == GroupsController::TargetUserType::ALL_MEMBERS
      filtered_plan_objects = plan_objects
    elsif @target_user_type == GroupsController::TargetUserType::INDIVIDUAL
      @target_user = get_target_user_for_v2(group, params_arg)
      filtered_plan_objects = plan_objects.select{|plan_object| (plan_object.connection_membership && plan_object.connection_membership.user_id == @target_user.id)}
    elsif @target_user_type == GroupsController::TargetUserType::UNASSIGNED
      filtered_plan_objects = plan_objects.select{|plan_object| plan_object.connection_membership.nil?}
    end
    filtered_plan_objects
  end

  def get_target_user_for_v2(group, params_arg)
    update_all_members_enabled(group)
    membership = group.membership_of(current_user)
    target_user_id = params_arg[:target_user_id]
    target_user_id ||= membership.try(:target_user_id)

    @target_user = group.members.find(target_user_id) if target_user_id.present?
    @target_user ||=
      if @all_members_enabled
        @is_member_view && group.members.size > GroupsController::SHOW_DEFAULT_ALL_MEMBERS_LIMIT ? current_user : nil
      else
        @is_member_view ? current_user : (group.mentors.first || group.members.first)
      end
  end

  def update_target_user_type(group, params_arg)
    update_all_members_enabled(group)
    membership = group.membership_of(current_user)

    @target_user_type = params_arg[:target_user_type] || membership.try(:target_user_type)
    @target_user_type = nil if @target_user_type == GroupsController::TargetUserType::ALL_MEMBERS && !@all_members_enabled
    @target_user_type ||=
      if @all_members_enabled
        @is_member_view && group.members.size > GroupsController::SHOW_DEFAULT_ALL_MEMBERS_LIMIT ? GroupsController::TargetUserType::INDIVIDUAL : GroupsController::TargetUserType::ALL_MEMBERS
      else
        GroupsController::TargetUserType::INDIVIDUAL
      end
  end

  def update_all_members_enabled(group)
    @all_members_enabled = group.members.size < GroupsController::SHOW_ALL_MEMBERS_FILTER_LIMIT
  end

  def access_to_show_profile(group, options = {})
    return false unless @current_program.connection_profiles_enabled?
    return false if !@current_user.can_manage_connections? && group.drafted?
    @outsider_view = !check_member_or_admin && group.global?
    group.global? || check_member_or_admin
  end

  private

  def is_chronologically_valid_task_pair?(task1, task2)
    task1[2] <= task2[1]
  end

  def get_meeting_scope_object
    is_member = @group.has_member?(current_user)
    is_admin = current_user.can_manage_connections?
    (!is_member && is_admin) ? @group : wob_member
  end

  def object_class_id(obj)
    [obj.class.name.underscore, obj.id].join("_")
  end

  def update_cache_and_return(cache_var)
    cache_val = eval(cache_var.to_s)
    if cache_val.nil?
      cache_val = yield
      instance_variable_set(cache_var, cache_val)
    end
    cache_val
  end

  def end_user_roles
    current_program.roles.for_mentoring
  end

  def admin_role
    current_program.roles.with_name(RoleConstants::ADMIN_NAME)
  end

  def fetch_mentoring_model
    @mentoring_model = current_program.mentoring_models.find(params[:mentoring_model_id])
    set_should_sync_warn(@mentoring_model)
    @mentoring_model
  end

  def get_current_milestone_chronological_ordering
    @current_first_and_last_required_task_in_milestones_list = get_first_and_last_required_task_in_milestones_list(@mentoring_model)
    @should_check_milestone_order = validate_milestone_order(@current_first_and_last_required_task_in_milestones_list)
  end

  def get_facilitation_message_tags
    @facilitation_message_tags = ChronusActionMailer::Base.mailer_attributes[:tags][:facilitation_message_tags]
  end

end