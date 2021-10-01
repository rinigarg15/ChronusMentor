module TabConfigurationHelper
  module MobileTabConfigurationHelper

    # Configures tabs that need to be shown, and also selects the tab based on
    # request url and context
    # This method will not be called for ajax requests, when used as a before_action
    def configure_mobile_tabs
      return if skip_mobile_tab_computation?
      @show_mobile_footer_tab = true
      configure_mobile_home_tab(params)
      get_mobile_messages_badge_count
      if @current_program.project_based?
        configure_mobile_pbe_tabs(params)
      else
        configure_mobile_non_pbe_tabs(params)
      end
      configure_mobile_manage_tab(params)
      configure_mobile_messages_tab(params) unless @current_program.project_based?
      configure_mobile_more_tab
      compute_active_mobile_tab
    end

    def configure_mobile_non_pbe_tabs(params)
      configure_mobile_pre_and_post_match_tabs(params)
      configure_mobile_requests_tab(params)
    end

    def configure_mobile_home_tab(options = {})
      add_mobile_tab(TabConstants::HOME, program_root_path(src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), is_mobile_tab_active?(MobileTab::Home, options), iconclass: "fa-home")
    end

    def configure_mobile_manage_tab(options = {})
      add_mobile_tab("display_string.Manage".translate, manage_program_path(src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), is_mobile_tab_active?(MobileTab::Manage, options), iconclass: "fa-cogs") if current_user.is_admin_only?
    end

    def configure_mobile_more_tab
      add_mobile_tab("app_layout.label.more".translate, '#sidebarLeft', false, iconclass: "fa-bars", mobile_tab_class: "cjs_mobile_more_tab navbar-minimalize")
    end

    def configure_mobile_pre_and_post_match_tabs(options = {})
      tab_options = options.deep_dup
      can_connect_with_a_mentor = current_user.can_connect_with_a_mentor?
      if current_user.is_unconnected? && current_user.can_be_shown_match_tab?(can_connect_with_a_mentor)
        configure_mobile_match_tab(tab_options.merge!(can_connect_with_a_mentor: can_connect_with_a_mentor))
      elsif show_mobile_connections_tab?(current_user)
        configure_mobile_connections_tab(tab_options)
      elsif current_user.program.only_one_time_mentoring_enabled? && @upcoming_meetings_count
        configure_mobile_meetings_tab(tab_options)
      end
    end

    def configure_mobile_match_tab(options = {})
      active = is_mobile_tab_active?(MobileTab::Match, options)
      add_mobile_tab("feature.user.label.match".translate, options[:can_connect_with_a_mentor] ? users_path(src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION) : users_path(view: RoleConstants::STUDENTS_NAME, src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), active, {iconclass: "fa-user-circle", badge_text: content_tag(:i, "", class: "fa fa-search")})
    end

    def configure_mobile_connections_tab(options = {})
      active = is_mobile_tab_active?(MobileTab::Connection, options)
      active_groups_count = current_user.groups.active.count
      badge_text = ""
      if active_groups_count == 1
        group = current_user.groups.active.first
        add_mobile_tab(_Mentoring_Connections, group_path(group, src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), active, {iconclass: "fa-users", badge_text: badge_text})
      else
        add_mobile_tab(_Mentoring_Connections, "#", active, {iconclass: "fa-users", badge_text: badge_text, mobile_tab_class: "cjs_connections_tab"})
      end
    end

    def configure_mobile_meetings_tab(options = {})
      @show_meeting_tab = true
      badge_text = @upcoming_meetings_count > 0 ? "#{@upcoming_meetings_count}" : ""
      add_mobile_tab(_Meetings, member_path(wob_member, tab:  MembersController::ShowTabs::AVAILABILITY, src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), is_mobile_tab_active?(MobileTab::Request, options), {iconclass: "fa-calendar", badge_text: badge_text})
    end

    def configure_mobile_pbe_tabs(options = {})
      if current_user.roles.for_mentoring.exists?
        active = is_mobile_tab_active?(MobileTab::Discover, options)
        add_mobile_tab("tab_constants.discover".translate, find_new_groups_path(src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), active, {iconclass: "fa-search"})
        active = is_mobile_tab_active?(MobileTab::Connection, options)
        add_mobile_tab(_Mentoring_Connections, "#", active, {iconclass: "fa-users", badge_text: "", mobile_tab_class: "cjs_connections_tab"})
      end
      configure_notifications_tab(options)
    end

    def configure_notifications_tab(options = {})
      badge_count = @mobile_requests_tab_badge_count + @cummulative_messages_count
      active = is_mobile_tab_active?(MobileTab::Notification, options)
      add_mobile_tab("tab_constants.notifications".translate, "#", active, {iconclass: "fa-bell-o", badge_text: badge_count > 0 ? "#{badge_count}" : "", modal_id: "#notifications_modal", mobile_tab_class: "cjs_footer_total_requests"})
    end

    def configure_mobile_requests_tab(options = {})
      return unless current_user.roles.for_mentoring.exists?
      tab_options = options.deep_dup
      links_to_show = @notification_quick_links.uniq
      active = is_mobile_tab_active?(MobileTab::Request, options)
      badge_count = @mobile_requests_tab_badge_count
      badge_text = get_badge_text(badge_count)
      if links_to_show.size > 1
        add_mobile_tab("tab_constants.sub_tabs.requested_meetings".translate, "#", active, {iconclass: "fa-user-plus", badge_text: badge_text, modal_id: "#requests_modal", mobile_tab_class: "cjs_footer_total_requests"})
      elsif links_to_show.size == 1
        configure_mobile_requests_individual_tabs(links_to_show[0], tab_options.merge!({badge_text: badge_text, active: active}))
      end
    end

    def configure_mobile_requests_individual_tabs(tab_to_show, options = {})
      badge_text = options[:badge_text]
      active = options[:active]
      case tab_to_show
      when MobileTab::QuickLink::MentorRequest
        add_mobile_tab("tab_constants.sub_tabs.requested_meetings".translate, mentor_requests_path({src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION }.merge(@mentor_requests_url_options)), active, {iconclass: "fa-user-plus", badge_text: badge_text})
      when MobileTab::QuickLink::MentorOffer
        add_mobile_tab("tab_constants.sub_tabs.requested_meetings".translate, mentor_offers_path(src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), active, {iconclass: "fa-user-plus", badge_text: badge_text})
      when MobileTab::QuickLink::Meeting
        add_mobile_tab(_Meetings, member_path(wob_member, tab:  MembersController::ShowTabs::AVAILABILITY, src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), active, {iconclass: "fa-calendar", badge_text: badge_text, mobile_tab_class: "cjs_footer_upcoming_meetings"}) unless @show_meeting_tab
      when MobileTab::QuickLink::ProgramEvent
        add_mobile_tab("feature.program_event.header.events".translate, program_events_path(src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), active, {iconclass: "fa-calendar", badge_text: badge_text})
      end
    end

    def configure_mobile_messages_tab(options)
      active = is_mobile_tab_active?(MobileTab::Message, options)
      badge_text = @cummulative_messages_count > 0 ? "#{@cummulative_messages_count}" : ""
      if @show_admin_messages
        add_mobile_tab("feature.messaging.title.messages".translate, "#", active, {iconclass: "fa-envelope", badge_text: badge_text, modal_id: "#messages_modal", mobile_tab_class: "cjs_footer_messages"})
      else
        add_mobile_tab("feature.messaging.title.messages".translate, messages_path(organization_level: true, src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), active, {iconclass: "fa-envelope", badge_text: badge_text, mobile_tab_class: "cjs_footer_messages"})
      end
    end

    private

    def skip_mobile_tab_computation?
      request.xhr? || !logged_in_program? || current_user.profile_pending?
    end

    def get_mobile_messages_badge_count
      @show_admin_messages = current_user.view_management_console?
      @message_count = wob_member.inbox_unread_count
      if @show_admin_messages
        @admin_message_count = @current_program.admin_messages_unread_count
        @cummulative_messages_count = @message_count + @admin_message_count
      else
        @cummulative_messages_count = @message_count
      end
    end

    def get_badge_text(badge_count)
      badge_count > 0 ? "#{badge_count}" : ""
    end
  end
end
