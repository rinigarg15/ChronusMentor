class ProgramsController < ApplicationController
  include SecuritySettingMethods
  include MeetingMentorSuggest
  include UsersHelper
  include UserListingExtensions
  include MentoringModelUtils
  include ApplicationHelper
  include ProgramsHelper
  include SolutionPack::ImporterUtils
  include ConnectionFilters::CommonInclusions
  include UserPreferencesHash
  include ProgramAssetUtils
  include SetProjectsAndConnectionQuestionAnswers
  # No. of mentors to show in mentors box in program page.
  # 3 rows of 3 pics
  MAX_GROUPS_TO_SHOW_IN_HOME               = 2
  MAX_PROJECTS_TO_SHOW_IN_HOME_PAGE_WIDGET = 5
  MEETINGS_TO_RENDER_IN_FLASH_WIDGET       = 3
  SRC_HOME_PAGE_WIDGET                     = 'src_hpw'
  RETAIN_FLASH                             = 'retain_flash'

  module SettingsTabs
    GENERAL     = 0
    TERMINOLOGY = 1
    MEMBERSHIP  = 2
    CONNECTION  = 3
    FEATURES    = 4
    PERMISSIONS = 5
    SECURITY    = 6
    MATCHING    = 8

    def self.get_label(tab, customized_terms = {})
      {
        GENERAL     => "program_settings_strings.tab.general",
        TERMINOLOGY => "program_settings_strings.tab.terminology",
        MEMBERSHIP  => "program_settings_strings.tab.membership",
        CONNECTION  => "program_settings_strings.tab.connection_v1",
        FEATURES    => "program_settings_strings.tab.features",
        PERMISSIONS => "program_settings_strings.tab.permissions",
        SECURITY    => "program_settings_strings.tab.security",
        MATCHING    => "program_settings_strings.tab.matching"
      }[tab].translate(customized_terms)
    end

    def self.get_mass_update_attributes(tab)
      Program::MASS_UPDATE_ATTRIBUTES[:update][{
        GENERAL     => :general,
        MEMBERSHIP  => :membership,
        CONNECTION  => :connection,
        FEATURES    => :features,
        PERMISSIONS => :permissions,
        SECURITY    => :security,
        MATCHING    => :matching
      }[tab]]
    end

    def self.all
      [GENERAL, TERMINOLOGY, MEMBERSHIP, MATCHING, CONNECTION, FEATURES, PERMISSIONS, SECURITY]
    end

    def self.get_tab(tab_number)
      self.all.each do |tab|
        return tab if tab == tab_number
      end

      return nil
    end
  end
  helper :recent_activity
  helper_method :prevent_disabling_one_time_mentoring?

  skip_action_callbacks_for_autocomplete :show_activities, :quick_connect_box, :home_page_widget, :meeting_feedback_widget, :mentoring_connections_widget, :flash_meetings_widget, :mentoring_community_widget, :publish_circles_widget, :remove_circle_from_publish_circle_widget
  skip_before_action :require_program, only: [:new, :create, :index]
  skip_before_action :login_required_in_program, only: [:new, :create, :show, :terms, :index]

  before_action :redirections_unlogged_in_and_other_roles, only: [:show]
  before_action :require_super_user, only: [:edit_analytics, :update_analytics]
  before_action :check_program_setting_access, only: [:edit, :update]
  before_action :add_custom_parameters_for_newrelic, only: [:show]
  before_action :set_v2_page, only: [:index, :edit, :update, :manage]
  before_action :show_pendo_launcher_in_all_devices, only: [:manage]

  after_action :expire_banner_cached_fragments, only: [:update]

  allow user: :can_customize_program?, only: [:edit, :update, :edit_analytics, :update_analytics]
  allow user: :view_management_console?, only: [:manage]
  allow exec: :check_program_creation_access, only: [:new, :create]
  allow exec: :program_view?, only: [:export_solution_pack]
  allow exec: :super_console?, only: [:export_solution_pack]
  allow user: :can_render_home_page_widget?, only: [:home_page_widget]
  allow user: :can_be_shown_connection_tab_or_widget?, only: [:mentoring_connections_widget]


  # We do not want the action :show_activities to contribute to the apdex score, but still want to see the transaction trace.
  newrelic_ignore_apdex :only => [:show_activities]

  def index
    if @current_program
      redirect_to root_path
    end
    options = {}
    options[Program::ProgramTypeConstants::PORTAL] = {association: :active_portals}
    options[Program::ProgramTypeConstants::TRACK] = {association: :active_tracks}
    ProgramsListingService.fetch_programs self, wob_member, wob_member.organization, options do |all_programs|
      all_programs.ordered
    end
  end

  # Global search action. Display all matching items viz., users, articles,
  # questions in a single page. Also renders tabs for viewing only specific type
  # of items.
  #
  def search
    @search_query = params[:query]
    
    # Convert query string of the form 'Hello World' to 'Hello | World' so as to
    # simulate *ANY* mode matching
    search_query = (@search_query || '').squeeze(" ").split(" ").join(' | ')
    classes_to_search = @current_program.searchable_classes(current_user)
    @viewer_role = current_user.get_priority_role if logged_in_program?

    # Restrict to the program from within which the page is viewed.
    with_options = {program_id: @current_program.id}

    group_status = if current_user.can_send_project_request?
      Group::Status::OPEN_CRITERIA
    else
      Group::Status::ACTIVE_CRITERIA
    end
    with_options.merge!(group_status: group_status)

    # For non-admins, exclude inactive users.
    # [false, nil] will match records having either of the values for :not_active
    with_options.merge!(state: User::Status::ACTIVE) unless current_user.is_admin?

    role_ids = []
    role_names = @current_program.role_names_without_admin_role

    # Show the users with non administrative roles if they are present
    role_names.each do |role_name|
      if current_user.can_view_role?(role_name)
        role_ids += @current_program.get_roles(role_name).collect(&:id)
      end
    end

    if current_user.can_offer_mentoring?
      @mentee_groups_map = current_user.mentee_connections_map
      @existing_connections_of_mentor = @mentee_groups_map.values.flatten.select(&:active?)
    end

    with_options.merge!(role_ids: role_ids) if role_ids.present?
    
    @results = GlobalSearchElasticsearchQueries.new.search(search_query,
      with: with_options,
      classes: classes_to_search,
      page: params[:page],
      per_page: ActiveRecord::Base.per_page,
      admin_view_check: current_user.is_admin?,
      current_user_role_ids: global_search_current_user_role_ids,
      filter_view: params[:filter_view]
    )
    @total_results = @results.total_entries

    student_object_ids = []
    mentor_object_ids = []
    @results.each do |res|
      if res["_type"] == User.document_type
        student_object_ids << res[:active_record].id if res[:active_record].is_student?
        mentor_object_ids << res[:active_record].id if res[:active_record].is_mentor?
      elsif res["_type"] == Group.document_type
        @find_new ||= true
        @connection_questions ||= @current_program.connection_questions.admin_only(false)
      end
    end
    initialize_student_actions_for_users(student_object_ids) if student_object_ids.present?
    initialize_mentor_actions_for_users(mentor_object_ids) if mentor_object_ids.present?
    track_user_search_activity
  end

  # Program home page
  def show
    set_gray_background
    @hide_side_bar = params[:hide_side_bar].try(:to_boolean)
    @src = params[:src]
    unless @hide_side_bar
      if current_user.is_student? && @current_program.matching_by_mentee_and_admin_with_preference?
        if flash[:notice].blank? && current_user.prompt_to_request?
          flash.now[:notice] = view_context.get_prompt_to_request_preferred_mentors_message(current_user.get_visible_favorites.size)
        end
      end

      # load data as relevant for various roles. Group loading dependency is force-loaded (true arg) because otherwise the groups are loaded.

      @can_be_shown_announcements_icon = current_user.get_active_announcements.size > 0 
      @announcements_badge_count = current_user.get_active_unviewed_announcements_count if @can_be_shown_announcements_icon

      @unanswered_questions = current_user.unanswered_questions if @current_program.profile_completion_alert_enabled?
    end

    if current_user.roles.for_mentoring.exists?
      @my_all_connections_count = current_user.groups.published.size
      @my_mentoring_connections = current_user.active_groups.includes(:members)
    end

    @recommendation_preferences_hash = MentorRecommendationsService.new(current_user).get_recommendations(MentorRecommendationsService::RecommendationCategory::ADMIN_RECOMMENDATIONS)
    @mentors_score = current_user.get_student_cache_normalized if @recommendation_preferences_hash.present?
    set_user_preferences_hash if show_favorite_ignore_links? && @recommendation_preferences_hash.present?

    if current_user.can_view_ra?
      @is_recent_activities_present = true
    end

    @connect_calendar_prompt = @current_program.calendar_sync_v2_for_member_applicable? && !wob_member.synced_external_calendar? && (current_user.groups.active.present? || @current_program.calendar_enabled?) && !working_on_behalf?

    if wob_member.is_mentor_or_student? && @current_program.is_meetings_enabled_for_calendar_or_groups?
      meetings = get_upcoming_recurrent_meetings
      @my_meetings = meetings.first(OrganizationsController::MY_MEETINGS_COUNT)
      @my_meetings_count = meetings.size
      @notify_availability = !session[UsersController::SessionHidingKey::SET_AVAILABILITY_PROMPT] && current_program.calendar_enabled? &&
        current_user.opting_for_one_time_mentoring?(current_program) && can_notify_availability?(current_user)
    end
    @render_quick_connect_box = current_user.is_student? && current_user.can_render_quick_connect_box?(@current_program, meetings: meetings) && @recommendation_preferences_hash.blank?
    @from_first_visit = params[:from_first_visit].present?
    track_activity_for_ei(EngagementIndex::Activity::VISIT_HOME_PAGE) unless @unanswered_mandatory_prof_qs
    initialize_flash_meetings_widget_vars if current_user.can_be_shown_flash_meetings_widget?
    initialize_publish_circle_widget_vars
  end

  #
  # Renders form for editing the program details.
  # There are two cases where this action is called.
  #   * Just after admin signup
  #   * Through program settings link.
  #
  def edit
    deny! :exec => lambda{ @tab.nil? }
    @first_visit = params[:first_visit]
    @src = params[:src]
    @program = @current_program
    @program.get_connection_limit
    initialize_calendar_setting unless @program.project_based?
    @roles = @program.roles_without_admin_role
    @program.allow_one_to_many_mentoring = false if @first_visit && @program.basic_type?
  end

  def new
    @program = @current_organization.programs.new
  end

  def create
    @message_warnings = {}
    enabled_features = params[:program].delete(:enabled_features) if params[:program]
    enabled_features ||= []
    @program = @current_organization.programs.new
    assign_program_params(:program)
    @program.mentor_request_style = params[:program][:mentor_request_style] if params[:program][:mentor_request_style].present?
    @program.allow_one_to_many_mentoring = params[:program][:allow_one_to_many_mentoring]

    is_success = save_program

    if is_success
      # Not catching any errors at this point.
      calendar_enabled = !@program.project_based? && enabled_features.include?(FeatureName::CALENDAR)
      @program.enable_feature(FeatureName::CALENDAR, calendar_enabled)
      @program.enable_feature(FeatureName::OFFER_MENTORING, enabled_features.include?(FeatureName::OFFER_MENTORING))

      set_program_owner
      if @program.created_using_solution_pack?
        unless import_from_solution_pack
          redirect_to new_program_path(root: nil) and return
        end
      else
        flash[:notice] = "flash_message.program_flash.created".translate(:Program => _Program)
      end

      set_current_user_redirect_to_program_root
    else
      handle_program_creation_failure
    end
  end

  # Updates the program details. There are two points in which a program update
  # can happen. One is just after admin signup where the admin completes
  # program details which is an update. The other is from normal program settngs
  # page which the admin can do any time.
  #
  def update
    # This is required, when the program attributes(name) are changed but not saved,
    # @current_program.name should still return the old value
    @program = @current_organization.programs.find(@current_program.id)
    @first_visit  = params[:first_visit]
    prog_feature_update = (@tab == SettingsTabs::FEATURES) && !@current_organization.standalone?
    is_success = true
    allow_custom_terms_alone_edit = @current_organization.standalone? && @current_organization.display_custom_terms_only
    group_closure_reasons = params[:group_closure_reasons]
    new_group_closure_reasons = params[:new_group_closure_reasons]
    update_group_closure_reasons(group_closure_reasons, new_group_closure_reasons)
    initialize_calendar_setting if !@program.project_based? && [SettingsTabs::CONNECTION, SettingsTabs::MATCHING].include?(@tab)
    update_calendar_setting(params[:calendar_settings].permit(CalendarSetting::MASS_UPDATE_ATTRIBUTES[:program_update_connection_tab])) if (@tab == SettingsTabs::CONNECTION && @program.calendar_enabled?)
    program_attrs = params[:program] || {}
    updated_features_matching = program_attrs.delete(:enabled_features) || [] if [SettingsTabs::MATCHING, SettingsTabs::GENERAL].include?(@tab)
    flash_message = { error: [], notice: [] }

    # Do not allow admin-matching to self-matching when multiple connections exist between same student-mentor pair
    if @tab == SettingsTabs::MATCHING && @program.show_existing_groups_alert?
      if GroupsAlertData.multiple_existing_groups_note_data(@program)[0].present?
        program_attrs.delete(:mentor_request_style)
        updated_features_matching -= [FeatureName::OFFER_MENTORING]
      end
    end
    update_role_attributes(program_attrs.delete(:role)) if (@tab == SettingsTabs::MATCHING && @program.project_based?)
    handle_role_permissions_update(params[:program].delete(:role_permissions)) if can_update_role_permissions?
    @error_disabling_calendar = !@program.can_disable_calendar? if going_to_disable_enabled_calendar_feature?(@program, updated_features_matching, @tab)
    is_success = handle_matching_settings(program_attrs, updated_features_matching, @tab) && handle_mentor_request_style_update(program_attrs) if @tab == SettingsTabs::MATCHING
    send_group_proposal_params = program_attrs.delete(:send_group_proposals)
    if @program.project_based? && @tab == SettingsTabs::MATCHING
      group_proposals_role_ids = send_group_proposal_params
      set_group_proposal_approval_setting(program_attrs.delete(:group_proposal_approval)) if program_attrs[:group_proposal_approval].present?
      apply_role_permissions!(@program, group_proposals_role_ids, RolePermission::PROPOSE_GROUPS)
    end

    if program_attrs[:can_increase_connection_limit].present?
      @program.set_connection_limit(program_attrs[:can_increase_connection_limit].to_i, program_attrs[:can_decrease_connection_limit].to_i)
      if program_attrs[:apply_to_all_mentors].to_i == 1 && program_attrs[:default_max_connections_limit].to_i > 0
        @program.delay.update_mentors_connection_limit(program_attrs[:default_max_connections_limit].to_i)
      end
    end

    # Allow the mentor_request_style attr update only one - if its not set
    protected_attrs = filter_protected_params(program_attrs, [:mentor_request_style, :allow_one_to_many_mentoring],
                                              [:sort_users_by, :mentor_offer_needs_acceptance, :allow_end_user_milestones, :allow_non_match_connection, :zero_match_score_message, :hybrid_templates_enabled, :number_of_licenses, :admin_access_to_mentoring_area, :email_theme_override])

    is_mentoring_period_update = (program_attrs[:mentoring_period_value] || program_attrs[:mentoring_period_unit])
    if is_mentoring_period_update
      # creating old_mp so as to check later if it has been changed (mp is an
      # abbreviation for mentoring period)
      old_mp = @program.mentoring_period
      @program.set_mentoring_period(
        program_attrs.delete(:mentoring_period_unit),
        program_attrs.delete(:mentoring_period_value)
      )
      is_mentoring_period_changed = (old_mp != @program.mentoring_period)
    end

    if program_attrs[:permissions]
      @program.update_permissions(program_attrs[:permissions])
      program_attrs.delete(:permissions)
    end

    @program.update_join_settings(program_attrs.delete(:join_settings)) if program_attrs[:join_settings]
    update_role_description(@program, program_attrs.delete(:role_description)) if program_attrs[:role_description]

    organization_attrs = program_attrs[:organization] || {}
    organization_attrs = OrganizationsController.filter_super_user_features(organization_attrs, @current_organization, super_console?)

    if organization_attrs[:security_setting_attributes].present?
      override_security_attributes!(params, organization_attrs, super_console?)
    end

    if program_attrs.has_key?(:third_role_enabled)
      add_third_role = program_attrs[:third_role_enabled].to_s.to_boolean == true
      if(add_third_role ^ @program.has_role?(RoleConstants::TEACHER_NAME))
        allow! exec: lambda{ super_console? }
        is_success = false unless enable_disable_third_role(add_third_role, flash_message)
      end
    end

    if program_attrs[:notification_setting]
      allow! :exec => lambda{ super_console? }
      program_notification_attrs = program_attrs.delete(:notification_setting)
      prog_notification_setting = @program.notification_setting
      prog_notification_setting.messages_notification = program_notification_attrs[:messages_notification].to_i if program_notification_attrs[:messages_notification].present?
    end

    update_banner_logo, org_or_prog_asset = if @current_organization.standalone?
      get_banner_logo_attributes(@current_organization, organization_attrs)
    else
      get_banner_logo_attributes(@program, program_attrs)
    end

    if update_banner_logo && !org_or_prog_asset.valid?
      is_success = false
      flash_error = get_safe_string
      org_or_prog_asset.errors.full_messages.each do |msg|
        flash_error << msg << "<br/>".html_safe
      end
      flash_message[:error] << flash_error
    end

    if @tab == ProgramsController::SettingsTabs::FEATURES &&
      @current_organization.standalone? &&
      !organization_attrs[:enabled_features].include?(FeatureName::MANAGER) &&
      @current_organization.profile_questions.manager_questions.any?
        is_success = false
        flash[:error] = "flash_message.organization_flash.manager_error".translate
    end

    if program_attrs.has_key?(:feedback_survey_id)
      new_survey_id = program_attrs[:feedback_survey_id]
      feedback_survey_changed = @program.feedback_survey_changed?(new_survey_id)
      existing_feedback_survey = @program.feedback_survey

      if existing_feedback_survey.present? && (new_survey_id.blank? || feedback_survey_changed)
        existing_feedback_survey.update_attributes!(form_type: nil)
      end
      if new_survey_id.present? && feedback_survey_changed
        new_feedback_survey = @current_program.surveys.find(new_survey_id)
        new_feedback_survey.update_attributes!(form_type: Survey::FormType::FEEDBACK)
      end
    end

    if program_attrs.present?
      program_attrs[:auto_terminate_reason_id] = program_attrs[:auto_terminate_checkbox].present? ? program_attrs[:auto_terminate_reason_id].to_i : nil
      program_attrs.delete(:auto_terminate_checkbox)
      program_attrs.delete(:auto_terminate_reason_id) unless program_attrs[:inactivity_tracking_period_in_days].present?
    end
    new_matching_settings_valid = !(@tab == SettingsTabs::MATCHING) || @program.project_based? || !(consider_calendar_enabled?(@program, updated_features_matching, @tab)) || @calendar_setting.valid?
    organization_attrs = reject_terms_and_privacypolicy(organization_attrs) if allow_custom_terms_alone_edit
    assign_user_and_sanitization_version(@current_organization)
    if is_success && new_matching_settings_valid && (!@error_disabling_calendar) && @program.update_attributes(get_program_params(:update).merge(protected_attrs)) && ((@current_organization.standalone? && !prog_feature_update) ? update_organization(@current_organization, organization_attrs) : true)
      org_or_prog_asset.save if update_banner_logo
      prog_notification_setting.save! if program_notification_attrs.present?
      update_features(updated_features_matching, @tab, program_attrs) if [SettingsTabs::MATCHING, SettingsTabs::GENERAL].include?(@tab)
      if prog_feature_update
        handle_prog_feature_update(organization_attrs[:enabled_features])
        Feature.handle_feature_dependency(@program)
      else
        Feature.handle_feature_dependency(@program)
        Feature.handle_feature_dependency(@current_organization)
      end

      if @first_visit
        # The member information in session is cleaned, so it doesn't interleave when super-user tries to create new organization the next time.
        nullify_session_data
        redirect_to program_root_url(
          subdomain: @current_organization.subdomain,
          host: @current_organization.domain,
          protocol: @current_organization.get_protocol,
          root: @program.root)
      else
        if flash_message[:notice].present?
          flash[:notice] =  flash_message[:notice].join(" ")
        else
          flash[:notice] = "flash_message.program_flash.updated".translate
          flash[:notice] += "flash_message.program_flash.mentoring_period_changed_v1".translate(:mentoring_connection => _mentoring_connection, :mentoring_connections => _mentoring_connections) if is_mentoring_period_changed
        end
        next_url = edit_program_path(:tab => @tab)
        # Go back to the context if 'src' param is set.
        # Note that this is a generic redirection to 'previous context' by just
        # checking for the presence of params[:src]
        params[:src].blank? ? redirect_to(next_url) : redirect_to_back_mark_or_default(next_url)
      end
    else
      flash[:error] = flash_message[:error].join(" ") if flash_message[:error].present?
      @redirected_from_update = true
      render :action => :edit
    end
  end

  # Program management page.
  def manage
    @mentoring_model = current_program.default_mentoring_model
    @can_create_portal = @current_organization.standalone? && can_create_portals?
    @can_invite_other_roles = current_user.can_invite_roles?
    @show_add_user_options_popup = (current_program.allow_track_admins_to_access_all_users && !@current_organization.standalone?) || current_program.user_csv_import_enabled?
  end

  # Responds to the Ajax request on close of the profile questions update
  # notification. Just sets the cookie.
  def disable_profile_update_prompt
    @cookie_expiration_time = 2.weeks.from_now # classvar for testing

    cookies[DISABLE_PROFILE_PROMPT] = {
      :value => params[:t].to_s,
      :expires => @cookie_expiration_time
    }
    head :ok
  end

  # Action to render the analytics page for the program
  def edit_analytics
    @analytics_script = @current_program.analytics_script
  end

  # Used to update the analytics script for the program
  def update_analytics
    if @current_program.update_attribute(:analytics_script, params[:program][:analytics_script])
      flash[:notice] = "flash_message.analytics_flash.updated".translate
    end

    redirect_to manage_program_path
  end

  def announcements_widget
    @announcements = current_user.get_ordered_active_announcements
  end

  def show_activities
    @is_my = params[:my]
    @offset_id = params[:offset_id]
    @is_conn = params[:connection]
    @src = params[:src]
    @per_page = params[:per_page]
    @from_activity_button = (@src == EngagementIndex::Activity::ACTIVITY_BUTTON_MANAGMENT_REPORT)

    ra_fetch_opts = {:offset_id => @offset_id}
    ra_fetch_opts[:actor] = wob_member if @is_my
    ra_fetch_opts[:connection] = true if @is_conn
    ra_fetch_opts[:per_page] = @per_page.present? ? RecentActivityConstants::PER_PAGE : RecentActivityConstants::PER_PAGE_SIDEBAR
    @recent_activities, @new_offset_id = current_user.activities_to_show(ra_fetch_opts)

    if @is_my
      set_tab(Program::RA_TABS::MY_ACTIVITY)
    elsif @is_conn
      set_tab(Program::RA_TABS::CONNECTION_ACTIVITY)
    else
      set_tab(Program::RA_TABS::ALL_ACTIVITY)
    end
  end

  def update_prog_home_tab_order
    selected_tab = params[:tab_order].to_i
    set_tab(selected_tab)

    head :ok
  end

  def quick_connect_box
    upcoming_recurrent_meetings = get_upcoming_recurrent_meetings
    @mentors_score = current_user.get_student_cache_normalized
    @only_explicit_preference_recommendations = params[:only_explicit_preference_recommendations].to_s.to_boolean
    @show_match_config_matches = false
    ignore_list = params[:ignore_mentors].to_s.split(",").collect(&:to_i)
    if @only_explicit_preference_recommendations
      get_mentor_lists_based_on_explcit_preferences_for_quick_connect_box(ignore_list, upcoming_recurrent_meetings)
    else
      get_mentor_lists_based_on_system_recommendations_for_quick_connect_box(ignore_list, upcoming_recurrent_meetings)
    end
    @show_meeting_availability = @current_program.only_one_time_mentoring_enabled?
    set_user_preferences_hash if show_favorite_ignore_links?
  end

  def export_solution_pack
    @solution_pack = SolutionPack.new(:program => @current_program, :created_by => params[:solution_pack][:created_by], :description => params[:solution_pack][:description])
    @solution_pack.export
    @solution_pack.save!
    flash[:notice] = "feature.program.content_pack.successful_export_html".translate(:click_here => view_context.link_to("display_string.Click_here".translate, solution_packs_url(:host => DEFAULT_DOMAIN_NAME, :subdomain => EMAIL_HOST_SUBDOMAIN, :organization_level => true)))
    redirect_to manage_program_path
  end

  def home_page_widget
    set_projects_and_connection_question_in_summary_hash
  end

  def meeting_feedback_widget
  end

  def mentoring_connections_widget
    prepare_template_for_connection_widget
  end

  def mentoring_community_widget
    @unconnected_user_widget_content = current_user.get_unconnected_user_widget_content_list
  end

  def publish_circles_widget
    initialize_publish_circle_widget_vars
  end

  def remove_circle_from_publish_circle_widget
    session[:closed_circles_in_publish_circle_widget_ids] = [] unless session[:closed_circles_in_publish_circle_widget_ids].present?
    session[:closed_circles_in_publish_circle_widget_ids] << params[:group_id].to_i
  end

  def flash_meetings_widget
    initialize_flash_meetings_widget_vars
  end

  def unsubscribe_from_weekly_update_mail
    flash[:notice] = "feature.email.content.unsubscribe_weekly_update_success_flash_v1".translate
    flash.keep
    redirect_to edit_member_path(wob_member, focus_notification_tab: true)
  end

  protected
  # params_to_filter: one time settings - no one should be able to change them, even super users
  # super_user_params_to_filter: only super users are allowed to change these settings
  def filter_protected_params(request_params, params_to_filter, super_user_params_to_filter)
    protected_attrs = {}
    params_to_filter.each do |p|
      protected_attrs[p] = request_params.delete(p) if request_params[p]
    end

    # If super console is enabled, collect the params and pass them for processing
    if super_console?
      super_user_params_to_filter.each do |p|
        protected_attrs[p] = request_params.delete(p) if request_params[p]
      end
    else # this is not super console. If there are attempts to change, raise permission denied
      super_user_params_to_filter.each do |p|
        raise Authorization::PermissionDenied if request_params[p]
      end
    end

    return protected_attrs
  end

  #
  # Checks whether the current member has the privelege to create a new program.
  #
  def check_program_creation_access
    logged_in_organization? && wob_member.admin?
  end

  def redirections_unlogged_in_and_other_roles
    # Unlogged in view of program home page. Redirect to default template
    unless logged_in_program?
      # Dont redirect to new membership request page if we just created membership request
      if wob_member.present? && wob_member.user_in_program(current_program).try(:suspended?) && params[:src] != MembershipRequest::Source::MEMBERSHIP_REQUEST_PAGE && !params[ProgramsController::RETAIN_FLASH]
        if current_program.allow_join_now?
          flash[:error] = "flash_message.user_session_flash.suspended_user_allowed_to_join_v1_html".translate(
            program: _program,
            administrator: _admin,
            here: get_contact_admin_path(current_program, label: "display_string.here".translate),
            again: content_tag(:a, "display_string.again".translate, href: new_membership_request_path)
          )
        else
          flash[:error] = "flash_message.user_session_flash.suspended_user_v3_html".translate(program: _program, admins: _admins, here: get_contact_admin_path(current_program, label: "display_string.here".translate))
        end
      else
        flash.keep
      end
      redirect_path = params[:src].present? ? about_path(src: params[:src]) : about_path
      redirect_to redirect_path
    end

    if current_user.present? && current_user.can_view_reports? && !(params[:hide_side_bar].try(:to_boolean))
      management_report_params = {}
      management_report_params.merge!({"error_raised" => params[:error_raised]}) if params[:error_raised].present?
      management_report_params.merge!({:lst => ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS})
      flash.keep
      redirect_to management_report_path(management_report_params)
    end
    return
  end

  def set_tab(tab)
    ActiveRecord::Base.connection.execute("UPDATE `users` SET `primary_home_tab` = '#{tab}', `updated_at` = '#{Time.now.utc.to_s(:db)}' WHERE `users`.`id` = #{current_user.id}") unless current_user.primary_home_tab == tab
  end

  def prevent_disabling_one_time_mentoring?(program)
    program.calendar_enabled? && !program.ongoing_mentoring_enabled?
  end

  private

  def can_update_role_permissions?
    (@tab.in?([SettingsTabs::PERMISSIONS, SettingsTabs::MEMBERSHIP, SettingsTabs::CONNECTION]) || (@tab == SettingsTabs::MATCHING && @program.project_based?)) && params[:program] && params[:program][:role_permissions]
  end

  def get_mentor_lists_based_on_explcit_preferences_for_quick_connect_box(ignore_list, upcoming_recurrent_meetings)
    allow! exec: Proc.new{ current_user.explicit_preferences_configured? }
    @mentors_list = MentorRecommendationsService.new(current_user).get_recommendations(MentorRecommendationsService::RecommendationCategory::EXPLICIT_PREFERENCE_RECOMMENDATIONS,ignore_list)
  end


  def get_mentor_lists_based_on_system_recommendations_for_quick_connect_box(ignore_list, upcoming_recurrent_meetings)
    allow! exec: Proc.new{ current_user.can_render_quick_connect_box?(@current_program, meetings: upcoming_recurrent_meetings) }
    @mentors_list = MentorRecommendationsService.new(current_user).get_recommendations(MentorRecommendationsService::RecommendationCategory::SYSTEM_RECOMMENDATIONS, ignore_list)
  end


  def initialize_publish_circle_widget_vars
    if current_program.project_based?
      @publishable_groups = current_user.get_groups_to_display_in_publish_circle_widget
      @publishable_groups = @publishable_groups.select{|group| !session[:closed_circles_in_publish_circle_widget_ids].include?(group.id)} if session[:closed_circles_in_publish_circle_widget_ids].present?
    end
  end

  def get_upcoming_recurrent_meetings
    include_options = [{:member_meetings => [:member]}]
    Meeting.upcoming_recurrent_meetings(@current_program.get_accessible_meetings_list(wob_member.meetings.accepted_meetings).includes(include_options))
  end

  def initialize_flash_meetings_widget_vars
    meetings = Meeting.get_meetings_to_render_in_home_page_widget(wob_member, @current_program)
    @show_view_all = meetings.size > MEETINGS_TO_RENDER_IN_FLASH_WIDGET
    @total_upcoming_meetings = meetings.size
    @meetings_to_show = meetings.first(MEETINGS_TO_RENDER_IN_FLASH_WIDGET)
  end

  def get_program_params(action)
    if params[:program].present? && action == :update
      params[:program].permit(SettingsTabs.get_mass_update_attributes(@tab))
    else
      {}
    end
  end

  def show_favorite_ignore_links?
    @show_favorite_ignore_links = @current_user.allowed_to_ignore_and_mark_favorite?
  end

  def get_organization_params(org_params)
    org_params.present? ? org_params.permit(Organization::MASS_UPDATE_ATTRIBUTES[:program_update]) : {}
  end

  def get_calendar_setting_attrs(calendar_settings)
    calendar_settings.permit(CalendarSetting::MASS_UPDATE_ATTRIBUTES[:program_update_matching_tab]).tap do |whitelisted|
      whitelisted[:allow_mentor_to_describe_meeting_preference] = calendar_settings[:allow_mentor_to_describe_meeting_preference].to_i > 0 if calendar_settings[:allow_mentor_to_describe_meeting_preference].present?
      whitelisted[:allow_mentor_to_configure_availability_slots] = calendar_settings[:allow_mentor_to_configure_availability_slots].to_i > 0 if calendar_settings[:allow_mentor_to_configure_availability_slots].present?
    end
  end

  def update_organization(current_organization, organization_attrs)
    ActiveRecord::Base.transaction do
      current_organization.enabled_features = organization_attrs[:enabled_features] if organization_attrs[:enabled_features]
      current_organization.update_attributes(get_organization_params(organization_attrs))
    end
  end

  def update_features(features_updated, tab, program_attrs)
    change_mentoring_mode = updating_mentoring_mode?(features_updated, tab, program_attrs)
    @program.enable_feature(FeatureName::OFFER_MENTORING, features_updated.include?(FeatureName::OFFER_MENTORING)) if (@first_visit && !current_program.created_using_solution_pack?) || @tab == SettingsTabs::MATCHING
    @program.prepare_to_disable_calendar if going_to_disable_enabled_calendar_feature?(@program, features_updated, tab)
    @program.prepare_to_re_enable_calendar if going_to_re_enable_calendar_feature?(@program, features_updated, tab)
    @program.enable_feature(FeatureName::CALENDAR, consider_calendar_enabled?(@program, features_updated, tab))
    @program.update_default_abstract_views_for_program_management_report if change_mentoring_mode
  end

  def updating_mentoring_mode?(features_updated, tab, program_attrs)
    going_to_disable_enabled_calendar_feature?(@program, features_updated, tab) || going_to_re_enable_calendar_feature?(@program, features_updated, tab) || ((!@current_program.ongoing_mentoring_enabled?) && program_attrs[:engagement_type].to_i == Program::EngagementType::CAREER_BASED_WITH_ONGOING) || (@current_program.ongoing_mentoring_enabled? && program_attrs[:engagement_type].to_i == Program::EngagementType::CAREER_BASED)
  end

  def update_calendar_setting(calendar_settings)
    @calendar_setting.update_attributes(calendar_settings)
  end

  def initialize_calendar_setting
    @calendar_setting = CalendarSetting.find_or_initialize_by(program_id: current_program.id)
  end

  def consider_calendar_enabled?(program, features_updated, tab)
    @consider_calendar_enabled_computed = (tab == SettingsTabs::MATCHING ? (features_updated.include?(FeatureName::CALENDAR) || prevent_disabling_one_time_mentoring?(program)) : program.calendar_enabled?) if @consider_calendar_enabled_computed.nil?
    @consider_calendar_enabled_computed
  end

  def going_to_disable_enabled_calendar_feature?(program, features_updated, tab)
    tab == SettingsTabs::MATCHING && program.calendar_enabled? && consider_calendar_enabled?(program, features_updated, tab) == false
  end

  def going_to_re_enable_calendar_feature?(program, features_updated, tab)
    tab == SettingsTabs::MATCHING && program.calendar_enabled? == false && consider_calendar_enabled?(program, features_updated, tab)
  end

  def handle_matching_settings(program_attrs, features_updated, tab)
    calendar_setting_attrs = program_attrs.delete(:calendar_setting) || ActionController::Parameters.new
    calendar_setting_attrs = get_calendar_setting_attrs(calendar_setting_attrs)
    update_calendar_setting(calendar_setting_attrs) if consider_calendar_enabled?(@program, features_updated, tab)
    mentor_offers_change_invalid = program_attrs[:mentor_offer_needs_acceptance] == "false" && @program.mentor_offers.pending.any?
    flash[:error] = "flash_message.program_flash.mentor_offer_acceptance_change_failed".translate(mentor: _mentor) if mentor_offers_change_invalid
    !mentor_offers_change_invalid
  end

  def handle_mentor_request_style_update(program_attrs)
    mentor_request_style = guess_mentor_request_style(program_attrs)
    return true if mentor_request_style.blank? || current_program.mentor_request_style == mentor_request_style
    return false if current_program.mentor_requests.active.exists?

    @program.mentor_request_style = mentor_request_style
    return true
  end

  # If program_attrs[:mentor_request_style] is NIL and current mentor_request_style is mentor requests mentor/admin and:
  #   1. if active requests are present, the mentor_request_style checkbox would have been disabled in UI and hence program_attrs[:mentor_request_style] is nil => Let it be nil.
  #   2. if active requests is empty, the mentor_request_style checkbox would have been enabled in UI and the admin unchecked mentor requests mentor/admin => So we consider it as Program::MentorRequestStyle::NONE
  def guess_mentor_request_style(program_attrs)
    if program_attrs[:mentor_request_style].present?
      program_attrs[:mentor_request_style].to_i
    elsif (current_program.matching_by_mentee_alone? || current_program.matching_by_mentee_and_admin?) && !current_program.mentor_requests.active.exists?
      Program::MentorRequestStyle::NONE
    end
  end

  def update_group_closure_reasons(group_closure_reasons, new_group_closure_reasons)
    if group_closure_reasons.present?
      group_closure_reasons.each do |closure_reason_id, attributes_to_update|
        if attributes_to_update[:reason].present?
          fetched_closure_reason = current_program.group_closure_reasons.find(closure_reason_id)
          if fetched_closure_reason.is_default
            fetched_closure_reason.update_attributes!(reason: attributes_to_update[:reason]) if super_console?
          else
            fetched_closure_reason.update_attributes!(reason: attributes_to_update[:reason], is_deleted: attributes_to_update[:is_deleted], is_completed: attributes_to_update[:is_completed])
          end
        end
      end
    end
    if new_group_closure_reasons.present?
      new_group_closure_reasons.each do |key, attributes_to_update|
        current_program.group_closure_reasons.create!(reason: attributes_to_update[:reason], is_completed: attributes_to_update[:is_completed]) if attributes_to_update[:reason].present?
      end
    end
  end

  def handle_prog_feature_update(feature_names)
    feature_names.reject!(&:blank?) # Remove empty entries.
    (FeatureName.all - FeatureName.removed_as_feature_from_ui - FeatureName.organization_level_features).each do |name|
      # <code>feature_names.include?(name)</code> will give whether to enable or not.
      @current_program.enable_feature(name, feature_names.include?(name))
    end
  end

  def handle_role_permissions_update(role_permissions)
    roles = @program.roles.where(id: role_permissions.keys.map(&:to_i))
    role_permissions.each do |role_id1, value|
      role1 = @program.roles.find(role_id1.to_i)
      if value.keys.include?("view_permissions")
        add_or_remove_view_permissions(roles, role1, value)
      elsif value.keys.include?("join_project_permissions")
        add_or_remove_permission(role1, value, "send_project_request")
      elsif value.keys.include?("add_role_permissions")
        add_or_remove_add_role_permission(role1, value)
      elsif value.keys.include?("reactivate_group_permissions")
        add_or_remove_permission(role1, value, "reactivate_groups")
      end
    end
  end

  def add_or_remove_view_permissions(roles, param_role, value)
    roles.each do |role|
      add_or_remove_permission(param_role, value, "view_#{role.name.pluralize}")
    end
  end

  def add_or_remove_add_role_permission(role, value)
    to_add_role_name = RoleConstants::AUTO_APPROVAL_ROLE_MAPPING[role.name]
    return unless to_add_role_name.present?
    permission_name = "become_#{to_add_role_name}"
    add_or_remove_permission(role, value, permission_name)
  end

  def add_or_remove_permission(role, value, permission_name)
    if value.keys.include?(permission_name)
      role.add_permission(permission_name)
    else
      role.remove_permission(permission_name)
    end
  end

  def update_role_attributes(role_attributes)
    roles = @program.roles.where(id: role_attributes.keys.map(&:to_i))
    role_attributes.each do |role_id, value|
      update_hash = {}
      role = roles.find { |role| role.id == role_id.to_i }
      if role.for_mentoring?
        update_hash[:can_be_added_by_owners] = value.keys.include?("can_be_added_by_owners")
        if super_console?
          update_hash[:slot_config] = value.keys.include?("slot_config") && RoleConstants::SlotConfig.all.include?(value["slot_config"].to_i) ? value["slot_config"].to_i : nil
        end
        update_hash[:max_connections_limit] = value[:max_connections_limit]
      end
      role.update_attributes(update_hash) if update_hash.present?
    end
  end

  def set_group_proposal_approval_setting(group_proposal_approval_hash)
    group_proposal_approval_hash.each do |role_id, value|
      role = @current_program.roles.find_by(id: role_id)
      add_remove_roles_permission([role], RolePermission::CREATE_PROJECT_WITHOUT_APPROVAL, value.to_s.to_boolean)
    end
  end

  def apply_role_permissions!(program, role_ids, permission_name)
    group_proposal_role_ids = (role_ids || []).collect(&:to_i)
    for_mentoring_roles = program.roles.for_mentoring.includes(:permissions)
    selected_roles = for_mentoring_roles.select{|role| group_proposal_role_ids.include?(role.id) }
    disable_roles = for_mentoring_roles - selected_roles
    add_remove_roles_permission(selected_roles, permission_name)
    add_remove_roles_permission(disable_roles, permission_name, true)
  end

  def add_remove_roles_permission(roles, permission_name, remove_permission = false)
    permission_method = remove_permission ? :remove_permission : :add_permission
    roles.each do |role|
      role.send(permission_method, permission_name)
    end
  end

  def nullify_session_data
    session[:member_id] = nil
    session[:new_organization_id] = nil
  end

  def update_role_description(program, role_description)
    program.roles_without_admin_role.each do |role|
      assign_user_and_sanitization_version(role)
      role.description = role_description["#{role.name}"]
      role.save!
    end
  end

  def enable_disable_third_role(add_third_role, flash_message)
    is_success = true
    if add_third_role
      if TeacherRoleManager.new(@program).create_third_role
        flash_message[:notice] << "flash_message.program_flash.third_role_added".translate
        flash_message[:notice] << view_context.get_edit_terminology_link
        flash_message[:notice] << "flash_message.program_flash.other_changes_saved".translate
      else
        is_success = false
        flash_message[:error] << "flash_message.program_flash.failed_to_add_third_role".translate
      end
    else
      third_role = @program.get_role(RoleConstants::TEACHER_NAME)
      third_role_name = third_role.customized_term.term
      if third_role.can_be_removed? && TeacherRoleManager.new(@program).remove_third_role
        flash_message[:notice] << "flash_message.program_flash.third_role_removed".translate(role_name: third_role_name, program_term: @current_organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase)
        flash_message[:notice] << "flash_message.program_flash.other_changes_saved".translate
      else
        is_success = false
        flash_message[:error] << "flash_message.program_flash.failed_to_remove_third_role".translate
      end
    end
    is_success
  end

  def assign_program_params(program_type)
    @program.root = params[program_type][:root]
    @program.name = params[program_type][:name]
    @program.description = params[program_type][:description]
    @program.program_type = params[program_type][:program_type]
    @program.number_of_licenses = params[program_type][:number_of_licenses]
    @program.engagement_type = params[program_type][:engagement_type] || Program::EngagementType::CAREER_BASED
    if params[:creation_way].to_i == Program::CreationWay::SOLUTION_PACK && params[program_type][:solution_pack_file].present?
      @program.solution_pack_file = save_content_pack_to_be_imported(params[program_type][:solution_pack_file])
    end
  end

  def save_program
    @program.creation_way = params[:creation_way].to_i
    @program.root = @current_organization.get_next_program_root(@program) unless @current_organization.can_update_root?

    is_success = @message_warnings.empty? && @program.save

    # If first sub-program creation, update current program and organization name and root.
    assign_user_and_sanitization_version(@current_organization)
    if @current_organization.standalone?
      is_success &&= @current_organization.update_attributes(get_organization_params(params[:organization]) || {})
      current_params = params[:current] || ActionController::Parameters.new
      current_params.delete(:root) unless @current_organization.can_update_root?
      is_success &&= @current_program.update_attributes(current_params.permit(:name))
    end

    unless is_success
      error_messages = ""
      error_messages << "Program: #{@program.errors.full_messages.to_sentence}" unless @program.valid?
      error_messages << "Current Program: #{@current_program.errors.full_messages.to_sentence}" if @current_program.present? && !@current_program.valid?
      error_messages << "Current Organization: #{@current_organization.errors.full_messages.to_sentence}" unless @current_organization.valid?
      notify_airbrake("Program Creation Failure - #{error_messages}") if error_messages.present?
    end

    return is_success
  end

  def set_program_owner
    @user = @program.users.of_member(wob_member).first
    @program.set_owner!(@user)
  end

  def import_from_solution_pack
    begin
      solution_pack, data_deleted = import_solution_pack(@program)
      message, message_type = get_solution_pack_flash_message(solution_pack, data_deleted)
      flash[message_type] = message
      return true
    rescue => e
      notify_airbrake("solution_pack.error.program_creation_failed".translate)
      @program.destroy
      clean_up_solution_pack_file(@program.solution_pack_file)
      flash[:error] = "flash_message.program_flash.failed_from_sp".translate(:program => _program)
      return
    end
  end

  def set_current_user_redirect_to_program_root
    self.current_user = @user
    redirect_to program_root_path(:root => @program.root)
  end

  def handle_program_creation_failure
    clean_up_solution_pack_file(@program.solution_pack_file) if @program.solution_pack_file.present?
    render :action => 'new'
  end

  def check_program_setting_access
    @tab = SettingsTabs.get_tab(params[:tab].to_i)
    deny! exec: Proc.new{ !allowed_tabs.include?(@tab) }
  end

  def track_user_search_activity
    if current_user.is_student? && !working_on_behalf?
      UserSearchActivity.delay(queue: DjQueues::HIGH_PRIORITY).add_user_activity(current_user, {locale: current_locale.to_s, source: UserSearchActivity::Src::GLOBAL_SEARCH, session_id: session.id, quick_search: @search_query})
    end
  end
end
