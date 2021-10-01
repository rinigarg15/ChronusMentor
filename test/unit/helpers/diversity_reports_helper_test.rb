require_relative './../../test_helper.rb'

class DiversityReportsHelperTest < ActionView::TestCase
  def test_get_comparison_type_options
    assert_equal [[DiversityReport::ComparisonType::PARTICIPANT, "feature.diversity_reports.label.participant".translate], [DiversityReport::ComparisonType::TIME_PERIOD, "feature.diversity_reports.label.time_period_v1".translate]], get_comparison_type_options
  end

  def test_get_display_name
    diversity_report = DiversityReport.new
    profile_question = ProfileQuestion.first
    diversity_report.profile_question = profile_question
    assert_equal "Diversity by #{profile_question.question_text}", get_display_name(diversity_report)
    diversity_report.name = "abc"
    assert_equal "abc", get_display_name(diversity_report)
  end

  def test_get_daterange_values
    start_date = Date.new(2018,9,10)
    end_date = Date.new(2018,9,20)
    assert_equal_hash({start: start_date, end: end_date}, get_daterange_values(start_date, end_date))
  end

  def test_get_html_id_suffix
    assert_equal "diversity_report_time_range_23", get_html_id_suffix(DiversityReport.new(id: 23))
  end

  def test_get_engagement_diversity_text
    assert_equal "<span class=\"font-600 big text-navy\">2%</span> of all the engagements had participants across different 'name'", get_engagement_diversity_text(2, "name")
  end
end