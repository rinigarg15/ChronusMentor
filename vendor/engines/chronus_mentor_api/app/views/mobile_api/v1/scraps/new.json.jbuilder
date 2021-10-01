jbuilder_responder(json, local_assigns) do
  json.receiver_names @new_scrap.receiver_names(@current_user)
end