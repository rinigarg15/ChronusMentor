module MentoringModel::TasksHelper
  SNIPPET_COLOR = {
    completed: "",
    overdue: "text-danger",
    pending: "text-muted"
  }

  PROGRESS_BAR_CLASS = {
    completed: "progress-bar-black",
    overdue: "progress-bar-danger",
    pending: "progress-bar-dark-gray"
  }

  FOR_ALL_USERS = "all_users"
  FOR_ALL_ROLE_ID = "role_id_"

  def new_task_action_item_options(group)
    MentoringModel::TaskTemplate::ActionItem.all.select do |item|
      case item
      when MentoringModel::TaskTemplate::ActionItem::MEETING
        manage_mm_meetings_at_end_user_level?(group)
      when MentoringModel::TaskTemplate::ActionItem::GOAL
        manage_mm_goals_at_end_user_level?(group)
      when MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY
        false
      else
        true
      end
    end.map do |item|
      [MentoringModel::TaskTemplate::ActionItem.text_to_translate[item].translate(:Meeting => _a_meeting), item]
    end
  end

  ## This method is called both by task progress and goal progress in reports page.
  ## Also we use this to show goal progress in side pane and goals listing page of a connection.
  def display_tasks_progress_bar(mentoring_model_tasks, options = {})
    options.reverse_merge!({goal_status: 0, connection_and_reports_page: false, from_goals: false})
    tasks = ActiveSupport::OrderedHash.new
    all_tasks_size = mentoring_model_tasks.size
    initialize_tasks_hash!(tasks, mentoring_model_tasks, :completed, :done?, all_tasks_size)
    initialize_tasks_hash!(tasks, mentoring_model_tasks, :overdue, :overdue?, all_tasks_size)
    initialize_tasks_hash!(tasks, mentoring_model_tasks, :pending, :pending?, all_tasks_size)
    content = []
    total_content = content_tag(:div, class: "progress progress-small m-b-xs") do
      tasks.each do |status, tasks_hash|
        content << content_tag(:div,"", class: "#{get_progress_bar_class(status, options)} progress-bar", style: "width: #{tasks_hash[:width]}") if tasks_hash[:count] > 0
      end
      content.join("").html_safe
    end 
    total_content += tasks_snippet(tasks, options) unless options[:reports_page]
    total_content
  end

  def get_progress_bar_class(status, options={}) 
    if reports_page_or_modified_tasks(options) && status != :completed
      return "progress-bar-dark-gray"
    elsif !reports_page_or_modified_tasks(options)
      PROGRESS_BAR_CLASS[status]
    end
  end

  def reports_page_or_modified_tasks(options={})
    options[:reports_page] || options[:modified_task_bar]
  end

  def get_assignee_container_select_box(task, group, user)
    selected_membership_id = (task.connection_membership_id || group.membership_of(user).id)
    select_tag_options = if task.new_record? && user.program.allow_one_to_many_mentoring?
      roles_by_id_hsh = user.program.roles.for_mentoring.includes(customized_term: :translations).index_by(&:id)
      grouped_options = group.memberships.includes(user: :member).group_by(&:role_id).map do |role_id, role_memberships|
        [roles_by_id_hsh[role_id].customized_term.pluralized_term, role_memberships.collect{|m| [m.user.name, m.id]}]
      end
      first_opt_group = ["feature.mentoring_model.label.mentoring_connection_members".translate(Mentoring_Connection: _Mentoring_Connection), [["feature.mentoring_model.label.all_users_option".translate, FOR_ALL_USERS]]]
      group.memberships.pluck(:role_id).uniq.sort.each do |role_id|
        role = roles_by_id_hsh[role_id]
        first_opt_group[1] << ["feature.mentoring_model.label.all_role_option".translate(rolename_captial: role.customized_term.pluralized_term, rolename: role.customized_term.term_downcase), "#{FOR_ALL_ROLE_ID}#{role_id}"]
      end
      grouped_options_for_select(grouped_options.unshift(first_opt_group), selected_membership_id)
    else
      options_for_select(group.memberships.collect{|m| [m.user.name,m.id]} , selected_membership_id)
    end
    select_tag("mentoring_model_task[connection_membership_id]", select_tag_options, {:class => "form-control", :id => "mentoring_model_task_connection_membership_id"})
  end

  def tasks_snippet(tasks, options)
    content = []
    progress_information = []
    content_tag(:div, class: "tasks_snippet") do
      if options[:from_goals]
        content << content_tag(:span, options[:connection_and_reports_page] ? "" : "feature.mentoring_model.information.goal_complete".translate(percent: options[:goal_status]), class: "text-success")
        content << (options[:connection_and_reports_page] ? "" : vertical_separator)
        content << content_tag(:span, "#{'feature.mentoring_model.header.tasks'.translate} ", class: "font-bold")
        tasks.each do |status, tasks_hash|
          progress_information << content_tag(:span, class: "#{SNIPPET_COLOR[status]}") do
            "feature.mentoring_model.information.tasks_#{status}".translate(count: tasks_hash[:count])
          end
        end
      else
        tasks.each do |status, tasks_hash|
          content << vertical_separator if status != :completed
          content << content_tag(:span, class: "#{get_snippet_color(status, options)}") do
            get_task_count_per_status(status, tasks_hash[:count], options) 
          end
        end
      end
      content.join("").html_safe + progress_information.join(COMMON_SEPARATOR).html_safe
    end
  end

  def get_snippet_color(status, options={})
    "#{SNIPPET_COLOR[status]}" unless options[:modified_task_bar]
  end

  def get_task_count_per_status(status, tasks_count, options={})
    options[:modified_task_bar] ? "feature.meetings.header.#{status}".translate + ": " + "#{tasks_count}" : "feature.mentoring_model.header.task_label".translate(count: tasks_count) + " " + "feature.mentoring_model.label.#{status}_label".translate
  end

  def display_mentoring_model_user_pic(task)
    common_class = "pull-left cjs_pic_holder m-r-sm no-vertical-margins"
    if can_show_task_user?(task)
      user_picture(task.user, {size: :small, no_name: true, outer_class: common_class, new_size: :tiny}, {:class => "img-circle", :size => "21x21"})
    else
      content_tag(:div, class: "member_box small " + common_class) do
        img_mentoring_model_profile_pic(task)
      end
    end
  end

  def can_show_task_user?(task)
    task.connection_membership_id? && !task.unassigned_from_template? && task.user.present?
  end

  def get_action_item_classes(controls_allowed, is_owner_of_task, task_completed)
    if controls_allowed && is_owner_of_task
      if task_completed
        "cjs-task-action-btn btn btn-white btn-xs"
      else
        "cjs-task-action-btn btn btn-primary btn-xs"
      end
    end
  end

  def get_tast_disabled_status(task, page_controls_allowed)
    !page_controls_allowed || (task.user.present? && task.user != current_user) || task.is_engagement_survey_action_item?
  end

  def get_disable_help_text(task, page_controls_allowed)
    if !page_controls_allowed || (task.user.present? && task.user != current_user)
      "feature.mentoring_model.label.not_task_owner".translate
    elsif task.is_engagement_survey_action_item?
      task.done? ? "feature.mentoring_model.label.survey_answered".translate : "feature.mentoring_model.label.please_answer_survey_v1".translate
    end
  end

  def additional_mentoring_model_attrs(task_params)
    additional_args = {}
    additional_args = {from_goal: true} if task_params[:from_goal]
    additional_args
  end

  def generate_mentoring_model_filter_class(task)
    if task.is_a?(MentoringModel::Task)
      "cjs-mentoring-model-filter-for-task-and-meetings-#{task.user.try(:id)}"
    elsif task.is_a?(Meeting)
      "cjs-mentoring-model-filter-for-meetings"
    end
  end
  
  def get_date_for_required_task_else_default_date(task)
    task.required ? DateTime.localize(task.due_date, format: :full_display_no_time) : DateTime.localize(Date.today + 7.days, format: :full_display_no_time)
  end

  private

  def initialize_tasks_hash!(tasks_hash, mentoring_model_tasks, status, method, all_tasks_size)
    count = mentoring_model_tasks.select{|task| task.send(method) }.size
    tasks_hash[status] = {count: count, width: "#{((count/all_tasks_size.to_f) * 100)}%"}
  end

  def img_mentoring_model_profile_pic(task)
    (task.connection_membership.present? ? 
      user_picture(task.user, {size: :small, no_name: true, skip_outer_class: true, new_size: :tiny}, {class: "cjs_default_pic img-circle", size: "21x21"}) : 
      image_tag(UserConstants::DEFAULT_PICTURE[:small], width: "21", class: "cjs_default_pic img-circle", title: "feature.mentoring_model.information.unassigned_task".translate))  
  end
end