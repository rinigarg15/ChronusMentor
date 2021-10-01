jbuilder_responder(json, local_assigns) do
  json.connection_memberships do
    json.array! @connection_memberships do |connection_membership|
      connection_user = connection_membership.user
      json.name connection_user.name
      json.image_url generate_member_url(connection_user.member, size: :small)
      json.id connection_membership.id
    end
  end
  json.task_details do
    embed_tasks_data(json, @task, @group, local_assigns[:group_features])
    embed_group_data(json, @group)
  end
  display_goals_milestones(json, @goals, @milestones)
  embed_current_milestone_and_goal(json, @task)
end