module MentoringModel::MilestonesHelper
  MILESTONE_STATUS = {
    overdue: "progress-bar-danger",
    completed: "progress-bar-black",
    current: "",
    not_started: "progress-bar-dark-gray"
  }

  def render_milestones_progress(milestones, required_tasks_hash, group_status, manage_connections_view=false)
    milestones_size = milestones.size
    current_milestone = group_status != Group::Status::CLOSED ? (milestones.current.first.presence || milestones.last) : nil
    milestone_statuses = {
      overdue: milestones.overdue.pluck(:id),
      completed: milestones.completed.pluck(:id),
      current: current_milestone
    }
    content = []
    popover_items = []
    milestone_width = 100/milestones_size.to_f

    total_milestone_content = content_tag(:div, class: "clearfix") do
      milestones.each do |milestone|
        content << content_tag(:div, style: "width: #{milestone_width}%", class: "pull-left", id: "milestone_#{milestone.id}") do
          milestone_content = ""
          milestone_content += content_tag(:div, class: "progress progress-small m-r-xxs m-b-0 pointer") do
            content_tag(:div, "", class: "progress-bar #{MILESTONE_STATUS[get_milestone_status(milestone, milestone_statuses)]}", style: "width: 100%", id: "milestone_progress_#{milestone.id}")
          end
          if current_milestone.try(:id) == milestone.id
            milestone_content += content_tag(:div, class: "text-center m-t-n-xs") do
              get_current_milestone_text(manage_connections_view)
            end
          end
          milestone_content.html_safe
        end
        popover_items << popover("#milestone_progress_#{milestone.id}", milestone.title, milestone_popover_snippet(milestone, required_tasks_hash))
      end
      safe_join(content, "") + safe_join(popover_items, "")
    end
    calculate_milestones_progress(total_milestone_content, current_milestone, required_tasks_hash, manage_connections_view)
  end

  def get_current_milestone_text(manage_connections_view)
    get_current_milestone_text = get_icon_content("fa fa-caret-up fa-lg m-r-0") 
    get_current_milestone_text += content_tag(:div, "feature.mentoring_model.label.current_milestone".translate, class: "row small") if manage_connections_view
    get_current_milestone_text
  end

  def calculate_milestones_progress(total_milestone_content, current_milestone, required_tasks_hash, manage_connections_view)
    total_milestone_content += current_milestone_snippet(current_milestone, required_tasks_hash) unless manage_connections_view
    total_milestone_content
  end

  def current_milestone_snippet(milestone, required_tasks_hash)
    return "" if milestone.nil?
    required_tasks = required_tasks_hash[milestone.id]
    tasks_list = compute_tasks_list_hash(required_tasks)
    content_tag(:div, class: "current_milestone_info") do
      current_milestone_status(milestone, required_tasks) +
      current_milestone_tasks(tasks_list)
    end
  end

  def milestone_popover_snippet(milestone, required_tasks_hash)
    return "" if milestone.nil?
    required_tasks = required_tasks_hash[milestone.id]
    tasks_list = compute_tasks_list_hash(required_tasks)
    popover_milestone_status(milestone, required_tasks) +
    popover_tasks_list(milestone, tasks_list)
  end

  def current_milestone_tasks(tasks_list)
    content = []
    content_tag(:div, class: "milestone_status_list m-t-xs") do
      content_tag(:ul) do
        tasks_list.each do |status, tasks|
          content << content_tag(:li) do
            content_tag(:span, "feature.mentoring_model.information.#{status}_tasks".translate(count: tasks[:count]), class: tasks[:color])
          end unless tasks[:count].zero?
        end
        safe_join(content, "")
      end
    end
  end

  def get_milestone_status(milestone, milestone_statuses)
    if milestone_statuses[:overdue].include?(milestone.id)
      :overdue
    elsif milestone_statuses[:completed].include?(milestone.id)
      :completed
    elsif milestone_statuses[:current].try(:id) == milestone.id
      :current
    else
      :not_started
    end
  end

  private

  def popover_tasks_list(milestone, tasks_list)
    tasks_content_list = []
    tasks_list.each do |status, tasks|
      tasks_content_list << content_tag(:span, "feature.mentoring_model.information.#{status.to_s}".translate(count: tasks[:count]), class: tasks[:color]) unless tasks[:count].zero?
    end

    content_tag(:div, class: "ct_popover_tasks_list clearfix m-t-xs") do
      content_tag(:div, "feature.mentoring_model.label.tasks_label".translate, class: "col-md-6 p-l-0 p-r-0 text-muted font-bold") +
      content_tag(:div, tasks_content_list.present? ? safe_join(tasks_content_list, COMMON_SEPARATOR) : "feature.mentoring_model.label.zero_tasks".translate, class: "ct_popover_task_info col-md-6 p-l-0 p-r-0")
    end
  end

  def compute_tasks_list_hash(required_tasks)
    tasks_list = ActiveSupport::OrderedHash.new
    if required_tasks.present?
      tasks_list[:ongoing] = { count: required_tasks.count(&:pending?), color: "text-muted" }
      tasks_list[:completed] = { count: required_tasks.count(&:done?), color: "" }
      tasks_list[:overdue] = { count: required_tasks.count(&:overdue?), color: "text-danger" }
    end
    tasks_list
  end

  def popover_milestone_status(milestone, required_tasks)
    content_tag(:div, class: "clearfix") do
      content_tag(:div, "feature.mentoring_model.label.due_date_label".translate, class: "col-md-6 p-l-0 p-r-0 text-muted font-bold") +
      content_tag(:div, formatted_time_in_words(required_tasks.last.due_date, no_ago: false, no_time: true), class: "col-md-6 p-l-0 p-r-0") if required_tasks.present?
    end
  end

  def current_milestone_status(milestone, required_tasks)
    content_string = []
    content_tag(:div, class: "m-t") do
      content_string << content_tag(:div, "feature.mentoring_model.label.current_milestone".translate, class: "font-600")
      content_string << content_tag(:div, class: "m-t-xs") do
        concat content_tag(:span, milestone.title, class: "font-bold m-r-xxs")
        concat content_tag(:span, "feature.mentoring_model.label.add_brackets".translate(string: "feature.mentoring_model.label.due_date".translate(date: formatted_time_in_words(required_tasks.last.due_date, no_ago: false, no_time: true))), class: "text-muted") if required_tasks.present?
      end
      safe_join(content_string, "")
    end
  end

  def get_milestone_bar_content(milestone_id, milestone_title, milestone_duration, completed = false)
    milestone_bar = []
    content_tag(:div) do
      if completed
        milestone_bar << get_icon_content("fa fa-check-circle text-navy")
      end
      milestone_bar << content_tag(:span, milestone_title)
      safe_join(milestone_bar, "")
    end 
  end

end
