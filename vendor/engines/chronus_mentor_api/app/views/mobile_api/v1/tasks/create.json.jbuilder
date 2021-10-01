jbuilder_responder(json, local_assigns) do
  json.task_details do
    json.id @task.id
  end
end