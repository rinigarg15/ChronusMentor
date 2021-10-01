require_relative './../../test_helper.rb'

class MatchReportHelperTest < ActionView::TestCase
  
  def test_get_match_report_section_settings
    section = MatchReport::Sections::MentorDistribution
    self.stubs(:render).with(partial: "match_reports/mentor_distribution/mentor_distribution_settings", locals: {section: section}).returns('mentor_distribution')
    assert_equal 'mentor_distribution', get_match_report_section_settings(section)
    
    section = MatchReport::Sections::MenteeActions
    self.stubs(:render).with(partial: "match_reports/mentee_actions/mentee_actions_settings", locals: {section: section}).returns('mentee_actions')
    assert_equal 'mentee_actions', get_match_report_section_settings(section)
  end

  def test_get_kendo_options_for_filters
    filters = {profile_questions(:string_q) => 1, profile_questions(:student_multi_choice_q) => 1}
    expected_hash = {
      filterData: [{questionText: "What is your name", count: 1}, {questionText: "What is your hobby", count: 1}],
      fields: { questionText: { type: "string" }, count: { type: "number" } },
      columns: [{ field: "questionText", title: "common_text.Applied_Filters".translate, width: "80%" }, { field: "count", title: "feature.reports.label.count".translate, width: "20%", headerAttributes: { class: "text-center" }, attributes: { class: "text-center" } }],
      perPage: 10,
      scrollable: true,
      sortable: true,
      pageable: true
    }
    assert_equal expected_hash, get_kendo_options_for_filters(filters)
  end

  def test_get_search_keywords_data
    search_keywords = [{keyword: "sample answer text", count: 3}, {keyword: "hyderabad", count: 1}]
    assert_equal [{name: "sample answer text", value: 3}, {name: "hyderabad", value: 1}], get_search_keywords_data(search_keywords)
  end

  def test_get_kendo_options_for_mentee_needs
    discrepancy_data = [{:discrepancy=>15, :student_need_count=>15, :mentor_offer_count=>0, :student_answer_choice=>"Male"}, {:discrepancy=>12, :student_need_count=>14, :mentor_offer_count=>2, :student_answer_choice=>"Female"}]
    program = programs(:albers)
    mc = program.match_configs.create(student_question: role_questions(:single_choice_role_q), mentor_question: role_questions(:single_choice_role_q), operator: MatchConfig::Operator::lt, threshold: 0.1)
    program.reload
    expected_hash = {
      dataSource: get_discrepancy_table_data_match_reports_path(match_config_id: mc.id, format: :json),
      fields: { questionText: { type: "string" }, menteeCount: { type: "number" }},
      column_names: { questionText: "What is your name", menteeCount: "feature.match_report.label.no_of_users".translate(role: _mentees), mentorCount: "feature.match_report.label.no_of_users".translate(role: _mentors), discrepancy: "feature.match_report.label.mentor_gap".translate(Mentor: _Mentor)},
      perPage: MatchReport::MenteeActions::FILTERS_POPUP_LISTING_LIMIT,
      scrollable: true,
      sortable: true,
      pageable: true
    }
    assert_equal expected_hash, get_kendo_options_for_mentee_needs(mc)
  end

  def test_get_current_status_subsections
    program = programs(:albers)
    current_time = Time.now
    graph_data = {first: '10', second: '20', third: '30'}
    Program.any_instance.expects(:set_current_status_graph_data).once.returns(graph_data)
    current_status = nil
    Timecop.freeze(current_time) do
      current_status = MatchReport::CurrentStatus.new(programs(:albers))
    end
    subsections = get_current_status_subsections(program, current_status)
    assert_equal [["Mentees who sent requests", "Number of mentees who have send requests out of total active mentees", "current_status_total_data"], ["Mentees with accepted requests", "Number of mentees whose requests have been accepted out of total mentees who have send request", "current_status_success_data"], ["Mentee match rate", "Number of mentees who were/are connected at least once out of total active mentees", "current_status_result_data"]], subsections

    program.stubs(:is_ongoing_carrer_based_matching_by_admin_alone?).returns(true)
    subsections = get_current_status_subsections(program, current_status)
    assert_equal [["Mentee match rate", "Number of mentees who got connected(past or ongoing) so far out of total active mentees", "current_status_total_data"], ["Drafted mentees", "Number of mentees who are in drafted state out of total active mentees", "current_status_success_data"], ["Never connected mentees", "Number of mentees who never got connected so far out of total current active mentees", "current_status_result_data"]], subsections
  end

  def test_get_current_status_tooltips
    tooltips = get_current_status_tooltips(true)
    expected_hash = {:first=>"Number of mentees who got connected(past or ongoing) so far out of total active mentees", :second=>"Number of mentees who are in drafted state out of total active mentees", :third=>"Number of mentees who never got connected so far out of total current active mentees"}
    assert_equal expected_hash, tooltips
    tooltips = get_current_status_tooltips(false)
    expected_hash = {:first=>"Number of mentees who have send requests out of total active mentees", :second=>"Number of mentees whose requests have been accepted out of total mentees who have send request", :third=>"Number of mentees who were/are connected at least once out of total active mentees"}
    assert_equal expected_hash, tooltips
  end

  private

  def _mentees
    "mentees"
  end

  def _mentors
    "mentors"
  end

  def _Mentees
    "Mentees"
  end

  def _Mentee
    "Mentee"
  end

  def _Mentors
    "Mentors"
  end

  def _Mentor
    "Mentor"
  end

end