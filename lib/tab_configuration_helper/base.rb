module TabConfigurationHelper
  module Base
    include HelpAndSupportTabConfigurationHelper
    include ProgramTabConfigurationHelper
    include MentoringConnectionTabConfigurationHelper
    include OrganizationTabConfigurationHelper
    include MeetingTabConfigurationHelper
    include MentoringCommunityTabConfigurationHelper
    include ReportTabConfigurationHelper
    include MobileTabConfigurationHelper
    include DashboardsTabConfigurationHelper

    private

    def init_sub_tabs
      {
        TabConfiguration::Tab::SubTabKeys::LINKS_LIST => [],
        TabConfiguration::Tab::SubTabKeys::LINK_LABEL_HASH => {},
        TabConfiguration::Tab::SubTabKeys::BADGE_COUNT_HASH => {},
        TabConfiguration::Tab::SubTabKeys::ICON_CLASS_HASH => {},
        TabConfiguration::Tab::SubTabKeys::IS_ACTIVE_HASH => {},
        TabConfiguration::Tab::SubTabKeys::HAS_PARTIAL_HASH => {},
        TabConfiguration::Tab::SubTabKeys::RENDER_PATH_HASH => {}
      }
    end

    def set_sub_tab_values(sub_tabs, sub_tab_link, options)
      sub_tabs = set_link_list_sub_tab(sub_tabs, sub_tab_link)
      sub_tabs = set_sub_tab_link_value(sub_tabs, TabConfiguration::Tab::SubTabKeys::LINK_LABEL_HASH, sub_tab_link, options[:link_label_hash])
      sub_tabs = set_sub_tab_link_value(sub_tabs, TabConfiguration::Tab::SubTabKeys::BADGE_COUNT_HASH, sub_tab_link, options[:badge_count_hash])
      sub_tabs = set_sub_tab_link_value(sub_tabs, TabConfiguration::Tab::SubTabKeys::ICON_CLASS_HASH, sub_tab_link, options[:icon_class_hash])
      sub_tabs = set_sub_tab_link_value(sub_tabs, TabConfiguration::Tab::SubTabKeys::IS_ACTIVE_HASH, sub_tab_link, options[:is_active_hash])
      sub_tabs = set_sub_tab_link_value(sub_tabs, TabConfiguration::Tab::SubTabKeys::HAS_PARTIAL_HASH, sub_tab_link, options[:has_partial_hash])
      set_sub_tab_link_value(sub_tabs, TabConfiguration::Tab::SubTabKeys::RENDER_PATH_HASH, sub_tab_link, options[:render_path_hash])
    end

    def set_link_list_sub_tab(sub_tabs, sub_tab_link)
      return sub_tabs unless sub_tab_link
      sub_tabs[TabConfiguration::Tab::SubTabKeys::LINKS_LIST] << sub_tab_link
      return sub_tabs
    end

    def set_sub_tab_link_value(sub_tabs, sub_tab_key, sub_tab_link, value)
      return sub_tabs unless value
      sub_tabs[sub_tab_key][sub_tab_link] = value
      return sub_tabs
    end

    def pages_to_tabs!
      if can_covert_pages_to_tabs?
        pages = filter_pages(@pages)
        # The about program tab is shown for all non-logged in requests
        pages = add_about_program_tab(pages) unless logged_in_at_current_level?

        pages.each do |page|
          add_tab(page.title, page_path(page, src: "tab"), (controller_name == "pages" && params[:id].to_i == page.id), iconclass: "fa-file")
        end
      end
    end

    def can_covert_pages_to_tabs?
      !logged_in_at_current_level? || working_on_behalf? || !is_user_or_member_admin_in_org_view?
    end

    def is_current_user_or_member_admin?
      ((current_member && current_member.admin?) || (current_user && current_user.is_admin?))
    end

    def is_user_or_member_admin_in_org_view?
      (organization_view? ? current_member.admin? : current_user.is_admin?)
    end

    def add_about_program_tab(pages)
      return [] unless pages.any?
      active = controller_name == "pages" && (action_name == "index" || params[:id] == pages.first.id)
      add_tab(pages.first.title, about_path, active, iconclass: "fa-file")
      return pages[1..-1]
    end
  end
end