jbuilder_responder(json, local_assigns) do
  json.mentor_request do
    json.extract! @mentor_request, :id, :created_at, :updated_at, :sender_id, :receiver_id, :message, :response_text, :group_id, :closed_by_id, :closed_at
    json.status AbstractRequest::Status::STATE_TO_STRING[@mentor_request.status]
    fetch_mentor_request_hash(json, @mentor_request, @filter, :large)
    json.filter @filter
  end
end