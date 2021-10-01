class UsersController < ApplicationController
  include UsersHelper
  include MentoringSlotsHelper
  include UserListingExtensions
  include UserSearch
  include EmailFormatCheck
  include UserPreferencesHash

  module SessionHidingKey
    MENTORING_TIP = 'hide_mentoring_tip'
    ANNOUNCEMENT_ALERT_BOX = 'hide_announcement_alert_box'
    PROFILE_COMPLETE_SIDEBAR = 'hide_profile_complete_sidebar'
    INACTIVITY_CONNECTION_FEEDBACK = 'hide_inactivity_connection_feedback'
    SET_AVAILABILITY_PROMPT = "set_availability_prompt"
    MENTORING_PERIOD_NOTICE = 'hide_mentoring_period_notice'

    def self.all
      self.constants.collect{|c| eval(c.to_s)}
    end
  end

  skip_action_callbacks_for_autocomplete :auto_complete_for_name

  skip_before_action :require_organization, :only => [:hide_item]
  skip_before_action :require_program, :only => [:exit_wob, :hide_item, :new_user_followup]
  skip_before_action :login_required_in_program, :only => [:exit_wob, :new_user_followup, :hide_item]
  skip_before_action :back_mark_pages, :except => [:index]
  skip_before_action :handle_pending_profile_or_unanswered_required_qs, :only => [:exit_wob, :auto_complete_for_name, :hide_item]
  skip_before_action :handle_terms_and_conditions_acceptance, only: [:exit_wob, :new_user_followup]

  before_action :set_bulk_dj_priority, only: [:new_from_other_program, :create_from_other_program]
  before_action :login_required_in_organization, :only => [:exit_wob]
  before_action :load_user_from_id, :only => [:edit, :show, :destroy, :work_on_behalf, :change_user_state, :fetch_change_roles, :change_roles, :destroy_prompt, :update_tags, :hovercard, :reviews, :pending_requests_popup, :add_role, :add_role_popup]
  before_action :add_custom_parameters_for_newrelic, :only => [:index]
  before_action :fetch_reset_code, only: [:new_user_followup]
  before_action :fetch_role_to_add, only: [:add_role, :add_role_popup]

  # SSL Actions
  allow :user => :can_work_on_behalf?,           :only => [:work_on_behalf]
  allow :user => :can_manage_user_states?,       :only => [:destroy, :change_user_state, :fetch_change_roles, :change_roles, :destroy_prompt]
  allow :user => :can_manage_connections?,       :only => [:matches_for_student]
  allow :user => :can_view_mentoring_calendar?,  :only => [:mentoring_calendar]
  allow :user => :is_admin?,                     :only => [:update_tags]

  allow :user => :is_mentor?,                    :only => [:auto_complete_user_name_for_meeting]

  allow :exec => :check_add_user_permissions, :only => [:new, :create]
  allow :exec => :check_import_user_permissions, :only => [:new_from_other_program, :create_from_other_program, :select_all_ids, :bulk_confirmation_view]
  allow :exec => :check_program_has_ongoing_mentoring_enabled, :only => [:matches_for_student]

  # Students and Mentors listing. Lists mentors by default. Pass view param to
  # list students
  #
  # ==== Params
  # => view - 'mentees' for listing students
  #
  def index
    @highlight_filters = params[:highlight_filters]
    @from_global_search = params[:src] == EngagementIndex::Src::BrowseMentors::SEARCH_BOX
    initialize_params(params)
    initialize_role_options
    allow! :exec => Proc.new { current_user.can_view_role?(@role) }
    get_indexed_users(params)
    set_user_preferences_hash if show_favorite_ignore_links?
    track_activity_for_ei(EngagementIndex::Activity::BROWSE_MENTORS, context_place: params[:src]) if @role == RoleConstants::MENTOR_NAME && @current_user.is_student?
    track_user_search_activity
  end

  def destroy
    allow! exec: Proc.new { current_user.can_remove_or_suspend?(@user) }
    flash[:notice] = "flash_message.user_flash.user_destroy".translate(user: @user.name, mentoring_connection: _mentoring_connections)
    @user.destroy
    redirect_to root_path
  end

  def new
    @email = params[:email]
    @existing_member = @current_organization.members.find_by(email: @email)
    # here letting global admin add existing user from add user manually, still not from add user from other program tab
    @can_add_existing_member = @current_program.allow_track_admins_to_access_all_users || wob_member.admin?
    @member = @existing_member && @can_add_existing_member ? @existing_member : @current_organization.members.new
    @user = @current_program.users.new
    @user.member = @member
    if @roles.present?
      @user.role_names = @roles
      @role_str = RoleConstants.human_role_string(@roles, :program => @current_program)
      @grouped_role_questions = @current_program.role_questions_for(@roles, user: current_user, include_privacy_settings: true).role_profile_questions.group_by(&:profile_question_id)
    end
  end

  # Mentor profile addition by admin
  def create
    @email = params[:email]
    if params[:member_id].present?
      @member = @current_organization.members.find(params[:member_id].to_i)
    else
      user_params = params[:user].dup
      user_params[:role_names] = @roles
      member_params = user_params.delete(:member) || {}
      member_params.merge!(email: params[:email])
      picture_params = member_params.delete(:profile_picture) if member_params
      @member = @current_organization.members.new(user_member_params(member_params))
      @member.profile_picture = ProfilePicture.new(user_profile_picture_params(picture_params)) if picture_params
    end
    param_hash = { program: @current_program, created_by: current_user, member: @member }
    param_hash.merge!(user_params.permit!) unless params[:member_id].present?
    @user = User.new_from_params(param_hash)
    @user.imported_from_other_program = true if params[:member_id].present?
    @user.role_names = @roles
    @user.state = User::Status::ACTIVE
    @answers = params[:profile_answers].try(:to_unsafe_h)
    @role_str = RoleConstants.human_role_string(@roles, :program => @current_program)
    role_str_articleized = RoleConstants.human_role_string(@roles, :program => @current_program, :articleize => true)

    if @user.valid? && @member.save
      @user.save!
      update_user_answers(@user, @answers, @user.profile_pending?) if @answers
      if @user.reload.profile_incomplete_roles.empty? && @user.profile_pending?
        @user.update_attribute(:state, User::Status::ACTIVE)
      end

      flash[:notice] =
        if @user.profile_pending?
          @user.profile_incomplete_roles.any? ? "feature.user.label.pending_profile_because_of_mandatory_fields_missing_v1_html".translate(user_profile: view_context.link_to(h(@user.name), member_path(@user.member)), program: _program) : "flash_message.user_flash.profile_invited_v1".translate
        elsif params[:add_another] == "1"
          "flash_message.user_flash.user_added_and_another_v1_html".translate(user: "<a href='#{member_path(@user.member)}'>#{h(@user.name)}</a>".html_safe, user_role_articleized: role_str_articleized, user_role: @role_str)
        else
          "flash_message.user_flash.user_added_v1_html".translate(user: "<a href='#{member_path(@user.member)}'>#{h(@user.name)}</a>".html_safe, user_role: role_str_articleized)
        end

      if params[:add_another] == "1"
        redirect_to new_user_path(:role => @role)
      else
        redirect_to_back_mark_or_default program_root_path
      end
    else
      @grouped_role_questions = @current_program.role_questions_for(@roles, user: current_user, include_privacy_settings: true).role_profile_questions.group_by(&:profile_question_id)
      @member.valid?
      @member.errors.each{|attr, msg| @user.errors.add(attr, msg)}
      render :action => "new"
    end
  end

  def show
    redirect_to member_path(@user.member_id)
  end

  def edit
    redirect_to edit_member_path(@user.member_id)
  end

  #
  # #############################################################################
  # Custom RESTful actions
  # #############################################################################

  def favorite_mentors
    allow! :user => :is_student?
    @request_type = params[:request_type]
    ups = UserPreferenceService.new(@current_user)
    @favorite_users = current_user.favorite_users.find(params[:favorite_user_ids]).first(AbstractPreference::FAVORITE_THRESHOLD)
    @favorite_preferences_hash = ups.get_favorite_preferences_hash
    render partial: "users/request_favorite_mentors.html", locals: {favorite_users: @favorite_users, favorite_preferences_hash: @favorite_preferences_hash, request_type: @request_type}
  end

  def mentoring_calendar
    @params = params
    @my_filters = []
    @role = RoleConstants::MENTOR_NAME
    @user_reference = _Mentor
    @user_reference_plural = _Mentors
    @user_references_downcase = _mentors
    session["mentoring_calendar_filter_hash_#{@current_program.id}".to_sym] = params[:ajax_filters] if params[:ajax_filters].present?
    @session_filters = session["mentoring_calendar_filter_hash_#{@current_program.id}".to_sym]
    @can_current_user_create_meeting = current_user.can_create_meeting?(@current_program)
    @status_filter_label = "feature.user.filter.availability_status".translate
    if request.xhr?
      @state = User::Status::ACTIVE
      @meetings = []
      @availability = []
      slot_user_ids = []
      @filter_field = params[:filter]
      @search_filters_param = params[:sf]
      @custom_profile_filters = UserProfileFilterService.get_profile_filters_to_be_applied(@search_filters_param)
      @sort_order = "asc"
      @sort_field = "name"
      @search_query = params[:search]
      start_time = Time.zone.at(params[:start].to_i)
      end_time = Time.zone.at(params[:end].to_i)
      @can_apply_explicit_preferences = true
      @my_filters << {:label => @status_filter_label, :reset_suffix => @status_filter_label.to_html_id} if @filter_field && @filter_field != UsersIndexFilters::Values::ALL
      can_see_match_score = current_user.is_student? && current_user.student_document_available? && @current_program.allow_user_to_see_match_score?(current_user)

      @mentors_score = current_user.student_cache_normalized if can_see_match_score

      student = current_user.is_student? ? current_user : nil
      @filter_questions = @current_program.role_profile_questions_excluding_name_type(@role, current_user).select(&:filterable).collect(&:profile_question).uniq
      filtered_user_ids = apply_sphinx_profile_calendar_filters! - [student.try(:id)]

      current_user_meetings_id = wob_member.meetings.of_program(@current_program).between_time(start_time, end_time).pluck(:id)

      base_users_scope = User.where(:id => filtered_user_ids).
        includes({ member: [:meetings, :mentoring_slots] }, :program, :user_setting)

      base_users_scope.
      where("meetings.start_time <? and meetings.end_time >?", end_time, start_time).
      references(member: [:meetings, :mentoring_slots]).
      find_each do |user|
        member = user.member
        available_meetings = member.meetings.of_program(@current_program).between_time(start_time, end_time).includes([{:member_meetings=> :member_meeting_responses}])
        available_meetings = Meeting.recurrent_meetings(available_meetings, {start_time: start_time, end_time: end_time, get_occurrences_between_time: true, get_merged_list: true})
        @meetings << member.get_meeting_slots(available_meetings, current_user_meetings_id, wob_member)
      end

      base_users_scope = base_users_scope.available_for_sessions if current_program.consider_mentoring_mode?
      member_ids = MentoringSlot.where(member_id: base_users_scope.collect(&:member_id)).where("start_time<? ", end_time).pluck(:member_id).uniq
      members = Member.where(id: member_ids)
      users = base_users_scope.where(member_id: member_ids)
      members_map = {}
      users.each{|u| members_map.merge!(u.member_id => u)}
      members.each do |member|
        user = members_map[member.id]
        score = @mentors_score[user.id] if can_see_match_score
        @availability << member.get_availability_slots(start_time, end_time, @current_program, true, score, true, student, false, user)
        add_urls(@availability.flatten)
      end
      @calendar_objects = (@availability + @meetings).flatten
      json_objects = { events: @calendar_objects, filters_content: render_to_string(partial: "common/your_filters", locals: { onclick_function: "MentorSearch.clearFilter", reset_url_options: { js: "BBQPlugin.applySavedFilters(this, '');" } } ) }
      render :json => json_objects.to_json
    else
      initialize_filterable_and_summary_questions
    end
    @skip_rounded_white_box_for_content = true
  end

  def matches_for_student
    @params = params; @current_user = current_user
    if params[:student_name]
      @student = GetMemberFromNameWithEmailService.new(params[:student_name], @current_organization).get_user(@current_program, RoleConstants::STUDENT_NAME)

      if @student
        @is_matches_for_student = true
        @role = RoleConstants::MENTOR_NAME
        @viewer_role = @current_user.get_priority_role
        initialize_user_references
        @match_view = true
        @show_filters = true
        @student_profile_last_updated_at = @current_program.role_questions_last_update_timestamp(RoleConstants::STUDENT_NAME)
        @mentor_profile_last_updated_at = @current_program.role_questions_last_update_timestamp(RoleConstants::MENTOR_NAME)
        @student_in_summary_questions = @current_program.in_summary_role_profile_questions_excluding_name_type(RoleConstants::STUDENT_NAME, current_user)
        @mentor_groups_map = @student.mentor_connections_map
        initialize_pagination_options
        initialize_filterable_and_summary_questions
        initialize_search_and_filter_options
        @filter_field = @filter_param.presence || UsersIndexFilters::Values::ALL
        initialize_sort_values(@student)
        get_filtered_users(@student, skip_explicit_preferences: true)
        initialize_actions_for_matches_for_students(@users.collect(&:id), @student, @current_program)
      else
        flash.now[:error] = "flash_message.user_flash.invalid_mentee_name".translate(mentee: _mentee)
      end
      @student_name_with_email = params[:student_name]
    end

    set_back_link_for_matches_for_student
  end

  def new_user_followup
    @only_login = true
    session[:reset_code] = @password.reset_code

    if @member.can_signin?
      auth_config_ids = @member.auth_config_ids
    else
      if new_user_authenticated_externally?
        @profile_answers_map = session_import_data.try(:[], "ProfileAnswer")
      elsif @auth_config.try(:non_indigenous?)
        auth_config_ids = [@auth_config.id]
      end
    end

    if auth_config_ids.present?
      clear_auth_config_from_session
      flash[:info] = "flash_message.membership.please_login_to_complete_signup_process".translate
      redirect_to login_path(auth_config_ids: auth_config_ids)
    else
      deserialize_from_session(Member, @member, :admin)
      initialize_login_sections if @auth_config.blank?
      render "registrations/new"
    end
  end

  #
  # #############################################################################
  # Non-RESTful actions
  # #############################################################################

  #
  # Renders the page for directly adding users from other sub programs.
  #
  def new_from_other_program
    @listing_options = UserService.get_listing_options(params)

    @my_filters = []
    @my_filters << {:label => _Program + "/" + "feature.member.label.role".translate, :reset_suffix => "program_role"} if @listing_options[:filters][:program_id].present? || @listing_options[:filters][:role].present?

    search_options = UserService.get_es_search_hash(@current_program, @current_organization, @listing_options)
    @members = Member.get_filtered_members(@listing_options[:filters][:search], {match_fields: ["name_only", "email"], source_columns: [:id, :first_name, :last_name, :email]}.merge(search_options))
  end

  #
  # Creates +User+s by importing members from other sub programs.
  #
  def create_from_other_program
    redirect_to new_from_other_program_users_path and return unless params[:member_ids].present?
    member_ids = params[:member_ids].split(",")
    roles = params[:roles]
    roles_str = RoleConstants.human_role_string(roles, :program => @current_program, :pluralize => (member_ids.size > 1))

    pending_users_created = 0

    member_ids.each do |member_id|
      user = @current_program.all_users.build
      user.program = @current_program
      user.member_id = member_id
      user.role_names = roles
      user.created_by = current_user
      user.imported_from_other_program = true
      pending_users_created += 1 if user.profile_incomplete_roles.any?
    end
    @current_program.save!
    user_added_state = pending_users_created.zero? ? "feature.user.status.active".translate : "feature.user.status.unpublished".translate if member_ids.size == 1

    flash[:notice] =
      if pending_users_created.zero? && member_ids.size > 1
        "flash_message.user_flash.add_from_other_program_success_only_active_state".translate(role: roles_str, program: _program, count: member_ids.size)
      elsif (pending_users_created == member_ids.size) && member_ids.size > 1
        "flash_message.user_flash.add_from_other_program_success_only_pending_state".translate(role: roles_str, program: _program, count: member_ids.size)
      else
        "flash_message.user_flash.add_from_other_program_success_v1".translate(role: roles_str, program: _program, count: member_ids.size, active_count: member_ids.size-pending_users_created, pending_count: pending_users_created, state_name: user_added_state)
      end

    redirect_to new_from_other_program_users_path
  end

  # Autocomplete for user. Returns name <email> pairs as response.
  #
  # ==== Params
  # * <tt>search</tt> the autocomplete query role
  # * <tt>role</tt> for which to perform autocomplete. One of RoleConstants::MENTOR_NAME
  #   or RoleConstants::STUDENT_NAME
  #
  def auto_complete_for_name
    @is_preferred_request = params[:preferred].present?
    @program_event_users = params[:program_event_users]
    allow! :exec => :check_access_auto_complete?
    @members = []
    with_options = {program_id: @current_program.id}
    with_options.merge!("roles.id" => @current_program.get_role(params[:role]).id) if params[:role].present?
    with_options.merge!({id: @program_event_users.split(COMMON_SEPARATOR).map(&:to_i)}) if @program_event_users.present?
    # Inside a program, show inactive users to admins and if :show_all_users is true.
    with_options.merge!({state: User::Status::ACTIVE}) unless (params[:show_all_users] == "true")

    without_options = {}
    without_options[:id] = params[:userIdsToIgnore].map(&:to_i) if params[:userIdsToIgnore].present?

    options = {
      per_page: SELECT2_PER_PAGE_LIMIT,
      page: params[:page].try(:to_i),
      with: with_options,
      without: without_options
    }

    if params[:filter].present?
      options = get_dormant_member_search_options
      options[:with] = {"users.program_id" => @current_program.id}
      @members_json = get_members_field_for_filters_autocomplete(params, options)
    else
      if (params[:role] == RoleConstants::MENTOR_NAME) && !current_user.can_view_mentors?
        @users = []
      else
        options[:includes_list] = [:member => :profile_picture] if @is_preferred_request
        @users = User.get_filtered_users(params[:search].strip, options.merge!(match_fields: ["name_only.autocomplete"]))
        @match_array = @current_user.student_cache_normalized
        if params[:connections]
          @groups = @users.collect(&:groups).flatten.uniq
        end
      end
    end
    respond_to do |format|
      format.json { render :json => fetch_json_objects_for_autocomplete(params)  }
    end
  end

  def auto_complete_user_name_for_meeting
    @no_js = true
    with_options = case params[:role]
    when nil then {}
    when RoleConstants::STUDENT_NAME.to_s then {"roles.id": @current_program.get_role(RoleConstants::STUDENT_NAME).id}
    end

    with_options.merge!(program_id: @current_program.id, state: User::Status::ACTIVE)

    options = {
      with: with_options,
      match_fields: ["name_only.autocomplete"],
      source_columns: [:name_only, :member_id],
      per_page: 5,
      page: 1
    }

    users = User.get_filtered_users(params[:search].strip, options)
    render json: users.map{|user| {"label" => user.name_only, "user-id" => user.member_id, "member-link" => member_path(id: user.member_id) }}.to_json
  end

  # Hides an item from being rendered for this session.
  # params[:item_key] => the session key of the item in SessionHidingKey to hide.
  def hide_item
    return unless SessionHidingKey.all.include?(params[:item_key])
    if params[:nested_item_key]
      session[params[:item_key]] ||= {}
      session[params[:item_key]][params[:nested_item_key]] = true
    elsif params[:hide_forever] && params[:item_key] == UsersController::SessionHidingKey::PROFILE_COMPLETE_SIDEBAR
      current_user.hide_profile_completion_bar!
    else
      session[params[:item_key]] = true
    end
    head :ok
  end

  def work_on_behalf
    session[:work_on_behalf_member] = @user.member_id
    session[:work_on_behalf_user] = @user.id
    self.current_user = @user

    redirect_to root_path
  end

  def exit_wob
    session[:work_on_behalf_member] = nil
    session[:work_on_behalf_user] = nil

    self.current_user = get_current_user if @current_program
    # If the admin was working on behalf of someone and clicks on the
    # program overview page, he should be exitted of the 'wob mode' and
    # should behave like an admin in the program in which he was working
    # on behalf. Please add the redirects from wob as constants if there are anymore.
    if params[:src] == "pages"
      redirect_to root_organization_path
    else
      redirect_to root_path
    end
  end

  def new_preference
    preferred_mentor_id = params[:user_id]
    @preferred_user = @current_program.mentor_users.find(preferred_mentor_id)
    @match_array = current_user.get_student_cache_normalized
    render partial: "mentor_recommendations/preferred_user_draggable", locals: {mentor_user: @preferred_user, match_array: @match_array, note: nil, position: params[:position].to_i }
  end

  def change_user_state
    case params[:new_state]
    when User::Status::SUSPENDED
      # Suspend user.
      allow! exec: Proc.new { current_user.can_remove_or_suspend?(@user) }
      reason = params[:state_change_reason]

      # FIXME: Can this check be moved to model?
      if reason.blank?
        flash[:error] = "flash_message.user_flash.suspend_reason_required_v1".translate(user: @user.name)
      else
        @user.suspend_from_program!(current_user, reason)
        flash[:notice] = "flash_message.user_flash.user_suspended_v2".translate(user: @user.name, program: _program)
      end

    when User::Status::ACTIVE
      # Activate user.
      @user.reactivate_in_program!(current_user)
      flash[:notice] = "flash_message.user_flash.user_reactivated_v1".translate(user: @user.name, program: _program)
    end

    redirect_to @user.member
  end

  def fetch_change_roles
    @profile_user = @user
    can_manage_admin_role = current_user.can_manage_admin_role_for(@profile_user, @current_program)
    roles = @current_program.roles.all
    @admin_roles = roles.select{|r| r.administrative }
    @non_admin_roles = roles.select{|r| !r.administrative }
    render :partial => "users/fetch_change_roles", :locals => {can_manage_admin_role: can_manage_admin_role}, layout: "program"
  end

  def change_roles
    @role_change_reason = params[:role_change_reason] || ''
    role_names = (params[:role_names_str] || []).split(',')
    role_names_to_add = (role_names - @user.role_names) & @current_program.roles.pluck(:name)
    role_names_to_remove = @user.role_names - role_names
    allow! exec: Proc.new{ current_user.can_manage_admin_role_for(@user, @current_program) } if (role_names_to_add.include?(RoleConstants::ADMIN_NAME) || role_names_to_remove.include?(RoleConstants::ADMIN_NAME))
    if role_names_to_add.blank? && role_names_to_remove.blank?
      flash[:error] = 'flash_message.user.role_change_failure_v1'.translate
      redirect_to @user.member
    else
      @user.promote_to_role!(role_names_to_add, current_user, @role_change_reason) if role_names_to_add.present?
      @user.demote_from_role!(role_names_to_remove, current_user, @role_change_reason) if role_names_to_remove.present?
      flash[:notice] = 'flash_message.user.role_change_success'.translate
      if current_user == @user && (role_names_to_add - [RoleConstants::ADMIN_NAME]).any?
        redirect_to edit_member_path(@user.member, :first_visit => true, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION_CHANGE_ROLES)
      else
        redirect_to @user.member
      end
    end
  end

  def add_role
    role_name_to_add = @to_add_role.try(:name)
    if role_name_to_add.present?
      @user.promote_to_role!([role_name_to_add], current_user, nil, no_email: true)
      flash[:notice] = 'flash_message.user.auto_role_approval_success'.translate(to_add_role: @to_add_role.customized_term.term)
    else
      flash[:error] = @error_flash
    end
    redirect_to program_root_path
  end

  def add_role_popup
  end

  def update_tags
    @user.tag_list = params[:user][:tag_list]
    @user.save!

    @profile_user = @user
  end

  def bulk_confirmation_view
    @bulk_action_title = params[:bulk_action_confirmation][:title]
    @member_ids = params[:bulk_action_confirmation][:users]
    @roles = current_program.roles.includes(:customized_term => :translations)

    render :partial => "users/bulk_confirmation_view"
  end

  def select_all_ids
    @listing_options = UserService.get_listing_options(params).merge!(items_per_page: ES_MAX_PER_PAGE)
    member_ids = Member.get_filtered_members(@listing_options[:filters][:search], {match_fields: ["name_only", "email"], source_columns: [:id]}.merge(UserService.get_es_search_hash(@current_program, @current_organization, @listing_options)))
    render :json => {member_ids: member_ids.map(&:to_s)}
  end

  def hovercard
    @viewing_group = Group.find(params[:group_view_id].to_i) if params[:group_view_id]
    role_names = @viewing_group ? [@viewing_group.membership_of(@user).role.name] : @user.role_names
    @user_roles = RoleConstants.to_program_role_names(@current_program, role_names).to_sentence
    email_profile_question = @current_organization.email_question
    email_role_questions = @current_program.role_questions_for(role_names, user: current_user).where(:profile_question_id => email_profile_question.id)
    @show_email = email_role_questions.select{|q| q.visible_for?(current_user, @user)}.present?
    @in_summary_questions = get_hovercard_summary_questions_for(@user, role_names)
    if @current_program.project_based?
      @groups = @user.groups.global.open_connections
    end
  end

  def reviews
    allow! :exec => Proc.new { current_user.can_view_coach_rating? }
    @reviews = @user.feedback_responses_received.includes(:rating_giver, :answers)
    render :partial => "users/fetch_reviews.html", :locals => {:reviews => @reviews}
  end

  def validate_email_address
    allowed_domains = @current_organization.security_setting.email_domain
    flash_message = allowed_domains.present? ? "feature.user.content.status.invalid_email_domain".translate(email_domain: allowed_domains.downcase) : "js_translations.error.email_address_format_error".translate
    render :json => {:is_valid => (ValidatesEmailFormatOf::validate_email_format(params[:email], check_mx: true).nil? && is_allowed_domain?(params[:email], @current_organization.security_setting)), :flash_message => flash_message}
  end

  def add_user_options_popup
    allow! :exec => Proc.new { current_user.can_add_non_admin_profiles?  || current_user.can_manage_admins? }
    @can_add_existing_member = @current_program.allow_track_admins_to_access_all_users && !@current_organization.standalone?
    @can_import_users_from_csv = @current_program.user_csv_import_enabled?
    @can_import_dormant_users = @current_organization.org_profiles_enabled? && @can_import_users_from_csv && @current_organization.standalone?
  end

  def pending_requests_popup
    @pending_requests = []

    if @current_program.ongoing_mentoring_enabled? && @current_program.matching_by_mentee_alone?
      connection_requests = current_user.received_mentor_requests.active.where(:sender_id => @user.id)
      @pending_requests.concat(connection_requests)
    end
    if @current_program.calendar_enabled?
      meeting_requests = current_user.pending_received_meeting_requests.where(:sender_id => @user.id).latest_first
      @pending_requests.concat(meeting_requests)
    end

    render partial: "users/pending_requests_popup", :locals => {:pending_requests => @pending_requests, :user => @user}
  end

  def match_details
    @mentor = current_program.users.find_by(id: params[:id])
    @mentors_score = @current_user.get_student_cache_normalized
    @questions_with_email = @current_user.get_visibile_match_config_profile_questions_for(@mentor)
    @show_match_config_matches = params[:show_match_config_matches].to_s.to_boolean
    @match_details = @current_user.get_match_details_of(@mentor, @questions_with_email, @show_match_config_matches)
    show_favorite_ignore_links = @current_user.allowed_to_ignore_and_mark_favorite?
    set_user_preferences_hash(false) if show_favorite_ignore_links
    track_activity_for_ei(EngagementIndex::Activity::VIEW_MATCH_DETAILS, context_place: params[:src], context_object: params[:id])
    render partial: "users/match_details", locals: {match_details: @match_details, mentor: @mentor, mentors_score: @mentors_score, show_favorite_ignore_links: show_favorite_ignore_links, favorite_preferences_hash: @favorite_preferences_hash, show_match_config_matches: @show_match_config_matches}
  end

  protected

  # Update the user answers. No exception should occur here.
  def update_user_answers(user, answers, is_pending)
    questions = @current_organization.profile_questions.group_by(&:id)
    is_new_record = true #this function is called only when we create a new user profie so thats y its always a new record and this variable is set to true
    member = user.member
    answers.each_pair do |question_id, answer_text|
      ques_obj = questions[question_id.to_i].first
      next if ques_obj && ques_obj.handled_after_check_for_conditional_question_applicability?(member)
      saved_successfully = if ques_obj.education?
        member.update_education_answers(ques_obj, answer_text, user, is_pending, is_new_record)
      elsif ques_obj.experience?
        member.update_experience_answers(ques_obj, answer_text, user, is_pending, is_new_record)
      elsif ques_obj.publication?
        member.update_publication_answers(ques_obj, answer_text, user, is_pending, is_new_record)
      elsif ques_obj.manager?
        member.update_manager_answers(ques_obj, answer_text, user, is_pending, is_new_record)
      elsif ques_obj.file_type?
        if path_to_file = FileUploader.get_file_path(ques_obj.id, 'new', ProfileAnswer::TEMP_BASE_PATH, { code: params["question_#{ques_obj.id}_code"], file_name: answer_text })
          File.open(path_to_file, 'rb') do |file_stream|
            user.save_answer!(ques_obj, file_stream, is_new_record) rescue false
          end
        end
      else
        user.save_answer!(ques_obj, answer_text, is_new_record) rescue false
      end
      ques_obj.update_dependent_questions(member) if saved_successfully
    end
    user.save!
    profile_question_ids = answers.present? ? answers.keys.map(&:to_i) : []
    User.delay.clear_invalid_answers(user.id, user.class, user.program.organization.id, profile_question_ids)
  end

  #
  # Checks whether the user has permission to import users from other
  # sub programs.
  #
  def check_import_user_permissions
    program_view? && !@current_organization.standalone? && current_user.import_members_from_subprograms?
  end

  def check_add_user_permissions
    # To allow open new form without preselected role
    return true if params[:role].blank? && action_name == 'new' && (current_user.can_manage_admins? || current_user.can_add_non_admin_profiles?)
    @role = params[:role]
    @roles = (params[:role] || "").split(COMMON_SEPARATOR)
    current_user.add_user_directly?(@roles)
  end

  def load_user_from_id
    @user = @current_program.users.find(params[:id])
    @viewer_role = current_user.get_priority_role if logged_in_program?
  end

  private

  def fetch_role_to_add
    @to_add_role = @user.get_applicable_role_to_add_without_approval(@current_program)
    unless @to_add_role.present?
      @error_flash = 'flash_message.user.role_change_failure_v1'.translate
    end
  end

  def user_member_params(member_params)
    member_params.permit(Member::MASS_UPDATE_ATTRIBUTES[:user][:create])
  end

  def user_profile_picture_params(profile_picture_params)
    profile_picture_params.permit(ProfilePicture::MASS_UPDATE_ATTRIBUTES[:user_create])
  end

  def show_favorite_ignore_links?
    @show_favorite_ignore_links = (@role == RoleConstants::MENTOR_NAME && @current_user.allowed_to_ignore_and_mark_favorite?)
  end

  def check_access_auto_complete?
    if @is_preferred_request
      current_program.matching_by_mentee_and_admin_with_preference? && current_user.is_student?
    elsif @program_event_users.present?
      @current_organization.program_events_enabled?
    else
      current_user.is_admin? || current_user.has_owned_groups?
    end
  end

  def set_back_link_for_matches_for_student
    if params[:src] == "students_listing"
      @back_link = {:label => "#{_Mentees}", :link => users_path(:view => RoleConstants::STUDENTS_NAME)}
    elsif params[:manage_connections_member]
      @back_link = {:label => "feature.user.header.Profile".translate,
        :link => member_path(:id => params[:manage_connections_member], :tab => MembersController::ShowTabs::MANAGE_CONNECTIONS)}
    elsif params[:src] == "students_profile" && @student
      @back_link = {:label => "feature.user.header.users_profile".translate(member_name: h(@student.name)), :link => member_path(:id => @student.member_id)}
    end
  end

  # Returns the summary role questions corresponding to all the roles of the user
  def get_hovercard_summary_questions_for(user, role_names)
    summary_questions = []
    role_names.each do |role|
      summary_questions += current_program.in_summary_role_profile_questions_excluding_name_type(role, current_user)
    end
    summary_questions.reject { |summary_question| summary_question.profile_question.email_type? }
  end

  def track_user_search_activity
    if can_track_user_search_activity?
      options = @search_filters_param.deep_dup
      options.merge!(locale: current_locale.to_s, source: UserSearchActivity::Src::LISTING_PAGE, session_id: session.id, custom_profile_filters: @custom_profile_filters)
      UserSearchActivity.delay(queue: DjQueues::HIGH_PRIORITY).add_user_activity(current_user, options)
    end
  end

  def can_track_user_search_activity?
    current_user.is_student? && !working_on_behalf? && @search_filters_param.present?
  end

  def fetch_json_objects_for_autocomplete(params)
    json_objects = if params[:filter].present?
      @members_json
    elsif params[:multi_complete].present?
      if @groups.present?
        @groups.map do |group|
          {
            render_html: view_context.display_group_in_auto_complete(group).html_safe,
            object_id: group.id,
            name: view_context.display_selected_group_in_auto_complete(group)
          }
        end
      else
        member_objects = @members.map do |member|
        {
          label: member.name(name_only: true),
          name: member.name(name_only: true),
          object_id: member.id
        }
        end
        user_objects = @users.map do |user|
        {
          label: user.name(name_only: true),
          name: user.name(name_only: true),
          object_id: user.member_id
        }
        end
        (member_objects + user_objects)
      end
    elsif @is_preferred_request
      if @users.present?
        @users.map do |user|
          {
            render_html: view_context.dropdown_cell_recommendation(user, match_array: @match_array, tag: "div", class: "inline").html_safe
          }
        end
      else
        { render_html: 'feature.preferred_mentoring.header.no_results'.translate }
      end
    elsif params[:for_autocomplete].present?
      objects_arr = @members.to_a + @users.to_a
      params[:no_email] ? objects_arr.map{|user| user.name(name_only: true)} : objects_arr.map(&:name_with_email)
    else
      if params[:page].present?
        {
          total_count: @users.total_entries,
          users: @users.map(&:email_with_id_hash)
        }
      else
        @users.map(&:name_with_email)
      end
    end
    return json_objects.to_json
  end
end
