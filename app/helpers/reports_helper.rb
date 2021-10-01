module ReportsHelper
  include HealthReportsHelper

  def get_activity_report_dropdown_options(role_filters,start_time, end_time)
    actions = [{:label => "feature.reports.label.csv".translate, :url => activity_report_path(:format => :csv, :role_filters => role_filters, :date_range_filter => "#{DateTime.localize(start_time, format: :date_range)} - #{DateTime.localize(end_time, format: :date_range)}"), :icon => "fa fa-file-excel-o"}]
    actions << {:label => "feature.reports.label.pdf".translate, :url => activity_report_path(:format => :pdf, :role_filters => role_filters, :date_range_filter => "#{DateTime.localize(start_time, format: :date_range)} - #{DateTime.localize(end_time, format: :date_range)}"), :icon => "fa fa-file-pdf-o"}
  end

  def get_executive_summary_report_dropdown_options
    actions = [{:label => "feature.reports.label.pdf".translate, :url => executive_summary_path(:format => :pdf), :icon => "fa fa-file-pdf-o"}]
  end

  def get_health_report_dropdown_options
    actions = [{:label => "feature.reports.label.pdf".translate, :url => health_report_path(:format => :pdf), :icon => "fa fa-file-pdf-o"}]
  end

  def get_activity_filter_id(id)
    id.translate.to_s.strip_html.gsub(/(\&gt\;)|(\&lt\;)|[^0-9a-z ]/i, '_').to_html_id + '_'
  end

  def configure_alert_tooltip
    content_tag(:span, get_icon_content("fa fa-info-circle"), :id => "cui_alert_explain") +
    tooltip("cui_alert_explain", "feature.reports.content.info_about_alert".translate(:program => _program, :admin => _admins))
  end

  def get_alert_filter_for_display(metric, alert, index)
    filter_params = alert.filter_params_hash if alert.present? && alert.filter_params.present?
    view = metric.abstract_view
    options = []
    if AbstractView::DefaultViewsCommons.with_filter_for_alert_classes.include?(view.class)
      options = [["common_text.prompt_text.Select".translate, "", {'data-url' => get_options_report_alert_path(format: :js, filter_name: "", view_id: view.id, index: index)}]]
      "FilterUtils::#{view.class.to_s}Filters::FILTERS".constantize.each_pair do |key, filter|
        extra_options = {'data-url' => get_options_report_alert_path(format: :js, filter_name: filter[:value], view_id: view.id, index: index)}
        options << [filter[:name].call(_Mentoring_Connection), filter[:value], extra_options]
      end
    elsif AbstractView::DefaultViewsCommons.no_filter_for_alert_classes.include?(view.class)
      raise "Filter called for non-supported views"
    end
    options_for_select(options, filter_params.try(:[], index).try(:[], :name))
  end

  def get_alert_filter_operator_for_display(view, filter_name, index, filter_operator=nil)
    filter_type = "FilterUtils::#{view.class.to_s}Filters::FILTERS".constantize[filter_name.to_sym][:type] if filter_name.present?
    date_filter_type = (filter_type == FilterUtils::FILTER_TYPE::DateRange)
    case filter_type
      when FilterUtils::FILTER_TYPE::DateRange
        return options_for_select([["common_text.prompt_text.Select".translate, ""], ["feature.reports.content.in_last".translate, FilterUtils::DateRange::IN_LAST], ["feature.reports.content.before_last".translate, FilterUtils::DateRange::BEFORE_LAST]], filter_operator)
      when FilterUtils::FILTER_TYPE::Equals
        return options_for_select([["common_text.prompt_text.Select".translate, ""], ["feature.reports.content.equals".translate, FilterUtils::Equals::EQUALS]], filter_operator)
    end
    options_for_select([["common_text.prompt_text.Select".translate, ""]])
  end

  def filter_metrics_based_on_mentoring_style(program, metrics)
    unless program.calendar_enabled?
      metrics.delete_if{|current_metric| Report::Metric::DefaultMetrics.onetime_mentoring_related_default_metrics.include?(current_metric.default_metric)}
    end
    unless program.ongoing_mentoring_enabled?
      metrics.delete_if{|current_metric| Report::Metric::DefaultMetrics.ongoing_mentoring_related_default_metrics.include?(current_metric.default_metric)}
    else
      metrics.delete_if{|current_metric| current_metric.default_metric == Report::Metric::DefaultMetrics::PENDING_CONNECTION_REQUESTS} if program.matching_by_admin_alone?
    end
    return metrics
  end

  def get_reports_time_filter(daterange_values, options = {})
    date_format = options[:header_date_format] || :abbr_short
    "#{DateTime.localize(daterange_values[:start], format: date_format)} - #{DateTime.localize(daterange_values[:end], format: date_format)}"
  end

  def get_reports_export_options(export_actions)
    if export_actions.size == 1
      data = export_actions.first[:data]||{}
      data.reverse_merge!({url: export_actions.first[:url]})
      link_to(content_tag(:span, get_icon_content("fa fa-download no-margins") + content_tag(:span, export_actions.first[:label], class: "sr-only")), export_actions.first[:url], class: "pull-right m-l-sm m-r-sm big #{export_actions.first[:class]} cjs-reports-export-options", data: data, id: "cjs_reports_export")
    else
      content = "".html_safe
      export_actions.each do |action|
        data = action[:data]||{}
        data.reverse_merge!({url: action[:url]})
        content += content_tag(:li, link_to(action[:label], action[:url], class: "#{action[:class]} cjs-reports-export-options", data: data))
      end
      content_tag(:div, class: "dropdown keep-open pull-right m-l-sm m-r-sm big", id: "cjs_reports_export") do
        link_to(content_tag(:span, get_icon_content("fa fa-download no-margins") + content_tag(:span, "", :class => "caret") + content_tag(:span, "feature.reports.content.export".translate, class: "sr-only")), "javascript:void(0)", class: "dropdown-toggle no-waves", id:"cjs-reports-export-dropdown", data: { toggle: "dropdown" }) +
        content_tag(:ul, class: "dropdown-menu animated fadeIn") do
          content
        end
      end
    end
  end

  def get_report_actions_modal_footer_content
    content_tag(:div, link_to("display_string.Cancel".translate, "javascript:void(0)", :class => "btn btn-white cancel cjs_other_filters_cancel", "data-dismiss" => "modal" ) + link_to("display_string.Reset".translate, "javascript:void(0)", :class => "btn btn-white cjs_other_filters_reset", "data-dismiss" => "modal" ) + submit_tag("display_string.Go".translate, :class => "btn btn-primary cjs-report-other-filters-submit", data: {:disable_with => "display_string.Please_Wait".translate}, "data-dismiss" => "modal" ) , class: "pull-right", id: "other_report_filters_footer")
  end

  def render_reports_from_collection(report_hash, program, options = {})
    report_objects = report_hash[:collection].call(program)
    content = get_safe_string

    if report_objects.present?
      category_has_atleast_one_object = false
      report_objects.each do |object|
        next unless report_hash[:object_condition].call(object) if report_hash[:object_condition].present?
        category_has_atleast_one_object = true
        content += render(partial: "reports/report", locals: { path: report_hash[:path].call(object, options[:default_params]), title: report_hash[:title].call(object), description: report_hash[:description].call(object), icon: report_hash[:icon], survey_type: report_hash[:survey].present? })
      end

      category_has_atleast_one_object ? content : render_category_with_empty_responses
    end
  end

  def render_category_with_empty_responses
    content_tag(:div, "feature.reports.content.empty_surveys".translate, class: "p-md text-center")
  end
end
