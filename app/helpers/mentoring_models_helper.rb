module MentoringModelsHelper
  include MentoringModelCommonHelper

  DESCRIPTION_LENGTH = 200

  FEATURE_DISPLAY_ORDER = [
    ObjectPermission::MentoringModel::MILESTONE,
    ObjectPermission::MentoringModel::GOAL,
    ObjectPermission::MentoringModel::TASK,
    ObjectPermission::MentoringModel::MEETING,
    ObjectPermission::MentoringModel::FACILITATION_MESSAGE,
    ObjectPermission::MentoringModel::ENGAGEMENT_SURVEY
  ]

  FEATURES_ENABLED_BY_DEFAULT = [
    ObjectPermission::MentoringModel::TASK,
    ObjectPermission::MentoringModel::FACILITATION_MESSAGE
  ]

  module Headers
    DESCRIBE_TEMPLATE = 1
    CONFIGURE_TEMPLATE = 2
    ADD_TEMPLATE = 3
  end

  module HybridHeaders
    DESCRIBE_TEMPLATE = 1
    CONFIGURE_TEMPLATE = 2
  end

  module MilestonePosition
    AS_FIRST_MILESTONE = 1
    INSERT_AFTER = 2
  end

  def mentoring_model_permission_checkbox(enabled, form, permission, param_name, mentoring_model_data_entities, updating_features_disabled)
    return if enabled.nil?
    data_entities_hash = {:entities => mentoring_model_data_entities[permission]}
    data_entities_hash.merge!({:taskcount => mentoring_model_data_entities[ObjectPermission::MentoringModel::TASK]}) if permission == ObjectPermission::MentoringModel::MILESTONE
    input_html_hash = {:id => "cjs_mentoring_model_#{param_name}_#{permission}", :data => data_entities_hash}
    input_html_hash.merge!({:disabled => true, :class => "cjs_features_list"}) if MentoringModelsHelper::FEATURES_ENABLED_BY_DEFAULT.include?(permission) || updating_features_disabled
    content_tag(:div, :class => "checkbox") do
      content_tag(:label) do
        check_box_tag("permissions[#{param_name}[#{permission}]]", 1, enabled, input_html_hash ) +
        "feature.mentoring_model.label.#{param_name}_can_configure".translate
      end
    end
  end

  def object_description_content(object)
    # This is ckeditor content Don't remove raw here
    raw(object.description)
  end

  def no_mentoring_model_entities(message, options = {})
    content_tag(:div, class: "text-muted p-sm text-center #{options[:additional_class]}") do
      message
    end
  end

  def generate_feature_list(mentoring_model, roles, object_permissions, options = {})
    users_role = {}
    admin_role = { roles[RoleConstants::ADMIN_NAME].first.id => _Admins }
    other_roles = roles.values.flatten.select(&:for_mentoring?)
    other_roles.each do |other_role|
      users_role[other_role.id] = "feature.multiple_templates.content.Users".translate
    end
    categorized_roles = [admin_role, users_role]
    content = []
    object_role_permissions = mentoring_model.object_role_permissions.group_by(&:object_permission_id)

    MentoringModelsHelper::FEATURE_DISPLAY_ORDER.each do |permission_name|
      permission_id = object_permissions[permission_name].first.id
      role_permissions = object_role_permissions[permission_id]
      permitted_roles = []
      if role_permissions.present?
        categorized_roles.each do |categorized_role_hash|
          role_ids = categorized_role_hash.keys
          if rp_object = role_permissions.find { |role_permission| role_ids.include?(role_permission.role_id) }
            permitted_roles << categorized_role_hash[rp_object.role_id]
          end
        end
        content << feature_list_snippet(permission_name, mentoring_model_v2_icon(permission_name), permitted_roles)
      end
      if permission_name == ObjectPermission::MentoringModel::TASK && options[:fixed_date_tasks_available]
        content << content_tag(:div, append_text_to_icon("fa fa-exclamation-circle", "feature.multiple_templates.help_text.fixed_dates".translate), class: "help-block m-l-md m-b-0 m-t-0")
      end
    end

    { allow_messaging: "fa fa-envelope", allow_forum: "fa fa-comment-o" }.each_pair do |setting, icon_class|
      if mentoring_model.send(setting)
        content << feature_list_snippet(setting, get_icon_content(icon_class), ["feature.multiple_templates.content.Users".translate])
      end
    end
    render_feature_list(content)
  end

  def render_feature_list(content)
    if content.present?
      content_tag(:div, "feature.multiple_templates.content.features_enabled".translate, :class => "h5 m-b-0 m-t-0") +
      content_tag(:div, safe_join(content))
    else
      content_tag(:i, "feature.multiple_templates.content.features_not_enabled".translate, class: "text-muted")
    end
  end

  def render_milestone_position_choices(mentoring_model)
    milestone_templates = mentoring_model.mentoring_model_milestone_templates.where("id IS NOT NULL")
    return unless milestone_templates.present?

    options = []
    selected_value = milestone_templates.first.position

    milestone_templates.each do |milestone_template|
      options << [milestone_template.title, milestone_template.position]
    end
    label = "feature.mentoring_model.label.add_milestone".translate
    content = content_tag(:div, label, class: "control-label")
    content += choices_wrapper(label) do
        content_tag(:div, class: "row") do
          content_tag(:div, class: "col-sm-10") do
            content_tag(:label, radio_button_tag("milestone_position", MilestonePosition::AS_FIRST_MILESTONE, false, class: 'cjs_radio_milestone_position') + "feature.mentoring_model.label.as_first_milestone".translate, class: "radio m-b-0")
          end
        end +
      content_tag(:div, class: "row") do
        content_tag(:div, class: "col-sm-3") do
          content_tag(:label, radio_button_tag("milestone_position", MilestonePosition::INSERT_AFTER, true, class: 'cjs_radio_milestone_position') + "feature.mentoring_model.label.insert_it_after".translate, class: "radio")
        end +

        content_tag(:div, class: "col-sm-6 p-l-0") do
          content_tag(:label, "feature.mentoring_model.label.insert_it_after".translate, :for => "cui_insert_milestone_after_dropdown", :class => "sr-only") +
          select_tag("insert_milestone_after", options_for_select(options, selected_value), class: "form-control", id: "cui_insert_milestone_after_dropdown")
        end
      end
    end

    return content_tag(:div, content, class: "m-b-md")
  end

  def get_mentoring_period_unit(mentoring_model)
    value = mentoring_model.mentoring_period_value
    unit = mentoring_model.mentoring_period_unit
    if unit == MentoringPeriodUtils::MentoringPeriodUnit::WEEKS
      "feature.multiple_templates.labels.Weeks".translate(count: value)
    elsif unit == MentoringPeriodUtils::MentoringPeriodUnit::DAYS
      "feature.multiple_templates.labels.Days".translate(count: value)
    end
  end

  def mentoring_period_options
    [
      ["feature.multiple_templates.labels.Weeks".translate(count: 2), MentoringPeriodUtils::MentoringPeriodUnit::WEEKS],
      ["feature.multiple_templates.labels.Days".translate(count: 2), MentoringPeriodUtils::MentoringPeriodUnit::DAYS]
    ]
  end

  def mentoring_model_pane_title(mentoring_model)
    content = mentoring_model.title
    content += " #{"feature.multiple_templates.header.default_marker".translate}" if mentoring_model.default?
    content
  end

  def render_mentoring_model_duration_info(mentoring_model)
    " #{mentoring_model.mentoring_period_value} #{get_mentoring_period_unit(mentoring_model)}"
  end

  def render_mentoring_model_description_info(mentoring_model, truncate = false)
    if mentoring_model.description.present?
      content_description = mentoring_model.description
      content_tag(:div, chronus_auto_link(truncate ? truncate(content_description, length: DESCRIPTION_LENGTH, separator: TRUNCATE_SPACE_SEPARATOR) : content_description), :class => "m-b")
    end
  end

  def render_tasks_filter(connection_users, group)

    users_selection = "".html_safe

    if @all_members_enabled
      checked = (@target_user_type == GroupsController::TargetUserType::ALL_MEMBERS) ? true : false
      users_selection = content_tag(:div, :class => "radio") do
        content_tag(:label, content_tag(:input, image_tag("all_members.png", :class => "img-circle m-r-sm", :width => "21") + content_tag(:span, "feature.mentoring_model.label.tasks_assigned_to_all".translate, :class => "cjs_task_and_meetings_filter_text"), :type => "radio", :name => "task_filter_by_member", :checked => checked, :id => "tasks_by_all_members_filter"), :class => "cjs_all_members cjs_task_and_meetings_filter", :data => {:target_user_type => GroupsController::TargetUserType::ALL_MEMBERS})
      end
    end

    connection_users.each do |user|
      checked = ((@target_user_type == GroupsController::TargetUserType::INDIVIDUAL) && (@target_user == user)) ? true : false
      options = {:no_name => true, :no_padding_for_media_body => true, :size => :small, :member_name => "feature.mentoring_model.label.tasks_assigned_to".translate(member: user.name(name_only: true)), :dont_link => true, :skip_outer_class=> true, :style_name_without_link => "cjs_task_and_meetings_filter_text", new_size: "tiny"}
      image_options = {:class => "img-circle", :size => "21x21"}

      users_selection << content_tag(:div, :class => "radio") do
        content_tag(:label, content_tag(:input, user_picture(user, options, image_options), :type => "radio", :name => "task_filter_by_member", :id => "tasks_by_member_#{user.id}_filter", :checked => checked), :class => "cjs_all_members_#{user.id} cjs_task_and_meetings_filter", :data => {:user_id => "#{user.id}", target_user_id: user.id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL})
      end

    end
    checked = (@target_user_type == GroupsController::TargetUserType::UNASSIGNED) ? true : false
    users_selection << content_tag(:div, :class => "radio p-t-xxs") do
      content_tag(:label, content_tag(:input, image_tag(UserConstants::DEFAULT_PICTURE[:small], :width => "21", :class => "img-circle m-r-sm") + content_tag(:span, "feature.mentoring_model.header.unassigned_tasks".translate, :class => "cjs_task_and_meetings_filter_text"), :type => "radio", :name => "task_filter_by_member", :id => "unassigned_tasks_filter", :checked => checked), :class => "cjs_all_members_unassigned cjs_task_and_meetings_filter", :data => {:target_user_type => GroupsController::TargetUserType::UNASSIGNED})
    end

    choices_wrapper("feature.mentoring_model.label.filter_tasks".translate){users_selection}

  end

  def get_task_filter_title(options = {})
    type_filter = if options[:no_type_filter]
      ""
      elsif view_by_milestones?
      "#{'feature.mentoring_model.label.by_milestones'.translate}, "
    elsif view_by_due_date?
      "#{'feature.mentoring_model.label.by_due_date'.translate}, "
    end

    if @target_user_type == GroupsController::TargetUserType::ALL_MEMBERS
      member_filter = "feature.mentoring_model.label.tasks_assigned_to_all".translate
    elsif @target_user_type == GroupsController::TargetUserType::UNASSIGNED
      member_filter = "feature.mentoring_model.header.unassigned_tasks".translate
    elsif(@target_user_type == GroupsController::TargetUserType::INDIVIDUAL)
      member_filter = "feature.mentoring_model.label.tasks_assigned_to".translate(member: @target_user.name(name_only: true))
    end
    filter_title = "feature.mentoring_model.label.view_tasks".translate + ": " + type_filter + member_filter
    mobile_content = content_tag(:span, get_icon_content("fa fa-filter no-margins"), class: "btn btn-white btn-xs visible-xs") + content_tag(:span, filter_title, class: "visible-xs sr-only")
    desktop_content = content_tag(:span, get_icon_content("fa fa-filter"), class: "hidden-xs") + content_tag(:span, filter_title, class: "hidden-xs")
    content_tag(:span,  mobile_content + desktop_content, class: "cjs-task-filter-text")
  end

  def render_view_mode_filter
    milestone_checked = false
    due_date_checked = false

    if view_by_milestones?
      milestone_checked = true
    elsif view_by_due_date?
      due_date_checked = true
    end
    view_items = content_tag(:div, :class => "radio") do
      content_tag(:label, content_tag(:input, "feature.mentoring_model.label.by_milestones".translate, :type => "radio", :id => "tasks_by_milestone_filter", :name => "task_filter_by_type", :checked => milestone_checked), :class => "cjs-view-mode-filter-by-milestone cjs-view-mode-filter-item", :data => {:"view-mode" => MentoringModelUtils::ViewMode::SORT_BY_MILESTONES})
    end
    view_items << content_tag(:div, :class => "radio") do
      content_tag(:label, content_tag(:input, "feature.mentoring_model.label.by_due_date".translate, :type => "radio", :id => "tasks_by_due_date_filter", :name => "task_filter_by_type", :checked => due_date_checked), :class => "cjs-view-mode-filter-by-due-date cjs-view-mode-filter-item", :data => {:"view-mode" => MentoringModelUtils::ViewMode::SORT_BY_DUE_DATE})
    end
    choices_wrapper("feature.mentoring_model.label.view_tasks".translate){ view_items }
  end

  def render_completed_view_mode_filter
    content_tag(:div, :class => "checkbox") do
     content_tag(:label, content_tag(:input, "feature.mentoring_model.header.show_completed_tasks".translate, :type => "checkbox", :checked => true, :id => "completed_view_mode_filter"), :class => "cjs-completed-tasks-checkbox")
    end
  end

  def mentoring_model_new_wizard(super_console)
    wizard_info = ActiveSupport::OrderedHash.new
    wizard_info[Headers::DESCRIBE_TEMPLATE] = { label: "feature.multiple_templates.wizard_headers.describe_template_v1".translate }
    wizard_info[Headers::CONFIGURE_TEMPLATE] = { label: "feature.multiple_templates.wizard_headers.configure_template_settings".translate } if super_console
    wizard_info[Headers::ADD_TEMPLATE] = { label: "feature.multiple_templates.wizard_headers.add_template_content".translate }
    wizard_info
  end

  def mentoring_model_wizard_edit_view(super_console, mentoring_model)
    wizard_info = ActiveSupport::OrderedHash.new
    wizard_info[Headers::DESCRIBE_TEMPLATE] = { label: "feature.multiple_templates.wizard_headers.describe_template_v1".translate, url: edit_mentoring_model_path(mentoring_model) }
    wizard_info[Headers::CONFIGURE_TEMPLATE] = { label: "feature.multiple_templates.wizard_headers.configure_template_settings".translate, url: setup_mentoring_model_path(mentoring_model) } if super_console
    wizard_info[Headers::ADD_TEMPLATE] = { label: "feature.multiple_templates.wizard_headers.add_template_content".translate, url: mentoring_model_path(mentoring_model) }
    wizard_info
  end

  def mentoring_model_wizard_view(super_console, current_page, mentoring_model, options = {})
    if options[:no_wizard_view].present?
      content_tag(:div) do
        yield
      end
    else
      wizard_headers(mentoring_model_wizard_edit_view(super_console, mentoring_model), current_page, options) do
        yield
      end
    end
  end

  def display_days_or_weeks_format(duration)
    duration != 0 && duration % 7 == 0 ? ["n_weeks_after_task", duration/7] : ["n_days_after_task", duration]
  end

  def generate_duration_unit_list_and_map
    duration_unit_list = [["feature.mentoring_model.information.days".translate, 1], ["feature.mentoring_model.information.weeks".translate, 7]]
    [duration_unit_list, duration_unit_list.map{|duration| "{durationName: '#{j(duration[0])}', durationId: '#{duration[1]}'}"}.join(",").html_safe]
  end

  def get_mentoring_model_settings_for_display(mentoring_model)
    settings = []
    settings << {
      name: :allow_due_date_edit,
      icon_class: "fa fa-check-square-o",
      heading: "feature.mentoring_model.header.alter_admin_created_tasks".translate,
      description: "feature.mentoring_model.description.alter_admin_created_tasks".translate,
      label: "feature.mentoring_model.label.users_can_configure".translate
    }
    settings << {
      name: :allow_messaging,
      icon_class: "fa fa-envelope",
      heading: "feature.connection.action.Messages".translate,
      description: "feature.mentoring_model.description.allow_messaging".translate(mentoring_connection: _mentoring_connection),
      label: "feature.mentoring_model.label.enable_messaging".translate,
      disable_tooltip: disable_allow_messaging_tooltip(mentoring_model)
    }
    settings << {
      name: :allow_forum,
      icon_class: "fa fa-comment",
      heading: "feature.mentoring_model.label.discussion_board".translate,
      description: "feature.mentoring_model.description.allow_discussion_board".translate(mentoring_connection: _mentoring_connection),
      label: "feature.mentoring_model.label.enable_discussion_board".translate,
      assoc_text_area_field: :forum_help_text,
      disable_tooltip: disable_allow_forum_tooltip(mentoring_model)
    }
    settings
  end

  def get_mentoring_models_collection
    mentoring_models = get_all_mentoring_models(current_program)
    mentoring_models.map { |mentoring_model| [mentoring_model_pane_title(mentoring_model), mentoring_model.id] }
  end

  private

  def feature_list_snippet(permission_name, icon, permitted_roles)
    content_tag(:div, class: "p-t-xs") do
      icon +
      content_tag(:b, "feature.multiple_templates.content.#{permission_name}-feature-enabled".translate) +
      content_tag(:span, " (#{permitted_roles.join(", ")})")
    end
  end

  def disable_allow_messaging_tooltip(mentoring_model)
    return unless mentoring_model.allow_messaging? && !mentoring_model.can_disable_messaging?

    message = "feature.mentoring_model.information.ongoing_closed_groups_tooltip".translate(mentoring_connection: _mentoring_connection, mentoring_connections: _mentoring_connections)
    "#{message} #{'feature.mentoring_model.information.disabled_messaging_tooltip'.translate(mentoring_connections: _mentoring_connections)}"
  end

  def disable_allow_forum_tooltip(mentoring_model)
    return unless mentoring_model.allow_forum? && !mentoring_model.can_disable_forum?

    message = "feature.mentoring_model.information.ongoing_closed_groups_tooltip".translate(mentoring_connection: _mentoring_connection, mentoring_connections: _mentoring_connections)
    "#{message} #{'feature.mentoring_model.information.disabled_forum_tooltip'.translate(mentoring_connections: _mentoring_connections)}"
  end
end