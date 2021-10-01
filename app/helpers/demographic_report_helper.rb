module DemographicReportHelper

  def get_demographic_report_table_header(report_view_columns, sort_param, sort_order)
    table_header = "".html_safe
    custom_term_options = {
      :Mentors => _Mentors,
      :Mentees => _Mentees,
      :Employees => _Employees
    }
    report_view_columns.each do |column|
      html_options = {}
      html_options[:class] = ""
      key = column.column_key
      order = (sort_param == key) ? sort_order : "both"
      sort_options = {
        :class => "sort_#{order} pointer cjs_sortable_column",
        :id => "sort_by_#{key}",
        :data => {
          :sort_param => key,
          :url => demographic_report_path(format: :js)
        }
      }
      html_options.merge!(sort_options)
      if ReportViewColumn::DemographicReport.columns_with_counts.include?(key)
        html_options[:class] += " text-center"
      end
      column_header = column.get_title(ReportViewColumn::ReportType::DEMOGRAPHIC_REPORT, custom_term_options)
      table_header += content_tag(:th, column_header, html_options)
    end
    return table_header
  end

  def get_demographic_report_table_row(country, locations, report_view_columns, index, city = false)
    table_row = "".html_safe
    report_view_columns.each do |column|
      html_options = {}
      key = column.column_key
      column_value = if key == ReportViewColumn::DemographicReport::Key::COUNTRY
        city ? content_tag(:span, (country.present? ? country : "display_string.Others".translate), :class => ((country.present? ?  "" : "dim ") << "has-before-2")) : (link_to(country, "javascript:void(0)", :class => "cjs_country_field no-underline", data: {"country-index" => index}))
      elsif aggregate_function = ReportViewColumn::DemographicReport::Key::AGGREGATION[key]
        locations[country].sum(&aggregate_function)
      end
      if ReportViewColumn::DemographicReport.columns_with_counts.include?(key)
        html_options.merge!(:class => "text-center")
      end
      table_row += content_tag(:td, column_value, html_options)
    end
    return table_row.html_safe
  end

end