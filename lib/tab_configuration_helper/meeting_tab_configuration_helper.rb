module TabConfigurationHelper
  module MeetingTabConfigurationHelper
    def configure_meeting_tab
      cname = params[:controller]
      aname = params[:action]

      return unless @upcoming_meetings_count
      if @current_program.calendar_enabled?
        add_tab_for_calendar_enabled_programs(cname, aname)
      elsif !current_user.can_be_shown_connection_tab_or_widget?
        add_tab(
          _Meetings, member_path(wob_member, tab: MembersController::ShowTabs::AVAILABILITY, src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION), (cname == 'members' && aname == 'show' && params[:tab] == MembersController::ShowTabs::AVAILABILITY),
          iconclass: "fa-calendar"
        )
      end
    end

    private

    def add_tab_for_calendar_enabled_programs(cname, aname)
      meetings_sub_tabs = init_sub_tabs
      meetings_sub_tabs = set_meeting_sub_tabs_for_requested_meetings(meetings_sub_tabs, cname, aname)
      meetings_sub_tabs = set_meeting_sub_tabs_for_upcoming_meetings(meetings_sub_tabs, cname, aname)
      meetings_sub_tabs = set_meeting_sub_tabs_for_past_meetings(meetings_sub_tabs, cname, aname)
      if current_user.can_view_mentoring_calendar? && current_user.is_allowed_to_set_slot_availability?
        meetings_sub_tabs[TabConfiguration::Tab::SubTabKeys::LINKS_LIST] << TabConstants::DIVIDER
        meetings_sub_tabs = set_meeting_sub_tabs_for_mentoring_calendar(meetings_sub_tabs, cname, aname)
      end

      add_tab(
        UnicodeUtils.upcase(_Meetings), '#', false,
        subtabs: meetings_sub_tabs, iconclass: "fa-calendar", open_by_default: @current_program.calendar_enabled?, tab_class: "cjs_meetings_header"
      )
    end

    def set_meeting_sub_tabs_for_requested_meetings(meetings_sub_tabs, cname, aname)
      options = {
        is_active_hash: (cname == 'meeting_requests' && aname == 'index'),
        link_label_hash: 'tab_constants.sub_tabs.requested_meetings'.translate,
        has_partial_hash: false,
        render_path_hash: meeting_requests_path(src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION, sub_src: EngagementIndex::SideBarSubSrc::MEETINGS),
        icon_class_hash: "fa-user-plus"
      }
      options.merge!(badge_count_hash: @new_meeting_requests_count) if @new_meeting_requests_count
      set_sub_tab_values(meetings_sub_tabs, TabConfiguration::Tab::SubTabLinks::REQUESTED_MEETINGS, options)
    end

    def set_meeting_sub_tabs_for_upcoming_meetings(meetings_sub_tabs, cname, aname)
      options = {
        is_active_hash: is_member_show_page_availability_tab_non_past_meetings?(cname, aname, params[:tab], params[:meetings_tab]),
        link_label_hash: 'tab_constants.sub_tabs.upcoming_meetings'.translate,
        has_partial_hash: false,
        render_path_hash: member_path(wob_member, tab: MembersController::ShowTabs::AVAILABILITY, src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION, sub_src: EngagementIndex::SideBarSubSrc::MEETINGS),
        icon_class_hash: "fa-calendar-check-o",
        badge_count_hash: @upcoming_meetings_count
      }
      set_sub_tab_values(meetings_sub_tabs, TabConfiguration::Tab::SubTabLinks::UPCOMING_MEETINGS, options)
    end

    def set_meeting_sub_tabs_for_past_meetings(meetings_sub_tabs, cname, aname)
      options = {
        is_active_hash: (cname == 'members' && aname == 'show' && params[:tab] == MembersController::ShowTabs::AVAILABILITY && params[:meetings_tab] == MeetingsController::MeetingsTab::PAST),
        link_label_hash: 'tab_constants.sub_tabs.past_meetings'.translate,
        has_partial_hash: false,
        render_path_hash: member_path(wob_member, tab: MembersController::ShowTabs::AVAILABILITY, src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION, meetings_tab: MeetingsController::MeetingsTab::PAST, sub_src: EngagementIndex::SideBarSubSrc::MEETINGS),
        icon_class_hash: "fa-calendar"
      }
      set_sub_tab_values(meetings_sub_tabs, TabConfiguration::Tab::SubTabLinks::PAST_MEETINGS, options)
    end

    def set_meeting_sub_tabs_for_mentoring_calendar(meetings_sub_tabs, cname, aname)
      options = {
        is_active_hash: (cname == 'users' && aname == 'mentoring_calendar'),
        link_label_hash: "feature.calendar.title.mentoring_calendar_v1".translate(Mentoring: _Mentoring),
        has_partial_hash: false,
        render_path_hash: mentoring_calendar_users_path(src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION, sub_src: EngagementIndex::SideBarSubSrc::MEETINGS),
        icon_class_hash: "fa-calendar-plus-o"
      }
      set_sub_tab_values(meetings_sub_tabs, TabConfiguration::Tab::SubTabLinks::MENTORING_CALENDAR, options)
    end

    def is_member_show_page_availability_tab_non_past_meetings?(cname, aname, tab_param, meetings_tab_param)
      (cname == 'members' && aname == 'show' && tab_param == MembersController::ShowTabs::AVAILABILITY && meetings_tab_param != MeetingsController::MeetingsTab::PAST)
    end
  end
end