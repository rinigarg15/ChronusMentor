# Currently included only in MentorRequest and ProjectRequest.
module AbstractRequestConcern
  extend ActiveSupport::Concern

  included do
    before_action :fetch_request, only: [:update]
  end

  private

  def handle_request_fetched_for_update(abstract_request, redirect_path)
    error_message = if abstract_request.blank?
      "flash_message.mentor_request_flash.invalid_request".translate
    elsif !abstract_request.active?
      get_status_based_message(abstract_request.status, true)
    end
    if error_message.present?
      flash[:error] = error_message
      do_redirect(redirect_path)
    end
  end

  def get_status_based_message(status, past_tense = false)
    key = past_tense ? "flash_message.mentor_request_flash.past_accepted_rejected_withdrawn" : "flash_message.mentor_request_flash.accepted_rejected_withdrawn_v1"

    status_string = case status
    when AbstractRequest::Status::ACCEPTED
      'display_string.accepted'.translate
    when AbstractRequest::Status::REJECTED
      'display_string.declined'.translate
    when AbstractRequest::Status::WITHDRAWN
      'display_string.withdrawn'.translate
    when AbstractRequest::Status::CLOSED
      'display_string.closed'.translate
    end
    key.translate(status: status_string) if status_string.present?
  end
end