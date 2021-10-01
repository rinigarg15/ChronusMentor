jbuilder_responder(json, local_assigns) do
  json.receiver do
    json.extract! @receiver, :id, :name, :member_id
    json.image_url generate_member_url(@receiver.member, size: :small)
  end
end