jbuilder_responder(json, local_assigns) do
  json.task_details do
    embed_tasks_data(json, @task, @group, local_assigns[:group_features])
    embed_group_data(json, @group)
  end
end