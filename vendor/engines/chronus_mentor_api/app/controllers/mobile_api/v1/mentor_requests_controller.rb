class MobileApi::V1::MentorRequestsController < MobileApi::V1::BasicController
  before_action :authenticate_user
  before_action :fetch_request, :only => [:show, :update]
  before_action :fetch_filter, :only => [:show, :update]

  STATUS = {
    "accept" => AbstractRequest::Status::ACCEPTED,
    "reject" => AbstractRequest::Status::REJECTED,
    "withdraw" => AbstractRequest::Status::WITHDRAWN
  }

  def create
    success = false
    if @current_program.allow_mentoring_requests? &&
      @current_program.matching_by_mentee_alone? &&
      current_user.can_send_mentor_request? &&
      !current_user.connection_limit_as_mentee_reached? &&
      !current_user.pending_request_limit_reached_for_mentee?

      mentor_request = current_user.sent_mentor_requests.new
      mentor_request.receiver_id = params[:mentor_request][:receiver_id].to_i
      mentor_request.message = params[:mentor_request][:message].to_s
      mentor_request.program = @current_program

      success = mentor_request.mentor.present? &&
        mentor_request.mentor.can_mentor? &&
        mentor_request.save
    end
    render_response(data: {success: success}, status: success ? 200 : 404)
  end

  def new
    @instruction = @current_program.mentor_request_instruction
    @receiver = @current_program.all_users.includes(:member).where(id: params[:receiver_id]).first
    unless @receiver.present?
      errors = [ApiConstants::CommonErrors::ENTITY_NOT_FOUND % {entity: _Mentor, attribute: :id, value: params[:receiver_id]}]
      render_errors(errors, 404) and return
    end
    render_success("mentor_requests/new")
  end

  def index
    render_error_response and return unless has_access_to_index
    @state_scope = params[:state] == "non_pending" ? :non_pending : :active
    @filter = get_default_filter
    if @filter == AbstractRequest::Filter::TO_ME
      mentor_requests = current_user.received_mentor_requests.includes(student: :member)
    elsif @filter == AbstractRequest::Filter::BY_ME
      mentor_requests = current_user.sent_mentor_requests.includes(mentor: :member)
    else
      render_error_response and return
    end
    @pending_requests_count = mentor_requests.active.count
    @past_requests_count = mentor_requests.inactive.count
    received_mentor_requests = current_user.received_mentor_requests.includes(student: :member)
    sent_mentor_requests = current_user.sent_mentor_requests.includes(mentor: :member)

    if @state_scope == "active".to_sym
      @mentor_requests = mentor_requests.active.order("created_at desc")
      @sent_by_me_requests_count = sent_mentor_requests.active.count
      @sent_to_me_requests_count = received_mentor_requests.active.count
    else
      @mentor_requests = mentor_requests.inactive.order("updated_at desc")
      @sent_by_me_requests_count = sent_mentor_requests.inactive.count
      @sent_to_me_requests_count = received_mentor_requests.inactive.count
    end

    if current_user.is_mentor? && current_user.can_send_mentor_request?
      @pending_requests_count = received_mentor_requests.active.count + sent_mentor_requests.active.count
      @past_requests_count = ((sent_mentor_requests.count + received_mentor_requests.count) - @pending_requests_count) 
    end

    render_success("mentor_requests/index")
  end

  def update
    new_status = STATUS[params[:status]]
    render_error_response and return unless has_access_to_update(new_status)
    if new_status == AbstractRequest::Status::ACCEPTED
      render_error_response and return unless @mentor_request.mark_accepted!
    elsif new_status == AbstractRequest::Status::REJECTED
      @mentor_request.status = AbstractRequest::Status::REJECTED
      @mentor_request.response_text = params[:response_text]
      render_error_response and return unless @mentor_request.save!
    elsif new_status == AbstractRequest::Status::WITHDRAWN
      @mentor_request.status = AbstractRequest::Status::WITHDRAWN
      @mentor_request.response_text = params[:response_text]
      render_error_response and return unless @mentor_request.save!
    else
      render_error_response and return
    end
    render_success("mentor_requests/update")
  end

  def show
    render_success("mentor_requests/show")
  end


  private

  def fetch_request
    @mentor_request = @current_program.mentor_requests.find(params[:id])
  end

  def has_access_to_mentor_requests
    MentorRequest.has_access?(current_user, @current_program)
  end

  def has_access_to_index
    has_access_to_mentor_requests || current_user.can_send_mentor_request?
  end

  def has_access_to_update(new_status)
    return false unless @mentor_request.status == AbstractRequest::Status::NOT_ANSWERED
    case new_status
    when AbstractRequest::Status::ACCEPTED, AbstractRequest::Status::REJECTED
      @mentor_request.mentor == current_user &&
      has_access_to_mentor_requests
    when AbstractRequest::Status::WITHDRAWN
      @mentor_request.student == current_user &&
      @current_program.allow_mentee_withdraw_mentor_request? &&
      current_user.can_send_mentor_request?
    else
      false
    end
  end

  def get_default_filter
    if params[:filter].present?
      params[:filter]
    elsif current_user.is_mentor?
      AbstractRequest::Filter::TO_ME
    elsif current_user.can_send_mentor_request?
      AbstractRequest::Filter::BY_ME
    end
  end

  def fetch_filter
    if @mentor_request.sender_id == current_user.id
      @filter = AbstractRequest::Filter::BY_ME
    else
      @filter = AbstractRequest::Filter::TO_ME
    end
  end

end
