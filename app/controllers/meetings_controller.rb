class MeetingsController < ApplicationController
  include AuthenticationForExternalServices
  include MeetingsHelper

  module MentoringSessionConstants
    DEFAULT_LIMIT = 1.week
  end

  module CalendarSessionConstants
    DEFAULT_LIMIT = 1.month

    module DashboardFilter
      ALL = 'all'
      UPCOMING = 'upcoming'
      PAST = 'past'
      COMPLETED = 'completed'
    end
  end

  include ConnectionFilters
  include MentoringModelUtils
  include UsersHelper
  include UserListingExtensions
  include MeetingUtils

  MEETINGS_COUNT_INSIDE_HOME_PAGE_CONNECTION_WIDGET = 1

  before_action :fetch_meeting, :only =>[:edit, :update, :destroy, :get_destroy_popup, :edit_state, :update_state]
  before_action :fetch_meeting_in_program, :only =>[:show, :survey_response]
  before_action :skip_side_pane, :only => [:index]
  before_action :load_meeting_and_attendee, only: :update_from_guest
  before_action :set_from_connection_home_page_widget, only: [:index, :create, :destroy, :update, :edit, :get_destroy_popup, :update_from_guest]
  before_action :set_from_meeting_area, only: [:update, :destroy, :get_destroy_popup]
  before_action :set_outside_group, only: [:index, :create, :edit, :update, :show, :update_from_guest, :destroy, :get_destroy_popup]

  common_extensions(:skip_check_group_active => true)
  before_action :compute_page_controls_allowed, :only => [:create, :update, :destroy]
  before_action :compute_past_meeting_controls_allowed, :only => [:create, :update, :destroy]
  before_action :check_user_presence, only: :mini_popup
  before_action :set_report_category, only: [:calendar_sessions, :mentoring_sessions]

  before_action :verify_signature, :verify_receiver, :only => :calendar_rsvp
  allow :exec => :check_group_active, :except => [:index, :create, :update, :destroy, :get_destroy_popup]
  skip_before_action :login_required_in_program, :only => [:ics_api_access, :update_from_guest, :get_calendar_sync_instructions_page, :update_meeting_notification_channel, :calendar_rsvp]
  
  skip_before_action :check_browser, :only => [:ics_api_access, :update_meeting_notification_channel, :calendar_rsvp]

  skip_before_action :verify_authenticity_token, :load_current_organization, :handle_inactive_organization, :load_current_root, :load_current_program, :require_organization, :require_program, only: [:update_meeting_notification_channel, :calendar_rsvp]

  after_action :mark_group_activity, :only => [:show, :edit, :get_destroy_popup, :index, :new, :destroy]

  allow :exec => :can_access_feature?, :except=>[:ics_api_access, :get_calendar_sync_instructions_page, :update_meeting_notification_channel, :calendar_rsvp]
  allow :exec => :can_access_mentoring_sessions_feature?, :only => [:mentoring_sessions]
  allow :exec => :can_access_calendar_sessions_feature?, :only => [:calendar_sessions]
  allow :exec => :check_action_access
  allow :user => :can_manage_mentoring_sessions?, :only => [:mentoring_sessions, :calendar_sessions]
  allow :exec => :can_edit_meeting?, only: [:edit, :update]

  module SourceParams
    QUICK_CONNECT = "home_page_quick_connect"
    FLASH_CALENDAR = "flash_calendar"
  end

  module MeetingsTab
    UPCOMING = "upcoming"
    PAST = "past"
  end

  module CalendarSyncResourceState
    SYNC = "sync"
    EXISTS = "exists"
    NOT_EXISTS = "not_exists"
  end


  def index
    @show_past_meetings = (params[:show_past_meetings] == "true")
    @new_private_note = @group.private_notes.new if @group.present?
    @can_current_user_create_meeting = current_user.can_create_meeting?(@current_program)
    @from_my_availability = params[:from_my_availability]
    valid_meeting = populate_feedback_id(params, current_program)
    if valid_meeting
      @ei_src = EngagementIndex::Src::UpdateMeeting::MENTORING_AREA_MEETING_LISTING unless @from_connection_home_page_widget
      initialize_meetings(@group, @is_admin_view, wob_member, current_program)
    else
      flash[:error] = "feature.meetings.flash_message.inactive_meeting".translate(meeting: _meeting)
      redirect_to root_path
    end

    if @from_connection_home_page_widget
      @can_access_tabs = can_access_tabs
      @show_meetings = show_meetings
      compute_page_controls_allowed
      @meetings_to_show = @meetings_to_be_held.present? ? [@meetings_to_be_held.first] : []
    end
  end

  def new
    @mentor = @current_organization.members.find(params[:mentor_id])
    @new_meeting = wob_member.meetings.build({:start_time => params[:start_time]})
    @allowed_individual_slot_duration = @current_program.get_calendar_slot_time
    @unlimited_slot = @current_program.calendar_setting.slot_time_in_minutes.zero?
    @new_meeting.end_time = (@unlimited_slot && params[:end_time].present?) ? params[:end_time] : (@new_meeting.start_time + @allowed_individual_slot_duration.minutes)
    @slot_duration = params[:end_time].to_time - params[:start_time].to_time
    @score = params[:score].to_i unless params[:score].blank?
    @valid_end_time = (params[:end_time].to_time - @allowed_individual_slot_duration.minutes) > (Time.now + @current_program.get_allowed_advance_slot_booking_time.hours)
    render :partial => "meetings/inadequate_slot_time" and return if (@slot_duration.to_i < @allowed_individual_slot_duration.minutes.to_i) || (!@valid_end_time)
    @new_meeting.location = params[:location]
    @role = @mentor.is_mentor? ? RoleConstants::MENTOR_NAME : RoleConstants::STUDENT_NAME
    @request_meeting_popup = params[:request_meeting_popup].present?
    @quick_meeting_popup = params[:quick_meeting_popup].present?
    @quick_connect_popup = params[:quick_connect_popup].present?
    unless @request_meeting_popup || @quick_meeting_popup
      @in_summary_questions = @current_program.in_summary_role_profile_questions_excluding_name_type(@role, current_user)
      mentor_user = @mentor.user_in_program(@current_program)
      initialize_mentor_actions_for_users([mentor_user.id]) if mentor_user.present?
      @viewer_role = current_user.get_priority_role
    end
    @src = EngagementIndex::Src::SendRequestOrOffers::MENTORING_CALENDAR if params[:mentoring_calendar]
    render :partial => (params[:mentoring_calendar] ? "meetings/mentor_info.html" : "meetings/new.html") unless @request_meeting_popup
  end

  def create
    @is_non_time_meeting = params[:non_time_meeting].present?
    @is_quick_meeting = params[:quick_meeting].present?
    @from_mentoring_calendar = params[:from_mentoring_calendar].present?
    @is_common_form = (params[:common_form] == "true")
    @past_meeting = params[:past_meeting].to_s.to_boolean
    @meeting = construct_meeting(params, self.action_name.to_sym, is_non_time_meeting: @is_non_time_meeting, group: @group, owner_member: wob_member, program: current_program, student_name: params[:student_name])
    execute_meeting_validations
    unless @error_flash
      begin
        @meeting.proposed_slots_details_to_create = get_proposed_slots_details(params[:meeting][:proposedSlots]) if params[:meeting].try(:[], :proposedSlots).present?
        @meeting.save!
        wob_member.update_attributes!(availability_not_set_message: params[:meeting][:menteeAvailabilityText]) if params[:meeting][:menteeAvailabilityText].present?
        if @group
          if params[:auto_update_task_id].to_i > 0
            @task = @group.mentoring_model_tasks.find_by(id: params[:auto_update_task_id])
            set_task_status!('true') if @task.try(:is_meeting_action_item?)
          end
          @meeting.delay(:queue => DjQueues::HIGH_PRIORITY).send_create_email
          @meeting.archived? ? track_activity_for_ei(EngagementIndex::Activity::RECORD_PAST_MEETING) : track_activity_for_ei(EngagementIndex::Activity::CREATE_GROUP_MEETING, {:context_place => params[:ei_src]})
          initialize_meetings(@group, @is_admin_view, wob_member, @current_program)
        else
          unless @is_quick_meeting
            initialize_meetings(@group, @is_admin_view, wob_member, @current_program)
          end
          @new_meeting = wob_member.meetings.build
          future_mentor_meeting = @meeting.mentor_created_meeting && @meeting.future?
          if !future_mentor_meeting
            track_ab_tests_data
            track_activity_for_ei(EngagementIndex::Activity::SEND_MEETING_REQUEST, {:context_place => params[:src]})
          end
          @mentor = @meeting.guests.first
          @favorite_user_ids = UserPreferenceService.new(@current_user, {request_type: UserPreferenceService::RequestType::MEETING}).find_available_favorite_users.collect(&:id) if @current_user.allowed_to_ignore_and_mark_favorite?
        end
      rescue => exception
        if @meeting.errors[:occurrences]
          @error_flash = @meeting.errors.delete(:occurrences).to_sentence
        else
          @error_flash = "flash_message.user_flash.meeting_creation_failure_v1".translate(:meeting => _meeting)
          notify_airbrake(exception)
        end
      end
    end
    unless request.xhr?
      options = {tab: MembersController::ShowTabs::AVAILABILITY, src: SourceParams::QUICK_CONNECT}
      options.merge({meeting_request_sent: 1}) if @track_ab_tests_data
      redirect_to member_path(wob_member, options)
    end
  end

  def edit
    @group = @meeting.group
    @unlimited_slot = @current_program.calendar_setting.slot_time_in_minutes.zero?
    @allowed_individual_slot_duration = @current_program.get_calendar_slot_time
    @slot_duration = @meeting.schedule.duration
    render(:partial => 'meetings/edit_form', :locals => {current_occurrence_time: params[:current_occurrence_time], show_recurring_options: params[:show_recurring_options].to_boolean,  meeting_area: params[:meeting_area].to_s.to_boolean, edit_time_only: params[:edit_time_only], set_meeting_time: params[:set_meeting_time].to_s.to_boolean, ei_src: params[:ei_src], from_connection_home_page_widget: @from_connection_home_page_widget, set_meeting_location: params[:set_meeting_location].to_s.to_boolean})
  end

  def update
    @set_meeting_location = params[:set_meeting_location].to_s.to_boolean
    handle_meeting_update(params[:set_meeting_time].to_s.to_boolean)
    if @from_meeting_area
      updated_current_occurrence_time =  Meeting.recurrent_meetings([@meeting], get_merged_list: true).first[:current_occurrence_time]
      flash[:notice] = "flash_message.user_flash.meeting_updation_success_v1".translate(:meeting => _meeting)
      if params[:group_id] && @meeting.recurrent?
        redirect_to meetings_path(:group_id => params[:group_id])
      else
        redirect_to meeting_path(@meeting, :current_occurrence_time => updated_current_occurrence_time, :edit_time_only => params[:edit_time_only].present?, meeting_updated: true, ei_src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_AREA) and return
      end
    else
      initialize_meetings(@group, @is_admin_view, wob_member, @current_program)
      @upcoming_meetings, @upcoming_meetings_in_next_seven_days = get_meetings_for_sidepanes(@group, @is_admin_view) if @group.present?
      render "update", formats: [:js], handlers: [:erb]
    end
  end

  def show
    @open_edit_popup = params[:open_edit_popup].to_s.to_boolean
    allow_member_open_edit_popup
    allow! :exec => :check_member_or_admin_for_meeting
    @current_occurrence_time = params[:current_occurrence_time]
    respond_to do |format|
      format.js {
        local_params = {meeting: @meeting.build_recurring_meeting(Meeting.parse_occurrence_time(@current_occurrence_time)), :group_admin_view => @group.present? && @is_admin_view}
        render(:partial => 'meetings/show', :locals => local_params, :layout => false)
      }
      format.html {
        @back_link = {:link => session[:back_url] }
        @group = @meeting.group
        @src = params[:ei_src]
        @src_path = params[:src]
        track_show_ei_activity
        @meeting_feedback_survey = @current_program.get_meeting_feedback_survey_for_user_in_meeting(@current_user, @meeting) unless @is_admin_view
        if !@meeting.is_valid_occurrence?(Meeting.parse_occurrence_time(@current_occurrence_time))
          @current_occurrence_time = @meeting.occurrences.first.start_time.to_s
        end
      }
    end
  end

  # This handles the RSVP
  def update_from_guest
    @current_occurrence_time = Meeting.parse_occurrence_time(params[:current_occurrence_time])
    allow! :exec => :check_member_or_admin_for_meeting if current_user.present?
    attending = params[:attending].to_i
    @rsvp_src = params[:src].try(:to_i)
    rsvp_change_source = params[:email].to_s.to_boolean ? MemberMeeting::RSVP_CHANGE_SOURCE::EMAIL :  MemberMeeting::RSVP_CHANGE_SOURCE::APP
    if params[:all_meetings].try(:to_boolean) || @meeting.occurrences.count == 1
      @member.mark_attending!(@meeting, { attending: attending, rsvp_change_source: rsvp_change_source })
    else
      @member.mark_attending_for_an_occurrence!(@meeting, attending, @current_occurrence_time, {rsvp_change_source: rsvp_change_source})
    end
    program = @meeting.program
    track_sessionless_activity_for_ei(EngagementIndex::Activity::RSVP_YES_MEETING, @member, @member.organization, {user: @member.user_in_program(program), program: program, browser: browser}) if attending == MemberMeeting::ATTENDING::YES

    @member_meeting = @meeting.member_meetings.where(member_id: @member.id).first
    @member_meeting_response = @member_meeting.get_response_object(@current_occurrence_time)

    owner_member_meeting = @meeting.member_meetings.find_by(member_id: @meeting.owner.id) if @meeting.owner.present?
    owner_user = @meeting.owner.user_in_program(@current_program) if owner_member_meeting.present?
    @owner_name = view_context.link_to_user(owner_user) if owner_user.present?
    @notice = view_context.get_update_from_guest_flash(@member_meeting, @member_meeting_response, @owner_name)
    if request.xhr?
      @upcoming_meetings, @upcoming_meetings_in_next_seven_days = get_meetings_for_sidepanes(@group, @is_admin_view) if @group
      flash.now[:notice] = @notice
      @show_details = true
      render "update_from_guest", formats: [:js], handlers: [:erb]
    else
      flash[:notice] = @notice
      if @group
        redirect_to meetings_path(:group_id => @group.id)
      else
        redirect_to member_path(@member, :tab => MembersController::ShowTabs::AVAILABILITY)
      end
    end
  end

  def destroy
    @meeting_id = @meeting.id
    @meeting.ics_sequence += 1
    handle_meeting_deletion
    initialize_meetings(@group, @is_admin_view, wob_member, @current_program)
    head :ok if params[:no_render]

    if @from_meeting_area
      flash[:notice] = "flash_message.user_flash.meeting_removal_success".translate(meeting: _meeting)
      redirect_ajax(session[:back_url])
    end
  end

  def mentoring_sessions
    initialize_mentoring_sessions_filter_params
    @meetings = get_filtered_group_meetings
    @ordered_meetings = @meetings.sort { |a, b|  b[:current_occurrence_time].to_time.utc <=> a[:current_occurrence_time].to_time.utc }
    if !(@is_csv_request || @is_pdf_request)
      @meetings = @ordered_meetings.paginate(:per_page => PER_PAGE, :page => params[:page] || 1)
      @total_meeting_time = compute_total_meeting_available_time(@ordered_meetings)
    elsif @is_csv_request
      report_file_name = ("feature.meetings.header.sessions_report_name_v1".translate(from_date_range: @from_date_range, to_date_range: @to_date_range, :Meetings => h(_Meetings))).to_html_id
      send_csv generate_meeting_session_report_csv(wob_member),
        :disposition => "attachment; filename=#{report_file_name}.csv"
    elsif @is_pdf_request
      @meetings = @ordered_meetings
      @total_meeting_time = compute_total_meeting_available_time(@ordered_meetings)
      @title = "feature.reports.header.mentoring_calendar_report_v1".translate(:Mentoring => _Mentoring)
      render :pdf => ("feature.meetings.header.sessions_report_name_v1".translate(from_date_range: @from_date_range, to_date_range: @to_date_range, :Meetings => h(_Meetings))).to_html_id
    end
  end
  
  def calendar_sessions
    handle_filters_from_dashboard
    @tab = params[:tab] || Meeting::ReportTabs::SCHEDULED
    @from_date_range, @to_date_range = ReportsFilterService.get_report_date_range(params[:filters], CalendarSessionConstants::DEFAULT_LIMIT.ago)
    @ordered_meetings = get_filtered_flash_meetings
    
    respond_to do |format|
      format.xls do
        @meeting_feedback_answers = get_meeting_feedback_answered_user_ids(@ordered_meetings)
        xls_data = MeetingCalendarReportXlsDataService.new(current_locale, wob_member, @ordered_meetings, current_program, @meeting_feedback_answers).build_xls_data_for_meeting_report
        filename = ("feature.reports.header.meeting_calendar_report_v1".translate(:Meeting => _Meeting) + " " + Time.zone.now.to_i.to_s).downcase.split(" ").join("_")
        send_data xls_data, :filename => "#{filename}.xls",
          :disposition => 'attachment', :encoding => 'utf8', :stream => false, :type => 'application/excel'
      end
      format.html do
        @meetings = @ordered_meetings.paginate(:per_page => PER_PAGE, :page => params[:page] || 1)
        @meeting_feedback_answers = get_meeting_feedback_answers(@meetings)
        @mentor_feedback_survey_questions = @current_program.get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME).survey_questions.includes({rating_questions: :translations, matrix_question: {question_choices: :translations}}, :translations, {question_choices: :translations})
        @mentee_feedback_survey_questions = @current_program.get_meeting_feedback_survey_for_role(RoleConstants::STUDENT_NAME).survey_questions.includes({rating_questions: :translations, matrix_question: {question_choices: :translations}}, :translations, {question_choices: :translations})
      end
      format.js do
        @meetings = @ordered_meetings.paginate(:per_page => PER_PAGE, :page => params[:page] || 1)
        @meeting_feedback_answers = get_meeting_feedback_answers(@meetings)
        @mentor_feedback_survey_questions = @current_program.get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME).survey_questions.includes({rating_questions: :translations, matrix_question: {question_choices: :translations}}, :translations, {question_choices: :translations})
        @mentee_feedback_survey_questions = @current_program.get_meeting_feedback_survey_for_role(RoleConstants::STUDENT_NAME).survey_questions.includes({rating_questions: :translations, matrix_question: {question_choices: :translations}}, :translations, {question_choices: :translations})
      end
    end
  end

  def ics_api_access
    if can_access_feature? && (member = @current_organization.members.where(calendar_api_key: params[:calendar_api_key]).first)
      member.calendar_sync_count += 1
      member.save!
      @meetings = member.meetings
      @ics_events = @meetings.any? ? Meeting.get_ics_event(@meetings, user: member) : []
      calendar = Meeting.generate_ics_calendar_events(@ics_events, Meeting::IcsCalendarScenario::PUBLISH_EVENT, false, {ics_cal_feed: true})
      download_ics(calendar)
    else
      head :ok
    end
  end

  def calendar_rsvp
    Meeting.update_rsvp_with_calendar(CalendarUtils.get_email_address(params["To"]), params["body-calendar"])
    head :ok
  end

  def update_meeting_notification_channel
    message_channel_id = request.env["HTTP_X_GOOG_CHANNEL_ID"]
    message_resource_id = request.env["HTTP_X_GOOG_RESOURCE_ID"]
    resource_state = request.env["HTTP_X_GOOG_RESOURCE_STATE"]

    notification_channel = get_valid_notification_channel(message_channel_id, message_resource_id)

    current_time = Time.now
    
    if resource_state == CalendarSyncResourceState::EXISTS && notification_channel.present?
      notification_channel.update_attribute(:last_notification_received_on, current_time)

      unless Meeting.is_rsvp_sync_currently_running?(notification_channel.id)
        Meeting.delay(queue: DjQueues::HIGH_PRIORITY).send("start_rsvp_sync_#{notification_channel.id}", current_time)
      end
    end

    head :ok
  end

  def new_connection_widget_meeting
    @is_past_meeting = params[:is_past_meeting].to_s.to_boolean
    @new_meeting = wob_member.meetings.build(group: @group)
  end

  def mini_popup
    @new_meeting = wob_member.meetings.new
    @src = params[:src]
    if @mentor_user.ask_to_set_availability?
      start_time = Time.now.in_time_zone(wob_member.get_valid_time_zone) + @current_program.calendar_setting.advance_booking_time.hours
      end_time = start_time.next_month.end_of_month
      @available_slots = @member.get_availability_slots(start_time, end_time, @current_program, false, nil, false, current_user, false, nil)
      @available_slots = MentoringSlot.remove_slots_smaller_than_calendar_slot_time(@available_slots, @current_program)
      @available_slots = MentoringSlot.sort_slots!(@available_slots)
    end
    render(:partial => "meetings/mini_popup.html", :locals => {:user => @mentor_user})
  end

  def select_meeting_slot
    @mentor = @current_organization.members.find(params[:mentor_id])
    @new_meeting = wob_member.meetings.build({:start_time => params[:start_time]})
    @allowed_individual_slot_duration = @current_program.get_calendar_slot_time
    @unlimited_slot = @current_program.calendar_setting.slot_time_in_minutes.zero?
    @new_meeting.end_time = (@unlimited_slot && params[:end_time].present?) ? params[:end_time] : (@new_meeting.start_time + @allowed_individual_slot_duration.minutes)
    @slot_duration = params[:end_time].to_time - params[:start_time].to_time
    @new_meeting.location = params[:location]
    @src = params[:src]
  end

  def validate_propose_slot
    mentor, mentor_user, minimum_time_allowed_to_request_meeting = get_mentor_and_mentor_user_and_minimum_time_allowed_to_request_meeting
    proposed_slots_hash = params[:slotDetails] || {}
    are_slots_valid, error_flash, slot_timing_string = validate_proposed_slots_hash(proposed_slots_hash, mentor, mentor_user, minimum_time_allowed_to_request_meeting, break_if_invalid: true)
    render :json => {:valid => are_slots_valid, :error_flash => error_flash, :slot_detail => slot_timing_string}
  end

  def valid_free_slots
    slots_hash = get_slots_hash
    free_slots = split_time_slot(slots_hash, params[:slot_time_in_minutes].to_i)
    # CALENDAR_SYNC_V2 : call this method when slot validation has to be done upfront
    # CALENDAR_SYNC_V2 : send @selected_group as params
    # free_slots = remove_invalid_slots(free_slots, validate: params[:propose_slots].to_s.to_boolean, selected_group: @selected_group)
    @indices = build_index_hash(free_slots).values.reverse
    @localized_free_slots = localize_free_slots(free_slots)
    @no_slots_available = @localized_free_slots[:start_times_array].blank?
    @selected_date = params[:pickedDate]
  end

  def valid_free_slots_for_range
    slots_hash = get_slots_hash_for_range(params[:pickedDate], params[:past_meeting].to_s.to_boolean, params[:groupId], span: params[:span])
    free_slots = get_free_slots_for_range(slots_hash, params)
    set_valid_free_slots_for_range_related_instance_vars(free_slots, params[:pickedDate])
  end

  def validate_proposed_slots_hash(proposed_slots_hash, mentor, mentor_user, minimum_time_allowed_to_request_meeting, options = {})
    valid_slots = []
    @validation_cache ||= initialize_validation_cache({mentor_user => [:is_max_capacity_user_reached?], current_user => [:is_student_meeting_limit_reached?, :is_student_meeting_request_limit_reached?]})
    validation_status = {are_slots_valid: true, error_flash: ""}
    @non_time_related_errors = []
    slot_timing_string = ""
    proposed_slots_hash.each do |_slot_index, slot_detail_hash|
      break if (!validation_status[:are_slots_valid] && options[:break_if_invalid])
      proposed_date = get_en_datetime_str(slot_detail_hash[:date])
      start_time, end_time = MentoringSlot.fetch_start_and_end_time(proposed_date, slot_detail_hash[:startTime], slot_detail_hash[:endTime])
      slot_timing_string = "feature.meetings.content.selected_proposed_slot_detail".translate(slot_timing: DateTime.localize(start_time, format: :full_display_with_zone_without_month), slot_minutes: ((end_time-start_time).to_i)/(1.minute.to_i))

      if start_time < Time.now
        proposed_slot_validation_followups!(validation_status, "feature.meetings.content.meeting_time_cannot_be_in_past".translate(Meeting: _Meeting), nil)
      elsif start_time < minimum_time_allowed_to_request_meeting
        proposed_slot_validation_followups!(validation_status, "feature.meetings.content.request_meeting_x_hours_in_advance_v1".translate(Meeting: _Meeting, number_of_hours: @current_program.calendar_setting.advance_booking_time, mentor_name: mentor.name(name_only: true)), nil)
      elsif (!options[:get_valid_slots] && !mentor.not_having_any_meeting_during_interval?(start_time, end_time))
        proposed_slot_validation_followups!(validation_status, "feature.meetings.content.mentor_unavailable_during_proposed_slot".translate(mentor_name: mentor.name(name_only: true), meeting: _meeting), nil)
      elsif get_from_cache_or_db(mentor_user, :is_max_capacity_user_reached?, date: start_time)
        proposed_slot_validation_followups!(validation_status, "feature.meetings.content.mentor_limit_exceeded".translate(meeting: _meeting, meetings: _meetings, calendar_month: DateTime.localize(start_time, format: :month_year), mentor_name: mentor_user.member.name(:name_only => true)), @non_time_related_errors)
        options[:break_if_invalid] = true
      elsif get_from_cache_or_db(current_user, :is_student_meeting_limit_reached?, date: start_time)
        proposed_slot_validation_followups!(validation_status, "feature.meetings.content.mentee_meeting_limit_exceeded".translate(meeting: _meeting, meetings: _meetings, calendar_month: DateTime.localize(start_time, format: :month_year)), @non_time_related_errors)
        options[:break_if_invalid] = true
      elsif get_from_cache_or_db(current_user, :is_student_meeting_request_limit_reached?)
        proposed_slot_validation_followups!(validation_status, "feature.meetings.content.mentee_request_limit_exceeded_html".translate(meeting: _meeting, click_here: view_context.link_to('display_string.Click_here'.translate, meeting_requests_path)), @non_time_related_errors)
        options[:break_if_invalid] = true
      else
        valid_slots << {start_time: start_time, end_time: end_time}
      end
    end
    return valid_slots if options[:get_valid_slots]
    [validation_status[:are_slots_valid], validation_status[:error_flash], slot_timing_string]
  end

  def initialize_validation_cache(params_hash)
    return_hash = {}
    params_hash.each do |key, value|
      return_hash[key.id] = value.collect {|method_symbol| [method_symbol, nil]}.to_h 
    end
    return_hash
  end

  def get_from_cache_or_db(user, method_symbol, options = {})
    if options[:date]
      @validation_cache[user.id][method_symbol] ||= {}
      @validation_cache[user.id][method_symbol][options[:date].month] = user.send(method_symbol, options[:date]) if @validation_cache[user.id][method_symbol][options[:date].month].nil?
      @validation_cache[user.id][method_symbol][options[:date].month]
    else
      @validation_cache[user.id][method_symbol] = user.send(method_symbol) if @validation_cache[user.id][method_symbol].nil?
      @validation_cache[user.id][method_symbol]
    end
  end

  def proposed_slot_validation_followups!(validation_status, error_message, non_time_related_errors)
    validation_status[:are_slots_valid] = false
    validation_status[:error_flash] = error_message
    non_time_related_errors << error_message unless non_time_related_errors.nil?
  end

  def get_destroy_popup
    render(:partial => 'meetings/delete_options', :locals => { meeting: @meeting, group_id: params[:group_id], current_occurrence_time: params[:current_occurrence_time], :outside_group => @outside_group, from_connection_home_page_widget: @from_connection_home_page_widget, from_meeting_area: @from_meeting_area })
  end

  def get_calendar_sync_instructions_page
  end

  def edit_state
    member_meeting = @meeting.member_meetings.find_by(:member_id => wob_member.id)
    @current_occurrence_time = params[:current_occurrence_time]
    @attendee = member_meeting.other_members.collect(&:name).to_sentence
    @src = params[:src].try(:to_i)
  end

  def update_state
    @current_occurrence_time = params[:current_occurrence_time]
    @meeting_feedback_survey = @current_program.get_meeting_feedback_survey_for_user_in_meeting(@current_user, @meeting)
    @member_meeting_id = @meeting.member_meetings.find_by(:member_id => wob_member.id).id
    meeting_state = params[:meeting_state]
    @src = params[:src]
    @meeting.update_attribute(:state_marked_at, Time.now)
    if meeting_state == Meeting::State::COMPLETED
      @meeting.complete!
    elsif meeting_state == Meeting::State::CANCELLED
      @meeting.cancel!
    end
    track_activity_for_ei(EngagementIndex::Activity::UPDATE_MEETING_STATE)
  end

  def survey_response
    srl = SurveyResponseListing.new(@current_program, @meeting, params)
    @questions = srl.get_survey_questions_for_meeting_or_group
    @user = srl.get_user_for_meeting_or_group
    @answers = srl.get_survey_answers_for_meeting_or_group
  end

  private

  def allow_member_open_edit_popup
    if @open_edit_popup.present? && !can_edit_meeting?
      @open_edit_popup = false
      flash[:error] = "feature.meetings.flash_message.no_permission_to_edit".translate(meeting: _meeting, mentors: _mentors)
    end
  end

  def fetch_meeting_in_program
    @meeting = current_program.meetings.find(params[:id])
  end

  def set_from_connection_home_page_widget
    @from_connection_home_page_widget = params[:from_connection_home_page_widget].to_s.to_boolean
  end

  def set_outside_group
    @outside_group = params[:outside_group].to_s.to_boolean
  end

  def set_from_meeting_area
    @from_meeting_area = params[:meeting_area].to_s.to_boolean
  end

  def get_valid_notification_channel(message_channel_id, message_resource_id)
    CalendarSyncNotificationChannel.where(channel_id: message_channel_id, resource_id: message_resource_id).last
  end

  def get_mandatory_times(picked_date)
    result_array = []
    if params[:isEditForm].to_s.to_boolean
      current_occurrence_time = Time.parse(params[:currentOccurrenceTime])
      return result_array unless valid_mandatory_time?(picked_date, current_occurrence_time)
      @trigger_no_change = true
      mandatory_times_hash = {}
      mandatory_times_hash[:start] = current_occurrence_time.utc
      mandatory_times_hash[:end] = @selected_meeting.occurrence_end_time(current_occurrence_time).utc
      result_array << mandatory_times_hash
    end
    result_array
  end

  def set_trigger_no_change(picked_date)
    if params[:isEditForm].to_s.to_boolean
      current_occurrence_time = Time.parse(params[:currentOccurrenceTime])
      @trigger_no_change = true if valid_mandatory_time?(picked_date, current_occurrence_time)
    end
  end

  def valid_mandatory_time?(picked_date, current_occurrence_time)
    picked_date.beginning_of_day.utc == current_occurrence_time.beginning_of_day.utc
  end

  def get_slots_hash
    picked_date = params[:pickedDate].present? ? Date.parse(get_en_datetime_str(params[:pickedDate])) : Date.current
    if params[:past_meeting].to_s.to_boolean || (picked_date < Date.current)
      @selected_group = current_program.groups.find_by(id: params[:groupId])
      get_all_time_slots(picked_date)      
    else
      handle_future_case_to_get_busy_slots(picked_date)
    end
  end

  def get_free_slots_for_range(slots_hash, params_hsh)
    free_slots = split_time_slot_for_range(slots_hash, params_hsh[:slot_time_in_minutes].to_i)
    free_slots = update_free_slots_for_all_days(free_slots, params_hsh[:pickedDate], params_hsh[:span])
    free_slots = remove_invalid_slots_for_range(free_slots, validate: params_hsh[:propose_slots].to_s.to_boolean, selected_group: @selected_group)
    free_slots
  end

  def update_free_slots_for_all_days(free_slots, params_picked_date, params_span)
    start_date, end_date = get_start_and_end_date_from_params(params_picked_date, params_span)
    while(start_date.beginning_of_day <= end_date.beginning_of_day) do
      free_slots[start_date.beginning_of_day] ||= []
      start_date = start_date.next
    end
    free_slots
  end

  def set_valid_free_slots_for_range_related_instance_vars(free_slots, picked_date)
    @indices = free_slots.map { |day_key, day_free_slots| [day_key, build_index_hash(day_free_slots).values.reverse] }.to_h
    @localized_free_slots = free_slots.map { |day_key, day_free_slots| [day_key, localize_free_slots(day_free_slots)] }.to_h
    @no_slots_available = @localized_free_slots.map{ |day_key, day_localized_free_slots| [day_key, day_localized_free_slots[:start_times_array].blank?] }.to_h
    @selected_date = picked_date
  end

  def get_start_and_end_date_from_params(picked_date_params_str, params_span)
    start_date = picked_date_params_str.present? ? Date.parse(get_en_datetime_str(picked_date_params_str)) : Date.current
    end_date = start_date + params_span.to_i.days
    [start_date, end_date].sort
  end

  def get_slots_hash_for_range(params_picked_date, past_meeting, group_id, options = {})
    start_date, end_date = get_start_and_end_date_from_params(params_picked_date, options[:span])
    if past_meeting || (end_date < Date.current)
      @selected_group = current_program.groups.find_by(id: group_id)
      get_all_time_slots_for_range(start_date, end_date)
    else
      slots_hash_ary = []
      if start_date < Date.current
        slots_hash_ary = get_slots_hash_for_range_inbetween(group_id, start_date)
        start_date = Date.current
      end
      handle_future_case_to_get_busy_slots_for_range(start_date, end_date).each { |slot| slots_hash_ary << slot }
      slots_hash_ary
    end
  end

  def get_slots_hash_for_range_inbetween(group_id, start_date)
    @selected_group = current_program.groups.find_by(id: group_id)
    get_all_time_slots_for_range(start_date, Date.current.yesterday)
  end

  def handle_future_case_to_get_busy_slots_for_range(start_date, end_date)
    members = (get_members_to_find_busy_slots + Array(wob_member)).uniq
    # finding free slots only for flash or 1-1 ongoing meetings
    if show_all_time_slots?(members)
      get_all_time_slots_for_range(start_date, end_date)
    else
      @shortlist_slots = true
      all_mandatory_times = (start_date).upto(end_date).map{ |date| get_mandatory_times(date) }.flatten
      Member.get_members_free_slots_after_meetings(start_date.strftime('time.formats.full_display_no_time'.translate), members, time_zone: start_date.in_time_zone(wob_member.get_valid_time_zone).strftime("%z"), mandatory_times: all_mandatory_times, program: current_program, scheduling_member: wob_member, end_date_str: end_date.strftime('time.formats.full_display_no_time'.translate))
    end
  end

  def handle_future_case_to_get_busy_slots(picked_date)
    members = (get_members_to_find_busy_slots + Array(wob_member)).uniq
    # finding free slots only for flash or 1-1 ongoing meetings
    if show_all_time_slots?(members)
      get_all_time_slots(picked_date)
    else
      @shortlist_slots = true
      Member.get_members_free_slots_after_meetings(picked_date.strftime('time.formats.full_display_no_time'.translate), members, time_zone: picked_date.in_time_zone(wob_member.get_valid_time_zone).strftime("%z"), mandatory_times: get_mandatory_times(picked_date), program: current_program, scheduling_member: wob_member)
    end
  end

  def get_all_time_slots_for_range(start_date, end_date)
    start_date.upto(end_date).each { |date| set_trigger_no_change(date) }
    [{start: start_date.beginning_of_day.utc, end: end_date.tomorrow.beginning_of_day.utc}]
  end
  
  def get_all_time_slots(picked_date)
    start_time = picked_date.beginning_of_day.utc
    set_trigger_no_change(picked_date)
    [{start: start_time, end: start_time.tomorrow}]
  end
  
  def show_all_time_slots?(members)
    # we shortlist time for flash and 1-1 groups alone
    (members == [wob_member]) || (members.size > 2) || calendar_sync_v2_disabled_or_group_mentoring(@selected_group) || (Array(@selected_group.try(:members)).size > 2)
  end

  def calendar_sync_v2_disabled_or_group_mentoring(selected_group)
    (!current_program.calendar_sync_v2_enabled?) || (current_program.allow_one_to_many_mentoring && selected_group.present?)
  end
  
  def get_members_to_find_busy_slots
    if params[:groupId].present?
      get_members_from_group_id(params[:groupId])
    elsif params[:meetingId].present?
      get_members_from_meeting_id(params[:meetingId])      
    else
      get_members_from_mentor_student_or_attendee_ids([params[:mentor_id], params[:student_id], params[:attendeeId]])      
    end  
  end
  
  def get_members_from_mentor_student_or_attendee_ids(ids)
    @current_organization.members.where(id: ids)
  end
  
  def get_members_from_meeting_id(meeting_id)
    @selected_meeting = current_program.meetings.find(meeting_id)
    @selected_group = @selected_meeting.group
    @selected_meeting.members
  end
  
  def get_members_from_group_id(group_id)
    @selected_group = current_program.groups.find(group_id)
    @selected_group.members.includes(:member).collect(&:member)
  end
  
  def build_index_hash(free_slots)
    slots_size = free_slots.size
    indices = { (slots_size - 1) => (slots_size - 1) }
    batch_index = slots_size - 1
    (batch_index - 1).downto(0).each do |index|
      batch_index = index if is_continuous?(free_slots[index][:start_time], free_slots[index + 1][:start_time])
      indices[index] = batch_index
    end
    indices
  end
  
  def is_continuous?(this_time, next_time)
    this_time != (next_time - Meeting::SLOT_TIME_IN_MINUTES.minutes)
  end
  
  def remove_invalid_slots(free_slots, options = {})
    return free_slots if (options[:validate].blank? || calendar_sync_v2_disabled_or_group_mentoring(options[:selected_group]))
    mentor, mentor_user, minimum_time_allowed_to_request_meeting = get_mentor_and_mentor_user_and_minimum_time_allowed_to_request_meeting
    free_slots_hash = {}
    free_slots.each_with_index do |slot, index|
      free_slots_hash[index] = {date: DateTime.localize(slot[:start_time], format: :full_display_no_time), startTime: DateTime.localize(slot[:start_time], format: :short_time_small), endTime: DateTime.localize(slot[:end_time], format: :short_time_small)}
    end
    validate_proposed_slots_hash(free_slots_hash, mentor, mentor_user, minimum_time_allowed_to_request_meeting, get_valid_slots: true)
  end

  def remove_invalid_slots_for_range(free_slots, options = {})
    free_slots.each do |key, value|
      free_slots[key] = remove_invalid_slots(value, options)
    end
    free_slots
  end

  def localize_free_slots(free_slots)
    result_hash = initialize_result_hash_for_localized_free_slots
    free_slots.each do |slot| 
      result_hash[:start_times_array] << DateTime.localize(slot[:start_time], format: :short_time_small)
      result_hash[:end_times_array] << DateTime.localize(slot[:end_time], format: :short_time_small)
    end
    result_hash
  end

  def split_time_slot(slots_hash, slot_time_in_minutes)
    result_array = []
    slots_hash.each do |slot_hash|
      populate_start_end_times_array(slot_hash[:start].in_time_zone(wob_member.get_valid_time_zone), slot_hash[:end].in_time_zone(wob_member.get_valid_time_zone), slot_time_in_minutes).each{|slot| result_array << slot}
    end
    result_array
  end

  def split_time_slot_for_range(slots_hash, slot_time_in_minutes)
    free_slots = split_time_slot(slots_hash, slot_time_in_minutes)
    free_slots_hsh = {}
    # TODO_CSV3 : Check perf
    free_slots.each { |slot| (free_slots_hsh[slot[:start_time].beginning_of_day] ||= []) << slot if (slot[:start_time] >= slot[:start_time].beginning_of_day && slot[:end_time] <= slot[:start_time].beginning_of_day.tomorrow) }
    free_slots_hsh
  end

  def initialize_result_hash_for_localized_free_slots
    {
      start_times_array: [],
      end_times_array: []
    }
  end

  def populate_start_end_times_array(start_time, end_time, slot_time_in_minutes)
    difference = ((end_time - start_time) / 60 ) / Meeting::SLOT_TIME_IN_MINUTES
    start_times_array = (0..(difference - (slot_time_in_minutes / Meeting::SLOT_TIME_IN_MINUTES))).collect { |index| start_time + (index * Meeting::SLOT_TIME_IN_MINUTES).minutes }
    start_times_array.collect { |start_time_element| {start_time: start_time_element, end_time: start_time_element + (slot_time_in_minutes).minutes} }
  end

  def get_mentor_and_mentor_user_and_minimum_time_allowed_to_request_meeting
    mentor = @current_organization.members.find(params[:mentor_id])
    mentor_user = mentor.user_in_program(@current_program)
    [mentor, mentor_user, @current_program.calendar_setting.advance_booking_time.hours.from_now]
  end

  def track_show_ei_activity
    return if @meeting.group_meeting?
    track_activity_for_ei(EngagementIndex::Activity::ACCESS_FLASH_MEETING_AREA, {:context_place => @src}) if @meeting.has_member?(wob_member)
  end

  def get_proposed_slots_details(proposed_slots_hash)
    proposed_slots_hash.permit!.to_h.map do |_slot_index, slot_detail_hash|
      proposed_slot = OpenStruct.new(location: slot_detail_hash[:location])
      slot_detail_hash[:date] = get_en_datetime_str(slot_detail_hash[:date])
      proposed_slot.start_time, proposed_slot.end_time = MentoringSlot.fetch_start_and_end_time(slot_detail_hash[:date], slot_detail_hash[:startTime], slot_detail_hash[:endTime])
      proposed_slot
    end
  end

  def mark_group_activity
    group = @group || (@meeting && @meeting.group)
    if group && group.has_member?(@current_user)
      RecentActivity.create!(
        :programs => [group.program],
        :ref_obj => group,
        :action_type => RecentActivityConstants::Type::GROUP_RELATED_ACTIVITY,
        :member => @curret_user,
        :target => RecentActivityConstants::Target::NONE
      )
    end
  end

  def load_meeting_and_attendee
    non_logged_in_member = @current_organization.members.find_by(id: params[:member_id]) if params[:member_id]
    @member = wob_member || non_logged_in_member
    @meeting = @member.meetings.find_by(id: params[:id]) if @member.present?
    if @member.blank? || @meeting.blank?
      flash[:error] = "feature.meetings.flash_message.inactive_meeting".translate(meeting: _meeting)
      redirect_to root_path and return
    end
  end

  def skip_side_pane
    @skip_meetings_side_pane = true
  end

  def fetch_meeting
    @meeting = wob_member.meetings.find(params[:id])
  end

  def fetch_group
    if params[:group_id]
      @group = @current_program.groups.published.find(params[:group_id])
    elsif params[:meeting] && params[:meeting][:group_id]
      @group = @current_program.groups.published.find(params[:meeting][:group_id])
    end
    if @group.present?
      allow! exec: Proc.new{
        !@current_program.mentoring_connections_v2_enabled? || manage_mm_meetings_at_end_user_level?(@group)
      }
    end
  end

  def check_action_access
	# @is_admin_view is used to check for a group show page which is accessed by an admin
    @group.nil? || @group.has_member?(current_user) || @is_admin_view
  end

  def can_edit_meeting?
    @meeting.can_be_edited_by_member?(wob_member)
  end

  def common_extensions
    super if @group
  end

  def download_ics(calendar)
    send_data(calendar.export,
      :filename => "event.ics",
      :disposition => "inline",
      :type => "text/calendar")
  end

  def initialize_mentoring_sessions_filter_params
    @is_csv_request = request.format == Mime[:csv]
    @is_pdf_request = request.format == Mime[:pdf]
    @tab = params[:tab] || Meeting::ReportTabs::SCHEDULED
    @from_date_range, @to_date_range = ReportsFilterService.get_report_date_range(params[:filters], MentoringSessionConstants::DEFAULT_LIMIT.ago)
    @filter_params = params[:filters]
  end

  def get_filtered_group_meetings
    msfs = MentoringSessionsFilterService.new(@current_program, params[:filters]||{})
    meetings = msfs.get_filtered_meetings
    @filters_count = msfs.get_number_of_filters

    from_time = @from_date_range.is_a?(Date) ? @from_date_range.to_time : @from_date_range
    to_time   = (@to_date_range.is_a?(Date) ? @to_date_range.to_time : @to_date_range) + 1.day
    
    upcoming_meetings, archived_meetings = Meeting.recurrent_meetings(meetings, {get_occurrences_between_time: true, start_time: from_time.utc, end_time: to_time.utc})
    meetings = upcoming_meetings + archived_meetings

    filtered_meetings = case @tab
    when Meeting::ReportTabs::UPCOMING
      upcoming_meetings
    when Meeting::ReportTabs::PAST
      archived_meetings
    else
      meetings
    end

    return filtered_meetings
  end

  def get_filtered_flash_meetings
    mfs = MeetingsFilterService.new(@current_program, params[:filters]||{})
    meeting_ids, prev_period_meeting_ids = mfs.get_filtered_meeting_ids
    @filters_count = mfs.get_number_of_filters
    accepted_flash_meetings = Meeting.where(id: meeting_ids).includes([{members: [:users, :profile_picture]}, {survey_answers: [:answer_choices, {common_question: [:translations]}]}, :program])
    get_flash_meetings(accepted_flash_meetings)

    @percentage, @prev_periods_count = ReportsFilterService.set_percentage_from_ids(prev_period_meeting_ids, meeting_ids)
    @prev_periods_count = 0 if @percentage.blank?

    filtered_meetings = case @tab
    when Meeting::ReportTabs::CANCELLED
      @meeting_hash[:cancelled_meetings]
    when Meeting::ReportTabs::COMPLETED
      @meeting_hash[:completed_meetings]
    when Meeting::ReportTabs::OVERDUE
      @meeting_hash[:overdue_meetings]
    else
      @meeting_hash[:scheduled_meetings]
    end
    return filtered_meetings.order("start_time DESC")
  end

  def get_flash_meetings(meetings)
    cancelled_meetings = meetings.where(state: Meeting::State::CANCELLED)
    completed_meetings = meetings.where(state: Meeting::State::COMPLETED)
    overdue_meetings = meetings.past.where(state: nil)
    scheduled_meetings = meetings

    @meeting_hash = {:cancelled_meetings => cancelled_meetings, :completed_meetings => completed_meetings, :overdue_meetings => overdue_meetings, :scheduled_meetings => scheduled_meetings }
  end

  def get_meeting_feedback_answers(meetings)
    feedback_answers = []
    meetings.each { |meeting|
      current_occurrence_time = meeting.first_occurrence
      feedback = meeting.survey_answers.select{|mm| mm.meeting_occurrence_time == current_occurrence_time}.group_by(&:user_id)
      feedback_answers << feedback || {}
    }
    return feedback_answers
  end

  def get_meeting_feedback_answered_user_ids(meetings)
    feedback_answers = []
    meetings.each { |meeting|
      feedback = meeting.survey_answers.collect(&:user_id)
      feedback_answers << feedback
    }
    return feedback_answers
  end

  def generate_meeting_session_report_csv(viewing_member)
    CSV.generate do |csv|
      csv << meeting_session_report_csv_headers

      @ordered_meetings.each do |meeting|
        csv_array = []
        csv_array << meeting[:meeting].topic 
        csv_array << meeting[:meeting].attendees.collect{|member| member.name(:name_only => true)}.join(", ") 
        csv_array << DateTime.localize(meeting[:current_occurrence_time].in_time_zone(viewing_member.get_valid_time_zone), format: :full_display_with_zone)
        csv_array << meeting[:meeting].duration_in_hours_for_one_occurrences
        csv_array << (meeting[:meeting].location.present? ? meeting[:meeting].location : "")
        csv << csv_array
      end
    end
  end

  def meeting_session_report_csv_headers
    ["feature.mentoring_slot.report_headers.Title".translate, "feature.mentoring_slot.report_headers.Members".translate, "feature.mentoring_slot.report_headers.Start_Time".translate, "feature.mentoring_slot.report_headers.Duration".translate, "feature.mentoring_slot.report_headers.Location".translate]
  end

  def compute_total_meeting_available_time(ordered_meetings)
    meetings = 0
    ordered_meetings.each{ |meeting|
      meetings += meeting[:meeting].duration_in_hours_for_one_occurrences
    }
    return meetings
  end

  def execute_meeting_validations
    unless @group
      mentor = @meeting.requesting_mentor
      if !@meeting.mentor_created_meeting && params[:meeting].try(:[], :proposedSlots).nil?
        @error_flash = if mentor.is_max_capacity_user_reached?(@meeting.start_time)
          "feature.meetings.content.mentor_limit_exceeded".translate(meeting: _meeting, meetings: _meetings, calendar_month: DateTime.localize(@meeting.start_time, format: :month_year), mentor_name: mentor.member.name(:name_only => true))
        elsif current_user.is_student_meeting_limit_reached?(@meeting.start_time)
          "feature.meetings.content.mentee_meeting_limit_exceeded".translate(meeting: _meeting, meetings: _meetings, calendar_month: DateTime.localize(@meeting.start_time, format: :month_year))
        elsif current_user.is_student_meeting_request_limit_reached?
          "feature.meetings.content.mentee_request_limit_exceeded_html".translate(meeting: _meeting, click_here: view_context.link_to('display_string.Click_here'.translate, meeting_requests_path))
        end
      end

      if !@meeting.mentor_created_meeting && !@meeting.schedulable?(@current_program) && !@is_non_time_meeting
        allowed_advance_slot_booking_time = @current_program.get_allowed_advance_slot_booking_time
        error_message = allowed_advance_slot_booking_time == 0 ? "flash_message.user_flash.meetings_in_past".translate(:meeting => _meeting.capitalize) : "flash_message.user_flash.inadequate_advance_time".translate(n: allowed_advance_slot_booking_time)
        @error_flash ||= Meeting.get_meetings_creation_message(@error_flash, error_message)
      end
    end
    if @meeting.members.size < 2
      @error_flash ||= Meeting.get_meetings_creation_message(@error_flash, "flash_message.user_flash.meeting_invalid_attendee_v1".translate(:meeting => _meeting))
    end
  end

  def can_access_feature?
    @current_program.is_meetings_enabled_for_calendar_or_groups?
  end

  def can_access_mentoring_sessions_feature?
    @current_program.mentoring_connection_meeting_enabled? && @current_program.ongoing_mentoring_enabled?
  end

  def can_access_calendar_sessions_feature?
    @current_program.calendar_enabled?
  end

  def initialize_meetings(group, is_admin_view, wob_member, current_program)
    if @outside_group
      meetings = Meeting.get_meetings_for_view(nil, nil, wob_member, current_program, {from_my_availability: @from_my_availability})
    else
      meetings = Meeting.get_meetings_for_view(group, is_admin_view, wob_member, current_program)
    end
    meetings_to_be_held, archived_meetings = Meeting.recurrent_meetings(meetings)
    @new_meeting = wob_member.meetings.build(:group => group) unless is_admin_view
    @meetings_to_be_held, @archived_meetings = Meeting.paginated_meetings(meetings_to_be_held, archived_meetings, params, wob_member)
  end

  def handle_meeting_deletion
    if @meeting.occurrences.count == 1 || (params[:delete_option] == Meeting::EditOption::ALL) || ((params[:delete_option] == Meeting::EditOption::FOLLOWING) && @meeting.first_occurrence?(params[:current_occurrence_time]))
      @meeting.false_destroy!
    elsif params[:delete_option] == Meeting::EditOption::CURRENT
      current_occurrence_time = @meeting.add_exception_rule_at(params[:current_occurrence_time])
    elsif params[:delete_option] == Meeting::EditOption::FOLLOWING
      @meeting.update_last_occurence_time(params[:current_occurrence_time])
      following_occurrence_time = Meeting.parse_occurrence_time(params[:current_occurrence_time])
    end
    unless @meeting.archived?(current_occurrence_time)
      if @meeting.active? && @meeting.can_be_synced?
        Meeting.delay(:queue => DjQueues::HIGH_PRIORITY).handle_update_calendar_event(@meeting.id)
        Meeting.delay(:queue => DjQueues::HIGH_PRIORITY).send_update_email_for_recurring_meeting_deletion(@meeting.id, wob_member.id)
      else
        Meeting.delay(:queue => DjQueues::HIGH_PRIORITY).remove_calendar_event(@meeting.id) if @meeting.can_be_synced?(true)
        Meeting.delay(:queue => DjQueues::HIGH_PRIORITY).send_destroy_email(@meeting.id, current_occurrence_time, following_occurrence_time)
      end
    end
  end

  def handle_meeting_update(set_meeting_time)
    meeting_date_changed = params[:meeting][:current_occurrence_date] != params[:meeting][:date]
    edit_option = params.delete(:edit_option)
    @current_occurrence_time = params[:meeting][:current_occurrence_time] || @meeting.occurrences.first.start_time.to_s
    # When datetime or location is changed, responses are reset - so, collecting responses before update. This previous response information is sent in update mails --
    # GAP: In recurrent meetings, when edit option is current/following, update of any attribute (topic/description/location/datetime) resets the responses.
    member_responses_hash = {}
    @meeting.member_meetings.each { |member_meeting| member_responses_hash[member_meeting.member_id] = member_meeting.attending }
    old_attributes = @meeting.attributes
    old_attributes["schedule_duration"] = @meeting.schedule.duration
    meeting_params = build_from_params(params, self.action_name.to_sym, new_action: false, meeting: @meeting, is_non_time_meeting: @is_non_time_meeting, group: @group, meeting_date_changed: meeting_date_changed, program: current_program, owner_member: wob_member)
    meeting_params[:group_id] = @meeting.group_id
    updated_meeting = @meeting
    @meeting.updated_by_member = wob_member
    ActiveRecord::Base.transaction do
      update_skipping_rsvp_change_email!(@meeting) do
        if @meeting.occurrences.count == 1 || (edit_option == Meeting::EditOption::ALL) || ((edit_option == Meeting::EditOption::FOLLOWING) && @meeting.first_occurrence?(@current_occurrence_time))
          meeting_update_options = {updated_by_member: wob_member, skip_rsvp_change_email: @meeting.skip_rsvp_change_email, meeting_time_zone: wob_member.get_valid_time_zone}
          meeting_update_options.merge!({calendar_time_available: true}) unless @meeting.calendar_time_available?
          @meeting.update_meeting_time(meeting_params[:start_time], meeting_params[:duration], meeting_update_options)
          @meeting.update_attributes!(meeting_params.except("start_time", "end_time", "duration"))
        else
          meeting_delay = meeting_params[:start_time] - @meeting.start_time
          if !meeting_date_changed
            meeting_params[:start_time] = Meeting.parse_occurrence_time(@current_occurrence_time) + meeting_delay
            meeting_params[:end_time] = meeting_params[:start_time] + meeting_params[:duration]
          end
          if edit_option == Meeting::EditOption::CURRENT
            meeting_params[:recurrent] = false
            meeting_params = merge_topic_description(set_meeting_time, meeting_params, old_attributes["topic"], old_attributes["description"])
            updated_meeting = @meeting.update_single_meeting(meeting_params, @current_occurrence_time, wob_member)
          elsif edit_option == Meeting::EditOption::FOLLOWING
            meeting_params[:recurrent] = true
            meeting_params = merge_topic_description(set_meeting_time, meeting_params, old_attributes["topic"], old_attributes["description"])
            updated_meeting = @meeting.update_following_meetings(meeting_params, @current_occurrence_time, wob_member)
          end
        end
      end
      updated_meeting.skip_rsvp_change_email = @meeting.skip_rsvp_change_email
    end
    if updated_meeting.active? && updated_meeting.details_updated?(old_attributes)
      track_activity_for_ei(EngagementIndex::Activity::UPDATE_MEETING, {:context_place => params[:ei_src]})
      updated_meeting.reset_responses(wob_member) if updated_meeting.datetime_updated?(old_attributes)
      Meeting.delay(:queue => DjQueues::HIGH_PRIORITY).send_update_emails_and_update_calendar_event(@meeting.id, updated_meeting.id, {member_responses_hash: member_responses_hash, updated_by_member_id: wob_member.id})
    end
    updated_meeting.mark_meeting_members_attending if updated_meeting.archived?
  end

  def merge_topic_description(set_meeting_time, meeting_params, topic, description)
    if(set_meeting_time && (!meeting_params[:topic] && !meeting_params[:description]))
      meeting_params.merge!(topic: topic, description: description)
    else
      meeting_params
    end
  end

  def update_skipping_rsvp_change_email!(meeting)
    initial_value = meeting.skip_rsvp_change_email
    meeting.skip_rsvp_change_email = true
    yield
    meeting.skip_rsvp_change_email = initial_value
  end

  def check_user_presence
    @member = @current_organization.members.select([:id, :first_name, :last_name, :availability_not_set_message, :will_set_availability_slots, :time_zone, :admin, :organization_id]).find(params[:member_id])
    if @member.present?
      @mentor_user = @member.user_in_program(@current_program)
      return true if @mentor_user.present?
    end
    head :ok
  end

  def handle_filters_from_dashboard
    return unless params[:dashboard_filters]
    params[:filters] ||= {}
    start_date, end_date = case params[:dashboard_filters]
                            when CalendarSessionConstants::DashboardFilter::ALL
                              [ReportsFilterService.program_created_date(@current_program), ReportsFilterService.dashboard_upcoming_end_date]
                            when CalendarSessionConstants::DashboardFilter::UPCOMING
                              [ReportsFilterService.dashboard_upcoming_start_date, ReportsFilterService.dashboard_upcoming_end_date]
                            when CalendarSessionConstants::DashboardFilter::PAST
                              [ReportsFilterService.program_created_date(@current_program), ReportsFilterService.dashboard_past_meetings_date]
                            when CalendarSessionConstants::DashboardFilter::COMPLETED
                              params[:tab] = Meeting::ReportTabs::COMPLETED
                              [ReportsFilterService.program_created_date(@current_program), ReportsFilterService.dashboard_past_meetings_date]
                           end

    params[:filters][:date_range] = ReportsFilterService.date_to_string(start_date, end_date)
  end

  def verify_signature
    unless mailgun_signature_verified?
      render plain: 'activerecord.custom_errors.incoming_mail.invalid_signature'.translate, status: HttpConstants::FORBIDDEN
    end
  end

  def verify_receiver
    if CalendarUtils.match_organizer_email(CalendarUtils.get_email_address(params["To"]), APP_CONFIG[:reply_to_calendar_notification]).blank?
      render plain: 'activerecord.custom_errors.incoming_mail.received_but_rejected'.translate, status: 200 # Set 200 success OK status
    end
  end

  def track_ab_tests_data
    finished_chronus_ab_test(ProgramAbTest::Experiment::GUIDANCE_POPUP)
    finished_chronus_ab_test(ProgramAbTest::Experiment::POPULAR_CATEGORIES)
    @guidance_experiment = chronus_ab_test_get_experiment(ProgramAbTest::Experiment::GUIDANCE_POPUP)
    @popular_categories_experiment = chronus_ab_test_get_experiment(ProgramAbTest::Experiment::POPULAR_CATEGORIES)
    @track_ab_tests_data = true
  end
end