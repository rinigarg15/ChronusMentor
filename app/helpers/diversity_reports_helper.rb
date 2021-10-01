module DiversityReportsHelper
  def get_comparison_type_options
    [
      [DiversityReport::ComparisonType::PARTICIPANT, "feature.diversity_reports.label.participant".translate],
      [DiversityReport::ComparisonType::TIME_PERIOD, "feature.diversity_reports.label.time_period_v1".translate]
    ]
  end

  def get_display_name(diversity_report)
    diversity_report.name.presence || "feature.diversity_reports.display_name_v1".translate(dimension_name: diversity_report.profile_question.question_text)
  end

  def get_daterange_values(start_date, end_date)
    { start: start_date, end: end_date }
  end

  def get_html_id_suffix(diversity_report)
    "diversity_report_time_range_#{diversity_report.id}"
  end

  def get_engagement_diversity_text(engagement_diversity_percentage_number, dimension_name)
    text = content_tag(:span, "#{engagement_diversity_percentage_number}%", class: "font-600 big text-navy")
    'feature.diversity_reports.content.engagement_diversity_html'.translate(percentage_text: text, dimension_name: dimension_name)
  end
end
