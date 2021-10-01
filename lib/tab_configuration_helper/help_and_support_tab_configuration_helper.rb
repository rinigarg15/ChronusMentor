module TabConfigurationHelper
  module HelpAndSupportTabConfigurationHelper
    def configure_help_and_support_tab(render_resources = true)
      cname = params[:controller]

      help_and_support_subtabs = init_sub_tabs

      if render_resources && @current_program.resources_enabled?
        help_and_support_subtabs = set_help_and_support_resources_subtabs(help_and_support_subtabs, cname)
      end

      if show_support_sub_tabs?
        help_and_support_subtabs = set_support_sub_tabs(help_and_support_subtabs)
      end

      if show_contact_admin_sub_tabs?
        help_and_support_subtabs = set_contact_admin_sub_tabs(help_and_support_subtabs)
      end

      if help_and_support_subtabs[TabConfiguration::Tab::SubTabKeys::LINKS_LIST].size > 0
        add_tab(
          "tab_constants.help_and_support".translate, '#', false,
          subtabs: help_and_support_subtabs, open_by_default: true, tab_class: "cjs_help_and_support_header"
        )
      end
    end

    private

    def set_help_and_support_resources_subtabs(help_and_support_subtabs, cname)
      if current_user.accessible_resources({only_quick_links: true, admin_view: current_user.is_admin?}).exists?
        return set_quick_links_resources_sub_tabs(help_and_support_subtabs, cname)
      elsif current_user.accessible_resources({admin_view: current_user.is_admin?}).exists?
        return set_all_resources_sub_tabs(help_and_support_subtabs, cname)
      end
      help_and_support_subtabs
    end

    def set_quick_links_resources_sub_tabs(help_and_support_subtabs, cname)
      options = {
        is_active_hash: (cname == 'resources'),
        has_partial_hash: true,
        render_path_hash: "resources/subtabs"
      }
      set_sub_tab_values(help_and_support_subtabs, TabConfiguration::Tab::SubTabLinks::RESOURCES, options)
    end

    def set_all_resources_sub_tabs(help_and_support_subtabs, cname)
      options = {
        is_active_hash: (cname == 'resources'),
        link_label_hash: _Resources,
        has_partial_hash: false,
        render_path_hash: resources_path(src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION, sub_src: EngagementIndex::SideBarSubSrc::MENTORING_COMMUNITY),
        icon_class_hash: "fa-book"
      }
      set_sub_tab_values(help_and_support_subtabs, TabConfiguration::Tab::SubTabLinks::RESOURCES, options)
    end

    def set_support_sub_tabs(help_and_support_subtabs)
      options = {
        is_active_hash: false,
        has_partial_hash: true,
        render_path_hash: "common/support"
      }
      set_sub_tab_values(help_and_support_subtabs, TabConfiguration::Tab::SubTabLinks::SUPPORT, options)
    end

    def set_contact_admin_sub_tabs(help_and_support_subtabs)
      options = {
        is_active_hash: false,
        has_partial_hash: true,
        render_path_hash: "common/contact_admin"
      }
      set_sub_tab_values(help_and_support_subtabs, TabConfiguration::Tab::SubTabLinks::CONTACT_ADMIN, options)
    end

    def show_support_sub_tabs?
      @current_organization.active? && logged_in_organization? && !working_on_behalf? && is_current_user_or_member_admin?
    end

    def show_contact_admin_sub_tabs?
      @current_organization.active? && logged_in_organization? && program_view? && !current_user.try(&:is_admin?)
    end
  end
end