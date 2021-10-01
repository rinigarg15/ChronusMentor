jbuilder_responder(json, local_assigns) do
  json.task_details do
    embed_tasks_data(json, @task, @group, local_assigns[:group_features])
    embed_group_data(json, @group)
    json.comments do
      comments_list(json, @comments)
    end
  	embed_current_milestone_and_goal(json, @task)
  end
end