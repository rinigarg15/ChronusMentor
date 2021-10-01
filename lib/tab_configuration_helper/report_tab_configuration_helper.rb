module TabConfigurationHelper
  module ReportTabConfigurationHelper
    def configure_report_tab
      return unless current_user.can_view_reports?

      cname = params[:controller]
      aname = params[:action]
      category = params[:category].to_i

      report_subtabs = init_sub_tabs
      report_subtabs = set_health_report_sub_tabs(report_subtabs, cname, aname, category)
      report_subtabs = set_outcomes_report_sub_tabs(report_subtabs, cname, aname, category)
      report_subtabs = set_user_report_sub_tabs(report_subtabs, cname, aname, category)

      add_tab("Reports", '#', false, subtabs: report_subtabs, open_by_default: true, tab_class: "report_tab")
    end

    private

    def set_health_report_sub_tabs(report_subtabs, cname, aname, category)
      options = get_report_sub_tab_options(category, cname, aname, { label_key: "health", icon_class: "fa-medkit", category: Report::Customization::Category::HEALTH })
      set_sub_tab_values(report_subtabs, TabConfiguration::Tab::SubTabLinks::HEALTH_REPORT, options)
    end

    def set_outcomes_report_sub_tabs(report_subtabs, cname, aname, category)
      options = get_report_sub_tab_options(category, cname, aname, { label_key: "outcome", icon_class: "fa-line-chart", category: Report::Customization::Category::OUTCOME })
      set_sub_tab_values(report_subtabs, TabConfiguration::Tab::SubTabLinks::OUTCOME_REPORT, options)
    end

    def set_user_report_sub_tabs(report_subtabs, cname, aname, category)
      options = get_report_sub_tab_options(category, cname, aname, { label_key: "user", icon_class: "fa-user", category: Report::Customization::Category::USER })
      set_sub_tab_values(report_subtabs, TabConfiguration::Tab::SubTabLinks::USER_REPORT, options)
    end

    def get_report_sub_tab_options(current_category, cname, aname, options)
      {
        is_active_hash: (cname == 'reports' && aname == 'categorized' && current_category == options[:category] ),
        link_label_hash: "feature.reports.header.#{options[:label_key]}".translate,
        has_partial_hash: false,
        render_path_hash: categorized_reports_path(category: options[:category], src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION),
        icon_class_hash: options[:icon_class]
      }      
    end
  end
end