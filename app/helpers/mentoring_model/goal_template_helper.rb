module MentoringModel::GoalTemplateHelper

  def display_goal_template_title(goal_template)
    content_tag :div, "feature.mentoring_model.label.Goal".translate(title: goal_template.title), class: "cjs_goal_template_title_below_description_#{goal_template.id} text-navy m-t-xs"
  end

end