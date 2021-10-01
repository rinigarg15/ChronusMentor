jbuilder_responder(json, local_assigns) do
  json.filter_states @filter_states
  json.state_scope @state_scope
  json.mentor_requests @mentor_requests do |mentor_request|
    json.extract! mentor_request, :id, :created_at, :updated_at, :sender_id, :receiver_id, :message, :response_text, :group_id, :closed_by_id, :closed_at
    json.status AbstractRequest::Status::STATE_TO_STRING[mentor_request.status]
    fetch_mentor_request_hash(json, mentor_request, @filter)
  end
  json.past_requests_count @past_requests_count
  json.pending_requests_count @pending_requests_count
  json.sent_by_me_requests_count @sent_by_me_requests_count
  json.sent_to_me_requests_count @sent_to_me_requests_count
end  