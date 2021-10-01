class MeetingRequestsController < ApplicationController
  include Report::MetricsUtils
  include UsersHelper
  include MeetingsHelper
  include MeetingUtils

  skip_before_action :login_required_in_program, except: [:manage, :select_all_ids, :fetch_bulk_actions, :update_bulk_actions, :reject_with_notes, :new, :create]
  allow exec: :check_access?, only: :index
  allow user: :is_admin?, only: [:manage, :select_all_ids, :fetch_bulk_actions, :update_bulk_actions]

  before_action :set_bulk_dj_priority, only: [:fetch_bulk_actions, :update_bulk_actions]
  before_action :auth_user, only: [:update_status, :create]
  before_action :fetch_meeting_request, only: [:update_status, :reject_with_notes, :propose_slot_popup]
  before_action :fetch_mentor_request, only: [:new, :create]
  before_action :set_up_filter_params, only: [:index, :manage, :select_all_ids, :fetch_bulk_actions, :update_bulk_actions]
  before_action :process_abstract_view_params, only: :manage
  before_action :set_user, only: [:update_status, :reject_with_notes, :create]
  allow exec: :can_update_status?, only: [:update_status, :reject_with_notes]
  allow exec: :check_can_allow_request_type_change_from_mentor_to_meeting, only: [:new, :create]
  before_action :get_user_setting , only: [:update_status, :reject_with_notes, :create]

  STATE_MAPPER = {
    active: "feature.meeting_request.label.pending".translate,
    accepted: "feature.meeting_request.label.accepted".translate,
    rejected: "feature.meeting_request.label.declined".translate,
    withdrawn: "feature.meeting_request.label.withdrawn".translate,
    closed: "feature.meeting_request.label.closed".translate
  }

  module EmailAction
    SHOW = "show"
    DECLINE = "decline"
    ACCEPT_AND_PROPOSE = "accept_and_propose"
  end

  def index
    return unless auth_in_program
    page = params[:page] || 1
    @filter_field = get_filter_field(params[:filter])
    @allow_multi_view = current_user.has_multiple_default_roles?
    @source = params[:src].to_s
    if @filter_field == AbstractRequest::Filter::TO_ME
      meeting_requests_scope = current_user.received_meeting_requests.send_only(@status_type, meeting_request_filter_states).order(@filter_params[:sort_field] => @filter_params[:sort_order])
      @email_meeting_request_id, @email_action = [params.delete(:email_meeting_request_id), params.delete(:email_action)]
      page = params[:page] = handle_email_action(current_user, @email_meeting_request_id, @status_type, meeting_requests_scope) if @email_meeting_request_id
      @meeting_requests = meeting_requests_scope.includes(:meeting_proposed_slots).paginate(page: page)
      # Accept/Decline popup of meeting request corresponding to meeting_request_id is opened
      if @status_type == MeetingRequest::Filter::ACTIVE && params[:meeting_request_id].present? && params[:meeting_request_status].present?
        @meeting_request = meeting_requests_scope.find_by(id: params[:meeting_request_id])
        @meeting_request_status = params[:meeting_request_status].to_i
      end
      @title = "feature.meeting_request.header.received_meeting_req_v1".translate(:Meeting => _Meeting)
    elsif @filter_field == AbstractRequest::Filter::BY_ME
      @meeting_requests = current_user.sent_meeting_requests.send_only(@status_type, meeting_request_filter_states).includes(:meeting_proposed_slots).paginate(:page => page).order(@filter_params[:sort_field] => @filter_params[:sort_order])
      @title = "feature.meeting_request.header.sent_meeting_req_v1".translate(:Meeting => _Meeting)
    elsif @filter_field == AbstractRequest::Filter::ALL
      @with_bulk_actions = (@status_type == MeetingRequest::Filter::ACTIVE)
      @meeting_requests = @current_program.meeting_requests.send_only(@status_type, meeting_request_filter_states).includes(:meeting_proposed_slots).paginate(:page => page).order(@filter_params[:sort_field] => @filter_params[:sort_order])
      @title = "feature.meeting_request.header.all_meeting_req".translate(:Meeting => _Meeting)
    end
  end

  def update_status
    update_meeting_details(params)
    update_status_for_meeting_request(params) if is_valid_meeting_request_details?(params)
  end

  def new
    student = @mentor_request.student
    new_meeting = student.member.meetings.new(program: current_program)
    @meeting_request = current_program.meeting_requests.build(student: student, mentor: current_user, show_in_profile: false, meeting: new_meeting, status: AbstractRequest::Status::NOT_ANSWERED)
    render partial: "meeting_requests/propose_slot_popup", :locals => {meeting_request: @meeting_request, allowed_individual_slot_duration: @current_program.get_calendar_slot_time, is_dual_request_mode: true, mentor_request_id: @mentor_request.id }
  end

  def create
    meeting = construct_meeting({}, nil, get_meeting_params)
    meeting.skip_email_notification = true
    begin
      ActiveRecord::Base.transaction do
        meeting.save!
        @meeting_request = meeting.meeting_request
        @meeting_request.skip_email_notification = false
        @new_status = AbstractRequest::Status::ACCEPTED
        update_meeting_details(params.merge(is_dual_request_mode: true))
        raise unless is_valid_meeting_request_details?(params)

        update_status_for_meeting_request(params)
        @meeting_request.update_attributes!(allowed_request_type_change: AbstractRequest::AllowedRequestTypeChange::MENTOR_REQUEST_TO_MEETING_REQUEST)
        @mentor_request.destroy
      end
    rescue => _e
      flash[:error] = "flash_message.user_flash.meeting_creation_failure_v1".translate(:meeting => _meeting)
    end

    render action: :update_status unless performed?
  end

  def get_meeting_params
    student = @mentor_request.student.member
    meeting_topic = [wob_member, student].collect(&:last_name).to_sentence(last_word_connector: LAST_WORD_CONNECTOR, two_words_connector: TWO_WORDS_CONNECTOR)

    {
      is_non_time_meeting: true,
      topic: meeting_topic,
      description: @mentor_request.message,
      attendee_ids: [wob_member.id, student.id],
      owner_member: student,
      is_dual_request_mode: true,
      program: @current_program,
    }
  end

  def get_user_setting
    @user_setting = UserSetting.find_or_initialize_by(user_id: @user.id)
  end

  def reject_with_notes
    if params[:meeting_request][:rejection_type].to_i == AbstractRequest::Rejection_type::REACHED_LIMIT
      @limit_updated = @user_setting.update_limit_based_on_reason
    end
    update_status_for_meeting_request(params)
  end

  def manage
    @metric = get_source_metric(current_program, params[:metric_id])
    @from_date_range, @to_date_range = ReportsFilterService.get_report_date_range(params[:filters], @current_program.created_at)
    @meeting_requests = get_filtered_meeting_requests
    @src_path = params[:src]
    @is_manage_view = true
    @with_bulk_actions = @is_manage_view && (@status_type == MeetingRequest::Filter::ACTIVE)
    @meeting_requests = @meeting_requests.order(@filter_params[:sort_field] => @filter_params[:sort_order])
    @title = "feature.meeting_request.header.manage_meeting_requests_v1".translate(:Meeting => _Meeting)
    activate_tab(tab_info[TabConstants::MANAGE])
    @filter_params = @filter_params.merge({on_select_function: "MeetingRequests.changeSortOptions"})
    if request.format == Mime[:csv]
      export_requests_to_csv(@meeting_requests, @status_type)
    else
      @meeting_requests = @meeting_requests.paginate(page: @params_with_abstract_view_params[:page] || 1)
      render action: :index if request.format == FORMAT::HTML
    end
  end

  def select_all_ids
    default_filter = {program_id: current_program.id}
    meeting_request_ids = []
    sender_ids = []
    receiver_ids = []
    if current_user.is_admin?
      @meeting_requests = build_meeting_requests
      @meeting_requests.each do |meeting_request|
        meeting_request_ids << meeting_request.id.to_s
        sender_ids << meeting_request.sender_id
        receiver_ids << meeting_request.receiver_id
      end
    end
    render :json => {meeting_request_ids: meeting_request_ids, sender_ids: sender_ids, receiver_ids: receiver_ids}
  end

  def fetch_bulk_actions
    @meeting_request = @current_program.meeting_requests.build
    is_manage_view = params[:bulk_action][:is_manage_view].to_s.to_boolean
    request_type = params[:bulk_action][:request_type]
    meeting_request_ids = params[:bulk_action][:meeting_request_ids].split(IDS_SEPARATOR)
    case request_type.to_i
    when AbstractRequest::Status::CLOSED
      render :partial => "meeting_requests/close_request_popup", :locals => {meeting_request_ids: meeting_request_ids, is_manage_view: is_manage_view}
    end
  end

  def update_bulk_actions
    is_manage_view = params[:is_manage_view].to_s.to_boolean
    request_type = params[:bulk_actions][:request_type]
    meeting_request_ids = params[:bulk_actions][:meeting_request_ids].split(IDS_SEPARATOR)
    meeting_requests = @current_program.meeting_requests.by_ids(meeting_request_ids)
    case request_type.to_i
    when AbstractRequest::Status::CLOSED
      meeting_requests.active.update_all({
        response_text: params[:meeting_request][:response_text],
        status: AbstractRequest::Status::CLOSED,
        closed_by_id: current_user.id,
        closed_at: Time.now,
      })
      meeting_requests.reload
      MeetingRequest.send_close_request_mail(meeting_requests.closed, params[:sender], params[:recipient]).delay
      closed_meeting_requests_count = meeting_requests.closed.count
      unless closed_meeting_requests_count > 1
        @notice = "flash_message.meeting_request_flash.one_closed".translate(meeting: _meeting)
      else
        @notice = "flash_message.meeting_request_flash.other_closed".translate(count: closed_meeting_requests_count, meeting: _meeting)
      end
      @back_url = session[:last_visit_url] unless is_manage_view
    end
  end

  def propose_slot_popup
    render partial: "meeting_requests/propose_slot_popup", :locals => {:meeting_request => @meeting_request, :allowed_individual_slot_duration => @current_program.get_calendar_slot_time, :source => params[:src].to_s}
  end

  private

  def get_filtered_meeting_requests
    mrfs = MeetingRequestsFilterService.new(@current_program, params[:filters] || {})
    meeting_request_ids, prev_period_meeting_request_ids = mrfs.get_filtered_meeting_request_ids
    meeting_requests = MeetingRequest.where(id: meeting_request_ids)

    get_scoped_meeting_requests(meeting_requests)
    
    @percentage, @prev_periods_count = ReportsFilterService.set_percentage_from_ids(prev_period_meeting_request_ids, meeting_request_ids)
    @prev_periods_count = 0 if prev_period_meeting_request_ids.blank?

    filtered_meeting_requests = case @status_type
    when MeetingRequest::Filter::ACTIVE
      @meeting_request_hash[:active_meeting_requests]
    when MeetingRequest::Filter::ACCEPTED
      @meeting_request_hash[:accepted_meeting_requests]
    when MeetingRequest::Filter::REJECTED
      @meeting_request_hash[:rejected_meeting_requests]
    when MeetingRequest::Filter::WITHDRAWN
      @meeting_request_hash[:withdrawn_meeting_requests]
    when MeetingRequest::Filter::CLOSED
      @meeting_request_hash[:closed_meeting_requests]
    end
    return filtered_meeting_requests
  end

  def get_scoped_meeting_requests(meeting_requests)
    @meeting_request_hash = {active_meeting_requests: meeting_requests.active, accepted_meeting_requests: meeting_requests.accepted, rejected_meeting_requests: meeting_requests.rejected, withdrawn_meeting_requests: meeting_requests.withdrawn, closed_meeting_requests: meeting_requests.closed, all_meeting_requests:  meeting_requests}
  end

  def get_flash_for_rejection
    mentee_name = @meeting_request.student.name(name_only: true)
    rejected_request_string = "flash_message.meeting_request_flash.rejected_request_flash_v2".translate(mentee_name: mentee_name)
    link_for_setting = view_context.link_to("display_string.profile_settings".translate, edit_member_path(wob_member, scroll_to: "max_meeting_slots_"+current_user.program_id.to_s, focus_settings_tab: true))
    limit_reached_string = "flash_message.meeting_request_flash.rejected_request_flash_limit_change_v3_html".translate(meeting: _meeting, profile_settings: link_for_setting, mentee_name: mentee_name)

    if @limit_updated
      return limit_reached_string
    else
      return rejected_request_string
    end
  end

  def update_status_for_meeting_request(options)
    url_options = {}

    if @meeting_request.active?
      DelayedEsDocument.skip_es_delta_indexing(auto_reindex: true) do
        @meeting_request.update_status!(@user, @new_status, member: @member, program: current_program, response_text: (options[:responseText] || options[:meeting_request].try(:[], :response_text)), acceptance_message: options[:acceptanceMessage] || options[:slotMessage], rejection_type: options[:meeting_request].try(:[], :rejection_type))
        @meeting_request.update_attributes!(accepted_at: Time.now) if @meeting_request.accepted?
      end
      flash[:notice] = get_flash_message_for_meeting(options)
      @source = options[:src]
      if @meeting_request.accepted?
        @meeting = @meeting_request.get_meeting
        @occurrence_time = @meeting.occurrences.first.start_time.in_time_zone(Time.zone)
        track_accept_meeting_request_ei_activity(options[:additional_info])
        redirect_to meeting_path(@meeting, current_occurrence_time: @occurrence_time, ei_src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_LISTING, src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_ACCEPTANCE) and return unless request.xhr?
      elsif @meeting_request.rejected? && [EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE, EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE].include?(@source)
        redirect_to_back_mark_or_default meeting_requests_path
        return true
      end
    else
      flash[:error] = "flash_message.meeting_request_flash.cannot_update_#{AbstractRequest::Status::STATE_TO_STRING[@meeting_request.status]}_v1".translate(:meeting => _meeting)
    end
    redirect_to meeting_requests_path(url_options) unless request.xhr?
  end

  def track_accept_meeting_request_ei_activity(additional_info)
    program = @meeting.program
    track_sessionless_activity_for_ei(EngagementIndex::Activity::ACCEPT_MEETING_REQUEST, @member, program.organization, {context_place: @source, context_object: additional_info, user: @member.user_in_program(program), program: program, browser: browser})
  end

  def handle_email_action(user, email_meeting_request_id, status_type, meeting_requests_scope)
    page = 1
    if email_meeting_request_id
      email_meeting_request = user.received_meeting_requests.find_by(id: email_meeting_request_id)
      if email_meeting_request.blank?
        flash.now[:error] = "flash_message.meeting_request_flash.not_found".translate(meeting: _meeting)
      elsif AbstractRequest::Status::STATUS_TO_SCOPE[email_meeting_request.status].to_s == status_type
        page = ((meeting_requests_scope.order(@filter_params[:sort_field] => @filter_params[:sort_order]).pluck(:id).in_groups_of(PER_PAGE).index{|ary|ary.include?(email_meeting_request.id)} || 0) + 1)
      else
        flash.now[:notice] = "flash_message.meeting_request_flash.moved_to_status".translate(meeting: _meeting, status: STATE_MAPPER[AbstractRequest::Status::STATUS_TO_SCOPE[email_meeting_request.status]])
      end
    end
    page
  end

  def update_meeting_details(options)
    ##if the accepted meeting time is from proposed slots then update the meeting time with the slot time
    ## If slot time is present then "calendar_time_available" field for the meeting is set to true
    return unless @meeting_request.active?

    common_options = {skip_rsvp_change_email: true, calendar_time_available: true}
    if options[:slot_id].present? #accepting the slot proposed by student
      proposed_slot = @meeting_request.meeting_proposed_slots.find_by(id: params[:slot_id])
      @meeting_request.meeting.update_meeting_time(proposed_slot.start_time, (proposed_slot.end_time - proposed_slot.start_time), common_options.merge(location: proposed_slot.location, all_attending: true, meeting_time_zone: @meeting_request.meeting.owner.get_valid_time_zone))
      @create_scrap = true
    elsif options[:proposedSlot].present?
      slot_options = options[:proposedSlot]
      slot_date = get_en_datetime_str(slot_options[:date])
      start_time, end_time = MentoringSlot.fetch_start_and_end_time(slot_date, slot_options[:startTime], slot_options[:endTime])
      @is_valid_proposed_slot = is_valid_slot?(start_time)
      return unless @is_valid_proposed_slot
      @meeting_request.meeting_proposed_slots.create!({start_time: start_time, end_time: end_time, location: slot_options[:location], proposer_id: @meeting_request.receiver_id})
      @meeting_request.meeting.update_meeting_time(start_time, (end_time - start_time), common_options.merge(location: slot_options[:location], updated_by_member: wob_member, meeting_time_zone: wob_member.get_valid_time_zone))
      @create_scrap = true
    elsif options[:acceptanceMessage].present?
      @meeting_request.meeting.update_attributes!(calendar_time_available: false)
      @is_valid_message = true
      @create_scrap = true
    elsif options[:status].to_i == AbstractRequest::Status::ACCEPTED && @meeting_request.status != AbstractRequest::Status::ACCEPTED
      @create_scrap = true
    end
    create_meeting_scrap(options) if @create_scrap && @meeting_request.active?
  end

  def auth_in_program
    unless logged_in_program?
      flash.keep
      login_required_in_program
      return false
    end
    true
  end

  def get_filter_field(filter_field)
    return filter_field unless is_valid_filter_field?(filter_field)
    return AbstractRequest::Filter::TO_ME if current_user.is_mentor?
    return AbstractRequest::Filter::BY_ME if current_user.is_student?
    return AbstractRequest::Filter::ALL if current_user.is_admin?
  end

  def is_valid_filter_field?(filter_field)
    !filter_field || !AbstractRequest::Filter.all.include?(filter_field) ||
    is_non_mentor_filter_field?(filter_field) ||
    is_non_student_filter_field?(filter_field) ||
    is_non_admin_filter_field?(filter_field)    
  end

  def is_non_mentor_filter_field?(filter_field)
    !current_user.is_mentor? && (filter_field == AbstractRequest::Filter::TO_ME)
  end

  def is_non_student_filter_field?(filter_field)
    !current_user.is_student? && (filter_field == AbstractRequest::Filter::BY_ME)
  end

  def is_non_admin_filter_field?(filter_field)
    !current_user.is_admin? && (filter_field == AbstractRequest::Filter::ALL)
  end

  def set_up_filter_params
    @status_type = MeetingRequest::Filter::ACTIVE
    if params[:list].present? && !(params[:filter] == AbstractRequest::Filter::TO_ME && params[:list] == MeetingRequest::Filter::WITHDRAWN)
      @status_type = params[:list]
    end
    date_range = params[:filters][:date_range] if params[:filters].present?
    @filter_params = {list: params[:list]}
    @filter_params = @filter_params.merge({date_range: date_range})
    CommonSortUtils.fill_user_sort_input_or_defaults!(@filter_params, params)
  end

  def build_meeting_requests
    @current_program.meeting_requests.send_only(@status_type, meeting_request_filter_states)
  end

  def export_requests_to_csv(meeting_requests, status_type)
    csv_file_name = "#{STATE_MAPPER[status_type.to_sym]} #{"feature.meeting_request.header.title_v1".translate(:Meeting => _Meeting)} #{DateTime.localize(Time.current, format: :csv_timestamp)}".to_html_id
    CSVStreamService.new(response).setup!("#{csv_file_name}.csv", self) do |stream|
      MeetingRequestReport::CSV.export_to_stream(stream, meeting_requests, status_type, wob_member)
    end
  end

  def check_access?
    !logged_in_program? || current_user.is_mentor_or_student?
  end

  def auth_user
    @member = @current_organization.members.select([:id, :calendar_api_key, :terms_and_conditions_accepted]).where(calendar_api_key: params[:secret]).first
    redirect_to program_root_path if @member.blank?
  end

  def fetch_meeting_request
    @meeting_request = @current_program.meeting_requests.find_by(id: params[:id])
    if @meeting_request.blank?
      flash[:error] = "flash_message.mentor_request_flash.invalid_request".translate
      redirect_path = logged_in_program? ? meeting_requests_path : program_root_path
      redirect_to redirect_path
    end
  end

  def fetch_mentor_request
    @mentor_request = current_user.received_mentor_requests.find_by(id: params[:mentor_request_id])
    return if @mentor_request.present?

    flash[:error] = "flash_message.mentor_request_flash.invalid_request".translate
    redirect_path = logged_in_program? ? mentor_requests_path(params.to_unsafe_h.pick(:filter, :list, :sort_field, :sort_order, :page)) : program_root_path

    respond_to do |format|
      format.html { render partial: "common/redirect_to", locals: { redirect_path: redirect_path } }
      format.js { redirect_ajax(redirect_path) }
    end
  end

  def check_can_allow_request_type_change_from_mentor_to_meeting
    @mentor_request.can_convert_to_meeting_request?
  end

  def set_user
    @user = current_user || @member.user_in_program(current_program)
  end

  def can_update_status?
    @new_status = params[:status].to_i
    @user.present? &&
      ((@user.is_mentor? && @meeting_request.mentor == @user && [AbstractRequest::Status::ACCEPTED, AbstractRequest::Status::REJECTED].include?(@new_status)) ||
      (@user.is_student? && @meeting_request.student == @user && AbstractRequest::Status::WITHDRAWN == @new_status))
  end

  def process_abstract_view_params
    if params[:abstract_view_id] && (@abstract_view = @current_program.abstract_views.find(params[:abstract_view_id]))
      alert = @abstract_view.alerts.find_by(id: params[:alert_id])
      filter_params = alert.present? ? FilterUtils.process_filter_hash_for_alert(@abstract_view, @abstract_view.filter_params_hash, alert) : @abstract_view.filter_params_hash
      @params_with_abstract_view_params = params.reverse_merge(ActionController::Parameters.new(filter_params).permit!)
    else
      @params_with_abstract_view_params = params
    end
  end

  def get_flash_message_for_meeting(options)
    if  @meeting_request.status == AbstractRequest::Status::ACCEPTED
      if !logged_in_program? && params[:src] == EngagementIndex::Src::AccessFlashMeetingArea::EMAIL
        current_time = @meeting_request.meeting.first_occurrence
        meeting_count = @user.get_meeting_slots_booked_in_the_month(current_time)
        flash_message = "feature.meetings.content.successful_connect".translate + ". " + view_context.get_meeting_accept_message(@meeting_request.meeting, meeting_count, current_time, false, @user)
      end
    elsif @meeting_request.status == AbstractRequest::Status::REJECTED
      flash_message = get_flash_for_rejection
    else
      flash_message = "flash_message.meeting_request_flash.status_update_#{AbstractRequest::Status::STATE_TO_STRING[@meeting_request.status]}_v1".translate(:meeting => _meeting)
    end
    return flash_message
  end

  def is_valid_slot?(start_time)
    start_time.utc > Time.now.utc
  end

  def is_valid_meeting_request_details?(options)
    return true unless options[:proposedSlot].present?
    @is_valid_proposed_slot
  end

  def create_meeting_scrap(options)
    scrap = @meeting_request.meeting.scraps.new
    scrap.program = @meeting_request.meeting.program
    scrap.sender = @meeting_request.mentor.member
    scrap.receivers = [@meeting_request.student.member]
    scrap.subject = "feature.meeting_request.content.accepted_request_scrap_subject".translate(mentor_name: @meeting_request.mentor.name, meeting: _meeting)
    scrap.content = get_message_content_for_scrap(options)
    scrap.no_email_notifications = true
    scrap.save!
  end

  def get_message_content_for_scrap(options)
    return (options[:acceptanceMessage].presence || options[:slotMessage].presence) if options[:is_dual_request_mode].present?

    if options[:proposedSlot].present?
      if options[:slotMessage].present?
        "feature.meeting_request.content.accepted_and_proposed_slot_with_message".translate(meeting: _meeting, message: options[:slotMessage])
      else
        "feature.meeting_request.content.accepted_and_proposed_slot_text".translate(meeting: _meeting)
      end
    elsif options[:acceptanceMessage].present?
      "feature.meeting_request.content.accepted_with_message_text".translate(meeting: _meeting, message: options[:acceptanceMessage])
    else
      "feature.meeting_request.content.accepted_with_slot_text".translate(meeting: _meeting)
    end
  end

  def meeting_request_filter_states
    if @is_manage_view || (@filter_field == AbstractRequest::Filter::BY_ME) || current_user.is_admin?
      MeetingRequest::Filter.states
    else
      MeetingRequest::Filter.states - [MeetingRequest::Filter::WITHDRAWN]
    end
  end
end