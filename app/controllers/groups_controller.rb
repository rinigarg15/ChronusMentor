class GroupsController < ApplicationController
  include HealthReportsHelper
  include ConnectionFilters
  include UsersHelper
  include HealthReportsHelper
  include GroupViewsHelper
  include GroupsHelper
  include MentoringModelsHelper
  include ProfileAnswersHelper
  include AdminViewsHelper
  include ActionView::Helpers::DateHelper
  include MentoringModelUtils
  include ScrapExtensions
  include GroupsFilters
  include MentoringModelCommonHelper
  include Report::MetricsUtils

  MY_CONNECTIONS_PER_PAGE = 5
  ACTIVITIES_PER_PAGE = 20
  LIST_VIEW_PER_PAGE = 25
  DETAILED_VIEW_PER_PAGE = 10
  SHOW_DEFAULT_ALL_MEMBERS_LIMIT = 2
  SHOW_ALL_MEMBERS_FILTER_LIMIT = 25
  DEFAULT_VIEW_COUNT_MOBILE = 3
  MAX_SIMILAR_CIRCLES_IN_DROPDOWN = 20

  OVERDUE_SURVEY_POPUP_COOKIE_EXPIRY_TIME = 5.days.from_now
  OVERDUE_SURVEY_POPUP_COOKIE_FORMAT = "survey_popup_shown_in_cm"

  module TargetUserType
    ALL_MEMBERS = "A"
    UNASSIGNED = "B"
    INDIVIDUAL = "C"
  end

  MY = "my"

  module StatusFilters
    #TO DO
    #constants like filter_#{code} is used in many places in javascript.
    module Code
      ACTIVE   = 0
      INACTIVE = 1
      CLOSED   = 2
      ONGOING  = 3
      DRAFTED  = 4
      PUBLISHED = 5
      PENDING = 6
      OPEN = 7
      PROPOSED = 8
      REJECTED = 9
      WITHDRAWN = 10
    end

    # Maps StatusFilters::Code to Group::Status
    MAP = {
      Code::ACTIVE    => Group::Status::ACTIVE,
      Code::INACTIVE  => Group::Status::INACTIVE,
      Code::CLOSED    => Group::Status::CLOSED,
      Code::DRAFTED   => Group::Status::DRAFTED,
      Code::ONGOING   => [Group::Status::ACTIVE, Group::Status::INACTIVE],
      Code::PUBLISHED => [Group::Status::ACTIVE, Group::Status::INACTIVE, Group::Status::CLOSED],
      Code::PENDING   => Group::Status::PENDING,
      Code::OPEN      => [Group::Status::PENDING, Group::Status::ACTIVE, Group::Status::INACTIVE],
      Code::PROPOSED  => Group::Status::PROPOSED,
      Code::REJECTED  => Group::Status::REJECTED,
      Code::WITHDRAWN  => Group::Status::WITHDRAWN
    }
    NOT_STARTED = 10
  end

  module TaskStatusFilter
    ALL = "mentoring_connections_all"
    OVERDUE = "mentoring_connections_overdue"
    NOT_OVERDUE = "mentoring_connections_ontrack"
    CUSTOM = "mentoring_connections_custom"
  end

  module DashboardFilter
    GOOD = "good"
    NEUTRAL_BAD = "neutral_bad"
    NO_RESPONSE = "no_response"
  end

  module ReactivationSrc
    LISTING_PAGE = "listing"
    NOTICE = "notice"
    MAIL = "mail"
    PROFILE = "profile"

    REDIRECTION_ALLOWED = [PROFILE, NOTICE]
  end

  skip_action_callbacks_for_autocomplete :auto_complete_for_name
  before_action :set_bulk_dj_priority, only: [:fetch_bulk_actions, :update_bulk_actions, :update_notes]
  before_action :fetch_group, :only => [:export, :edit, :update, :destroy, :profile, :more_activities, :leave_connection, :edit_answers, :update_answers, :publish, :discard, :withdraw, :fetch_notes, :update_notes, :update_expiry_date, :reactivate, :fetch_terminate, :fetch_reactivate, :set_expiry_date, :fetch_publish, :fetch_withdraw, :fetch_discard, :get_activity_details, :add_members, :update_members, :fetch_owners, :update_owners, :survey_response, :remove_new_member, :get_users_of_role, :edit_join_settings, :update_join_settings, :setup_meeting, :get_edit_start_date_popup]
  before_action :get_view, :only => [:new, :edit, :create, :update, :index, :destroy, :discard, :withdraw, :publish, :reactivate, :update_notes, :fetch_notes, :update_expiry_date, :set_expiry_date, :fetch_bulk_actions, :update_bulk_actions, :edit_columns, :select_all_ids, :fetch_owners, :update_owners]
  before_action :fetch_group_and_prefetch_objects, :only => [:show, :update_view_mode_filter]
  before_action :redirect_if_feature_disabled, :only => [:profile]
  before_action :fetch_current_connection_membership, :only => [:show, :update_view_mode_filter, :profile, :edit_answers, :leave_connection, :update_expiry_date]
  before_action :update_login_count, :only => [:show]
  after_action :update_last_visited_tab, only: [:show]
  before_action :add_custom_parameters_for_newrelic, :only => [:show, :index]
  before_action :get_group_view, :only => [:create, :edit_columns]
  before_action :initialize_filter_params, :only => [:index, :create]
  before_action :set_end_user_edit_view, :only => [:profile, :edit_answers]
  before_action :set_target_user_and_type, :only => [:show, :get_values_connection_plan_v2, :update_view_mode_filter]
  before_action :set_page_view, :only => [:show]
  before_action :set_attributes_for_updated_members, only: [:add_new_member, :replace_member]
  before_action :initialize_existing_groups_alert_data, only: [:add_new_member, :remove_new_member, :replace_member]
  before_action :fetch_groups_and_action_type, only: [:update_bulk_actions]
  before_action :redirect_if_bulk_limit_exceeded, only: [:update_bulk_actions]

  allow :user => :can_manage_connections?, :except => [:new, :create, :find_new, :export, :leave_connection, :index, :profile, :show, :update_view_mode_filter, :more_activities, :edit_answers, :update_answers, :update, :set_expiry_date, :update_expiry_date, :update_owners, :fetch_owners, :fetch_publish, :publish, :fetch_terminate, :destroy, :fetch_reactivate, :reactivate, :edit, :add_new_member, :remove_new_member, :replace_member, :fetch_withdraw, :withdraw, :get_users_of_role, :edit_join_settings, :update_join_settings, :index_mobile, :setup_meeting, :get_edit_start_date_popup, :get_similar_circles]
  allow :exec => :can_access_mentoring_area?, :only => [:show]
  allow :exec => :check_user_can_create_group, :only => [:new, :create]
  allow :exec => :check_member_or_admin,   :except => [:find_new, :profile, :assign_match_form, :get_users_of_role, :get_similar_circles]
  allow :exec => :check_access_to_show_profile,  :only   => [:profile]
  allow :exec => :check_user_can_leave_connection, :only => [:leave_connection]
  # Explicit pbe check is not needed here, because these permissions will be added only if pbe is enabled
  allow user: :can_view_find_new_projects?, only: [:find_new]
  allow :exec => :access_to_edit_answers, :only => [:edit_answers]
  allow :exec => :access_to_mentoring_area, :only => [:show, :update_view_mode_filter]
  allow :exec => :check_approve_project_requests?, :only => [:update_owners, :fetch_owners]
  allow :exec => :check_manage_or_own_group?, :only => [:fetch_publish, :publish, :fetch_terminate, :destroy, :edit, :add_new_member, :replace_member, :remove_new_member, :fetch_withdraw, :withdraw, :edit_join_settings, :update_join_settings]
  allow :exec => :can_view_ongoing_mentoring_related_page?
  allow :exec => :check_program_has_ongoing_mentoring_enabled
  allow exec: :can_access_join_settings, only: [:edit_join_settings, :update_join_settings]
  allow exec: "@group&.can_be_reactivated_by_user?(current_user)", only: [:fetch_reactivate, :reactivate]

  before_action :fetch_source_and_check_from_member_profile, :only => [:edit, :destroy, :reactivate, :publish, :discard, :update, :update_bulk_actions, :fetch_terminate, :fetch_reactivate, :fetch_publish, :fetch_discard, :fetch_bulk_actions, :fetch_withdraw, :fetch_notes, :update_notes]
  before_action :redirect_to_scraps_index, :only => [:show]
  before_action :handle_last_visited_tab, only: [:show]
  before_action :prepare_template, :only => [:profile, :show, :update_view_mode_filter, :edit_answers]
  before_action :set_view_mode, only: [:show, :update_view_mode_filter]
  before_action :set_src, only: [:index, :profile, :find_new]
  before_action :set_from_find_new, only: [:profile]
  before_action :set_group_profile_view, only: [:profile]
  before_action :checkin_base_permission, only: [:show]
  before_action :initialize_student_mentor, only: [:assign_match_form, :save_as_draft]
  before_action :check_access_to_update_connection_answers, only: [:update_answers]

  helper_method :group_params

  def show
    @add_new_tab = group_params[:add_new] || 'discussion'

    if @current_program.mentoring_connection_meeting_enabled?
      @new_meeting = @group.meetings.new
    end
    @coaching_goal = @group.coaching_goals.new if @current_program.coaching_goals_enabled?

    if @is_mentor_in_group
      # If viewed by mentor, show request sent by the students to the mentor.
      @student_requests = @group.students.collect{|student| student.my_request(:to_mentor => current_user) }.compact
    elsif current_user.can_manage_connections?
      # If viewed by admin, show requests sent by the students to the mentors of this connection.
      @student_requests = @group.students.collect do |student|
        @group.mentors.collect{|mentor| student.my_request(:to_mentor => mentor) }
      end.flatten.compact
    end

    get_connection_plan_values_and_update_milestone_status if current_program.mentoring_connections_v2_enabled?

    if current_program.coach_rating_enabled? && @group.has_mentee?(current_user)
      recipient_id = group_params[:coach_rating].to_i
      @response_url = new_feedback_response_path(group_id: @group.id, recipient_id: recipient_id) if recipient_id && @group.mentors.pluck(:id).include?(recipient_id)
    end

    @render_past_meeting_modal = @new_meeting.present? && manage_mm_meetings_at_end_user_level?(@group) if @home_page_view

    @back_link = {:link => session[:back_url]} if session[:back_url].present?
  end

  def update_view_mode_filter
    allow! :exec => lambda{ @group.published? }
    allow! :exec => lambda{ current_program.mentoring_connections_v2_enabled? }
    compute_page_controls_allowed
    get_connection_plan_values_and_update_milestone_status
    update_target_user_info
  end

  # Fetches more activities and updates the activity feed.
  def more_activities
    get_group_activities_with_offset
  end

  def profile
    return unless @group.pending?
    set_circle_start_date_params
    if !@show_profile_tab && !@show_plan_tab && check_member_or_admin
      if @show_messages_tab
        redirect_to group_scraps_path(group_id: @group.id, from_find_new: @from_find_new, src: @src_path, show_set_start_date_popup: group_params[:show_set_start_date_popup], manage_circle_members: group_params[:manage_circle_members])
      elsif @show_forum_tab
        redirect_to forum_path(@group.forum, from_find_new: @from_find_new, src: @src_path, show_set_start_date_popup: group_params[:show_set_start_date_popup], manage_circle_members: group_params[:manage_circle_members])
      end
    elsif @show_profile_tab && !group_params[:show_plan]
      @is_pending_group_show_profile_tab = true
    elsif @show_plan_tab
      @is_pending_group_show_plan_tab = true
    end
  end

  def new
    redirect_to groups_path(show_new: true, tab: Group::Status::ACTIVE) and return if !request.xhr? && @current_program.career_based?
    @group = @current_program.groups.build
    @connection_questions = Connection::Question.get_viewable_or_updatable_questions(@current_program, @current_user.is_admin? && !@propose_view) if @current_program.project_based?
  end

  def clone
    redirect_to groups_path(show_clone: true, clone_group_id: group_params[:id], tab: Group::Status::ACTIVE) and return if !request.xhr? && @current_program.career_based?

    @group = build_duplicate_group!(group_params[:id])
    render action: "new"
  end

  def create
    if @current_program.project_based?
      # create project based engagement
      return handle_creation_of_project_group
    end
    # Is the admin creating the connection from mentor requests page?
    @mentor_request_params = group_params[:mentor_request_id]
    begin
      # For assignment by admin from mentor requests page, find the corresponding request
      if @mentor_request_params
        handle_creation_from_mentor_request
      else
        # Create a new group with the mentor and the student. Program needs to be set first
        @group = @current_program.groups.new
        mentors, students, other_roles_hash = split_users_by_roles
        if group_params[GroupsHelper::GROUPS_ALERT_FLAG_NAME] != "true"
          @existing_groups_alert = view_context.existing_groups_alert([], [[students.collect(&:id), mentors.collect(&:id)]], Group::Status::DRAFTED, :user)
          return if @existing_groups_alert.present?
        end

        @group.mentors = mentors
        @group.students = students
        other_roles_hash.each do |role, users|
          users.each do |user|
            @group.custom_memberships.build(user_id: user.id, role_id: role.id)
          end
        end
        mentoring_model_param_value = group_params[:group].try(:delete, :mentoring_model_id)
        @group.attributes = group_strong_params(:create).to_h
        assign_actor_and_creator(@group)

        if group_params[:draft]
          @group.status = Group::Status::DRAFTED
          @drafted_connections_view = true
        end
        if @current_program.mentoring_connections_v2_enabled? && mentoring_model_param_value.present?
          mentoring_model = @current_program.mentoring_models.find(mentoring_model_param_value)
          @group.mentoring_model = mentoring_model
        end
        @tab_number = @group.status
        @group.save
      end
      object = @current_program.groups
      @tab_counts = {}
      @tab_counts[:ongoing], @tab_counts[:closed] = get_groups_size_with_status_active_closed(object)
      @tab_counts[:drafted] = get_groups_size_with_status_drafted(@current_program)
      # Here pending connections_count is not required as we redirect the user to the index page after creating a connection
    rescue ActiveRecord::RecordInvalid
      @error_flash = "activerecord.custom_errors.group.already_connected".translate(Mentee: _Mentee, Mentor: _Mentor)
    end

    if @mentor_request_params
      @mentoring_models = get_all_mentoring_models(current_program)
      @mentor_request_partial = 'mentor_requests/mentor_request_for_admin'
      fetch_active_mentor_requests
      render :action => 'create_from_request'
    end
  end

  def setup_meeting
    @new_meeting = wob_member.meetings.build(group: @group)
    @past_meeting = group_params[:past_meeting].to_s.to_boolean
    @common_form = group_params[:common_form].to_s.to_boolean
    @ei_src = group_params[:ei_src]
    @task_id = group_params[:task_id] if group_params[:task_id].present?
  end

  def add_members
    # This is an empty action, please do not remove this, there are view files for this.
  end

  # The below method will require role_id, group_id and the selected_user as params
  def add_new_member
  end

  # The below method will require role_id, group_id, user_id as params
  def remove_new_member
  end

  # The below method will require role_id, group_id, user_id and the selected_user as params
  def replace_member
  end

  def update_members
    mentors, students, other_roles_hash = split_users_by_roles
    add_as_pending = group_params[:save_and_continue_later].blank?
    if @group.update_members(mentors, students, current_user, other_roles_hash: other_roles_hash, check_actor_can_update_members: true)
      if add_as_pending
        @group.status = Group::Status::PENDING
        @group.message = (group_params[:group] || {})[:message]
      end
      @group.save!
    else
      flash[:error] = @group.errors.full_messages.to_sentence
      redirect_to add_members_group_path(@group) and return
    end
    redirect_to groups_path(tab: add_as_pending ? Group::Status::PENDING : Group::Status::DRAFTED)
  end

  def publish
    @ga_src = group_params[:ga_src]
    begin
      allow_join = group_params[:group].try(:[], :membership_settings).try(:[], :allow_join) || "false"
      @group.publish(current_user, group_params[:group][:message], allow_join.to_boolean)
    rescue ActiveRecord::RecordInvalid
      @error_flash = @group.errors.full_messages.to_sentence
    end

    if @group.active_project_requests.present? && !@error_flash.present?
      redirect_path = ProjectRequest.get_project_request_path_for_privileged_users(current_user, filtered_group_ids: [@group.id], from_bulk_publish: false, track_publish_ga: true, ga_src: @ga_src, src: EngagementIndex::Src::PUBLISH_CIRCLE_WIDGET)
    elsif @source == "profile" || (@source == EngagementIndex::Src::PUBLISH_CIRCLE_WIDGET && !@error_flash.present?)
      redirect_path = profile_group_path(@group, track_publish_ga: true, ga_src: @ga_src)
    end

    flash[:error] = @error_flash if @error_flash.present? && @source == "profile"
    flash[:notice] = "flash_message.group_flash.draft_actions".translate(mentoring_connection: _mentoring_connection, action: "display_string.published".translate) if (@source == EngagementIndex::Src::PUBLISH_CIRCLE_WIDGET && !@error_flash.present?)

    if redirect_path.present?
      if request.xhr?
        render js: "closeQtip(); window.location.href = \'#{redirect_path}\'"
      else
        redirect_to redirect_path
      end
    end
  end

  def edit
    is_table_view = (group_params[:is_table_view]=="true")

    render :partial => "groups/update_members", :layout => false, :locals => {:group => @group, :tab => group_params[:tab].to_i, :is_table_view => is_table_view, :view => @view.to_i, :profile_user => group_params[:profile_user]}
  end

  def update
    if group_params[:group].try{ |params| params[:src] == "admin_view"}
      handle_update_from_admin_view
      return
    end
    if group_params[:src] == "profile"
      handle_update_of_group_members
      if @error_flash || @group.errors.full_messages.to_sentence.present?
        flash[:error] = @error_flash || @group.errors.full_messages.to_sentence
      else
        flash[:notice] = "flash_message.group_flash.update_success".translate(mentoring_connection: _mentoring_connection)
      end
      redirect_url = @current_program.connection_profiles_enabled? ? profile_group_path(@group) : group_path(@group)
      redirect_to redirect_url and return
    end
    # This is from group edit form
    @tab_number = group_params[:tab].to_i
    @is_table_view = (group_params[:is_table_view]=="true")
    @profile_user = group_params[:profile_user]
    @is_manage_connections_view = current_user.can_manage_connections?
    @drafted_connections_view = @is_manage_connections_view && (@tab_number == Group::Status::DRAFTED)
    if request.xhr?
      allow! :exec => lambda{ @is_manage_connections_view }
      # Assign mentor action. Add the student in the mentor request to the group.
      if group_params[:mentor_request_id]
        @mentor_request = @current_program.mentor_requests.find(group_params[:mentor_request_id])
        @mentor_request.assign_mentor!(@group)
        @mentoring_models = get_all_mentoring_models(current_program)
        fetch_active_mentor_requests
        @mentor_request_partial = 'mentor_requests/mentor_request_for_admin'

        render :action => 'create_from_request'
      else
        # Update members
        handle_update_of_group_members
        initialize_connection_questions if @tab_number == Group::Status::DRAFTED || @tab_number == Group::Status::PENDING
        render :action => :update
      end
    # This is either group reactivation or extension
    else
      if group_params[:mentoring_period]
        reactivate_or_set_expiry_date
      else
        flash[:error] = "flash_message.group_flash.mentoring_period_v1".translate
      end

      if group_params[:manage_connections_member]
        redirect_to member_path(:id => group_params[:manage_connections_member], :tab => MembersController::ShowTabs::MANAGE_CONNECTIONS, :filter => group_params[:filter])
      else
        redirect_to_back_mark_or_default groups_path
      end
    end
  end

  # Serves three purposes * Mentor assignment page * Groups listing page * My connections page
  def index
    if group_params[:first_group]
      source_options = {}
      source_options.merge!(src: EngagementIndex::Src::Announcement) if group_params[:announcement].present?
      group = current_user.groups.active.first
      redirect_to (group ? group_path(group, source_options) : groups_path({show: MY}.merge!(source_options))) and return
    end
    @metric = get_source_metric(current_program, group_params[:metric_id])
    @mentoring_model_v2_enabled = @current_program.mentoring_connections_v2_enabled?
    @group_view = @current_program.group_view
    session[:groups_tab] = group_params[:tab] if group_params[:tab].present?
    @tab_number = session[:groups_tab].to_i
    @show_params = group_params[:show]

    @is_manage_connections_view = current_user.can_manage_connections? && group_params[:show].blank?
    @is_global_connections_view = (group_params[:show] == "global") && @current_program.connection_profiles_enabled? && @current_program.ongoing_mentoring_enabled?
    @is_my_connections_view = !@is_manage_connections_view && !@is_global_connections_view
    @drafted_connections_view = @is_manage_connections_view && (@tab_number == Group::Status::DRAFTED)
    if @current_program.project_based?
      @is_open_connections_view = @is_my_connections_view
      @is_pending_connections_view = @is_manage_connections_view && (@tab_number == Group::Status::PENDING)
      if @is_manage_connections_view || current_user.can_propose_groups?
        @is_proposed_connections_view = (@tab_number == Group::Status::PROPOSED)
        @is_rejected_connections_view = (@tab_number == Group::Status::REJECTED)
      end
      @is_withdrawn_connections_view = (@tab_number == Group::Status::WITHDRAWN)
    end

    @groups_scope = ((@is_manage_connections_view || @is_global_connections_view) ? @current_program : current_user).groups
    @groups_scope = @groups_scope.global if @is_global_connections_view

    @sort_field = get_groups_sort_field
    @sort_order = (@is_view_changed || group_params[:order].blank?) ? ((@view == Group::View::LIST) ? "asc" : "desc") : group_params[:order]
    sort_field_mapping_image = param_to_sort_field_map(@sort_field)
    per_page_groups = (@view == Group::View::DETAILED) ? DETAILED_VIEW_PER_PAGE : LIST_VIEW_PER_PAGE

    @tab_counts = get_groups_listing_tab_counts(@groups_scope)

    @status_filter = get_groups_status_filter
    @filter_field = StatusFilters::MAP[@status_filter]

    initialize_common_search_filters if group_params[:search_filters].present?
    @goals_v2_enabled = (@view == Group::View::LIST) && @group_view.get_group_view_columns(@tab_number).include?(GroupViewColumn::Columns::Key::GOALS_STATUS_V2)
    @v2_tasks_overdue_filter = @mentoring_model_v2_enabled && @is_manage_connections_view && (@tab_number == Group::Status::ACTIVE || @tab_number.nil?)
    @my_filters = group_params[:my_filters] || initialize_my_filters

    filter_params = {
      page: group_params[:page],
      per_page: per_page_groups,
      includes_list: get_sql_includes_hash(@view,
        goals_enabled: @goals_v2_enabled,
        mentoring_model_v2_enabled: @mentoring_model_v2_enabled,
        pbe_enabled: @current_program.project_based? && @is_manage_connections_view
      ),
      sort: { sort_field_mapping_image => @sort_order }
    }

    @with_options = (@is_manage_connections_view && (@tab_number.to_i == Group::Status::ACTIVE)) ? { status_filter: true } : { status: @filter_field }
    if @is_my_connections_view
      @with_options["members.id"] = current_user.id
    elsif @is_global_connections_view
      @with_options[:global] = true
    end

    handle_filters_and_init_connections_questions
    @dashboard_filtered_groups_count = handle_dashboard_health_filters(group_params[:dashboard]) if group_params[:dashboard]

    @is_csv_request = (request.format == Mime[:csv]) && @is_manage_connections_view
    @es_filter_hash = construct_group_search_options(filter_params)
    @groups = fetch_filtered_groups(filter_params)

    if (@filter_field == [Group::Status::ACTIVE, Group::Status::INACTIVE] || @filter_field == Group::Status::ACTIVE) && (group_params[:show_new] == "true" || group_params[:show_clone] == "true") && @is_manage_connections_view
      @group = group_params[:show_clone].present? ? build_duplicate_group!(group_params[:clone_group_id]) : @current_program.groups.build
    end

    handle_fetch_reactivate_group

    if group_params[:src] == "req_change_expiry" && @groups.empty?
      flash[:notice] = "flash_message.group_flash.already_expired".translate(:mentoring_connection => _mentoring_connection)
    end

    @create_connection_member = @current_organization.members.find_by(id: group_params[:create_connection_member]) if group_params[:create_connection_member]
    @back_link =
      if @create_connection_member
        {label: "Profile", link: member_path(:id => group_params[:create_connection_member], tab: MembersController::ShowTabs::MANAGE_CONNECTIONS)}
      elsif group_params[:from_mentoring_models].present? && !request.xhr? && @is_manage_connections_view && @mentoring_model_v2_enabled
        {label: "feature.multiple_templates.header.multiple_templates_title_v1".translate(Mentoring_Connection: _Mentoring_Connection), link: mentoring_models_path}
      end
  end

  def index_mobile
    sort_field_mapping_image = param_to_sort_field_map("active")
    @with_options = { status: @current_program.project_based? ? StatusFilters::MAP[StatusFilters::Code::OPEN] : StatusFilters::MAP[StatusFilters::Code::ONGOING] }
    @with_options["members.id"] = current_user.id
    filter_params = {
      sort: { sort_field_mapping_image => "desc" }
    }
    @es_filter_hash = construct_group_search_options(filter_params)
    my_groups = fetch_filtered_groups(filter_params)
    if @current_program.project_based?
      filter_params[:per_page] = DEFAULT_VIEW_COUNT_MOBILE
      @with_options[:status] = StatusFilters::MAP[StatusFilters::Code::PROPOSED]
      @es_filter_hash = construct_group_search_options(filter_params)
      proposed_groups = fetch_filtered_groups(filter_params)
      render :partial => 'groups/circles_listing_mobile', locals: { my_groups: proposed_groups.present? ? my_groups.first(DEFAULT_VIEW_COUNT_MOBILE) : my_groups, proposed_groups: proposed_groups }
    else
      render :partial => 'groups/groups_mobile', locals: { my_groups: my_groups }
    end
  end

  # This is used to terminate a group. The action performs a soft delete
  def destroy
    @group.terminate!(current_user, group_params[:group][:termination_reason], group_params[:group][:closure_reason])
    track_activity_for_ei(EngagementIndex::Activity::CLOSE_CONNECTION) if @group.has_member?(current_user)
    redirect_to profile_group_path(@group) if group_params[:src] == "profile"
  end

  #This is used for drafted connections to perform a hard delete
  def discard
    @group.destroy
    redirect_to groups_path if group_params[:src] == "profile"
  end

  def withdraw
    withdraw_groups([@group], group_params[:withdraw_message])
    redirect_to profile_group_path(@group)
  end

  def edit_answers
    if request.xhr?
      render :partial => "groups/edit_title_logo.html", :layout => "program"
    else
      @connection_questions = Connection::Question.get_viewable_or_updatable_questions(@current_program, @current_user.can_manage_or_own_group?(@group))
      deserialize_from_session(Group, @group, :id, :global)
    end
  end

  def get_edit_start_date_popup
    @propose_workflow = group_params[:propose_workflow].to_s.to_boolean
    @from_profile_flash = group_params[:from_profile_flash].to_s.to_boolean
  end

  def update_answers
    # Profile for group
    set_start_date_popup = group_params[:set_start_date_popup].to_s.to_boolean
    @from_propose_workflow = group_params[:propose_workflow].to_s.to_boolean
    @from_profile_flash = group_params[:from_profile_flash].to_s.to_boolean
    @edit_start_date = group_params[:edit_start_date].to_s.to_boolean
    
    @group.name = group_params[:group][:name] if group_params[:group][:name]
    @group.logo = group_params[:group][:logo] if group_params[:group][:logo]
    @group.start_date = group_params[:group][:start_date].in_time_zone(wob_member.get_valid_time_zone).beginning_of_day if group_params[:group][:start_date].present? && @current_program.allow_circle_start_date?
    @group.global = (group_params[:group][:global] == "1") if group_params[:group][:global]
    @group.notes = group_params[:group][:notes] if group_params[:group][:notes]
    if @group.save && (set_start_date_popup || (@group.update_answers(group_params[:connection_answers]) && update_membership_setting))
      if set_start_date_popup
        flash[:notice] = "flash_message.group_flash.set_start_date_success".translate(:mentoring_connection => _mentoring_connection) if @from_propose_workflow && @group.start_date.present?
      else
        flash[:notice] = "flash_message.group_flash.update_answers_success_v1".translate(:Mentoring_Connection => _Mentoring_Connection)
        redirect_to (@group.published? && @group.admin_enter_mentoring_connection?(@user) ? group_path(@group) : profile_group_path(@group))
      end
    else
      serialize_to_session(@group)
      redirect_to edit_answers_group_path(@group)
    end
  end

  # Schedules an export of the mentoring area to PDF, to be emailed to the user.
  #
  # === Params
  # +next_url+ - the next url to redirect to after processing the export.
  #
  def export
    @group.delay(queue: DjQueues::HIGH_PRIORITY).generate_and_email_mentoring_area(current_user, JobLog.generate_uuid, super_console?, current_locale)

    message = "flash_message.group_flash.export_successful_v1".translate(mentoring_area: _mentoring_connection)
    message = "#{message} #{'flash_message.group_flash.export_does_not_include_discussion_board'.translate}" if @group.forum_enabled?
    flash[:notice] = message

    respond_to do |format|
      format.js {}
      format.html { redirect_back(fallback_location: root_path) }
    end
  end

  # This action will assing a new mentor to a mentee in "Find a Mentor" page
  # This will be done after matching
  def assign_from_match
    student  = @current_program.student_users.find(group_params[:student_id])
    mentor = @current_program.mentor_users.find(group_params[:mentor_id])

    unless group_params[:group_id].blank?
      @group = @current_program.groups.find(group_params[:group_id])
      @group.message = group_params[:message]
      @group.assigned_from_match = true
      student_objs = [student, @group.students].flatten
      @group.update_members(@group.mentors, student_objs)
    else
      @group = @current_program.groups.new
      @group.mentors = [mentor]
      @group.students = [student]
      @group.message = group_params[:message]
      @group.actor = current_user
      if group_params[:mentoring_model].present? && @current_program.mentoring_connections_v2_enabled?
        mentoring_model = @current_program.mentoring_models.find(group_params[:mentoring_model])
        @group.mentoring_model = mentoring_model
      end

      if group_params[:group_status] == "draft"
        @group.created_by = current_user
        @group.status = Group::Status::DRAFTED
        @group.notes = group_params[:notes]
      end
      @group.save
    end

    if @group.valid?
      flash[:notice] = @group.drafted? ? "flash_message.group_flash.mentoring_connection_saved_as_draft_html".translate(:mentoring_connection => _mentoring_connection, :click_here => view_context.link_to("display_string.Click_here".translate, groups_path(tab: Group::Status::DRAFTED))) : "flash_message.group_flash.mentor_assigned_html".translate(:student => "<b>#{h(student.name)}</b>".html_safe, :mentoring_connection => _mentoring_connection)
    else
      flash[:error] = @group.errors.full_messages.to_sentence
    end
    redirect_to matches_for_student_users_path
  end

  def assign_match_form
    @mentor_groups = @mentor.mentoring_groups.active - Group.involving(@student, @mentor)
    render partial: "groups/assign_matched_mentor.html"
  end

  def save_as_draft
    render partial: "groups/save_as_draft"
  end

  def leave_connection
    if request.xhr?
      render :partial => "groups/leave_connection_popup.html", :layout => false
    else
      @group.actor = current_user
      membership = @group.memberships.where(:user_id => current_user.id).first
      if @group.is_terminate_action_for?(current_user)
        @group.termination_reason = group_params[:group][:termination_reason]
        @group.terminate!(current_user, @group.termination_reason, group_params[:group][:closure_reason], Group::TerminationMode::LEAVING)
        track_activity_for_ei(EngagementIndex::Activity::CLOSE_CONNECTION)
        flash[:notice] =  "flash_message.group_flash.group_closed".translate(:Mentoring_Connection => _Mentoring_Connection)
      else
        membership.leave_connection_callback = true
        membership.leaving_reason = group_params[:group][:termination_reason]
        if membership.destroy
          track_activity_for_ei(EngagementIndex::Activity::LEAVE_CONNECTION)
        end
        flash[:notice] =  "flash_message.group_flash.membership_destroy".translate(:Mentoring_Connection => _Mentoring_Connection)
      end
      redirect_to program_root_path
    end
  end

  def fetch_notes
    @tab_number = group_params[:tab].to_i
    render :partial => "update_notes_popup", :layout => false
  end

  def update_notes
    @tab_number = group_params[:tab].to_i
    @group.update_attributes!(group_strong_params(:update_notes))
    @mentoring_model_v2_enabled = @current_program.mentoring_connections_v2_enabled?
  end

  def set_expiry_date
    @tab_number = group_params[:tab].to_i
    render :partial => "set_expiry_date", :layout => false
  end

  def fetch_terminate
    render :partial => "termination_reason", :layout => false
  end

  def fetch_reactivate
    unless request.xhr?
      redirect_to groups_path(reactivate_group_id: group_params[:id], tab: Group::Status::CLOSED, src: group_params[:src]) and return
    end

    fetch_inconsistent_roles(@group)
    render :partial => "reactivation_popup", :layout => false
  end

  def fetch_publish
    render partial: "publish_popup", layout: false, locals: { reached_critical_mass: group_params[:reached_critical_mass], ga_src: group_params[:ga_src] }
  end

  def fetch_discard
    render :partial => "discard_popup", :layout => false
  end

  def fetch_withdraw
    render :partial => "withdraw_popup", :layout => false
  end

  def fetch_custom_task_status_filter
    @templates = @current_program.mentoring_models
    @selected_template = group_params[:template].present? ? @templates.find{|t| t.id == group_params[:template].to_i} : @current_program.default_mentoring_model
    render :partial => "groups/custom_task_status_filter", :layout => false
  end

  def reset_task_options_for_custom_task_status_filter
    @selected_template = group_params[:template].present? ? @current_program.mentoring_models.find(group_params[:template].to_i) : @current_program.default_mentoring_model
  end

  def update_expiry_date
    @tab_number = group_params[:tab].to_i
    mentoring_period_en = get_en_datetime_str(group_params[:mentoring_period]) if group_params[:mentoring_period].present?
    if @group.change_expiry_date(current_user, mentoring_period_en, group_params[:revoking_reason])
      track_activity_for_ei(EngagementIndex::Activity::EXTEND_MENTORING_SESSION) if @is_member_view
    else
      @error_flash = @group.errors.full_messages.to_sentence
    end
  end

  def reactivate
    mentoring_period_en = get_en_datetime_str(group_params[:mentoring_period]) if group_params[:mentoring_period].present?
    unless @group.change_expiry_date(current_user, mentoring_period_en, group_params[:revoking_reason], {:clear_closure_reason => true})
      @error_flash = @group.errors.full_messages.to_sentence
    end
    handle_redirection_for_reactivate(group_params[:src])
  end

  def fetch_bulk_actions
    @action_type = group_params[:bulk_action][:action_type]
    @group_ids = group_params[:bulk_action][:group_ids]
    @groups = @current_program.groups.where(id: @group_ids)
    @tab_number = group_params[:bulk_action][:tab_number].to_i
    @individual_action = group_params[:individual_action].present?
    case @action_type.to_i
    when Group::BulkAction::PUBLISH
      render :partial => "groups/bulk_actions/bulk_publish", :layout => false
    when Group::BulkAction::DISCARD
      render :partial => "groups/bulk_actions/bulk_discard", :layout => false
    when Group::BulkAction::REACTIVATE
      render :partial => "groups/bulk_actions/bulk_reactivate", :layout => false
    when Group::BulkAction::SET_EXPIRY_DATE
      render :partial => "groups/bulk_actions/bulk_set_expiry", :layout => false
    when Group::BulkAction::TERMINATE
      render :partial => "groups/bulk_actions/bulk_terminate", :layout => false
    when Group::BulkAction::EXPORT
      render :partial => "groups/bulk_actions/bulk_export", :layout => false
    when Group::BulkAction::ASSIGN_TEMPLATE
      @mentoring_models = get_all_mentoring_models(current_program)
      render partial: "groups/bulk_actions/bulk_assign_template", :layout => false
    when Group::BulkAction::MAKE_AVAILABLE
      @show_start_date_field = @individual_action && @groups.first.has_past_start_date?(wob_member) && @current_program.allow_circle_start_date?
      render partial: "groups/bulk_actions/bulk_make_available", :layout => false
    when Group::BulkAction::ACCEPT_PROPOSAL
      @mentoring_models = get_all_mentoring_models(current_program)
      @show_start_date_field = @individual_action && @groups.first.has_past_start_date?(wob_member) && @current_program.allow_circle_start_date?
      render partial: "groups/bulk_actions/bulk_accept_proposal", :layout => false
    when Group::BulkAction::REJECT_PROPOSAL
      render partial: "groups/bulk_actions/bulk_reject_proposal", :layout => false
    when Group::BulkAction::WITHDRAW_PROPOSAL
      render partial: "groups/bulk_actions/bulk_withdraw_proposal", :layout => false, :locals => {ga_src: group_params[:ga_src]}
    when Group::BulkAction::DUPLICATE
      render partial: "groups/bulk_actions/bulk_duplicate", layout: false, locals: { mentoring_models: get_all_mentoring_models(current_program)}
    end
  end

  def update_bulk_actions
    with_new_start_date = group_params[:with_new_start_date].to_s.to_boolean
    @tab_number = group_params[:bulk_actions][:tab_number].to_i
    @ga_src = group_params[:ga_src]
    @groups_with_past_start_date = []
    case @action_type.to_i
    when Group::BulkAction::PUBLISH
      allow_join = group_params[:group].try(:[], :membership_settings).try(:[], :allow_join) || "false"
      publish_groups(@groups, allow_join) and return
    when Group::BulkAction::DISCARD
      discard_groups(@groups)
    when Group::BulkAction::REACTIVATE
      reactivate_or_set_expiry_date_groups(@groups)
    when Group::BulkAction::SET_EXPIRY_DATE
      reactivate_or_set_expiry_date_groups(@groups, true)
    when Group::BulkAction::TERMINATE
      terminate_groups(@groups)
    when Group::BulkAction::EXPORT
      export_groups_csv(@groups, @tab_number)
    when Group::BulkAction::ASSIGN_TEMPLATE
      allow! exec: Proc.new{ @groups.not_published.exists? }
      @mentoring_model = current_program.mentoring_models.find(group_params[:mentoring_model])
      if group_params[GroupsHelper::GROUPS_ALERT_FLAG_NAME] != "true"
        @assign_template_alert = view_context.assign_template_alert(@groups, @mentoring_model)
        return if @assign_template_alert.present?
      end
      @groups.each{|group| group.update_attribute(:mentoring_model_id, @mentoring_model.id)}
    when Group::BulkAction::MAKE_AVAILABLE
      allow! exec: Proc.new{ !@groups.where("status NOT IN (?)", [Group::Status::DRAFTED]).exists? }
      set_groups_with_past_start_date if @current_program.allow_circle_start_date?
      if with_new_start_date || !@groups_with_past_start_date.present?
        @groups.find_each do |group|
          group.status = Group::Status::PENDING
          group.message = group_params[:bulk_actions][:message]
          group.actor = current_user
          group.start_date = group_params[:start_date].in_time_zone(wob_member.get_valid_time_zone).beginning_of_day if with_new_start_date && group_params[:start_date].present?
          group.save!
        end
      else
        set_bulk_action_failed_with_past_start_date_flash
      end
    when Group::BulkAction::ACCEPT_PROPOSAL
      @mentoring_model = current_program.mentoring_models.find(group_params[:mentoring_model])
      set_groups_with_past_start_date if @current_program.allow_circle_start_date?
      if with_new_start_date || !@groups_with_past_start_date.present?
        @groups.find_each do |group|
          group.status = Group::Status::PENDING
          group.message = group_params[:bulk_actions][:message]
          group.mentoring_model_id = @mentoring_model.id
          group.pending_at = Time.now.utc
          group.start_date = group_params[:start_date].in_time_zone(wob_member.get_valid_time_zone).beginning_of_day if with_new_start_date && group_params[:start_date].present?
          group.skip_observer = true
          made_proposer_owner = false
          ActiveRecord::Base.transaction do
            if group_params[:make_proposer_owner] && group.created_by.present? && group.has_member?(group.created_by)
              group.make_proposer_owner!
              made_proposer_owner = true
            end
            group.save!
          end
          Group.delay(:queue => DjQueues::HIGH_PRIORITY).send_group_accepted_emails(group.id, group.message, made_proposer_owner)
          Push::Base.queued_notify(PushNotification::Type::PBE_PROPOSAL_ACCEPTED, group)
        end
      else
        set_bulk_action_failed_with_past_start_date_flash
      end
    when Group::BulkAction::REJECT_PROPOSAL
      @groups.find_each do |group|
        group.terminate!(
          current_user, group_params[:bulk_actions][:message], nil,
          Group::TerminationMode::REJECTION, Group::Status::REJECTED
        )
        Group.delay(:queue => DjQueues::HIGH_PRIORITY).send_group_rejected_emails(group.id)
        Push::Base.queued_notify(PushNotification::Type::PBE_PROPOSAL_REJECTED, group)
      end
    when Group::BulkAction::WITHDRAW_PROPOSAL
      withdraw_groups(@groups, group_params[:bulk_actions][:message])
    when Group::BulkAction::DUPLICATE
      duplicate_groups(@groups, group_params)
    end

    @redirect_path = profile_group_path(@groups.first) if group_params[:src] == "profile"
    
    if @redirect_path.present?
      if request.xhr?
        render js: "closeQtip(); window.location.href = \'#{@redirect_path}\'"
      else
        redirect_to @redirect_path
      end
    end
  end

  def edit_columns
    profile_questions_hash = {}
    @current_program.roles.for_mentoring.includes(:translations, customized_term: :translations).each do |role|
      profile_questions_hash[role] = @group_view.profile_questions_for_role(role)
    end
    connection_questions = @current_program.connection_questions
    @tab_number = group_params[:tab].present? ? group_params[:tab].to_i : session[:groups_tab].to_i
    render partial: "group_views/edit", locals: { view: @view, tab: @tab_number, profile_questions_hash: profile_questions_hash, connection_questions: connection_questions }
  end

  def select_all_ids
    session[:groups_tab] = group_params[:tab] if group_params[:tab].present?
    @tab_number = session[:groups_tab].to_i

    @is_manage_connections_view = true
    @mentoring_model_v2_enabled = @current_program.mentoring_connections_v2_enabled?
    @v2_tasks_overdue_filter = @mentoring_model_v2_enabled && (@tab_number == Group::Status::ACTIVE)
    @groups_scope = @current_program.groups
    @my_filters = []
    @with_options = {}

    initialize_common_search_filters if group_params[:search_filters].present?
    if @tab_number == Group::Status::ACTIVE
      @with_options[:status_filter] = true
    elsif group_params[:filter_field].present?
      @with_options[:status] = group_params[:filter_field].is_a?(Array) ? group_params[:filter_field].map(&:to_i) : group_params[:filter_field].to_i
    end
    handle_filters_and_init_connections_questions

    es_filter_hash = construct_group_search_options
    group_ids = Group.get_filtered_group_ids(es_filter_hash).map(&:to_s)
    render json: { group_ids: group_ids }
  end

  def get_activity_details
    @login_activity = @group.login_activity
    @scraps_activity = @group.scraps_activity if @group.scraps_enabled?
    @posts_activity = @group.posts_activity if @group.forum_enabled?
    @meetings_activity = @group.meetings_activity if @group.meetings_enabled?(@current_program.roles.for_mentoring)
    if @current_program.mentoring_connections_v2_enabled?
      @survey_answers = @group.survey_answers.select([:user_id, :response_id, :group_id]).distinct.group_by(&:user_id) if @current_program.surveys.of_engagement_type.present?
      mentoring_model_roles = @current_program.roles.for_mentoring_models
      @tasks_activity = @group.tasks_activity if @group.can_manage_mm_tasks?(mentoring_model_roles)
    end
  end

  def find_new
    @find_new = true
    @search_query = group_params[:search]
    @my_filters = []
    # Expiry, Mentors, Mentees filters
    initialize_common_search_filters if group_params[:search_filters].present?
    filter_params, @with_options = sphinx_params_for_find_new
    @groups_scope = @current_program.groups
    filter_and_init_connections_questions({find_new: true})
    handle_membership_based_filter if group_params[:member_filters]
    handle_available_to_join_filter(@groups_scope, @with_options)
    filter_params[:search_query] = make_search_query(group_params[:search_filters], @search_query)
    @es_filter_hash = construct_group_search_options(filter_params)
    @es_filter_hash[:must_filters].merge!(program_id: @current_program.id)
    @groups = Group.get_filtered_groups(@es_filter_hash.merge(page: group_params[:page] || 1, per_page: DETAILED_VIEW_PER_PAGE))
    @my_filters += initialize_my_filters
  end

  def fetch_owners
    @from_index = group_params[:from_index]
    @tab_number = group_params[:tab].to_i
    @view = group_params[:view].to_i
  end

  def update_owners
    @from_index = group_params[:from_index]
    @tab_number = group_params[:tab].to_i
    @view = group_params[:view].to_i
    @is_manage_connections_view = current_user.can_manage_connections?
    owner_ids = group_params["group_owner"].split(',').map(&:to_i)
    old_owner_ids = @group.owner_ids
    owner_ids_to_remove = old_owner_ids - owner_ids
    owner_ids_to_add = owner_ids - old_owner_ids
    @group.memberships.includes(:user).where(user_id: owner_ids_to_add).each do |membership|
      membership.update_attributes!(:owner => true)
      Group.delay(:queue => DjQueues::HIGH_PRIORITY).send_owner_addition_notification(membership.user, @group)
    end
    @group.memberships.where(user_id: owner_ids_to_remove).update_all(owner: false)
    flash[:notice] = "feature.connection.content.update_successful".translate(mentoring_connection: _mentoring_connection) unless @from_index
    @owners_changed = true if owner_ids_to_remove.present? || owner_ids_to_add.present?
  end

  def survey_response
    srl = SurveyResponseListing.new(@current_program, @group, group_params)
    @questions = srl.get_survey_questions_for_meeting_or_group
    @user = srl.get_user_for_meeting_or_group
    @answers = srl.get_survey_answers_for_meeting_or_group
  end

  def fetch_survey_questions
    @engagement_survey = @current_program.surveys.of_engagement_type.find(group_params[:survey_id]) if group_params[:survey_id].present?
    @survey_questions = @engagement_survey.get_questions_in_order_for_report_filters if @engagement_survey
    @is_reports_view = group_params[:is_reports_view].to_s.to_boolean
  end

  def fetch_survey_answers
    engagement_survey = @current_program.surveys.of_engagement_type.find(group_params[:survey_id]) if group_params[:survey_id].present?
    @survey_question = engagement_survey.get_questions_for_report_filters.find(group_params[:question_id]) if engagement_survey && group_params[:question_id].present?
    @is_reports_view = group_params[:is_reports_view].to_s.to_boolean
  end

  def get_users_of_role
    @show_skype = @current_organization.skype_enabled?
    @allow_individual_messaging = @group.has_member?(current_user) && !@group.scraps_enabled? && @current_program.allow_user_to_send_message_outside_mentoring_area?
    @role_id = group_params[:role_id].to_i
    @members_in_role = @group.get_users(@role_id)
  end

  def group_params
    if params[:filters_applied].present?
      params
    elsif params[:abstract_view_id] && @_abstract_view.nil?
      @_abstract_view = current_program.abstract_views.find(params[:abstract_view_id])
      @_abstract_view.filter_params_hash[:params].each do |key, value|
        params[key] = value unless params.has_key?(key)
      end
      @_group_params_with_abstract_view_params = params
    elsif params[:abstract_view_id] && @_abstract_view
      @_group_params_with_abstract_view_params
    else
      params
    end
  end

  def edit_join_settings
    render partial: "edit_join_settings", layout: false
  end

  def update_join_settings
    role_permission_map = group_params[:group][:role_permission]
    current_program.roles.for_mentoring.with_permission_name(RolePermission::SEND_PROJECT_REQUEST).each do |role|
      role_id = role.id
      next unless role_permission_map.has_key?(role_id.to_s)

      if role_permission_map[role_id.to_s].to_boolean
        group_setting = @group.setting_for_role_id(role_id)
        group_setting.update_attributes(allow_join: nil) if group_setting.present? && (group_setting.allow_join == false)
      else
        group_setting = @group.membership_settings.find_or_create_by!(role_id: role_id)
        group_setting.update_attributes(allow_join: false) if group_setting.allow_join.nil?
      end
    end
  end

  def get_similar_circles
    @similar_circles = get_similar_circles_list
  end

  def auto_complete_for_name
    list_groups = get_groups_list
    group_roles = current_program.roles.for_mentoring.includes(:permissions, customized_term: :translations)
    render json: { groups: list_groups.map{ |group| generate_hash(group, group_roles) }, total_count: list_groups.total_entries }.to_json
  end

  private

  def handle_redirection_for_reactivate(source)
    return unless  source.in?(ReactivationSrc::REDIRECTION_ALLOWED)
    if @error_flash.present?
      flash[:error] = @error_flash
    else
      flash[:notice] = "flash_message.group_flash.reactivated_v1".translate(mentoring_connection: _mentoring_connection)
    end
    case source
    when ReactivationSrc::PROFILE
      redirect_to profile_group_path(@group)
    when ReactivationSrc::NOTICE
      redirect_to group_path(@group)
    end
  end

  def handle_fetch_reactivate_group
    return if @filter_field != Group::Status::CLOSED || group_params[:reactivate_group_id].blank?

    @group = current_program.groups.find_by(id: group_params[:reactivate_group_id].to_i)
    allow! exec: Proc.new { @group&.can_be_reactivated_by_user?(current_user) }
    @source = group_params[:src]
    @reactivate_group = true
    fetch_inconsistent_roles(@group)
  end

  def set_proposer_as_owner_of_group
    @group.membership_of(current_user).update_attribute(:owner, true)
  end

  def set_circle_start_date_params
    @show_set_start_date_popup = group_params[:show_set_start_date_popup].to_s.to_boolean
    @manage_circle_members = group_params[:manage_circle_members].to_s.to_boolean
  end

  def set_groups_with_past_start_date
    @groups_with_past_start_date = @current_program.groups.where("groups.id IN (?) AND groups.start_date IS NOT NULL AND groups.start_date < ?", @group_ids, Time.now + Group::AUTO_PUBLISH_CRON_DURATION_DIFFERENCE.hours)
  end

  def set_bulk_action_failed_with_past_start_date_flash
    @error_flash = ["feature.connection.content.bulk_make_available_failure_message_html".translate(mentoring_connection_term: @groups_with_past_start_date.size > 1 ? _mentoring_connections : _mentoring_connection, mentoring_connection: _mentoring_connection, connections_with_past_dates: @groups_with_past_start_date.map{|group| view_context.link_to(group.name, profile_group_path(group), target: "_blank")}.join(", ").html_safe)]
  end

  def redirect_if_bulk_limit_exceeded
    bulk_action_limit = Group::BulkActionLimit[@action_type.to_i]
    if bulk_action_limit.present? && @groups.size > bulk_action_limit
      flash[:error] = "feature.connection.content.bulk_limit_exceeded".translate(count: bulk_action_limit, mentoring_connections_term: _mentoring_connections)
      redirect_to groups_path
    end
  end

  def fetch_groups_and_action_type
    @action_type = group_params[:bulk_actions][:action_type]
    @group_ids = group_params[:bulk_actions][:group_ids].split(" ")
    @groups = @current_program.groups.where(id: @group_ids)
  end

  def get_groups_list
    without_options = group_params[:groupIdToIgnore].present? ? { id: group_params[:groupIdToIgnore].to_i } : {}
    options = { must_filters: { program_id: current_program.id, status: Group::Status::OPEN_CRITERIA }, sort: { published_at: "asc", pending_at: "asc" }, per_page: SELECT2_PER_PAGE_LIMIT, must_not_filters: without_options, page: group_params[:page].try(:to_i) }
    options.merge!({ search_conditions: { fields: ["name.autocomplete"], search_text: QueryHelper::EsUtils.sanitize_es_query(group_params[:search]) }, operator: "AND" }) if group_params[:search].present?
    Group.get_filtered_groups(options)
  end

  def get_similar_circles_list
    options = { must_filters: { program_id: current_program.id, status: Group::Status::OPEN_CRITERIA }, per_page: MAX_SIMILAR_CIRCLES_IN_DROPDOWN, page: 1 , sort: { _score: "desc", published_at: "desc", pending_at: "desc" }}
    options.merge!({ search_conditions: { fields: ["name.autocomplete"], search_text: QueryHelper::EsUtils.sanitize_es_query( group_params[:search]), operator: "OR"} }) if group_params[:search].present?
    options.merge!({should_filters: [get_availability_slot_filter_hash_for_user]}) unless current_user.is_admin?
    Group.get_filtered_groups(options)
  end

  def get_availability_slot_filter_hash_for_user
    filter_hash = {}
    current_user.roles.for_mentoring.each do |role|
      filter_hash["membership_setting_slots_remaining.#{role.name}"] = {gt: 0}
    end
    filter_hash
  end

  def handle_update_from_admin_view
    allow! exec: lambda{ current_user.is_admin? }
    mentors, students, other_roles_hash = split_users_by_roles
    @group.message = group_params[:group][:message]
    if @group.update_members(mentors, students, current_user, other_roles_hash: other_roles_hash, check_actor_can_update_members: true, disallow_removal: true)
      @success_flash = "flash_message.group_flash.admin_view_update_success".translate(group_name: @group.name)
    end
  end

  def generate_hash(group, group_roles)
    {
      name: view_context.display_project_based_group_in_auto_complete(group, group_roles).html_safe,
      groupId: group.id,
    }
  end

  def fetch_inconsistent_roles(group)
    @inconsistent_roles = {}
    group.memberships.includes(:role, [:user => :roles]).group_by(&:role).each do |role, memberships|
      memberships.collect(&:user).each do |user|
        (@inconsistent_roles[role] ||= []) << user unless user.roles.include?(role)
      end
    end
    @inconsistent_roles
  end

  def build_duplicate_group!(group_id, options = {})
    source_group =  @current_program.groups.find(group_id.to_i)

    allow! exec: -> { source_group.closed? && !@current_program.project_based? && current_user.can_manage_connections? }

    @is_clone = true

    return if fetch_inconsistent_roles(source_group).present?

    options.merge!(program: @current_program)

    clone_factory = Group::CloneFactory.new(source_group, options)

    return clone_factory.clone
  end

  def can_access_join_settings
    @group.active? && @group.program.allows_users_to_apply_to_join_in_project?
  end

  def group_strong_params(action)
    group_params[:group].try(:permit, Group::MASS_UPDATE_ATTRIBUTES[action])
  end

  def get_connection_plan_values_and_update_milestone_status
    get_values_connection_plan_v2
    update_milestone_status unless @mentoring_model_milestones.nil?
  end

  def set_target_user_and_type
    get_target_user_for_v2(@group, group_params)
    update_target_user_type(@group, group_params)
  end

  def set_page_view
    @home_page_view = group_params[:home_page_view].to_s.to_boolean
    if @home_page_view
      compute_page_controls_allowed
      compute_surveys_controls_allowed
    end
  end

  def update_target_user_info
    membership = @group.membership_of(current_user)
    target_user_info = group_params[:target_user_id].presence || group_params[:target_user_type].presence
    membership.update_attributes!(last_applied_task_filter: {user_info: target_user_info, view_mode: group_params[:view_mode]}) if @is_member_view && target_user_info.present? && group_params[:view_mode].present?
  end

  def set_attributes_for_updated_members
    @role = @current_program.roles.find(group_params[:role_id])
    @group = Group.find(group_params[:group_id])
    selected_member = group_params[:add_member] || group_params[:replace_member]
    @new_user = User.find_by_email_program(selected_member[/#{"<"}(.*?)#{">"}/m, 1], @current_program)
    @error_flash = "flash_message.group_flash.invalid_member".translate if @new_user.nil? || (@new_user.present? && !@new_user.has_role?(@role.name))
  end

  def initialize_existing_groups_alert_data
    return if @error_flash.present? || !@current_program.show_existing_groups_alert?

    student_role = @current_program.find_role RoleConstants::STUDENT_NAME
    mentor_role = @current_program.find_role RoleConstants::MENTOR_NAME
    @student_ids_mentor_ids = [fetch_selected_user_ids(student_role.id), fetch_selected_user_ids(mentor_role.id)]
  end

  def fetch_selected_user_ids(role_id)
    selected_user_ids = group_params[:selected_user_ids][role_id.to_s] || ""
    selected_user_ids = selected_user_ids.split(",").select(&:present?).collect(&:to_i)
    if role_id == group_params[:role_id].to_i
      case group_params[:action]
      when "add_new_member"
        selected_user_ids << @new_user.id
      when "remove_new_member"
        selected_user_ids -= [group_params[:user_id].to_i]
      when "replace_member"
        selected_user_ids -= [group_params[:user_id].to_i]
        selected_user_ids << @new_user.id
      end
    end
    selected_user_ids
  end

  def get_non_empty_completed_mentoring_model_milestones
    completed_mentoring_model_milestones = @mentoring_model_milestones.completed
    empty_milestone_ids = []
    completed_mentoring_model_milestones.each do |cm|
      meetings_and_tasks = @mentoring_model_tasks[cm.id]
      empty_milestone_ids << cm.id if !meetings_and_tasks.any?{|item| item.is_a?(MentoringModel::Task)}
    end
    completed_mentoring_model_milestones.where.not(id: empty_milestone_ids)
  end

  def get_current_mentoring_model_milestones
    current_mentoring_model_milestones = @mentoring_model_milestones.overdue.to_a
    current_mentoring_model_milestones += [@mentoring_model_milestones.current.first] if @mentoring_model_milestones.current.present?
    # 'uniq' since a milestone can be both; current and overdue at the same time.
    current_mentoring_model_milestones.uniq.sort_by(&:position)
  end

  def update_milestone_status
    @zero_upcoming_tasks = false
    @completed_mentoring_model_milestone_ids = []
    @mentoring_model_milestone_ids_to_expand = []

    if view_by_due_date?
      @zero_upcoming_tasks = MentoringModel::Task.get_upcoming_tasks(@mentoring_model_tasks).blank?
    else
      completed_mentoring_model_milestones = get_non_empty_completed_mentoring_model_milestones
      completed_mentoring_model_milestones_to_expand = completed_mentoring_model_milestones.with_incomplete_optional_tasks
      current_mentoring_model_milestones = get_current_mentoring_model_milestones
      completed_mentoring_model_milestones_to_hide = get_completed_milestones_to_hide(completed_mentoring_model_milestones, current_mentoring_model_milestones)
      @mentoring_model_milestones -= completed_mentoring_model_milestones_to_hide
      @mentoring_model_milestones = @group.get_connections_widget_milestones(@mentoring_model_milestones, current_user) if @home_page_view

      if current_mentoring_model_milestones.blank?
        current_mentoring_model_milestones = @mentoring_model_milestones
      end
      @completed_mentoring_model_milestone_ids = completed_mentoring_model_milestones.pluck(:id)
      @completed_mentoring_model_milestone_ids_to_hide = completed_mentoring_model_milestones_to_hide.collect(&:id)
      @mentoring_model_milestone_ids_to_expand = completed_mentoring_model_milestones_to_expand.pluck(:id) + current_mentoring_model_milestones.collect(&:id)
    end
  end

  def get_completed_milestones_to_hide(completed_mentoring_model_milestones, current_mentoring_model_milestones)
    current_mentoring_model_milestones.present? ? completed_mentoring_model_milestones.positioned_before(current_mentoring_model_milestones.first.position.to_i) : completed_mentoring_model_milestones
  end

  def make_search_query(search_filters, search_query)
    quick_search_string = search_filters && search_filters[:quick_search]
    @my_filters << {:label => "#{'feature.user.filter.Keyword'.translate} (#{quick_search_string})", :reset_suffix => "quick_search"} if quick_search_string.present?
    (quick_search_string.presence || search_query || '').squeeze(" ")
  end

  def update_should_show_tour(group)
    user = current_member.user_in_program(current_program)
    @show_tour_v2 = @is_member_view && (group.members.size > SHOW_DEFAULT_ALL_MEMBERS_LIMIT) && !OneTimeFlag.has_tag?(user, OneTimeFlag::Flags::TourTags::GROUP_SHOW_V2_TOUR_TAG)
  end

  def get_values_connection_plan_v2
    update_should_show_tour(@group)
    @mentoring_model_tasks = {}
    if manage_mm_milestones_at_admin_level?(@group) || manage_mm_milestones_at_end_user_level?
      @mentoring_model_milestones = @group.mentoring_model_milestones
      if view_by_milestones?
        mentoring_plan_objects = @group.get_tasks_list(task_eager_loadables, milestones_enabled: true, milestones: @mentoring_model_milestones, view_mode: @view_mode, target_user: @target_user, target_user_type: @target_user_type, home_page_view: @home_page_view)
        @mentoring_model_milestones.each do |milestone|
          @mentoring_model_tasks[milestone.id] = mentoring_plan_objects.select{|plan_object| plan_object.milestone_id == milestone.id}
        end
      elsif view_by_due_date?
        @mentoring_model_milestones = @group.get_connections_widget_milestones(@mentoring_model_milestones, current_user) if @home_page_view
        @mentoring_model_tasks = get_all_mentoring_model_task_list_items(@group, target_user: @target_user, target_user_type: @target_user_type)
      end
    elsif manage_mm_tasks_at_admin_level?(@group) || manage_mm_tasks_at_end_user_level?(@group)
      @mentoring_model_tasks = get_all_mentoring_model_task_list_items(@group, target_user: @target_user, target_user_type: @target_user_type)
    end
    if manage_mm_goals_at_admin_level?(@group) || manage_mm_goals_at_end_user_level?(@group)
      @goals_cache = @group.mentoring_model_goals.pluck(:id)
    end
  end

  def fetch_source_and_check_from_member_profile
    @source = group_params[:src]
    @from_member_profile = @source == "member_groups"
  end

  def get_sql_includes_hash(current_view, options = {})
    if current_view == Group::View::LIST
      inner_list = [:member => [:profile_answers => [:educations, :experiences, :publications]]]
      include_attrs = [:answers, :mentors => inner_list, :students => inner_list]
      if options[:goals_enabled]
        (include_attrs += [:mentoring_model_tasks, :mentoring_model_goals])
      end
      include_attrs += [:mentoring_model] if options[:mentoring_model_v2_enabled]
      include_attrs
    elsif current_view == Group::View::DETAILED
      include_attrs = [{:memberships => [:user => [:member, :roles]]},:scraps, :object_role_permissions]
      if options[:mentoring_model_v2_enabled]
        include_attrs += [:mentoring_model_tasks, [:mentoring_model_goals => :mentoring_model_tasks], :mentoring_model_milestones]
        include_attrs << :mentoring_model
      end
      include_attrs << :answers if @connection_questions.present?
      include_attrs += [:active_project_requests, :membership_settings] if options[:pbe_enabled]
      include_attrs
    else
      {}
    end
  end

  def export_groups_csv(groups, tab_number)
    report_file_name = "#{_Mentoring_Connections}_#{DateTime.localize(Time.current, format: :csv_timestamp)}".to_html_id
    send_csv generate_mentoring_connections_csv(groups, tab_number.to_i),
      :disposition => "attachment; filename=#{report_file_name}.csv"
  end

  def publish_groups(groups, allow_join = true)
    group_params[:publish_progress_id].present? ? render_publish_complete : bulk_group_publish_with_progress(groups, allow_join)
  end

  def bulk_group_publish_with_progress(groups, allow_join)
    bulk_group_publish = BulkGroupPublish.new(groups, get_options_for_bulk_publish(groups, allow_join))
    bulk_group_publish.delay(queue: DjQueues::HIGH_PRIORITY).publish_groups_background
    @progress = bulk_group_publish.progress
    @data = { bulk_actions: { group_ids: group_params[:bulk_actions][:group_ids], action_type: @action_type }, publish_progress_id: @progress.id }
    render "groups/bulk_actions/bulk_publish.js.erb"
  end

  def get_options_for_bulk_publish(groups, allow_join)
    options = group_params[:src] == "profile" ? { redirect_path: profile_group_path(groups.first) } : {}
    options.merge({ allow_join: allow_join , current_user: current_user, message: group_params[:bulk_actions][:message], mentoring_connections_term: _mentoring_connections })
  end

  def render_publish_complete
    progress_status = ProgressStatus.find_by(id: group_params[:publish_progress_id])
    details = progress_status.details || {}

    redirect_path = details[:redirect_path]
    render js: "window.location.href = \'#{redirect_path}\'" and return if redirect_path.present?
    @error_flash = details[:error_flash]
    @error_groups = Group.where(id: details[:error_group_ids])
    progress_status.update_columns(details: nil, skip_delta_indexing: true)
  end

  def discard_groups(groups)
    groups.each do |group|
      group.destroy
    end
  end

  def withdraw_groups(groups, withdraw_reason)
    groups.each do |group|
      group.terminate!(
        current_user, withdraw_reason, nil,
        Group::TerminationMode::WITHDRAWN, Group::Status::WITHDRAWN
      )
      Group.delay.send_group_withdrawn_emails(group.id)
    end
  end

  def get_duplicate_groups_error_flash(errors)
    error_flash = []
    errors.each do |error|
      error_flash << content_tag(:li, error)
    end
    [content_tag(:ul, safe_join(error_flash)).html_safe]
  end

  def get_duplicate_groups_errors(cloned_groups)
    cloned_groups.map do |cloned_group|
      "#{cloned_group.name} : #{cloned_group.errors.full_messages.to_sentence}" if cloned_group.errors.present?
    end.compact
  end

  def duplicate_groups(groups, group_params)
    is_draft = group_params[:draft]
    cloned_groups = build_duplicate_groups(groups)
    unless @error_flash.present?
      cloned_groups.each{ |cloned_group| cloned_group.status = Group::Status::DRAFTED } if is_draft
      cloned_groups.each{ |cloned_group| assign_attributes_to_cloned_group(cloned_group, group_params) }
      cloned_groups.map(&:save)
      handle_duplicate_completion(cloned_groups, is_draft)
    end
  end

  def build_duplicate_groups(groups)
    errors = []
    cloned_groups = []
    groups.each do |source_group|
      cloned_groups << build_duplicate_group!(source_group.id, bulk_duplicate: true, clone_mentoring_model: @current_program.mentoring_connections_v2_enabled?)
      if @inconsistent_roles.present?
        errors << "#{source_group.name} : #{get_inconsistent_roles_reason(current_program, @inconsistent_roles)}"
      end
    end
    @error_flash = get_duplicate_groups_error_flash(errors) if errors.present?
    cloned_groups
  end

  def assign_attributes_to_cloned_group(cloned_group, group_params)
    assign_actor_and_creator(cloned_group)
    cloned_group.notes = group_params[:bulk_actions][:notes]
    cloned_group.message = group_params[:bulk_actions][:message]
    cloned_group.mentoring_model = current_program.mentoring_models.find(group_params[:mentoring_model]) if group_params[:bulk_actions][:assign_new_template].to_s.to_boolean
  end

  def assign_actor_and_creator(group)
    group.created_by = current_user
    group.actor = current_user
  end

  def handle_duplicate_completion(cloned_groups, is_draft)
    errors = get_duplicate_groups_errors(cloned_groups)
    @tab_id = is_draft ? "cjs_drafted_count" : "cjs_ongoing_count"
    if errors.present?
      handle_duplicate_errors(errors, is_draft)
    else
      handle_duplicate_success(is_draft)
    end
  end

  def handle_duplicate_success(is_draft)
    @number_of_groups_duplicated = @groups.size
    @success_flash =  if is_draft
      "feature.connection.content.draft_success".translate(Mentoring_Connections: _Mentoring_Connections)
    else
      "feature.connection.content.publish_success".translate(Mentoring_Connections: _Mentoring_Connections)
    end
  end

  def handle_duplicate_errors(errors, is_draft)
    @number_of_groups_duplicated = @groups.size - errors.size
    if @number_of_groups_duplicated == 0
      @error_flash = get_duplicate_groups_error_flash(errors)
    else
      @success_flash = get_partial_errors_flash(errors, is_draft)
    end
  end

  def get_partial_errors_flash(errors, is_draft)
    if is_draft
      safe_join([append_text_to_icon("fa fa-check-circle", "feature.connection.content.duplicate_draft_success".translate(count: @number_of_groups_duplicated, total_number_of_groups: @groups.size, mentoring_connections: _mentoring_connections)),
      append_text_to_icon("fa fa-times-circle","feature.connection.content.duplicate_draft_errors".translate(count: errors.size, mentoring_connections: _mentoring_connections, mentoring_connection: _mentoring_connection)),
      get_duplicate_groups_error_flash(errors)], tag(:br))
    else
      safe_join([append_text_to_icon("fa fa-check-circle", "feature.connection.content.duplicate_success".translate(count: @number_of_groups_duplicated, total_number_of_groups: @groups.size, mentoring_connections: _mentoring_connections)),
      append_text_to_icon("fa fa-times-circle","feature.connection.content.duplicate_errors".translate(count: errors.size, mentoring_connections: _mentoring_connections, mentoring_connection: _mentoring_connection)),
      get_duplicate_groups_error_flash(errors)], tag(:br))
    end
  end

  def reactivate_or_set_expiry_date_groups(groups, is_bulk_action = false)
    new_expiry_date = get_en_datetime_str(group_params[:bulk_actions][:mentoring_period]) if group_params[:bulk_actions][:mentoring_period].present?
    reason = group_params[:bulk_actions][:reason]
    @error_flash = []
    @error_groups = []
    groups.each do |group|
      # For Perf, skipping check_only_one_group_for_a_student_mentor_pair validation
      group.skip_student_mentor_validation = is_bulk_action
      unless group.change_expiry_date(current_user, new_expiry_date, reason, {for_bulk_change_expiry_date: is_bulk_action})
        @error_flash << group.errors.full_messages.to_sentence
        @error_groups << group
      end
    end
  end

  def terminate_groups(groups)
    termination_reason = group_params[:bulk_actions][:termination_reason]
    closure_reason = group_params[:bulk_actions][:closure_reason]
    groups.each do |group|
      group.terminate!(current_user, termination_reason, closure_reason)
    end
  end

  def fetch_group
    @group = @current_program.groups.find(group_params[:id])
  end

  def fetch_group_and_prefetch_objects
    eager_load_params = [:students, :mentors]
    @group = @current_program.groups.find_by(id: group_params[:id])
    unless @group.present?
      flash[:error] = "flash_message.group_flash.group_not_found".translate(mentoring_connection: _mentoring_connection)
      redirect_to program_root_path and return
    end
    load_user_membership_params
  end

  # Handles group assignment from a mentor request.
  def handle_creation_from_mentor_request
    @mentor_request = @current_program.mentor_requests.find(@mentor_request_params)
    @mentor = GetMemberFromNameWithEmailService.new(group_params[:group][:mentor_name], @current_organization).get_user(@current_program, RoleConstants::MENTOR_NAME)

    # If group mentoring is allowed, check if the mentor already has connections
    # so that we ask the admin which connection to assign the student to, or
    # create a new one if required.
    if !group_params[:assign_new] && (@mentor && @current_program.allow_one_to_many_mentoring? && @mentor.mentoring_groups.active.any?)
      @existing_connections_of_mentor = @mentor.mentoring_groups.active
    else
      mentoring_model = current_program.mentoring_models.find_by(id: group_params[:mentoring_model_id])
      @group = @mentor_request.assign_mentor!(@mentor, created_by: current_user, mentoring_model: mentoring_model)
    end
  end

  def fetch_active_mentor_requests
    @mentor_requests = @current_program.mentor_requests.active.paginate(
      :page => get_current_page,
      :per_page => PER_PAGE
    )

    # Compute the student-mentor matches for all the mentor requests.
    @match_results_per_mentor = {}
    @mentor_requests.each do |mentor_request|
      student = mentor_request.student
      @match_results_per_mentor[mentor_request] = student.student_cache_normalized(true) if student.student_document_available?
    end
  end

  def get_current_page
    @page = group_params[:page].to_i != 0 ? group_params[:page].to_i.abs : 1
    if @page > 1 && (@current_program.mentor_requests.active.count <= (@page - 1)*PER_PAGE)
      @page = @page -1
      group_params[:page] = @page.to_s
    end
    return @page
  end


  def reactivate_or_set_expiry_date
    new_expiry_date = get_en_datetime_str(group_params[:mentoring_period]) if group_params[:mentoring_period].present?

    # Reactivate or change the expiry date of the group
    should_close = @group.closed? # We need this variable to track the state of group before update.
    if @group.change_expiry_date(current_user, new_expiry_date, group_params[:revoking_reason])
      if should_close
        flash[:notice] = "flash_message.group_flash.reactivated".translate(:mentoring_connection => _mentoring_connection)
      else
        flash[:notice] = "flash_message.group_flash.expiration_date_set".translate(:mentoring_connection => _mentoring_connection)
      end
    else
      flash[:error] = @group.errors.full_messages.to_sentence
    end
  end



  # Extracts mentor and students' name-emails from group_params[:group] and returns the
  # corresponding User objects.
  def get_mentor_and_students_from_emails
    # Fetch mentor and students from the name-emails.
    mentors = (group_params[:group].delete(:mentor_names) || []).collect do |name_email|
      User.find_by_email_program(
        Member.extract_email_from_name_with_email(name_email),
        @current_program
      )
    end.compact.uniq

    students = (group_params[:group].delete(:student_names) || []).collect do |name_email|
      User.find_by_email_program(
        Member.extract_email_from_name_with_email(name_email),
        @current_program
      )
    end.compact.uniq

    [mentors, students]
  end

  # Fetches the connections with the given +mentor_name+ and +student_name+
  #
  def fetch_filtered_groups(filter_params)
    @es_filter_hash.merge!(:page => filter_params[:page], :per_page => filter_params[:per_page]) unless @is_csv_request
    Group.get_filtered_groups(@es_filter_hash)
  end

  def generate_mentoring_connections_csv(groups, tab_number)
    group_view = @current_program.group_view
    group_view_columns = group_view.get_group_view_columns(tab_number)
    role_based_activity = Group.get_role_based_details(groups, group_view_columns)
    roles_hsh = group_view_columns.present? ? @current_program.roles.includes(:translations, customized_term: :translations).index_by(&:id) : {}
    CSV.generate do |csv|
      csv_header = []
      group_view_columns.each do |column|
        csv_header << column.get_title(roles_hsh)
      end
      csv_header.flatten!
      csv << csv_header

      groups.each do |group|
        options = build_role_based_activity_hash(role_based_activity, group.id)
        options.merge!(csv_export: true)
        csv_array = []
        group_view_columns.each do |column|
          answers, names = get_group_list_view_answer(group, column, true, options)
          csv_array << format_list_answer(answers, names , column, :for_csv => true)
        end
        csv << csv_array
      end
    end
  end

  def redirect_if_feature_disabled
    return if @current_program.connection_profiles_enabled?
    redirect_to group_path(@group, group_params.to_unsafe_h.except("controller", "action", "id", "root"))
  end
  
  def check_access_to_show_profile
    access_to_show_profile(@group)
  end

  def access_to_edit_answers
    return false if @group.closed? || (!@group.published? && !@current_user.can_manage_or_own_group?(@group) && !@user_edit_view)
    @user_edit_view || @current_user.can_manage_or_own_group?(@group) || (check_member_or_admin && !@current_program.project_based?)
  end

  def check_access_to_update_connection_answers
    return if @current_program.connection_profiles_enabled? || group_params[:connection_answers].blank?
    flash[:error] =  "common_text.error_msg.permission_denied".translate
    redirect_to edit_answers_group_path(@group)
  end

  def access_to_mentoring_area
    return false unless @group.published?
    check_member_or_admin
  end

  def set_end_user_edit_view
    @user_edit_view = @group.proposed? && @group.created_by == @current_user && !@current_user.is_admin?
  end

  #Program should allow leaving connection and user should have membership for that connection
  def check_user_can_leave_connection
    @group.program.allow_users_to_leave_connection? && @group.memberships.where(:user_id => current_user.id).present?
  end

  def check_user_can_create_group
    @propose_view = group_params[:propose_view] == "true" && @current_user.allow_to_propose_groups?
    @is_manage_connections_view = !@propose_view && @current_user.can_manage_connections?
    @propose_view || @is_manage_connections_view
  end

  def get_group_activities_with_offset
    @offset_id = group_params[:offset_id].to_i

    # Convert to array so that methods like 'last' and 'any?' are invoked on the
    # Array and not on the ActiveRecord scope, where the latter will result in
    # the sql LIMIT getting affected and hence the results.
    @group_activities = @group.activities.for_display.latest_first.fetch_with_offset(
      ACTIVITIES_PER_PAGE, @offset_id, {:include => [:ref_obj, :member]}
    ).to_a

    @new_offset_id = @offset_id + ACTIVITIES_PER_PAGE
  end

  def get_groups_size_with_status_active_closed(object)
    return object.active.size, object.closed.size
  end

  def get_groups_size_with_status_drafted(object)
    return object.groups.drafted.size
  end

  # Map to db column name.
  def param_to_sort_field_map(sort_param)
    case sort_param
    when 'connected_time' || 'Active_since'
      (@filter_field == Group::Status::DRAFTED) ? 'created_at' : 'published_at'
    when 'Active_since'
      (@filter_field == Group::Status::DRAFTED) ? 'created_at' : 'published_at'
    when 'active'
      (@is_my_connections_view || @is_open_connections_view || @is_pending_connections_view) ? 'last_activity_at' : 'last_member_activity_at'
    when 'Last_activity'
      @is_my_connections_view ? 'last_activity_at' : 'last_member_activity_at'
    when 'activity'
      'activity_count'
    when 'Closed_by', 'rejected_by', 'withdrawn_by'
      'closed_by.name_only.sort'
    when 'Expires_on'
      'expiry_time'
    when 'Expires_in'
      'expiry_time'
    when 'Reason'
      'closure_reason_id'
    when 'Created_by', 'proposed_by'
      'created_by.name_only.sort'
    when 'Drafted_since'
      'created_at'
    when 'Available_since'
      'pending_at'
    when 'Milestone_progress'
      'milestone_progress'
    when 'name'
      'name.sort'
    when 'Pending_requests'
      'pending_project_requests_count'
    when 'proposed_at'
      'created_at'
    when 'rejected_at', 'Closed_on', 'withdrawn_at'
      'closed_at'
    when 'mentoring_model_templates_v1'
      'mentoring_model.title.sort'
    when 'tasks_overdue_status_v2'
      'tasks_overdue_count'
    when 'tasks_pending_status_v2'
      'tasks_pending_count'
    when 'tasks_completed_status_v2'
      'tasks_completed_count'
    when 'milestones_overdue_status_v2'
      'milestones_overdue_count'
    when 'milestones_pending_status_v2'
      'milestones_pending_count'
    when 'milestones_completed_status_v2'
      'milestones_completed_count'
    when 'survey_responses'
      'survey_responses_count'
    else
      sort_param
    end
  end

  def get_view
    group_params[:view] = Group::View::DETAILED if group_params[:show].present?
    @is_view_changed = (group_params[:view].present? && session[:groups_view] != group_params[:view].to_i)
    session[:groups_view] = group_params[:view].present? ? group_params[:view].to_i : (session[:groups_view].present? ? session[:groups_view] : Group::View::DETAILED)
    @view = session[:groups_view]
  end

  def get_group_view
    @group_view = @current_program.group_view
  end

  def initialize_filter_params
    @filter_params = {}

    param_filters = [:search_filters, :sub_filter]

    param_filters.each do |filter|
      if group_params[filter].present?
        @filter_params[filter] = group_params[filter]
      end
    end
  end

  def handle_update_of_group_members
    new_mentors, new_students, options = GroupUserSplitter.new(@current_program, @group, group_params[:connection].try(:[], :users).try(:permit!).to_h).split_users_by_roles_and_options
    if new_mentors.blank? && new_students.blank? && (!@current_program.project_based? || @group.published?)
      @error_flash = "flash_message.group_flash.member_blank_v1".translate(role_name: "#{_mentor} #{'display_string.and'.translate} #{_mentee}", mentoring_connection: _mentoring_connection)
    elsif new_mentors.blank? && (!@current_program.project_based? || @group.published?)
      @error_flash = "flash_message.group_flash.member_blank_v1".translate(role_name: _mentor, mentoring_connection: _mentoring_connection)
    elsif new_students.blank? && (!@current_program.project_based? || @group.published?)
      @error_flash = "flash_message.group_flash.member_blank_v1".translate(role_name: _mentee, mentoring_connection: _mentoring_connection)
    else
      @group.update_members(new_mentors, new_students, current_user, options.merge(check_actor_can_update_members: true))
    end
  end

  def split_users_by_roles
    mentoring_roles = @current_program.roles.for_mentoring
    role_wise_users = get_users_by_roles(mentoring_roles)
    mentors = role_wise_users.delete(mentoring_roles.find{|role| role.name == RoleConstants::MENTOR_NAME })
    students = role_wise_users.delete(mentoring_roles.find{|role| role.name == RoleConstants::STUDENT_NAME })
    other_roles_hash = role_wise_users
    [mentors, students, other_roles_hash]
  end

  def get_users_by_roles(mentoring_roles)
    roles_based_users = {}
    group_params[:group_members][:role_id].each do |role_id, name_emails|
      role = mentoring_roles.find{|role| role.id == role_id.to_i}
      users = []
      name_emails.split(",").each do |name_email|
        users << User.find_by_email_program(
          Member.extract_email_from_name_with_email(name_email),
          @current_program
        )
      end
      roles_based_users.merge!({role => users.uniq.compact})
    end
    roles_based_users
  end

  def handle_creation_of_project_group
    @can_create_group_directly = !get_joins_as_role.needs_approval_to_create_circle? if @propose_view
    @group = @current_program.groups.new
    @group.name = group_params[:group][:name]
    @group.start_date = group_params[:group][:start_date].in_time_zone(wob_member.get_valid_time_zone).beginning_of_day if group_params[:group][:start_date].present?
    @group.logo = group_params[:group][:logo] if group_params[:group][:logo]
    @group.notes = group_params[:group][:notes] if group_params[:group][:notes]
    @group.global = true
    @group.status = @propose_view ? (@can_create_group_directly ? Group::Status::PENDING : Group::Status::PROPOSED) : Group::Status::DRAFTED
    @group.created_by = current_user
    if @current_program.mentoring_connections_v2_enabled? && group_params[:group][:mentoring_model_id].present?
      mentoring_model = @current_program.mentoring_models.find(group_params[:group][:mentoring_model_id])
      @group.mentoring_model = mentoring_model
    end
    begin
      ActiveRecord::Base.transaction do
        @group.save!
        @group.update_answers(group_params[:connection_answers])
        raise "Invalid Membership Settings!" unless update_membership_setting
        add_propopser_in_group
      end
    rescue => e
      logger.error "--- #{e.message} ---"
      @creation_failure = true
    end

    if @creation_failure
      redirect_to program_root_path
    else
      if @propose_view
        # admins should be notified via email
        Group.delay.send_email_to_admins_after_proposal(@group.id, JobLog.generate_uuid) unless @can_create_group_directly
        set_proposer_as_owner_of_group
        @can_set_start_date = @current_program.allow_circle_start_date?
        unless @can_set_start_date
          flash[:notice] = @can_create_group_directly ? "flash_message.group_flash.group_creation_without_approval_success".translate(mentoring_connection: _mentoring_connection) : "flash_message.group_flash.group_proposed_success".translate(mentoring_connection: _mentoring_connection, admin: _admin)
          redirect_to profile_group_path(@group)
        end
      else
        if group_params[:proceed_to_add_members]
          redirect_to add_members_group_path(@group)
        else
          redirect_to groups_path(tab: Group::Status::DRAFTED)
        end
      end
    end
  end

  def add_propopser_in_group
    return true unless @propose_view
    join_as_role = get_joins_as_role
    proposer_membership = @group.memberships.find_or_initialize_by(user_id: @current_user.id)
    proposer_membership.update_role!(join_as_role)
  end

  def get_joins_as_role
    @current_program.roles.for_mentoring.find_by(id: group_params[:group]["join_as_role_id"].try(:to_i)) || @current_user.roles_for_proposing_groups.first
  end

  def update_membership_setting
    return true unless @current_program.project_based? # membership setting is applicable only to PBE
    validate_update = true
    error_messages = []
    @current_program.roles.for_mentoring.each do |role|
      next unless role.slot_config_enabled?
      if group_params[:group][:membership_setting]["#{role.id}"].blank? && role.slot_config_required?
        validate_update = false
        error_messages << "flash_message.group_flash.max_limit_required".translate(plural_role_name: RoleConstants.human_role_string([role.name], pluralize: true, no_capitalize: true, program: @current_program), mentoring_connection: _mentoring_connection)
      elsif group_params[:group][:membership_setting]["#{role.id}"].blank?
        membership_setting = @group.setting_for_role_id(role.id, false)
        membership_setting.update_attribute(:max_limit, nil) if membership_setting.try(:max_limit).present?
      else
        new_max_limit = group_params[:group][:membership_setting]["#{role.id}"].to_i
        if new_max_limit >= @group.memberships.where(role_id: role.id).size
          membership_setting = @group.membership_settings.find_or_initialize_by(role_id: role.id)
          membership_setting.max_limit = new_max_limit
          validate_update = membership_setting.save && validate_update
        else
          validate_update = false
          error_messages << "flash_message.group_flash.max_limit_update_error".translate(role_name: RoleConstants.human_role_string([role.name], no_capitalize: true, program: @current_program), plural_role_name: RoleConstants.human_role_string([role.name], pluralize: true, no_capitalize: true, program: @current_program), mentoring_connection: _mentoring_connection, count: new_max_limit)
        end
      end
    end
    flash[:error] = error_messages.join(" ") if error_messages.present?
    validate_update
  end

  def initialize_connection_questions
    if @current_program.connection_profiles_enabled? && @current_program.mentoring_connections_v2_enabled?
      @connection_questions = Connection::Question.get_viewable_or_updatable_questions(@current_program, true)
    end
  end

  def handle_available_to_join_filter(groups, sphinx_with_options)
    if can_apply_available_filter?
      roles_for_mentoring = current_user.roles.for_mentoring.with_permission_name(RolePermission::SEND_PROJECT_REQUEST).pluck(:id)
      group_ids = groups.available_projects(roles_for_mentoring).pluck(:id)
      group_ids = sphinx_with_options[:id].present? ? (group_ids & sphinx_with_options[:id]) : group_ids
      sphinx_with_options[:id] = group_ids.present? ? group_ids : [0]
    end
  end

  def sphinx_params_for_find_new
    sphinx_options = [
      {
        includes_list: get_sql_includes_hash(
          Group::View::DETAILED,
          goals_enabled: false,
          mentoring_model_v2_enabled: @current_program.mentoring_connections_v2_enabled?
        ),
        sort: {pending_at: "desc"}
      }
    ]
    sphinx_with_options = { status: find_new_status_filter, global: true }
    sphinx_options << sphinx_with_options
    sphinx_options
  end

  def can_apply_available_filter?
    @apply_available_filter ||= current_user.can_send_project_request? && (
      group_params[:search_filters].nil? ||  group_params[:search_filters][:available_to_join] == GroupsHelper::DEFAULT_AVAILABLE_TO_JOIN_FILTER
    )
  end

  def find_new_status_filter
    if current_user.can_send_project_request?
      Group::Status::OPEN_CRITERIA
    else
      Group::Status::ACTIVE_CRITERIA
    end
  end

  def check_manage_or_own_group?
    current_user.can_manage_or_own_group?(@group)
  end

  def check_approve_project_requests?
    current_user.can_approve_project_requests?(@group)
  end

  def get_groups_listing_tab_counts(groups_scope)
    tab_counts = {}
    tab_counts[:drafted] = groups_scope.drafted.size if @is_manage_connections_view
    if @current_program.project_based?
      projects_scope = !(@is_manage_connections_view || @is_global_connections_view) ? @current_program.groups.created_by(current_user) : groups_scope
      tab_counts[:pending] = groups_scope.pending.size if @is_manage_connections_view
      tab_counts[:proposed] = projects_scope.proposed.size
      tab_counts[:rejected] = projects_scope.rejected.size
      tab_counts[:withdrawn] = groups_scope.withdrawn.size
    end
    if @is_open_connections_view
      tab_counts[:open] = groups_scope.open_connections.size
      tab_counts[:closed] = groups_scope.closed.size
    else
      tab_counts[:ongoing] = groups_scope.active.size
      tab_counts[:closed] = groups_scope.closed.size
    end
    tab_counts
  end

  def handle_filters_and_init_connections_questions
    filter_and_init_connections_questions
    handle_membership_based_filter if group_params[:member_filters]
    handle_member_profile_based_filter if group_params[:member_profile_filters]
  end

  def get_groups_status_filter
    status_filter =
      if @is_manage_connections_view && group_params[:sub_filter].present?
        if (group_params[:sub_filter][:active].present? && group_params[:sub_filter][:inactive].present?) || (group_params[:sub_filter][:active].blank? && group_params[:sub_filter][:inactive].blank?)
          StatusFilters::Code::ONGOING
        elsif group_params[:sub_filter][:active].present?
          StatusFilters::Code::ACTIVE
        else
          StatusFilters::Code::INACTIVE
        end
      else
        group_params[:filter].to_i
      end

    if @drafted_connections_view
      StatusFilters::Code::DRAFTED
    elsif @is_pending_connections_view
      StatusFilters::Code::PENDING
    elsif @is_proposed_connections_view
      StatusFilters::Code::PROPOSED
    elsif @is_rejected_connections_view
      StatusFilters::Code::REJECTED
    elsif @is_withdrawn_connections_view
      StatusFilters::Code::WITHDRAWN
    elsif @tab_number == GroupsController::StatusFilters::Code::CLOSED
      StatusFilters::Code::CLOSED
    elsif @is_open_connections_view && ((group_params[:filter].blank? && group_params[:sub_filter].blank?) || (status_filter == StatusFilters::Code::ONGOING))
      StatusFilters::Code::OPEN
    elsif ((@is_my_connections_view || @is_manage_connections_view) && ((group_params[:filter].blank? && group_params[:sub_filter].blank?) || (status_filter  == GroupsController::StatusFilters::Code::ONGOING))) || @is_global_connections_view
      StatusFilters::Code::ONGOING
    else
      status_filter
    end
  end

  def get_groups_sort_field
    if @is_view_changed || group_params[:sort].blank?
      if @view == Group::View::LIST
        "name"
      elsif @is_rejected_connections_view || @is_withdrawn_connections_view
        "closed_at"
      elsif @is_proposed_connections_view
        "created_at"
      elsif @is_open_connections_view || @is_my_connections_view || @is_global_connections_view || @drafted_connections_view || @is_pending_connections_view
        "active"
      else
        "connected_time"
      end
    else
      group_params[:sort]
    end
  end

  def redirect_to_scraps_index
    set_src
    return if group_params[:show_plan] == "true" || @current_program.mentoring_connections_v2_enabled?

    # Redirecting to scraps page by default if v2 is not enabled
    track_access_mentoring_area_activity
    if @src_path == EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST
      redirect_to group_scraps_path(@group, src: EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST)
    else
      redirect_to group_scraps_path(@group)
    end
  end

  def handle_last_visited_tab
    if group_params[:show_plan] == "true" || group_params[:coach_rating].present? || group_params[:notif_settings].present?
      track_access_mentoring_area_activity
      return 
    end
    return if @current_connection_membership.blank?

    prepare_tabs
    track_access_mentoring_area_activity
    case @current_connection_membership.last_visited_tab
    when ScrapsController.controller_path
      redirect_to group_scraps_path(@group) if @show_messages_tab
    when ForumsController.controller_path, TopicsController.controller_name
      redirect_to forum_path(@group.forum) if @show_forum_tab
    when MeetingsController.controller_path
      redirect_to meetings_path(group_id: @group.id) if @show_meetings_tab
    when MentoringModel::GoalsController.controller_path
      redirect_to group_mentoring_model_goals_path(@group) if @show_mentoring_model_goals_tab
    when Connection::PrivateNotesController.controller_path
      redirect_to group_connection_private_notes_path(@group) if @show_private_journals_tab
    end
  end

  def track_access_mentoring_area_activity
    track_activity_for_ei(EngagementIndex::Activity::ACCESS_MENTORING_AREA) if @is_member_view 
  end

  def initialize_student_mentor
    select_list = [:id, :member_id, :program_id]
    @student = @current_program.student_users.select(select_list).find(group_params[:student_id])
    @mentor = @current_program.mentor_users.select(select_list).find(group_params[:mentor_id])
  end

end