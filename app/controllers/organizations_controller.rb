class OrganizationsController < ApplicationController
  include SecuritySettingMethods
  include ProgramAssetUtils

  MEMBERS_BOX_SIZE            = 6
  MAX_GROUPS_TO_SHOW_IN_HOME  = 2
  MY_MEETINGS_COUNT           = 3
  ALLOWED_EDIT_TABS           = [
    ProgramsController::SettingsTabs::GENERAL,
    ProgramsController::SettingsTabs::TERMINOLOGY,
    ProgramsController::SettingsTabs::FEATURES,
    ProgramsController::SettingsTabs::SECURITY,
  ]

  skip_action_callbacks_for_autocomplete :show_activities
  skip_before_action :require_program, :login_required_in_program
  skip_before_action :handle_inactive_organization, :update_last_seen_at, only: [:inactive]

  before_action :login_required_in_organization, except: [:show, :inactive, :deactivate]
  before_action :add_custom_parameters_for_newrelic, only: [:show]
  before_action :require_super_user, only: [:deactivate]
  before_action :set_v2_page, only: [:edit, :update, :manage, :show]
  after_action :expire_banner_cached_fragments, only: [:update]
  before_action :show_pendo_launcher_in_all_devices, only: [:show, :manage]

  allow exec: :check_admin_access, only: [:edit, :update, :manage, :update_three_sixty_settings]

  #
  # Organization settings page. Contains 2 tabs.
  #
  #   * General Settings
  #   * Customize Terminology
  #   * Features
  #
  def edit
    @tab = ProgramsController::SettingsTabs.get_tab(params[:tab].to_i)
    allow! :exec => lambda{ ALLOWED_EDIT_TABS.include?(@tab) }
    @organization = @current_organization
  end

  def update
    # This is required, when the organiation attributes(name) are changed but not saved,
    # @current_organization.name should still return the old value
    @organization = Organization.find(@current_organization.id)

    @tab = ProgramsController::SettingsTabs.get_tab(params[:tab].to_i)
    allow! :exec => lambda{ ALLOWED_EDIT_TABS.include?(@tab) }
    organization_attrs = organization_params(:update)
    organization_attrs = self.class.filter_super_user_features(organization_attrs, @organization, super_console?)

    unless super_console?
      organization_attrs.delete(:email_theme_override)
    end

    if organization_attrs[:security_setting_attributes].present?
      override_security_attributes!(params, organization_attrs, super_console?)
    end

    organization_attrs = reject_terms_and_privacypolicy(organization_attrs) if @current_organization.display_custom_terms_only
    update_banner_logo, program_asset = get_banner_logo_attributes(@organization, params[:organization])

    is_success = update_banner_logo ? program_asset.valid? : true
    if !is_success && update_banner_logo
      flash[:error] = get_safe_string
      program_asset.errors.full_messages.each do |msg|
        flash[:error] << msg << "<br />".html_safe
      end
    end

    if super_console? && @tab == ProgramsController::SettingsTabs::GENERAL
      feed_export_frequency = organization_attrs.delete(:feed_export_frequency).to_i

      if organization_attrs.delete(:activate_feed_export) == "true"
        feed_exporter = FeedExporter.find_or_initialize_by(program_id: @organization.id)
        feed_exporter.frequency = feed_export_frequency
        feed_exporter.save!
      else
        @organization.feed_exporter.try(:destroy)
      end
    end

    if @tab == ProgramsController::SettingsTabs::FEATURES &&
      !organization_attrs[:enabled_features].include?(FeatureName::MANAGER) &&
      @current_organization.profile_questions.manager_questions.any?
        is_success = false
        flash[:error] = "flash_message.organization_flash.manager_error".translate
    end

    assign_user_and_sanitization_version(@organization)
    if is_success && @organization.update_attributes(organization_attrs)
      program_asset.save if update_banner_logo
      Feature.handle_feature_dependency(@organization)
      flash[:notice] = "flash_message.organization_flash.updated".translate
      redirect_to edit_organization_path(:tab => @tab)
    else
      render :action => :edit
    end
  end

  #
  # Organization management page.
  #
  def manage
    @portals = @current_organization.portals.ordered.select([:id, :parent_id, :root]).includes(:translations)
    @can_create_portal = can_create_portals?
    @show_manage_portal =  @can_create_portal || @current_organization.can_show_portals?
  end

  def inactive
    if @current_organization.active?
      redirect_to root_organization_path
      return
    end
    respond_to do |format|
      format.html {}
      format.any { head :ok }
    end

    @no_tabs = true
    @no_page_actions = true
  end

  #
  # Dashboard
  #
  def show
    # ORG_PERMISSIONS_FIXME
    set_gray_background
    # If not logged in at organization level, redirect to organization home page
    unless logged_in_organization?
      flash.keep

      # Note that we are explicitly giving :organization_level => true so that
      # we do not redirect to program about page if standalone
      # (i.e., program_view? is true)
      redirect_to about_path(:organization_level => true)
      return
    end

    # If this is an organization with a single program, redirect to the program
    # home page.
    return redirect_to(program_root_path(:root => @current_program.root)) if program_view?

    redirect_to enrollment_path and return if wob_member.dormant?

    @show_admin_dashboard = wob_member.show_admin_dashboard?(params[:activities_dashboard].to_s.to_boolean)
    if @show_admin_dashboard
      @managed_programs = get_managed_programs(@current_organization, scoped_programs: wob_member.admin_only_at_track_level? ? wob_member.managing_programs : nil)
      @rollup_info = get_rollup_info(@current_organization, track_level_admin: wob_member.admin_only_at_track_level?, ongoing_engagements: true, rollup_needed: false)
    else
      @my_programs = wob_member.active_programs.ordered.includes([:translations])
      @is_recent_activities_present = wob_member.can_view_ra?
    end
  end

  def get_global_dashboard_program_info_box_stats
    @program = get_managed_programs(@current_organization).find { |this| this.id == params[:program_id].to_i } if wob_member.show_admin_dashboard?
  end

  def get_global_dashboard_org_current_status_stats
    @rollup_info = get_rollup_info(@current_organization, active_licenses: params[:active_licenses].to_s.to_boolean, ongoing_engagements: params[:ongoing_engagements].to_s.to_boolean, connected_members_count: params[:connected_members_count].to_s.to_boolean, track_level_admin: wob_member.admin_only_at_track_level?) if wob_member.show_admin_dashboard?
  end

  def show_activities
    @recent_activities_with_user = []
    @is_my = params[:my]
    @offset_id = params[:offset_id]

    # For each activity, find the user to whom it is targeted towards and push
    # it into the activities array.
    ra_fetch_opts = {:offset_id => @offset_id}
    ra_fetch_opts[:actor] = wob_member if @is_my

    users_in_program = wob_member.users.includes(:program).group_by(&:program)
    member_programs = users_in_program.keys

    activities = wob_member.activities_to_show(ra_fetch_opts)

    activities.each do |act|
      common_programs = act.programs & member_programs
      @recent_activities_with_user << {:user => users_in_program[common_programs.first].first, :act => act}
    end

    last_activity = @recent_activities_with_user.last
    @new_offset_id = last_activity && last_activity[:act].id
  end

  def enrollment
    @users, @programs_allowing_roles, visible_programs_ids = @current_organization.get_enrollment_content(wob_member, ids_only: true)

    ProgramsListingService.fetch_programs self, @current_organization do |all_programs|
      all_programs.ordered.includes([{:organization => :program_asset}, :translations, :program_asset]).select(['programs.id, root, parent_id, show_multiple_role_option']).where(id: visible_programs_ids)
    end

    @membership_requests = wob_member.membership_requests.pending.includes(:roles)
  end

  def enrollment_popup
    roles = params[:roles]
    @program = @current_organization.programs.find(params[:program])
    user = wob_member.user_in_program(@program)
    program_join_roles = @program.role_names_with_join_directly_or_join_directly_only_with_sso
    program_membership_roles = @program.role_names_allowing_membership_request
    program_membership_roles += @program.role_names_allowing_join_with_criteria
    @membership_roles = roles & program_membership_roles
    @join_roles = []
    if user.present? && user.suspended?
      @membership_roles += (roles & program_join_roles)
    else
      @join_roles = roles & program_join_roles
    end
    @is_checkbox = @program.show_and_allow_multiple_role_memberships?
  end

  def update_three_sixty_settings
    @current_organization.update_attribute(:show_text_type_answers_per_reviewer_category, !@current_organization.show_text_type_answers_per_reviewer_category?)
    head :ok
  end

  def deactivate
    if @current_organization.present? && params[:organization][:active] == "1"
      @current_organization.active = false
      @current_organization.save!
      @current_organization.feed_import_configuration.try(:disable!)
      InternalMailer.deactivate_organization_notification(@current_organization.name, @current_organization.account_name, @current_organization.url).deliver_now
      logout_killing_session!
    end
    redirect_to deactivate_path
  end

  # Returns whether the current member is an organization admin.
  def check_admin_access
    wob_member && wob_member.admin?
  end

  def self.filter_super_user_features(organization_attrs, organization, super_console)
    if organization_attrs[:enabled_features]
      if super_console
        return organization_attrs
      else
        su_features = FeatureName.super_user_features
        enabled_su_features = su_features & organization.enabled_db_features.collect(&:name)
        submitted_features = organization_attrs[:enabled_features]

        raise Authorization::PermissionDenied if (submitted_features & su_features).any?

        organization_attrs[:enabled_features] += enabled_su_features
        return organization_attrs
      end
    else
      return organization_attrs
    end
  end

  private

  def get_managed_programs(organization, options = {})
    managed_programs_scope = options[:scoped_programs] || organization.programs
    managed_programs_scope.ordered.includes([:translations], [:roles => {:customized_term => :translations}], [:customized_terms], [:program_asset => :translations])
  end

  def get_rollup_info(organization, options = {})
    if options[:track_level_admin]
      options[:scoped_programs] = wob_member.managing_programs
      options[:scoped_program_ids] = options[:scoped_programs].collect(&:id)
    end
    info = {}
    info[:active_licenses] = get_active_license_rollup_info(organization, options) if options[:active_licenses]
    info[:ongoing_engagements] = get_ongoing_engagements_rollup_info(organization, options) if options[:ongoing_engagements]
    info[:connected_members_info] = get_connected_members_count(organization, options.merge(ongoing_engagements_info: info[:ongoing_engagements])) if options[:connected_members_count]
    info
  end  
  
  def get_connected_members_count(organization, options = {})
    options[:track_level_admin] ? get_connected_members_count_for_track_level_admin(organization, options) : get_connected_members_count_for_global_admin(organization, options)
  end

  def get_connected_members_count_for_global_admin(organization, options = {})
    active_license_admin_view = organization.admin_views.find_by(default_view: AbstractView::DefaultType::LICENSE_COUNT)
    dynamic_filter_params = {non_profile_field_filters: [AdminView::MEMBER_WITH_ONGOING_ENGAGEMENTS_FILTER_HSH]}
    member_ids_connected_by_group = get_admin_view_count_or_ids_for_track_or_org_level_admin(active_license_admin_view, dynamic_filter_params: dynamic_filter_params, get_member_ids: true)
    get_connected_members_count_for_ongoing_and_flash(member_ids_connected_by_group, options[:ongoing_engagements_info])
  end

  def get_connected_members_count_for_track_level_admin(organization, options = {})
    member_ids_connected_by_group = organization.current_connected_member_ids(program_ids: options[:scoped_program_ids], include_active_users_only: true)
    get_connected_members_count_for_ongoing_and_flash(member_ids_connected_by_group, options[:ongoing_engagements_info])
  end

  def get_connected_members_count_for_ongoing_and_flash(member_ids_connected_by_group, ongoing_engagements_info_hash)
    connected_members_split_up_for_groups = get_connected_members_split_up_for_group(ongoing_engagements_info_hash)
    connected_members_split_up_for_meetings = get_connected_members_split_up_for_meeting(ongoing_engagements_info_hash)
    {
      count: (member_ids_connected_by_group + ongoing_engagements_info_hash.dig(:meetings_rollup, :active_meeting_member_ids).to_a).uniq.count,
      mentors_count: (connected_members_split_up_for_groups[:mentors] + connected_members_split_up_for_meetings[:mentors]).uniq.size,
      students_count: (connected_members_split_up_for_groups[:students] + connected_members_split_up_for_meetings[:students]).uniq.size
    }
  end

  def get_active_license_rollup_info(organization, options = {})
    get_active_license_rollup_info_split_up(organization, options)
  end

  def get_active_license_rollup_info_split_up(organization, options = {})
    active_member_ids = get_admin_view_count_or_ids_for_track_or_org_level_admin(organization.admin_views.find_by(default_view: AbstractView::DefaultType::LICENSE_COUNT), options.merge(get_member_ids: true))
    mentor_mentee_member_count = get_mentor_mentee_split_up_for_active_license(organization, active_member_ids, options)
    {
      total_count: active_member_ids.size,
      mentors_count: mentor_mentee_member_count[:mentor],
      students_count: mentor_mentee_member_count[:mentee]
    }
  end

  def get_connected_members_split_up_for_group(ongoing_engagements_info_hash)
    {
      mentors: Member.member_ids_of_users(user_ids: Connection::Membership.where(group_id: ongoing_engagements_info_hash[:groups_rollup][:active_group_ids].to_a, type: Connection::MentorMembership.name).pluck(:user_id), filter_active_users_scope: true),
      students: Member.member_ids_of_users(user_ids: Connection::Membership.where(group_id: ongoing_engagements_info_hash[:groups_rollup][:active_group_ids].to_a, type: Connection::MenteeMembership.name).pluck(:user_id), filter_active_users_scope: true)
    }
  end

  def get_connected_members_split_up_for_meeting(ongoing_engagements_info_hash)
    meeting_ids = ongoing_engagements_info_hash.dig(:meetings_rollup, :active_meeting_ids).to_a
    active_users_member_ids = ongoing_engagements_info_hash.dig(:meetings_rollup, :active_users_member_ids).to_a
    {
      mentors: (active_users_member_ids & MemberMeeting.for_mentor_role.where(meeting_id: meeting_ids).pluck(:member_id).uniq),
      students: (active_users_member_ids & MemberMeeting.for_mentee_role.where(meeting_id: meeting_ids).pluck(:member_id).uniq)
    }
  end

  def get_mentor_mentee_split_up_for_active_license(organization, active_member_ids, options = {})
    options[:scoped_programs] ? get_mentor_and_mentee_member_count(options[:scoped_programs].to_a, active_member_ids) : get_mentor_and_mentee_member_count(organization, active_member_ids)
  end

  def get_mentor_and_mentee_member_count(program_or_organization, active_member_ids)
    scoped_program_ids = (program_or_organization.is_a?(Array) ? program_or_organization.pluck(:id) : program_or_organization.program_ids)
    local_logic_consolidator = ->(program_ids, member_ids, role_name) { User.where(program_id: program_ids, member_id: member_ids).joins(:roles).where("roles.name = ?", role_name).distinct.count(:member_id) }
    {
      mentor: local_logic_consolidator.call(scoped_program_ids, active_member_ids, RoleConstants::MENTOR_NAME),
      mentee: local_logic_consolidator.call(scoped_program_ids, active_member_ids, RoleConstants::STUDENT_NAME)
    }
  end

  def get_ongoing_engagements_rollup_info(organization, options = {})
    hsh = {}
    scoped_programs = options[:scoped_programs] || organization.programs.active
    calendar_enabled_scoped_programs = scoped_programs.select(&:calendar_enabled?)
    hsh[:show_meeting_rollup] = calendar_enabled_scoped_programs.present?
    return hsh if (options[:rollup_needed] == false)
    hsh[:groups_rollup] = get_group_related_counts(organization, scoped_programs)
    hsh[:meetings_rollup] = get_ongoing_engagements_meeting_rollup_info(calendar_enabled_scoped_programs) if hsh[:show_meeting_rollup]
    hsh.merge!(get_total_active_and_closed_ongoing_engagements(hsh))
  end

  def get_group_related_counts(organization, scoped_programs)
    ongoing_enabled_scoped_programs = scoped_programs.select(&:ongoing_mentoring_enabled?)
    active_group_ids = organization.current_active_connection_ids(program_ids: ongoing_enabled_scoped_programs.collect(&:id))
    {
      active_group_ids: active_group_ids,
      active_groups_count: active_group_ids.size,
      closed_groups_count: organization.closed_connections_count(program_ids: ongoing_enabled_scoped_programs.collect(&:id))
    }
  end

  def get_ongoing_engagements_meeting_rollup_info(calendar_enabled_scoped_programs)
    program_ids = calendar_enabled_scoped_programs.map(&:id)
    active_users_member_ids = User.active.where(program_id: program_ids).pluck(:member_id).uniq
    meeting_ids = MemberMeeting.where(member_id: active_users_member_ids).pluck(:meeting_id)  
    get_meetings_and_meeting_members_rollup_info(meeting_ids, program_ids, active_users_member_ids)
  end

  def get_meetings_and_meeting_members_rollup_info(meeting_ids, program_ids, active_users_member_ids)
    meetings = Meeting.where(id: meeting_ids).non_group_meetings.in_programs(program_ids).accepted_meetings
    ongoing_meetings = meetings.upcoming
    closed_meetings = meetings.past
    get_ongoing_and_closed_meetings_rollup(ongoing_meetings, closed_meetings, active_users_member_ids)
  end

  def get_ongoing_and_closed_meetings_rollup(ongoing_meetings, closed_meetings, active_users_member_ids)
    {
      active_meeting_ids: ongoing_meetings.pluck(:id),
      active_meetings_count: ongoing_meetings.count,
      active_meeting_member_ids: (active_users_member_ids & MemberMeeting.where(meeting_id: ongoing_meetings.pluck(:id).flatten.uniq).pluck(:member_id).uniq),
      closed_meetings_count: closed_meetings.count,
      active_users_member_ids: active_users_member_ids
    }
  end

  def get_total_active_and_closed_ongoing_engagements(ongoing_engagements_info_hash)
    {
      total_active_count: ongoing_engagements_info_hash.dig(:groups_rollup, :active_groups_count).to_i + ongoing_engagements_info_hash.dig(:meetings_rollup, :active_meetings_count).to_i,
      total_closed_count: ongoing_engagements_info_hash.dig(:groups_rollup, :closed_groups_count).to_i + ongoing_engagements_info_hash.dig(:meetings_rollup, :closed_meetings_count).to_i
    }
  end

  def organization_params(action)
    return {} if params[:organization].blank?
    tab_key = if @tab == ProgramsController::SettingsTabs::GENERAL
      "general"
    elsif @tab == ProgramsController::SettingsTabs::SECURITY
      "security"
    end
    attr_key = super_console? ? "#{tab_key}_super_console" : tab_key
    permitted_params = params.require(:organization).permit(Organization::MASS_UPDATE_ATTRIBUTES[action][attr_key.try(:to_sym)])
    if @tab == ProgramsController::SettingsTabs::FEATURES
      permitted_params.merge!(enabled_features: params[:organization][:enabled_features]) if params[:organization][:enabled_features]
    elsif @tab == ProgramsController::SettingsTabs::SECURITY
      permitted_params[:security_setting_attributes].merge!(allowed_ips: params[:organization][:security_setting_attributes][:allowed_ips]) if params[:organization].try(:[], :security_setting_attributes).try(:[], :allowed_ips)
    elsif @tab == ProgramsController::SettingsTabs::GENERAL
      if super_console?
        permitted_params.merge!(activate_feed_export: params[:organization][:activate_feed_export]) if params[:organization][:activate_feed_export]
        permitted_params.merge!(feed_export_frequency: params[:organization][:feed_export_frequency]) if params[:organization][:feed_export_frequency]
      end
    end
    permitted_params
  end

  def get_admin_view_count_or_ids_for_track_or_org_level_admin(admin_view, options = {})
    dynamic_filter_params = options[:dynamic_filter_params] || {}
    if options[:track_level_admin] && options[:scoped_program_ids].present?
      (dynamic_filter_params[:non_profile_field_filters] ||= []) << AdminView::MEMBERS_IN_SPECIFIED_PROGRAMS.call(options[:scoped_program_ids].join(","))
    end
    get_admin_view_count_or_id(admin_view, dynamic_filter_params, options.pick(:get_member_ids))
  end

  def get_admin_view_count_or_id(admin_view, dynamic_filter_params, options = {})
    options[:get_member_ids] ? admin_view.fetch_all_member_ids(dynamic_filter_params: dynamic_filter_params) : admin_view.count(nil, dynamic_filter_params: dynamic_filter_params)
  end
end
