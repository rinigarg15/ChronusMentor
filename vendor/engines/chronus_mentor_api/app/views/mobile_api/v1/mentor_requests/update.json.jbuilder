jbuilder_responder(json, local_assigns) do
  json.success true
  json.group_id @mentor_request.group_id if @mentor_request.status == AbstractRequest::Status::ACCEPTED
  json.mentor_request do
    json.status AbstractRequest::Status::STATE_TO_STRING[@mentor_request.status]
    json.extract! @mentor_request, :id, :created_at, :updated_at, :sender_id, :receiver_id, :message, :response_text
  end
end  