jbuilder_responder(json, local_assigns) do
  json.announcements @announcements do |announcement|
    json.extract! announcement, :id, :title, :updated_at
  end
end