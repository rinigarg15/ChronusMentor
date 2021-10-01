module MentoringModel::GoalsHelper
  TRUNCATE_GOAL_STRING_LENGTH = 50
  DISPLAY_SIDE_PANE_GOALS_LENGTH = 3

  def mentoring_model_tasks_list(goal, tasks_cache = nil)
    if tasks_cache.nil?
      goal.mentoring_model_tasks.includes(task_eager_loadables)
    else
      tasks_cache[goal.id]
    end
  end

  def display_goal_title(goal)
    content_tag(:div, goal.title, :id => "cjs_goal_title_#{goal.id}")
  end

  def display_goal_description(goal)
    content_tag(:div, preserve_new_line(goal.description), :id => "cjs_goal_description_#{goal.id}", :class => "word_break cjs_show_on_collapse_goal m-b-xs")
  end

  def display_goal_status(goal_id, goal_tasks, goal_status, options={})
    content_tag(:div, class: "cjs-mentoring-model-goal-progress-#{goal_id}") do
      if goal_tasks.blank?
        content_tag(:div, "(#{'feature.mentoring_model.label.zero_tasks'.translate})", class: "pull-right text-muted")
      elsif options[:show_manage_connections_view]
        content_tag(:div, "#{options[:completed_tasks]}" + "/"+ "#{goal_tasks.count}", class: "font-bold pull-right")
      else
        content_tag(:div, "#{goal_status.to_s}%", class: "font-bold pull-right")
      end
    end
  end

  def display_no_goals
    content_tag(:div, "feature.mentoring_model.description.no_goal".translate, :class => "cjs_no_goal_msg text-center p-sm")
  end
end