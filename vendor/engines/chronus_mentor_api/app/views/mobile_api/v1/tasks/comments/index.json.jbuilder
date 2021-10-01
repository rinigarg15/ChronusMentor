jbuilder_responder(json, local_assigns) do
  json.comments do
    comments_list(json, @comments) 
  end
end