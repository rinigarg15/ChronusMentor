class ProgramEventsController < ApplicationController
  include AuthenticationForExternalServices
  include CalendarIcsGenerator

  before_action :fetch_program_event, :except => [:index, :new, :create, :send_test_emails]
  before_action :fetch_admin_views, :only => [:new, :edit]
  before_action :force_back_mark, only: [:new, :edit]
  before_action :verify_signature, :verify_receiver, :only => :calendar_rsvp_program_event

  skip_before_action :login_required_in_program, :check_browser, :verify_authenticity_token, :load_current_organization, :check_feature_access, :fetch_program_event, :handle_inactive_organization, :load_current_root, :load_current_program, :require_organization, :require_program, only: [:calendar_rsvp_program_event]

  allow :user => :is_admin?, :except => [:show, :index, :update_invite, :update_reminder, :more_activities, :calendar_rsvp_program_event]
  allow :exec => :authorize_user, :only => [:show, :update_invite, :update_reminder, :more_activities]
  allow exec: :published_upcoming_event?, only: [:add_new_invitees]

  def index
    @tab_number = params[:tab].to_i
    pagination_options = {:page => params[:page] || 1, :per_page => PER_PAGE}
    program_events = @current_program.program_events
    @program_events_upcoming = program_events.published.upcoming.for_user(current_user).includes(:admin_view, :program_event_users).paginate(pagination_options)
    @program_events_past = program_events.published.past.for_user(current_user).paginate(pagination_options)
    @program_events_drafted = current_user.is_admin? ? program_events.drafted.paginate(pagination_options) : []
    @admin_view_changed_events = {} #will be set in fetch_tab_events
    @program_events = fetch_tab_events
  end

  def new
    @program_event = @current_program.program_events.new
  end

  def create
    program_event_params = fetch_program_event_params(:create)
    @program_event = @current_program.program_events.new(program_event_params)
    @program_event.email_notification = (params[:program_event][:email_notification]=="true")
    program_enable_or_disable_mailer(@program_event, NewProgramEventNotification)
    @program_event.user = current_user
    assign_user_and_sanitization_version(@program_event)
    @program_event.save!
    flash[:notice] = "flash_message.program_event_flash.action_success".translate(title: @program_event.title, action: "display_string.created".translate)
    redirect_to program_event_path(@program_event)
  end

  def edit
  end

  def update
    @program_event.attributes = fetch_program_event_params(:update)
    @program_event.email_notification = (params[:program_event][:email_notification]=="true")
    program_enable_or_disable_mailer(@program_event, ProgramEventUpdateNotification)
    @program_event.user = current_user
    assign_user_and_sanitization_version(@program_event)
    @program_event.save!
    flash[:notice] = "flash_message.program_event_flash.action_success".translate(title: @program_event.title, action: "display_string.updated".translate)
    redirect_to program_event_path(@program_event)
  end

  def show
    respond_to do |format|
      format.any(:html, :js) do
        @questions, @user_info = get_user_info_label
        @is_admin_view = current_user.is_admin?
        @program_event.set_users_from_admin_view!(increment_version: true) if @program_event.draft? && @is_admin_view && @program_event.current_admin_view_changed?
        @response_tab = params[:tab]
        if @response_tab.present?
          @page = params[:page] || 1
          @users_for_listing = get_users_for_listing
        else
          get_event_invites_user_ids_by_status
          get_program_event_activities_with_offset
        end
      end
      format.csv do
        csv_file_name = "Event_#{@program_event.title.to_html_id}_#{DateTime.localize(@program_event.start_time.in_time_zone(wob_member.get_valid_time_zone), format: :csv_timestamp)}"
        send_csv File.read(@program_event.generate_attendees_csv(csv_file_name)),
          :disposition => "attachment; filename=#{csv_file_name}.csv"
      end
    end
  end

  def publish
    @program_event.email_notification = params[:program_event].present? && params[:program_event][:email_notification]=="true"
    @program_event.status = ProgramEvent::Status::PUBLISHED
    program_enable_or_disable_mailer(@program_event, NewProgramEventNotification)
    @program_event.save!
    flash[:notice] = "flash_message.program_event_flash.action_success".translate(title: @program_event.title, action: "display_string.published".translate)
    redirect_to program_event_path(@program_event)
  end

  def destroy
    @program_event.destroy
    flash[:notice] = "flash_message.program_event_flash.action_success".translate(title: @program_event.title, action: "display_string.deleted".translate)
    redirect_to program_events_path
  end

  def update_invite
    if params[:status].present?
      invite = @program_event.event_invites.for_user(current_user)
      @invite = invite.present? ? invite.first : @program_event.event_invites.new(user_id: current_user.id)
      @invite.status = params[:status]
      @invite.reminder = params[:event_invite].try(:[], :reminder) == "true"
      @invite.save!
      flash[:notice] =
      if params[:src] == "email" && !@invite.not_attending?
        status_string = @invite.attending? ? "attending" : "maybe_attending"
        set_reminder_link = view_context.link_to("display_string.Click_here".translate, "javascript:void(0);", data: { toggle: 'modal', target: "#modal_invite_response_#{status_string}_show_#{@program_event.id}" })
        "flash_message.program_event_flash.update_invite_success_from_email_html".translate(click_here: set_reminder_link)
      else
        "flash_message.program_event_flash.update_invite_success".translate
      end
      track_activity_for_ei(EngagementIndex::Activity::ATTEND_PROGRAM_EVENT, context_object: @program_event.title) if @invite.attending?
    end
    redirect_to program_event_path(@program_event)
  end

  def update_reminder
    invite = @program_event.event_invites.for_user(current_user).first
    invite.reminder = params[:event_invite].present? && params[:event_invite][:reminder]=="true"
    invite.save!
    flash[:notice] = "flash_message.program_event_flash.update_reminder_success".translate
    redirect_to program_event_path(@program_event)
  end

  def calendar_rsvp_program_event
    ProgramEvent.update_rsvp_with_calendar(CalendarUtils.get_email_address(params["To"]), params["body-calendar"])
    head :ok
  end

  # Fetches more activities and updates the activity feed.
  def more_activities
    get_program_event_activities_with_offset
  end

  def send_test_emails
    if params[:src]=="show"
      program_event = @current_program.program_events.find_by!(id: params[:id])
      program_event.notification_list_for_test_email = params[:test_program_event][:notification_list_for_test_email]
    else
      program_event = params[:id].present? ? @current_program.program_events.find_by!(id: params[:id]) : @current_program.program_events.new
      program_event.attributes = program_event_permitted_params(params[:test_program_event], :send_test_emails)
      program_event.title = "feature.program_event.label.no_title".translate if program_event.title.blank?
      test_event_date = get_en_datetime_str(params[:test_program_event][:date])
      program_event.start_time = fetch_time_in_zone(test_event_date, params[:test_program_event][:start_time], params[:test_program_event][:time_zone]) if test_event_date.present? && params[:test_program_event][:start_time].present?
      program_event.end_time = fetch_time_in_zone(test_event_date, params[:test_program_event][:end_time], params[:test_program_event][:time_zone]) if test_event_date.present? && params[:test_program_event][:end_time].present?
      program_event.user = current_user
    end
    program_event.notification_list_for_test_email = get_valid_emails(program_event.notification_list_for_test_email)
    @email_list = program_event.notification_list_for_test_email
    program_event.send_test_emails
  end

  def add_new_invitees
    @program_event.set_users_from_admin_view!(send_mails_for_newly_added: true, increment_version: true)
    flash[:notice] = "feature.program_event.content.admin_view_changed_success".translate(program_event_title: @program_event.title)
    if params[:from] == "show"
      redirect_to program_event_path(@program_event)
    else
      redirect_to program_events_path
    end
  end

  private
  def program_event_permitted_params(params, action)
    params.permit(ProgramEvent::MASS_UPDATE_ATTRIBUTES[action])
  end

  def program_enable_or_disable_mailer(program_event, mailer)
    program_event.program.mailer_template_enable_or_disable(mailer, program_event.email_notification) if program_event.published?
  end

  def fetch_time_in_zone(date, time_of_day, time_zone)
    d_time = DateTime.strptime(date + " " + time_of_day, "#{'time.formats.full_display_no_time'.translate} #{'time.formats.short_time_small'.translate}").to_time.utc
    # DateTime doesn't take care of DST, while Time does
    if time_zone.present?
      date_time = ActiveSupport::TimeZone.new(time_zone).parse(DateTime.localize(d_time, format: :full_date_full_time))
    else
      date_time = Time.zone.parse(DateTime.localize(d_time, format: :full_date_full_time))
    end
    return date_time
  end


  def authorize_user
    (current_user.is_admin? || !@program_event.draft?) && @current_program.program_events.for_user(current_user).include?(@program_event)
  end

  def fetch_program_event
    @program_event = @current_program.program_events.find_by(id: params[:id])
    if @program_event.blank?
      flash[:error] = "flash_message.program_event_flash.event_not_found".translate
      redirect_to program_events_path
    end
  end

  def fetch_program_event_params(action)
    program_event_params = program_event_permitted_params(params[:program_event], action)
    date = get_en_datetime_str(program_event_params.delete(:date))
    program_event_params[:start_time] = fetch_time_in_zone(date, program_event_params.delete(:start_time), program_event_params[:time_zone])
    program_event_params[:end_time] = fetch_time_in_zone(date, program_event_params.delete(:end_time), program_event_params[:time_zone]) if program_event_params[:end_time].present?
    program_event_params[:status] = program_event_params.delete(:status).to_i
    return program_event_params
  end

  def fetch_tab_events
    case @tab_number
    when ProgramEventConstants::Tabs::DRAFTED
      allow! :user => :is_admin?
      @program_events_drafted.each do |program_event|
        program_event.set_users_from_admin_view!(increment_version: true) if program_event.current_admin_view_changed?
      end
      @program_events_drafted
    when ProgramEventConstants::Tabs::PAST
      @program_events_past
    else
      @admin_view_changed_events = Hash[@program_events_upcoming.collect{ |e| [e.id, e.current_admin_view_changed?] }] if current_user.is_admin?
      @program_events_upcoming # Any other case is handled here
    end
  end

  def get_user_info_label
    non_private_profile_questions = get_profile_questions
    questions = non_private_profile_questions.select(&:experience?)
    user_info = "experience"
    if questions.empty?
      questions = non_private_profile_questions.select(&:education?)
      user_info = "education"
    end
    if questions.empty?
      questions = non_private_profile_questions.select(&:location?)
      user_info = "location"
    end
    if questions.empty?
      user_info = "join_date"
    end
    return questions, user_info
  end

  def get_profile_questions
    role_names = @program_event.role_names

    role_names = @current_program.roles_without_admin_role.collect(&:name) unless role_names.present?
    role_ques = @current_program.role_questions_for(role_names, user: current_user).role_profile_questions.includes(:profile_question).group_by(&:profile_question_id)
    prof_ques = []
    role_ques.each do |_prof_ques_id, role_questions|
      next if role_questions.select{|q| q.private?}.present?
      pq = role_questions.first.profile_question
      prof_ques << pq unless pq.default_type? || pq.skype_id_type?
    end
    prof_ques
  end

  def get_program_event_activities_with_offset
    @offset_id = params[:offset_id].to_i
    @program_event_activities = @program_event.recent_activities.for_display.latest_first.fetch_with_offset(
      ProgramEvent::ACTIVITIES_PER_PAGE, @offset_id, {}
    ).to_a

    @new_offset_id = @offset_id + ProgramEvent::ACTIVITIES_PER_PAGE
  end

  def get_event_invites_user_ids_by_status
    initialize_hash
    event_invites = @program_event.event_invites.select('status, COUNT(user_id) AS size, GROUP_CONCAT(user_id) AS user_ids').group(:status)
    responded_user_ids = [0] # declaring to be [0] only for case if no users have replied for scope of not_responded_count
    event_invites.each do |invite|
      @responses[ProgramEvent::StatusMap[invite.status].to_sym], user_ids = users_from_invite(invite)
      responded_user_ids << user_ids
    end
    not_responded_count = @program_event.users.where("users.id NOT IN (?)", responded_user_ids.flatten).count
    not_responded_users_to_display = get_not_responded_users(responded_user_ids.flatten).limit(ProgramEvent::SIDE_PANE_USER_LIMIT)
    @responses[:not_responded] = {size: not_responded_count, users_to_diplay: not_responded_users_to_display}
    invited_users_to_display = get_invited_users
    @responses[:invited] = {size: invited_users_to_display.size, users_to_diplay: invited_users_to_display.limit(ProgramEvent::SIDE_PANE_USER_LIMIT)}
  end

  def users_from_invite(invite)
    user_ids = invite.user_ids.split(",").map(&:to_i)
    users = get_users(user_ids).limit(ProgramEvent::SIDE_PANE_USER_LIMIT)
    return {size: invite.size, users_to_diplay: users}, user_ids
  end

  def initialize_hash
    base_hash = {size: 0, users_to_diplay: []}
    @responses = {attending: base_hash, not_attending: base_hash, may_be_attending: base_hash, not_responded: base_hash}
  end

  def get_users_for_listing
    if @response_tab == ProgramEventConstants::ResponseTabs::NOT_RESPONDED.to_s
      responded_user_ids = @program_event.event_invites.pluck(:user_id)
      users_scope = get_not_responded_users(responded_user_ids)
    elsif @response_tab == ProgramEventConstants::ResponseTabs::INVITED.to_s
      users_scope = get_invited_users
    else
      user_ids = @program_event.event_invites.where(:status => ProgramEvent::StatusByTabMap[@response_tab.to_i]).pluck(:user_id)
      users_scope = get_users(user_ids)
    end
    @all_users_for_listing_ids = users_scope.map(&:id)
    users_scope = users_scope.where(:id => filter_users) if params[:search_content].present?
    @search_params = params[:search_content].presence
    users_scope.paginate({:page => @page, :per_page => PER_PAGE})
  end

  def get_not_responded_users(responded_user_ids)
    responded_user_ids = [0] unless responded_user_ids.present?
    @program_event.users_for_listing(current_user).where("users.id NOT IN (?)", responded_user_ids)
  end

  def get_users(user_ids)
    @program_event.users_for_listing(current_user).where('users.id' => user_ids)
  end

  def get_invited_users
    @program_event.users_for_listing(current_user)
  end

  def fetch_admin_views
    @admin_views = AdminView.get_admin_views_ordered(@current_program.admin_views.select("id, title, filter_params, created_at, favourite, favourited_at"))
  end

  def filter_users
    User.search_by_name_with_email(@current_program, params[:search_content], false).collect(&:id)
  end

  def published_upcoming_event?
    @program_event.published_upcoming?
  end

  def verify_signature
    unless mailgun_signature_verified?
      render plain: 'activerecord.custom_errors.incoming_mail.invalid_signature'.translate, status: HttpConstants::FORBIDDEN
    end
  end

  def verify_receiver
    if CalendarUtils.match_organizer_email(CalendarUtils.get_email_address(params["To"]), APP_CONFIG[:reply_to_program_event_calendar_notification]).blank?
      render plain: 'activerecord.custom_errors.incoming_mail.received_but_rejected'.translate, status: 200 # Set 200 success OK status
    end
  end
end