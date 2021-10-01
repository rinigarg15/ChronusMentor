module TabConfigurationHelper
  module MentoringConnectionTabConfigurationHelper
    def configure_mentoring_connection_tab
      cname = params[:controller]
      aname = params[:action]

      mentoring_connection_sub_tabs = init_sub_tabs

      return if skip_mentoring_connnection_tab_config?
      if is_mobile?
        mentoring_connection_sub_tabs = set_mobile_mentoring_connection_sub_tabs(mentoring_connection_sub_tabs, cname, aname, current_user)
      else
        mentoring_connection_sub_tabs = set_web_mentoring_connection_sub_tabs(mentoring_connection_sub_tabs, cname, aname)
      end

      add_tab(
        UnicodeUtils.upcase(_Mentoring_Connections), "#", false,
        subtabs: mentoring_connection_sub_tabs, iconclass: "fa-users", open_by_default: true, tab_class: "cjs_mentoring_connection_header")
    end

    private

    def set_mobile_mentoring_connection_sub_tabs(mentoring_connection_sub_tabs, cname, aname, current_user)
      return mentoring_connection_sub_tabs if current_user.groups.closed.size <= 0
      options = {
        is_active_hash: is_group_index_my_page?(cname, aname, params[:show]),
        link_label_hash: "tab_constants.sub_tabs.closed".translate,
        has_partial_hash: false,
        render_path_hash: groups_path(show: "my", tab: Group::Status::CLOSED, view: Group::View::DETAILED, src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION, sub_src: EngagementIndex::SideBarSubSrc::CONNECTION),
        icon_class_hash: "fa-list"
      }
      set_sub_tab_values(mentoring_connection_sub_tabs, TabConfiguration::Tab::SubTabLinks::CLOSED_CONNECTION, options)
    end

    def set_web_mentoring_connection_sub_tabs(mentoring_connection_sub_tabs, cname, aname)
      options = {
        is_active_hash: active_mentoring_connection_tab?(cname, aname, params),
        has_partial_hash: true,
        render_path_hash: "groups/group_subtabs"
      }
      set_sub_tab_values(mentoring_connection_sub_tabs, TabConfiguration::Tab::SubTabLinks::MENTORING_CONNECTION, options)
    end

    def is_group_index_my_page?(cname, aname, show_param)
      cname == 'groups' && aname == 'index' && ['my'].include?(show_param)
    end

    def is_group_find_new_page?(cname, aname)
      cname == 'groups' && aname == 'find_new'
    end

    def is_group_new_page_propose_view?(cname, aname, propose_view)
      cname == 'groups' && aname == 'new' && propose_view == "true"
    end

    def is_member_show_availability_tab?(cname, aname, tab_param)
      cname == 'members' && aname == 'show' && tab_param == MembersController::ShowTabs::AVAILABILITY
    end

    def active_mentoring_connection_tab?(cname, aname, params)
      (is_group_index_my_page?(cname, aname, params[:show]) ||
        is_group_find_new_page?(cname, aname) || is_group_new_page_propose_view?(cname, aname, params[:propose_view]) || 
        (!@current_program.calendar_enabled? && is_member_show_availability_tab?(cname, aname, params[:tab])))
    end

    def skip_mentoring_connnection_tab_config?
      !current_user.can_be_shown_connection_tab_or_widget? || (is_mobile? && current_user.groups.closed.size <= 0) 
    end
  end
end