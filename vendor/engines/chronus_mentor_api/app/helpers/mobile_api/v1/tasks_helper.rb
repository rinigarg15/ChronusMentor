module MobileApi::V1::TasksHelper
  def generate_status_string(task)
    if task.done?
      "completed"
    elsif task.overdue?
      "overdue"
    else
      "pending"
    end
  end

  ## The json variable below is a json builder object. Unable to write helper tests for this :(
  ## There are controller tests for this logic though
  def embed_dates_and_assignee(json, task, image_size)
    json.due_date datetime_to_string(task.due_date)
    if task.done?
      json.completed_date datetime_to_string(task.completed_date)
    end
    assignee_args = task.user.present? ? [task.user.member, {size: image_size}] : [nil, {size: image_size, anonymous_or_default: true}]
    json.assignee_image_url generate_member_url(*assignee_args)
    assignee_name = task.user.present? ? task.user.member.name(:name_only => true) : "feature.mentoring_model.label.unassigned_capitalized".translate
    json.assignee_name assignee_name
    json.assignee_connection_membership_id task.connection_membership_id.to_s
  end

  ## The json variable below is a json builder object. Unable to write helper tests for this :(
  ## There are controller tests for this logic though
  def embed_group_data(json, group)
    json.group do
      json.id @group.id
      json.name @group.name
    end
  end

  def can_update_task?(task)
    !(task.user.present? && task.user != current_user)
  end

  def embed_tasks_data(json, task, group, group_features)
    json.id task.id
    json.title task.title
    json.can_mark_status can_update_task?(task)
    json.can_edit_template_due_date @page_controls_allowed && task.from_template? && allow_due_date_edit?(group) && task.required?
    json.description task.description
    json.update_template_assignee @page_controls_allowed && task.from_template? && task.unassigned_from_template?
    json.status generate_status_string(task)
    json.from_template task.from_template?
    json.can_edit @page_controls_allowed && !task.from_template? && group_features[ObjectPermission::MentoringModel::TASK][:other_users]
    json.comments_count task.comments.size
    json.required task.required?
    json.milestone_id task.milestone_id if group_features[ObjectPermission::MentoringModel::MILESTONE].values.any?
    json.goal_id task.goal_id if group_features[ObjectPermission::MentoringModel::GOAL].values.any?
    embed_dates_and_assignee(json, task, :small)
  end

  def display_goals_milestones(json, goals, milestones)
    if goals.present?
      json.goals do
        json.array! goals do |goal|
          json.id goal.id
          json.title goal.title
          json.description goal.description
        end
      end
    end
    if milestones.present?
      json.milestones do
        json.array! milestones do |milestone|
          json.id milestone.id
          json.title milestone.title
          json.description milestone.description
        end
      end
    end
  end

  def embed_current_milestone_and_goal(json, task)
    if task.milestone.present?
      json.current_milestone do
        json.id task.milestone_id
        json.title task.milestone.title
      end
    end  
    if task.mentoring_model_goal.present?
      json.current_goal do
        json.id task.goal_id
        json.title task.mentoring_model_goal.title
      end
    end
  end
end