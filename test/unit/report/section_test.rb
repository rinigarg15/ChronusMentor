require_relative './../../test_helper.rb'

class Report::SectionTest < ActiveSupport::TestCase
  def test_section_metrics_should_be_fetched_by_positon
    program = programs(:albers)
    view = program.abstract_views.first
    section = program.report_sections.create(title: "Users", description: "All users metrics")
    metric1 = section.metrics.create({title: "pending users", description: "see pending users counts", abstract_view_id: view.id, position: 1})
    metric2 = section.metrics.create({title: "pending users tour", description: "see pending users counts", abstract_view_id: view.id, position: 0})
    assert_equal [metric2, metric1], section.metrics
  end

  def test_non_ongoing_mentoring_related_scope
  	program = programs(:albers)
  	sections = program.report_sections.non_ongoing_mentoring_related
  	Report::Section::DefaultSections.ongoing_mentoring_related_sections.each do |section|
  	  assert_false sections.collect(&:default_section).include?(section)
  	end
  end

  def test_tile
    section = report_sections(:report_section_1)
    assert_nil section.default_section
    assert_nil section.tile

    section.default_section = Report::Section::DefaultSections::RECRUITMENT
    assert_equal DashboardReportSubSection::Tile::ENROLLMENT, section.tile

    section.default_section = Report::Section::DefaultSections::ENGAGEMENT
    assert_equal DashboardReportSubSection::Tile::GROUPS_ACTIVITY, section.tile

    section.default_section = Report::Section::DefaultSections::CONNECTION
    assert_equal DashboardReportSubSection::Tile::MATCHING, section.tile
  end
end