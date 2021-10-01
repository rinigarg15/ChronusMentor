require_relative './../../test_helper.rb'

class MatchReportTest < ActiveSupport::TestCase

  def test_initialize
    program = programs(:albers)
    current_time = Time.now
    match_report = nil
    MatchReport.any_instance.expects(:get_section_data).with(MatchReport::Sections::DefaultSections, program).returns("Default Sections Data")
    Timecop.freeze(current_time) do
      match_report = MatchReport::new(program)
    end
    assert_equal "Default Sections Data", match_report.default_sections_data
    assert_equal MatchReport::Sections::NonDefaultSections, match_report.non_default_sections
    assert_equal program, match_report.program
  end


  def test_get_section_data
    program = programs(:albers)
    match_report = MatchReport::new(program)
    MatchReport::MentorDistribution.expects(:new).with(program).returns("MentorDistribution data")
    MatchReport::MenteeActions.expects(:new).with(program).returns("MenteeActions data")
    data = match_report.get_section_data(MatchReport::Sections::NonDefaultSections, program)
    assert_equal [{MatchReport::Sections::MentorDistribution=>"MentorDistribution data"}, {MatchReport::Sections::MenteeActions=>"MenteeActions data"}], data
  end

  def test_get_non_default_sections_to_show
    program = programs(:albers)
    match_report = MatchReport::new(program)
    program.expects(:career_based_self_match_or_flash?).returns(false)
    assert_equal [MatchReport::Sections::MentorDistribution], match_report.get_non_default_sections_to_show(program)
    program.expects(:career_based_self_match_or_flash?).returns(true)
    assert_equal [MatchReport::Sections::MentorDistribution, MatchReport::Sections::MenteeActions], match_report.get_non_default_sections_to_show(program)
  end

end