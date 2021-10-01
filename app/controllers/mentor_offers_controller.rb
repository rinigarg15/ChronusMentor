class MentorOffersController < ApplicationController
  SEPARATOR = ","

  before_action :set_bulk_dj_priority, only: [:fetch_bulk_actions, :update_bulk_actions]
  before_action :set_up_filter_params, only: [:index, :select_all_ids, :manage]
  before_action :fetch_offer, only: [:update]

  allow user: :is_admin?, only: [:select_all_ids, :fetch_bulk_actions, :update_bulk_actions, :manage]
  allow :user => :can_offer_mentoring?, only: [:new, :create]
  allow :exec => :check_program_has_ongoing_mentoring_enabled
  allow exec: :check_access_to_index_and_manage, only: [:index, :manage]

  def new
    @student = @current_program.student_users.find(params[:student_id])
    @mentor = current_user
    @existing_connections_of_mentor = @mentor.mentoring_groups.active
    @can_add_to_existing_group = @current_program.allow_one_to_many_mentoring? && @existing_connections_of_mentor.any?
    @src = params[:src]
    render partial: "users/offer_mentoring"
  end

  def create
    @student = @current_program.student_users.find(params[:student_id])
    @message = params[:message].presence
    @group = @current_program.groups.find(params[:group_id]) if params[:group_id].present?

    if !current_user.can_mentor?
      if @current_program.allow_mentor_update_maxlimit?
        @error_flash = "flash_message.group_flash.limit_for_mentor_reached".translate(mentoring_connections: _mentoring_connections)
      else
        @error_flash = "flash_message.group_flash.limit_for_mentor_reached_cannot_update".translate(mentoring_connections: _mentoring_connections)
      end
    elsif @student.connection_limit_as_mentee_reached?
      @error_flash = "flash_message.group_flash.limit_for_mentee_exceeded_for_mentor_offer".translate(mentoring: _mentoring, mentee: @student.member.name, mentoring_connections: _mentoring_connection)
    elsif @current_program.mentor_offer_needs_acceptance?
      handle_mentoring_offer_by_mentor
    else
      handle_mentee_addition_by_mentor
    end
    track_activity_for_ei(EngagementIndex::Activity::SEND_MENTORING_OFFER, {:context_place => params[:src]}) unless @error_flash
    flash[:error] = @error_flash if @error_flash

    if @error_flash || @current_program.mentor_offer_needs_acceptance?
      redirect_to_back_mark_or_default(users_path(:view => RoleConstants::STUDENTS_NAME))
    else
      redirect_to group_path(@group)
    end
  end

  def index
    @mentor_offer_partial = @filter_params[:filter_field] == AbstractRequest::Filter::ALL ? 'mentor_offer_for_admin' : 'mentor_offer'
    @received_offers_view = @filter_params[:filter_field] == AbstractRequest::Filter::TO_ME
    @title = "feature.mentor_offer.title.#{@filter_params[:filter_field]}".translate(Mentoring: _Mentoring)
    @mentor_offers = build_mentor_offers
  end

  def manage
    @mentor_offer_partial = 'mentor_offer_for_admin'
    @title = "feature.mentor_offer.title.all".translate(Mentoring: _Mentoring)
    @mentor_offers = get_filtered_mentoring_offers.order(@filter_params[:sort_field] => @filter_params[:sort_order]).paginate(page: @filter_params[:page], per_page: PER_PAGE)
    mentor_offer_ids = MentorOffer.where(id: @mentor_offers.collect(&:id))

    respond_to do |format|
      format.csv do
        export_mentor_offers(mentor_offer_ids)
      end

      format.html do
      end
      
      format.js do
      end
    end
  end

  def update
    new_status = params[:mentor_offer][:status].to_i
    check_access = (new_status == MentorOffer::Status::WITHDRAWN) ? check_access_to_withdraw : check_access_accept_or_reject
    allow! :exec => Proc.new { check_access }
    if new_status == MentorOffer::Status::ACCEPTED
      if current_user.connection_limit_as_mentee_reached?
        flash[:error] = "flash_message.mentor_request_flash.acceptance_failed_v2_html".translate(:mentoring_connections => _mentoring_connections)
        redirect_to mentor_offers_path
      elsif !@mentor_offer.can_be_accepted_based_on_mentors_limits?
        flash[:error] = "flash_message.mentor_offer_flash.acceptance_failed_mentor_limit_html".translate(mentor: @mentor_offer.mentor.name, mentoring_connections: _mentoring_connections)
        redirect_to mentor_offers_path
      else
        @mentor_offer.mark_accepted!(@mentor_offer.group)
        track_activity_for_ei(EngagementIndex::Activity::ACCEPT_MENTORING_OFFER)
        @group = @mentor_offer.group
        flash[:notice] = "flash_message.mentor_offer_flash.mentee_accepts_request_v1".translate(mentor: @mentor_offer.mentor.name, :mentoring_connection => _mentoring_connection)
        redirect_to group_path(@group)
      end
    elsif new_status == MentorOffer::Status::REJECTED
      @mentor_offer.update_attributes(:status => MentorOffer::Status::REJECTED, :response => params[:mentor_offer][:response])
      flash[:notice] = "flash_message.mentor_offer_flash.offer_rejected".translate(mentor: @mentor_offer.mentor.name)
      redirect_to mentor_offers_path
    elsif new_status == MentorOffer::Status::WITHDRAWN
      allow! :exec => Proc.new { check_access_to_withdraw }
      @mentor_offer.update_attributes(:status => MentorOffer::Status::WITHDRAWN, :response => params[:mentor_offer][:response])
      flash[:notice] = "flash_message.mentor_offer_flash.offer_withdrawn".translate(mentor: @mentor_offer.mentor.name)
      redirect_to mentor_offers_path
    end
  end

  def fetch_bulk_actions
    is_manage_view = params[:bulk_action][:is_manage_view].to_s.to_boolean
    @mentor_offer = @current_program.mentor_offers.build
    offer_status = params[:bulk_action][:offer_status]
    mentor_offer_ids = params[:bulk_action][:mentor_offer_ids]
    case offer_status.to_i
    when MentorOffer::Status::CLOSED
      render :partial => "mentor_offers/close_offer_popup", :locals => {:mentor_offer_ids => mentor_offer_ids, is_manage_view: is_manage_view}
    end
  end

  def update_bulk_actions
    is_manage_view = params[:is_manage_view].to_s.to_boolean
    offer_status = params[:bulk_actions][:offer_status]
    mentor_offer_ids = params[:bulk_actions][:mentor_offer_ids].split(" ")
    mentor_offers = @current_program.mentor_offers.pending.where(id: mentor_offer_ids)
    case offer_status.to_i
    when MentorOffer::Status::CLOSED
      mentor_offers.each do |mentor_offer|
        mentor_offer.response = params[:mentor_offer][:response]
        mentor_offer.status = MentorOffer::Status::CLOSED
        mentor_offer.closed_by = current_user
        mentor_offer.closed_at = Time.now
        mentor_offer.save!
      end
      MentorOffer.delay.send_close_offer_mail(mentor_offers.collect(&:id), params[:sender], params[:recipient])
      @notice = "flash_message.mentor_offer_flash.closed".translate(count: mentor_offers.size)
      @back_url = session[:last_visit_url] unless is_manage_view
    end
  end

  def select_all_ids
    default_filter = {program_id: current_program.id}
    mentor_offer_ids = []
    sender_ids = []
    receiver_ids = []
    @mentor_offers = MentorOffer.get_filtered_mentor_offers(@filter_params)
    mentor_offer_ids = @mentor_offers.map(&:id).map(&:to_s)
    sender_ids = @mentor_offers.map(&:mentor_id)
    receiver_ids = @mentor_offers.map(&:student_id)
    render :json => {mentor_offer_ids: mentor_offer_ids, sender_ids: sender_ids, receiver_ids: receiver_ids}
  end

  def export
    mentor_offer_ids = params[:mentor_offer_ids].split(MentorOffersController::SEPARATOR)
    respond_to do |format|
      format.csv do
        export_mentor_offers(mentor_offer_ids)
      end
    end
  end

  private

  def get_filtered_mentoring_offers
    mentor_offers = @current_program.mentor_offers
    get_scoped_mentor_offers(mentor_offers)

    filtered_mentor_offers = case @filter_params["status"]
    when MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::PENDING]
      @mentor_offer_hash[:pending_mentor_offers]
    when MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::ACCEPTED]
      @mentor_offer_hash[:accepted_mentor_offers]
    when MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::REJECTED]
      @mentor_offer_hash[:rejected_mentor_offers]
    when MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::WITHDRAWN]
      @mentor_offer_hash[:withdrawn_mentor_offers]
    when MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::CLOSED]
      @mentor_offer_hash[:closed_mentor_offers]
    end
    return filtered_mentor_offers
  end

  def get_scoped_mentor_offers(mentor_offers)
    @mentor_offer_hash = {pending_mentor_offers: mentor_offers.pending, accepted_mentor_offers: mentor_offers.accepted, rejected_mentor_offers: mentor_offers.rejected, withdrawn_mentor_offers: mentor_offers.withdrawn, closed_mentor_offers: mentor_offers.closed, all_mentor_offers: mentor_offers}
  end

  def build_mentor_offers
    filter_field = @filter_params[:filter_field]
    mentor_offers = case filter_field 
    when AbstractRequest::Filter::ALL
      @current_program.mentor_offers
    when AbstractRequest::Filter::TO_ME
      current_user.received_mentor_offers
    when AbstractRequest::Filter::BY_ME 
      current_user.sent_mentor_offers
    end
    return mentor_offers.order(@filter_params[:sort_field] => @filter_params[:sort_order]).send(@filter_params["status"].to_sym).paginate(page: @filter_params[:page], per_page: PER_PAGE)
  end

  def check_access_to_index_and_manage
    @current_program.mentor_offer_enabled? &&
    @current_program.mentor_offer_needs_acceptance? &&
    current_user.is_admin_or_mentor_or_student?
  end

  def check_access_to_withdraw
    current_user.can_offer_mentoring? && @mentor_offer.mentor == current_user
  end

  def check_access_accept_or_reject
    current_user.is_student? && @mentor_offer.student == current_user
  end

  def set_up_filter_params
    page = params[:page].to_i
    params_to_pick = [:action, :controller, :format, :root, :filter]
    @filter_params = ActiveSupport::HashWithIndifferentAccess.new
    @filter_params[:filter_field] = get_filter_field
    @filter_params[:status] = params[:status] || MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::PENDING]
    @filter_params[:page] = page > 0 ? page : 1
    CommonSortUtils.fill_user_sort_input_or_defaults!(@filter_params, params)
    @filter_params.merge!(params.permit(params_to_pick))
    @filter_params.merge!(user_id: current_user.id, program_id: @current_program.id)
  end

  def fetch_offer
    @mentor_offer = current_program.mentor_offers.find_by(id: params[:id])
    error_message = if @mentor_offer.blank?
      "flash_message.mentor_offer_flash.invalid_offer".translate
    elsif !@mentor_offer.pending?
      get_status_based_message(@mentor_offer.status)
    end
    if error_message.present?
      flash[:error] = error_message
      redirect_to mentor_offers_path
    end
  end

  def get_filter_field
    filter = params[:filter]
    if filter.present?
      case filter
      when AbstractRequest::Filter::ALL
        return filter if current_user.is_admin?
      when AbstractRequest::Filter::TO_ME
        return filter if current_user.is_student?
      when AbstractRequest::Filter::BY_ME
        return filter if current_user.is_mentor?
      else
        return get_filter_field_when_not_passed
      end
      redirect_to mentor_offers_path and return
    else
      get_filter_field_when_not_passed
    end
  end

  def get_filter_field_when_not_passed
    if current_user.is_admin?
      AbstractRequest::Filter::ALL
    elsif current_user.is_student?
      AbstractRequest::Filter::TO_ME
    elsif current_user.is_mentor?
      AbstractRequest::Filter::BY_ME
    else
      # user role does not have permission to access mentor offer listing
      raise Authorization::PermissionDenied
    end
  end

  def handle_mentoring_offer_by_mentor
    @mentor_offer = @current_program.mentor_offers.new
    @mentor_offer.mentor = current_user
    @mentor_offer.student = @student
    @mentor_offer.group = @group
    @mentor_offer.message = @message
    @mentor_offer.status = MentorOffer::Status::PENDING
    if @mentor_offer.save
      flash[:notice] = "flash_message.mentor_offer_flash.mentee_offer_v1".translate(mentee: @student.name, mentoring: _mentoring)
    else
      @error_flash = @mentor_offer.errors.full_messages.to_sentence
    end
  end

  def handle_mentee_addition_by_mentor
    @group ||= @current_program.groups.new
    @group.actor = current_user
    @group.offered_to = @student
    @group.message = @message
    student_name = @student.member.name
    if @group.new_record?
      @group.mentors = [current_user]
      @group.students = [@student]
      @group.save!
      flash[:notice] = "flash_message.mentor_offer_flash.mentee_added_new_group_v1".translate(mentee: student_name, :mentoring_connection => _mentoring_connection)
    else
      student_objs = [@student, @group.students].flatten
      @group.update_members(@group.mentors, student_objs, current_user)
      if @group.errors.presence
        @error_flash = @group.errors.full_messages.to_sentence
      else
        flash[:notice] = "flash_message.mentor_offer_flash.mentee_added_existing_group_v1".translate(mentee: student_name, :mentoring_connection => _mentoring_connection)
      end
    end
  end

  def get_status_based_message(status)
    status_string = case status
    when MentorOffer::Status::ACCEPTED
      'display_string.accepted'.translate
    when MentorOffer::Status::REJECTED
      'display_string.declined'.translate
    when MentorOffer::Status::WITHDRAWN
      'display_string.withdrawn'.translate
    when MentorOffer::Status::CLOSED
      'display_string.closed'.translate
    end
    "flash_message.mentor_offer_flash.past_status_message".translate(status: status_string) if status_string.present?
  end

  def export_mentor_offers(mentor_offer_ids)
    file_name = MentorOffer.export_file_name(@current_program, params[:status] == 'active' ? 'pending' : params[:status], :csv)
    CSVStreamService.new(response).setup!(file_name, self) do |stream|
      MentorOffer.export_to_stream(stream, current_user, mentor_offer_ids)
    end
  end
end