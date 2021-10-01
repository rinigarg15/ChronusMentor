module MentoringModel::ManualProgressGoalsHelper
  DISPLAY_SIDE_PANE_GOALS_LENGTH = 3

  def manual_progress_goal_progress_bar(group, goal, options = {})
    completion_percentage = goal.completion_percentage
    content = progress_bar(completion_percentage, :id => "progress_#{goal.id}",
      :tooltip => true, 
      :tooltip_content => display_percentage(completion_percentage),
      :class => "progress-small no-margins"
    )
    content
  end

  def display_update_link(goal)
    link_to("display_string.Update".translate, new_group_mentoring_model_goal_activity_path(goal.group, goal), 
      :class => "small cjs_manual_progress_goal_update_link strong")
  end

  def display_percentage(percentage)
    "feature.mentoring_model.information.goal_complete_percentage".translate(percent: percentage)
  end

  def goal_activity_title_text(goal_activity, user)
    name = goal_activity.connection_membership.present? ? link_to_user(goal_activity.member) : goal_activity.member.name
    if goal_activity.progress_value.present?
      content_tag(:span, "feature.mentoring_model.label.goal_progress_updated_by#{"_self" if goal_activity.member_id == user.member_id}_html".translate(user: name)) + content_tag(:span, "#{goal_activity.progress_value.to_i}%", :class => "text-navy font-600 p-l-xxs small")
    else
      "feature.mentoring_model.label.goal_comment_by#{"_self" if goal_activity.member_id == user.member_id}_html".translate(user: name)
    end
  end

end