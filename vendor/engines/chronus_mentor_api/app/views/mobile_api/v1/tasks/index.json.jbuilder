jbuilder_responder(json, local_assigns) do
  json.tasks do
    json.list do
      json.array! @tasks do |task|
        embed_tasks_data(json, task, @group, local_assigns[:group_features])
      end
    end
    embed_group_data(json, @group)
    display_goals_milestones(json, @goals, @milestones)
  end
end