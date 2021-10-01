module TabConfigurationHelper
  module DashboardsTabConfigurationHelper
    def configure_dashboards_tab
      return unless @current_organization.global_reports_v3_applicable?(accessing_as_super_admin: super_console?, member: wob_member)
      dashboards_subtabs = init_sub_tabs
      dashboards_subtabs = set_executive_dashboard_sub_tab(dashboards_subtabs, params[:controller])
      add_tab(TabConstants::DASHBOARDS, '#', false, subtabs: dashboards_subtabs, open_by_default: true, tab_class: "cjs-dashboards-tab")
    end

    private

    def set_executive_dashboard_sub_tab(dashboards_subtabs, cname)
      set_sub_tab_values(dashboards_subtabs, TabConfiguration::Tab::SubTabLinks::EXECUTIVE_DASHBOARD, {
        is_active_hash: (cname == 'global_reports'),
        link_label_hash: "tab_constants.sub_tabs.executive_dashboard".translate,
        has_partial_hash: false,
        render_path_hash: global_reports_path,
        icon_class_hash: "fa-line-chart"
      })
    end
  end
end