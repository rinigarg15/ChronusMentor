class MentorRequestsController < ApplicationController
  include MentorRequestsHelper
  include Report::MetricsUtils
  include AbstractRequestConcern
  include MentoringModelCommonHelper
  SEPARATOR = ","

  allow :user => :can_send_mentor_request?, :only => [:new, :create]

  before_action :set_bulk_dj_priority, only: [:fetch_bulk_actions, :update_bulk_actions]
  before_action :redirect_if_not_allowed, :only => [:new, :create]
  allow :user => :can_manage_mentor_requests?, :only => [:fetch_bulk_actions, :update_bulk_actions, :export, :manage]
  before_action :set_up_filter_params, :only => [:index, :manage, :select_all_ids]
  before_action :add_custom_parameters_for_newrelic, :only => [:index, :manage]
  before_action :fetch_mentoring_models, only: [:index, :manage]

  allow :exec => :check_program_has_ongoing_mentoring_enabled

  # List mentor requests
  def index
    @src_path = params[:src]
    allow! :exec => :check_access_to_index
    default_filter = {program_id: current_program.id}
    respond_to do |format|
      format.any(:html, :js) do
        @page = params[:page] || 1
        if @is_request_manager_view_of_all_requests
          @title = 'feature.mentor_request.header.mentor_requests_v1'.translate(:Mentoring => _Mentoring)
          @mentor_requests = build_mentor_requests(default_filter)
          @mentor_request_partial = 'mentor_request_for_admin'
          activate_tab(tab_info[TabConstants::MANAGE])
        else
          if @filter_field == AbstractRequest::Filter::TO_ME
            @mentor_requests = build_mentor_requests(default_filter.merge({receiver_id: current_user.id}))
            @title = 'feature.mentor_request.header.received_mentor_requests_v1'.translate(:Mentoring => _Mentoring)
          elsif @filter_field == AbstractRequest::Filter::BY_ME
            @mentor_requests = build_mentor_requests(default_filter.merge({sender_id: current_user.id}))
            @title = 'feature.mentor_request.header.sent_mentor_requests_v1'.translate(:Mentoring => _Mentoring)
          elsif @filter_field == AbstractRequest::Filter::ALL
            allow! :user => :is_admin?
          end
          @mentor_request_partial = 'mentor_request'
          @existing_connections_of_mentor = current_user.mentoring_groups.active
          activate_tab(tab_info[TabConstants::HOME])
        end
        #Showing flash with proper status of the mentor request (from email or recent activity)
        if params[:mentor_request_id].present?
          req = @current_program.mentor_requests.find(params[:mentor_request_id])
          status_message = get_status_based_message(req.status)
          flash[:notice] = status_message if status_message.present?
        end

        # remove param used for scroll
        params.delete(:mentor_request_id)

        # Fallback of a failed reject
        if params[:failed_mentor_request_id]
          @failed_mentor_request = MentorRequest.find(params[:failed_mentor_request_id])
          @failed_mentor_request = deserialize_from_session(MentorRequest, @failed_mentor_request, :response_text)
        end

        set_match_results_per_mentor
      end

      format.pdf do
        export_requests(default_filter, :pdf)
      end

      format.csv do
        export_requests(default_filter, :csv)
      end
    end
  end

  def manage
    @metric = get_source_metric(current_program, params[:metric_id])
    @src_path = params[:src]
    if params[:export]
      @export_format = params[:export].to_sym
      @mentor_requests_ids = MentorRequest.get_filtered_mentor_requests(@action_params, {program_id: current_program.id}, true, ["id"]).collect(&:id)
      MentorRequest.delay(:queue => DjQueues::HIGH_PRIORITY).generate_and_email_report(current_user, @mentor_requests_ids, @list_field, @export_format, JobLog.generate_uuid, current_locale) if @mentor_requests_ids.any?
    else
      @page = params[:page] || 1
      @mentor_requests = build_mentor_requests({program_id: current_program.id})
      set_tiles_data
      set_match_results_per_mentor
      set_filters_count
      if @mentor_request_view
        @back_link = {:label => "feature.reports.header.program_management_report".translate(program: _Program), :link => management_report_path}
        @title = @mentor_request_view.title
      else
        @title = "feature.mentor_request.header.mentor_requests_v1".translate(:Mentoring => _Mentoring)
      end
    end
  end

  # Form for sending request for mentoring to a mentor
  def new
    mentor_request_options = {}
    if @current_program.matching_by_mentee_alone?
      # The mentor to whom to send request
      @mentor =  @current_program.all_users.for_role([RoleConstants::MENTOR_NAME]).find(params[:mentor_id])
      deny! :exec => Proc.new {@mentor == current_user}
      @src = params[:src]
      mentor_request_options[:mentor] = @mentor
      set_dual_request_mode(@mentor)
    end
    @favorites = current_user.get_visible_favorites.includes(:favorite => :member)
    mentor_user_ids = params[:mentor_user_ids].presence || @favorites.pluck(:favorite_id)
    if @current_program.matching_by_mentee_and_admin_with_preference?
      if mentor_user_ids
        @mentor_users = @current_program.mentor_users.find(mentor_user_ids)
        @mentor_users = mentor_user_ids.map{|id| @mentor_users.detect{|user| user.id == id.to_i}}.compact
      end
      valid_recommendation_preferences = current_user.try(:published_mentor_recommendation).try(:valid_recommendation_preferences)
      @recommended_users = valid_recommendation_preferences.collect(&:preferred_user) if valid_recommendation_preferences.present?
      @mentor_users = @recommended_users if @mentor_users.blank?
      @mentor_users ||= []
      @notes_hash = current_user.get_notes_hash
      @match_array = current_user.student_cache_normalized
    end
    @mentor_request = MentorRequest.new(mentor_request_options)
    @skip_rounded_white_box_for_content = true
  end

  # Creates a new MentorRequest for the current user in the current program
  def create
    @mentor_request = current_user.sent_mentor_requests.new(mentor_request_params(:create))
    mentor = @mentor_request.mentor
    set_dual_request_mode(mentor)
    set_allowed_request_type_change(mentor)
    @mentor_request.program = @current_program

    if @current_program.matching_by_mentee_and_admin?
      @mentor_request.build_favorites(params[:preferred_mentor_ids]) if params[:preferred_mentor_ids]
    elsif mentor.slots_available_for_mentor_request <= 0
      flash[:error] = "flash_message.mentor_request_flash.limit_reached".translate(mentor_name: mentor.name, mentors: _mentors)
      redirect_to(users_path) and return
    end

    if @mentor_request.save
      if @current_program.matching_by_mentee_and_admin?
        track_activity_for_ei(EngagementIndex::Activity::REQUEST_ADMIN_MATCH)
        flash[:notice] = "flash_message.mentor_request_flash.created_to_admin_v1".translate(mentor: _mentor, administrator: _admin)
        url = program_root_path
      else
        flash[:notice] = "flash_message.mentor_request_flash.created_v1".translate(:mentor => _mentor, :mentoring_connection => _mentoring_connection, :mentor_name => mentor.name)
        flash_label = 'feature.mentor_request.content.see_more_mentors'.translate(mentors: _mentors)
        finished_chronus_ab_test(ProgramAbTest::Experiment::GUIDANCE_POPUP)
        finished_chronus_ab_test(ProgramAbTest::Experiment::POPULAR_CATEGORIES)
        track_activity_for_ei(EngagementIndex::Activity::SEND_MENTORING_REQUEST, {:context_place => params[:mentor_request][:src]})
        params_options = {src: EngagementIndex::Src::BrowseMentors::FLASH}
        favorite_user_ids = UserPreferenceService.new(@current_user, {request_type: UserPreferenceService::RequestType::GROUP}).find_available_favorite_users.collect(&:id) if @current_user.allowed_to_ignore_and_mark_favorite?
        if !current_user.pending_request_limit_reached_for_mentee? && current_user.can_view_mentors?
          flash[:view_item] = {:label => get_safe_string + "#{flash_label} " + get_safe_string("&raquo;"), :link => users_path(params_options)}
        end
        # The only page from where the user can create a mentor request is the mentor profile page
        url = member_path(mentor.member, :mentor_request_sent => 1, favorite_user_ids: favorite_user_ids)
      end
      redirect_to(url)
    else
      if @mentor_request.errors[:sender_id].include?("activerecord.errors.models.mentor_request.attributes.sender_id.taken".translate)
        flash[:error] = "flash_message.mentor_request_flash.duplicate_request_to_mentor".translate(mentor: _mentor)
        redirect_to member_path(mentor.member) and return
      end
      flash[:error] = @mentor_request.errors.full_messages.join(',')
      @all_active_mentors = @current_program.mentor_users.active.includes([:member => {:profile_answers => :experiences}]) if @current_program.matching_by_mentee_and_admin?
      render :action => :new
    end
  end

  # Updates MentorRequest Only accept and reject state changes are valid actions
  # Only the mentor can update the request to accepted or rejected. mentee update to withdrawn.
  #
   def update
    new_status = params[:mentor_request][:status].to_i
    if new_status == AbstractRequest::Status::ACCEPTED || new_status == AbstractRequest::Status::REJECTED
      allow! :exec => Proc.new { @current_program.matching_by_mentee_and_admin? || !current_user.is_mentor? || @mentor_request.mentor == current_user }
      allow! :exec => :check_access
      if new_status == AbstractRequest::Status::ACCEPTED
        if current_user.mentoring_mode == User::MentoringMode::ONE_TIME
          flash[:error] = "flash_message.mentor_request_flash.mentor_cant_accept_request".translate(mentoring_connection: _mentoring_connection)
          redirect_to mentor_requests_path(page: get_current_page) and return
        end
        group = @current_program.groups.find_by(id: params[:mentor_request][:group_id])
        # The mark_accepted method creates a group and sets it on mentor_request
        if @mentor_request.mark_accepted!(group)
          track_activity_for_ei(EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST, {:context_place => params[:mentor_request][:src]})
          @group = @mentor_request.group
          redirect_to group_path(@group, src: EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST)
        else
          connection_permission = @mentor_request.mentor.program.connection_limit_permission
          if connection_permission == Program::ConnectionLimit::BOTH || connection_permission == Program::ConnectionLimit::ONLY_INCREASE
            flash[:error] = "flash_message.mentor_request_flash.acceptance_failed_v1_html".translate(:mentoring_connections => _mentoring_connections, :click_here => (view_context.link_to('display_string.Click_here'.translate, edit_member_path(@mentor_request.mentor.member, :section => MembersController::EditSection::SETTINGS, ei_src: EngagementIndex::Src::EditProfile::MAX_CONNECTION_LIMIT_REACHED, scroll_to: "user_max_connections_limit", focus_settings_tab: true))))
          else
            flash[:error] = "flash_message.mentor_request_flash.acceptance_failed_v2_html".translate(:mentoring_connections => _mentoring_connections)
          end
          redirect_to mentor_requests_path(:page => get_current_page)
        end
      elsif new_status == AbstractRequest::Status::REJECTED
        other_attrs = @current_program.matching_by_mentee_and_admin? ? {:rejector => current_user} : {}
        if params[:mentor_request][:rejection_type].to_i == AbstractRequest::Rejection_type::REACHED_LIMIT
          update_limit_after_rejection
        end
        if @mentor_request.update_attributes!(other_attrs.merge({:status => AbstractRequest::Status::REJECTED, :response_text => params[:mentor_request][:response_text], rejection_type: params[:mentor_request][:rejection_type].to_i}))
          set_flash_for_rejection
          if [EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE, EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE].include?(params[:mentor_request][:src])
            redirect_to_back_mark_or_default mentor_requests_path
            return true
          else
            redirect_to mentor_requests_path(:page => get_current_page)
          end
        else
          serialize_to_session(@mentor_request)
          redirect_to(mentor_requests_path(:failed_mentor_request_id => @mentor_request.id, :page => get_current_page))
        end
      end
    elsif new_status == AbstractRequest::Status::WITHDRAWN
      allow! :exec => Proc.new { check_access_to_withdraw && @mentor_request.student == current_user}
      if @mentor_request.update_attributes({:status => AbstractRequest::Status::WITHDRAWN, :response_text => params[:mentor_request][:response_text]})
        if @current_program.matching_by_mentee_alone?
          flash[:notice] = "flash_message.mentor_request_flash.request_rejected_or_withdrawn".translate(:user => @mentor_request.mentor.name)
        else
          flash[:notice] = "flash_message.mentor_request_flash.request_rejected_or_withdrawn".translate(:user => @current_program.owner.name)
        end
      end
      redirect_to mentor_requests_path(:page => get_current_page)
    end
    # Not handling other cases. Let them raise exception if they should, since
    # there is no template for update.
  end

  def select_all_ids
    allow! :exec => :check_access_to_index
    default_filter = {program_id: current_program.id}
    mentor_request_ids = []
    sender_ids = []
    receiver_ids = []
    if @is_request_manager_view_of_all_requests
      @mentor_requests = build_mentor_requests(default_filter, {:skip_pagination => true, :source_columns => ["id", "sender_id", "receiver_id"]})
      mentor_request_ids = @mentor_requests.map(&:id).map(&:to_s)
      sender_ids = @mentor_requests.map(&:sender_id)
      receiver_ids = @mentor_requests.map(&:receiver_id)
    end
    render :json => {mentor_request_ids: mentor_request_ids, sender_ids: sender_ids, receiver_ids: receiver_ids}
  end

  def fetch_bulk_actions
    @from_manage = params[:from_manage].present?
    @mentor_request = @current_program.mentor_requests.build
    request_type = params[:bulk_action][:request_type]
    mentor_request_ids = params[:bulk_action][:mentor_request_ids]
    case request_type.to_i
    when AbstractRequest::Status::CLOSED
      render :partial => "mentor_requests/close_request_popup", :locals => {mentor_request: @mentor_request, mentor_request_ids: mentor_request_ids, from_manage: @from_manage}
    end
  end

  def update_bulk_actions
    request_type = params[:bulk_actions][:request_type]
    mentor_request_ids = params[:bulk_actions][:mentor_request_ids].split(" ")
    mentor_requests = @current_program.mentor_requests.active.where(id: mentor_request_ids).to_a
    case request_type.to_i
    when AbstractRequest::Status::CLOSED
      mentor_requests.each do |mentor_request|
        mentor_request.response_text = params[:mentor_request][:response_text]
        mentor_request.status = AbstractRequest::Status::CLOSED
        mentor_request.closed_by = current_user
        mentor_request.closed_at = Time.now
        mentor_request.save!
      end
      MentorRequest.send_later(:send_close_request_mail, mentor_requests, params[:sender], params[:recipient])
      @flash_message = "flash_message.mentor_request_flash.closed_v1".translate(count: mentor_requests.size)
    end
    respond_to do |format|
      format.html do
        flash[:notice] = @flash_message
        redirect_to_back_mark_or_default mentor_requests_path(:filter => params[:filter], :list => params[:list], :search_filters => params[:search_filters])
      end
      format.js {}
    end
  end

  def export
    mentor_request_ids = params[:mentor_request_ids].split(MentorRequestsController::SEPARATOR)
    respond_to do |format|
      format.csv do
        file_name = MentorRequest.export_file_name(@current_program, params[:list] == 'active' ? 'pending' : params[:list], :csv)
        CSVStreamService.new(response).setup!(file_name, self) do |stream|
          MentorRequest.export_to_stream(stream, current_user, mentor_request_ids)
        end
      end
    end
  end

  private
  def set_flash_for_rejection
    mentee_name =  @mentor_request.student.name(name_only: true)
    settings_link = view_context.link_to("display_string.profile_settings".translate, edit_member_path(wob_member, scroll_to: "user_max_connections_limit", focus_settings_tab: true))
    flash_hash = get_flash_string_based_on_mailer_template_enabled(mentee_name, settings_link)
    if @set_flash_limit_reset
      flash[:notice] = flash_hash[:limit_reached_flash]
    else
      flash[:notice] = flash_hash[:rejected_request_flash]
    end
  end

  def set_dual_request_mode(mentor)
    @is_dual_request_mode = current_program.dual_request_mode?(mentor, current_user, true)
  end

  def set_allowed_request_type_change(mentor)
    return unless params[:mentor_request][:allowed_request_type_change].to_i == AbstractRequest::AllowedRequestTypeChange::MENTOR_REQUEST_TO_MEETING_REQUEST && @is_dual_request_mode
    @mentor_request.allowed_request_type_change = AbstractRequest::AllowedRequestTypeChange::MENTOR_REQUEST_TO_MEETING_REQUEST
  end

  def get_flash_string_based_on_mailer_template_enabled(mentee_name, settings_link)
    #In case mentor request reject template is disabled
    if !@mentor_request.program.is_mailer_template_enabled(MentorRequestRejected.mailer_attributes[:uid])
      limit_reached_string = "flash_message.mentor_request_flash.rejected_request_flash_v2_not_notified_html".translate(mentoring_connection: _mentoring_connections, profile_settings: settings_link)
      rejected_request_string = "flash_message.meeting_request_flash.rejected_request_flash_not_notified".translate
    else
      limit_reached_string = "flash_message.mentor_request_flash.rejected_request_flash_v3_html".translate(mentoring_connection: _mentoring_connections, profile_settings: settings_link, mentee_name: mentee_name)
      rejected_request_string = "flash_message.meeting_request_flash.rejected_request_flash_v2".translate(mentee_name: mentee_name)
    end
    { limit_reached_flash: limit_reached_string, rejected_request_flash: rejected_request_string }
  end
  
  def update_limit_after_rejection
    limit_to_reset = current_user.get_mentor_limit_to_reset
    @set_flash_limit_reset = ((limit_to_reset <= current_user.students(:active).count) && (limit_to_reset != current_user.max_connections_limit)) if limit_to_reset.present?
    current_user.update_attribute(:max_connections_limit, limit_to_reset) if limit_to_reset.present?
  end

  def mentor_request_params(action)
    params.require(:mentor_request).permit(MentorRequest::MASS_UPDATE_ATTRIBUTES[action])
  end

  def set_up_index_action_params
    if params[:view_id] && (@mentor_request_view = @current_program.abstract_views.find_by(id: params[:view_id]))
      view_params = @mentor_request_view.get_params_to_service_format
      alert = @mentor_request_view.alerts.find_by(id: params[:alert_id])
      filter_params = alert.present? ? FilterUtils.process_filter_hash_for_alert(@mentor_request_view, view_params, alert) : view_params
      @action_params = params.reverse_merge(ActionController::Parameters.new(filter_params).permit!)
      @action_params[:filter] ||= AbstractRequest::Filter::ALL
    else
      @action_params = params
    end
    CommonSortUtils.fill_user_sort_input_or_defaults!(@action_params)
  end

  def fetch_mentoring_models
    @mentoring_models = get_all_mentoring_models(current_program)
  end

  def set_up_filter_params
    set_up_index_action_params
    list_status = AbstractRequest::Status::STRING_TO_STATE[@action_params[:list] || MentorRequest::Filter::ACTIVE]
    @list_field = AbstractRequest::Status::STATUS_TO_SCOPE[list_status].to_s
    set_time_filters
    @filter_field = get_filter_field(@action_params[:filter])
    # Management view if
    # 1. Groups moderated or
    # 2. Loosely manged, but the user is not a mentor, or is a mentor but
    # in 'all' view.
    @is_request_manager_view_of_all_requests = (current_user.can_manage_mentor_requests? && @filter_field == AbstractRequest::Filter::ALL) || params[:action] == "manage" || params[:from_manage].present?

    # Admin viewing has three cases.
    #
    # 1. Moderated program
    # 2. Not-moderated, admin-mentor user and viewing 'All requests'
    # 3. Not-moderated, admin only user viewing requests in the system.
    #
    @my_filters = initialize_my_filters
    @filter_params = {:filter => @action_params[:filter], :list => @action_params[:list], :search_filters => @action_params[:search_filters]}
  end

  def build_mentor_requests(default_filter, options = {})
    if @action_params[:search_filters].present? && (@action_params[:search_filters][:sender].present? || @action_params[:search_filters][:receiver].present? || @action_params[:search_filters][:expiry_date].present?)
      reqs = MentorRequest.get_filtered_mentor_requests(@action_params, default_filter, options[:skip_pagination], options[:source_columns])
    elsif default_filter[:receiver_id].present?
      unless options[:skip_pagination]
        reqs = current_user.received_mentor_requests.send(@list_field).paginate(:page => @page)
      else
        reqs = current_user.received_mentor_requests.send(@list_field)
      end
    elsif default_filter[:sender_id].present?
      unless options[:skip_pagination]
        reqs = current_user.sent_mentor_requests.send(@list_field).paginate(:page => @page)
      else
        reqs = current_user.sent_mentor_requests.send(@list_field)
      end
    else
      unless options[:skip_pagination]
        reqs = @current_program.mentor_requests.send(@list_field).paginate(:page => @page, :per_page => PER_PAGE)
      else
        reqs = @current_program.mentor_requests.send(@list_field)
      end
    end
    reqs = reqs.order(@action_params[:sort_field] => @action_params[:sort_order]) if reqs.is_a?(ActiveRecord::AssociationRelation)
    return reqs
  end

  def set_tiles_data
    prev_period_ids = get_prev_period_ids
    received_reqs_ids = MentorRequest.get_filtered_mentor_request_ids(@action_params, {program_id: current_program.id, status: MentorRequest::Status.all})

    percentage, prev_periods_count = ReportsFilterService.set_percentage_from_ids(prev_period_ids, received_reqs_ids)
    prev_periods_count = 0 if prev_periods_count.blank?

    @tiles_data = {received: received_reqs_ids.size, pending: MentorRequest.where(id: received_reqs_ids).active.count, accepted: MentorRequest.where(id: received_reqs_ids).accepted.count, other: MentorRequest.where(id: received_reqs_ids).with_status_in([MentorRequest::Status::REJECTED, MentorRequest::Status::WITHDRAWN, MentorRequest::Status::CLOSED]).count, percentage: percentage, prev_periods_count: prev_periods_count}
  end

  def get_prev_period_ids
    prev_period_start_date, prev_period_end_date = ReportsFilterService.get_previous_time_period(@start_time, @end_time, @current_program)
    if prev_period_start_date.present? && prev_period_end_date.present?
      filters = {search_filters: {}}
      filters[:search_filters][:expiry_date] = ReportsFilterService.date_to_string(prev_period_start_date, prev_period_end_date)
      MentorRequest.get_filtered_mentor_request_ids(@action_params.merge(filters), {program_id: current_program.id, status: MentorRequest::Status.all}) 
    else
      return nil
    end
  end

  def initialize_my_filters
    my_filters = []
    if @action_params[:search_filters]
      my_filters << {:label => "feature.mentor_request.label.Sender".translate, :reset_suffix => 'sender'} if @action_params[:search_filters][:sender].present?
      my_filters << {:label => "feature.mentor_request.label.Receiver".translate, :reset_suffix => 'receiver'} if @action_params[:search_filters][:receiver].present?
      my_filters << {:label => "feature.mentor_request.label.SentBy".translate, :reset_suffix => 'expiry_date'} if @action_params[:search_filters][:expiry_date].present?
    end
    return my_filters
  end

  def fetch_request
    @mentor_request = @current_program.mentor_requests.find_by(id: params[:id])
    handle_request_fetched_for_update(@mentor_request, mentor_requests_path)
  end

  # This is to check who has tha access to update a request.
  def check_access
    MentorRequest.has_access?(current_user, @current_program)
  end

  # This is to check if a program has enabled option for mentee to withdraw mentor request
  def check_access_to_withdraw
    @current_program.allow_mentee_withdraw_mentor_request? && current_user.can_send_mentor_request?
  end

  def check_access_to_index
    MentorRequest.has_access?(current_user, @current_program) || current_user.can_manage_mentor_requests? || current_user.can_send_mentor_request?
  end

  def redirect_if_not_allowed
    return if request.xhr?
    error_message = if !@current_program.allow_mentoring_requests?
      @current_program.allow_mentoring_requests_message.presence || "flash_message.mentor_request_flash.blocked_by_admin_v1".translate(program: _program, administrator: _admin)
    elsif current_user.connection_limit_as_mentee_reached?
      "flash_message.mentor_request_flash.limit_for_mentee_reached".translate(mentoring_connection: _mentoring_connections)
    elsif current_user.pending_request_limit_reached_for_mentee?
      if check_access_to_withdraw
        "flash_message.mentor_request_flash.request_limit_for_mentee_reached_html".translate(click_here: view_context.link_to('display_string.Click_here'.translate, mentor_requests_path))
      else
        "flash_message.mentor_request_flash.request_limit_for_mentee_reached".translate
      end
    end
    if error_message.present?
      flash[:error] = error_message
      redirect_to_back_mark_or_default root_path
    end
  end

  def get_current_page
    page = params[:page].to_i != 0 ? params[:page].to_i : 1
    if page > 1 && (@current_program.mentor_requests.active.count <= (page - 1) * PER_PAGE)
      page = page -1
      params[:page] = page.to_s
    end
    return page
  end

  def get_filter_field(filter)
    if current_program.matching_by_mentee_alone?
      filter ||= ( current_user.is_mentor? && !current_user.is_student? ? AbstractRequest::Filter::TO_ME : nil )
    end
    filter ||= ( current_user.is_student? ? AbstractRequest::Filter::BY_ME : AbstractRequest::Filter::ALL )
  end

  def export_requests(filter, format)
    mentor_requests = MentorRequest.get_filtered_mentor_requests(@action_params, filter, true, ["id"]).map(&:id).map(&:to_i)
    allow! :user => :can_manage_mentor_requests?
    if mentor_requests.empty?
      flash[:error] = "flash_message.mentor_request_flash.no_data_to_export_v1".translate
    else
      MentorRequest.delay(:queue => DjQueues::HIGH_PRIORITY).generate_and_email_report(current_user, mentor_requests, @list_field, format, JobLog.generate_uuid, current_locale)
      flash[:notice] = "flash_message.mentor_request_flash.export_successful_v1".translate(file_format: format.to_s.upcase, :mentoring => _mentoring)
    end
    redirect_to_back_mark_or_default(mentor_requests_path(:list => @list_field, :page => @page))
  end

  def set_match_results_per_mentor
    # Compute the student-mentor matches for all the mentor requests.
    if @current_program.matching_by_mentee_and_admin?
      @match_results_per_mentor = {}
      @mentor_requests.each do |mentor_request|
        student = mentor_request.student
        @match_results_per_mentor[mentor_request] = student.student_cache_normalized(@is_request_manager_view_of_all_requests) if student.student_document_available?
      end
    end 
  end

  def set_time_filters
    if params[:action] == "index"
      @start_time, @end_time = CommonFilterService.initialize_date_range_filter_params(@action_params[:search_filters][:expiry_date]) if @action_params[:search_filters].present?
    elsif params[:action] == "manage"
      @action_params[:search_filters] ||= {}
      @action_params[:search_filters][:expiry_date] = params[:date_range] unless @action_params[:search_filters][:expiry_date].present?
      @start_time, @end_time = ReportsFilterService.get_report_date_range(params, @current_program.created_at)
    end
  end

  def set_filters_count
    @filters_count = 0
    if @action_params[:search_filters].present?
      @filters_count += 1 if @action_params[:search_filters][:sender].present?
      @filters_count += 1 if @action_params[:search_filters][:receiver].present? 
    end
  end
end