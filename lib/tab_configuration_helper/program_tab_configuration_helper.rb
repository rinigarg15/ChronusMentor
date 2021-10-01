module TabConfigurationHelper
  module ProgramTabConfigurationHelper
    def configure_program_tabs
      return if skip_program_tabs_configuration?

      # Do not render tabs when the user has not completed their profile.
      @no_tabs = is_pending_profile_tabs?
      return configure_help_and_support_tab(false) if @no_tabs

      fetch_program_pages
      return configure_all_non_logged_in_tabs unless logged_in_at_current_level?

      # Delegate to +configure_organization_tabs+ when inside organization view.
      return configure_organization_tabs if organization_view?

      cname = params[:controller]
      aname = params[:action]

      add_grouped_tabs(cname, aname)
      pages_to_tabs!
      add_overview_tab(cname)      

      compute_active_tab
    end

    private

    def skip_program_tabs_configuration?
      request.xhr? || @current_organization.nil?
    end

    def is_pending_profile_tabs?
      logged_in_program? && current_user.profile_pending?
    end

    def configure_all_non_logged_in_tabs
      configure_unloggedin_tabs
      configure_help_and_support_tab(false)
    end

    def fetch_program_pages
      @pages ||= collect_all_pages
    end

    def add_grouped_tabs(cname, aname)
      add_program_root_tab(cname, aname)
      add_tabs_for_all_roles(cname, aname)

      # Connection Tab
      configure_mentoring_connection_tab

      # Meetings Tab
      configure_meeting_tab

      # Dashboards Tab
      configure_dashboards_tab if @current_organization.standalone?

      # Reports Tab
      configure_report_tab

      add_tab(TabConstants::DIVIDER, '#', false)

      add_manage_program_tab(cname, aname, params)

      # Mentoring Community Tab
      configure_mentoring_community_tab

      # Help and Support Tab
      configure_help_and_support_tab
    end

    def add_overview_tab(cname)
      add_tab("tab_constants.overview".translate, about_path, (cname == "pages"), iconclass: "fa-file") unless current_user.view_management_console?
    end

    # Returns the set of tabs and the default tab for a non-loggedin user
    def configure_unloggedin_tabs
      invite_code = session[:invite_code] || params[:invite_code]
      reset_code = session[:reset_code] || params[:reset_code]
      signup_url = compute_signup_url(invite_code, reset_code)

      if signup_url
        add_tab("tab_constants.sign_up".translate, signup_url, is_signup_request?(controller_name, action_name), iconclass: "fa-user-plus #{hidden_on_web}")
      end

      pages_to_tabs!

      add_program_listing_tab_heading(controller_name, action_name)
    end

    def collect_all_pages
      scope = get_all_pages_scope
      scope = scope.published unless has_page_management_access?
      logged_in_pages_enabled = (organization_view? ? @current_organization : @current_program).logged_in_pages_enabled?
      filter_pages_scope_by_login_status(scope, logged_in_pages_enabled)
    end

    def filter_pages_scope_by_login_status(scope, logged_in_pages_enabled)
      return scope if can_use_given_pages_scope?(logged_in_pages_enabled)
      if logged_in_at_current_level?
        return []
      else
        return scope.for_not_logged_in_users
      end
    end

    def can_use_given_pages_scope?(logged_in_pages_enabled)
      logged_in_at_current_level? && logged_in_pages_enabled || !logged_in_pages_enabled && !logged_in_pages_enabled
    end

    def has_page_management_access?
      organization_view? ? (wob_member && wob_member.admin?) :
        (current_user && current_user.can_manage_custom_pages?)
    end

    def get_all_pages_scope
      if organization_view?
        # Only organization pages
        @current_organization.pages
      elsif @current_organization.standalone?
        # If standalone, fetch both program and organization pages.
        @current_program.all_pages.includes(:translations)
      else
        # Sub-Program : fetch only sub-program specific pages.
        @current_program.pages.includes(:translations)
      end
    end

    def add_program_root_tab(cname, aname)
      add_tab(
        TabConstants::HOME, program_root_path(src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION),
        ((cname == 'programs' && aname == 'show') || (cname == 'reports' && aname == "management_report")), iconclass: "fa-home", tab_class: "#{hidden_on_mobile}"
      )
    end

    def add_tabs_for_all_roles(cname, aname)
      add_mentors_tab(cname, aname)
      add_mentees_tab(cname, aname)
      add_role_tabs(cname, aname)
    end

    def add_mentors_tab(cname, aname)
      if current_user.can_view_mentors?
        add_tab(
          h(_Mentors), users_path(src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION),
          is_user_index_with_view?(cname, aname, params[:view], nil) ||
            (cname == 'users' && aname == 'mentoring_calendar') ||
            (cname == 'mentor_requests' && aname == 'new'), iconclass: "fa-user-circle"
        )
      end
    end

    def add_mentees_tab(cname, aname)
      if current_user.can_view_students?
        # Students index and new mentor requests.
        add_tab(
          h(_Mentees), users_path(view: RoleConstants::STUDENTS_NAME, src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION),
          cname == 'users' &&
            (aname == 'index' && params[:view] == RoleConstants::STUDENTS_NAME), iconclass: "fa-user-circle"
        )
      end
    end

    def add_role_tabs(cname, aname)
      # Should they be visible to all or do they require some permission
      @current_program.roles.includes(customized_term: :translations).non_administrative.each do |role|
        if @current_user.can_view_role?(role.name) && (!RoleConstants::MENTORING_ROLES.include?(role.name))
          add_tab(
              h(role.customized_term.pluralized_term), users_path(view: role.name, src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION),
              is_user_index_with_view?(cname, aname, params[:view], role.name), iconclass: "fa-user-circle")
        end
      end
    end

    def add_manage_program_tab(cname, aname, params)
      # Show Manage tab to Organization admin and if program user has permission.
      if organization_view? ? wob_member.admin? : current_user.view_management_console?
        # The following pages come under the manage tab, for admin.
        #
        # * Manage tab
        # * Program edit page
        # * Mentor requests index
        # * Announcements
        # * Membership requests
        # * Invite users page
        # * Add new mentor page
        #
        add_tab(
          TabConstants::MANAGE, manage_program_path,
            is_manage_tab_active?(cname, aname, params), iconclass: "fa-cogs"
        )
      end
    end

    def compute_signup_url(invite_code, reset_code)
      if invite_code
        new_registration_path(invite_code: session[:invite_code])
      elsif reset_code
        new_user_followup_users_path(reset_code: session[:reset_code])
      end
    end

    def is_signup_request?(controller_name, action_name)
      (controller_name == "registrations" && action_name == "new") || (controller_name == "users" && action_name == "new_user_followup")
    end

    def add_program_listing_tab_heading(controller_name, action_name)
      programs_listing_tab_heading = view_context.get_programs_listing_tab_heading
      return unless programs_listing_tab_heading.present?
      if logged_in_organization?
        add_tab(programs_listing_tab_heading, enrollment_path, (controller_name == "organizations" && action_name == ""), iconclass: "fa-th-large")
      else
        add_tab(programs_listing_tab_heading, programs_pages_path, (controller_name == "pages" && action_name == "programs"), iconclass: "fa-th-large")
      end
    end

    def is_user_index_with_view?(cname, aname, view_param, role_name)
      (cname == 'users' && aname == 'index' && view_param == role_name)
    end

  end
end