require_relative './../../../test_helper'

class MenteeActionsTest < ActiveSupport::TestCase

  def test_initialize
    program = programs(:albers)
    mentee_actions_object = MatchReport::MenteeActions.new(programs(:albers), {mentee_view_user_ids: [1, 2]})
    assert_equal program, mentee_actions_object.program
    assert_equal [1, 2], mentee_actions_object.user_ids
  end

  def test_fetch_default_admin_view
    program = programs(:albers)
    assert_equal program.admin_views.where(default_view: AbstractView::DefaultType::MENTEES, program_id: program.id).first, MatchReport::MenteeActions.fetch_default_admin_view(program)
  end

  def test_get_sections_data
    mentee_actions_object = MatchReport::MenteeActions.new(programs(:albers), {})
    mentee_actions_object.expects(:get_applied_filters_data).returns({"sample_profile_question": 3})
    mentee_actions_object.expects(:search_keywords_data).returns([])
    expected_hash = {filter_data: {"sample_profile_question": 3}, search_data: []}
    assert_equal expected_hash, mentee_actions_object.get_section_data
  end

  def test_get_applied_filters_data
    program = programs(:albers)
    mentee_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES)
    user_ids = mentee_view.generate_view("", "",false).to_a
    mentee_actions_object = MatchReport::MenteeActions.new(program, {mentee_view_user_ids: user_ids})
    expected_hash = {profile_questions(:string_q) => 1, profile_questions(:student_multi_choice_q) => 1}
    assert_equal expected_hash, mentee_actions_object.get_applied_filters_data

    user = users(:f_student)
    profile_question = profile_questions(:string_q)
    options = {locale: "de", source: UserSearchActivity::Src::LISTING_PAGE, session_id: "fght4n7sk", profile_question_id: profile_question.id, profile_question_text: profile_question.question_text}
    UserSearchActivity.create_user_search_activity(user, options)
    expected_hash = {profile_questions(:string_q) => 2, profile_questions(:student_multi_choice_q) => 1}
    assert_equal expected_hash, mentee_actions_object.get_applied_filters_data
  end

  def test_search_keywords_data
    mentee_actions_object = MatchReport::MenteeActions.new(programs(:albers), {mentee_view_user_ids: [1, 2]})
    UserSearchActivity.expects(:get_search_keywords).with({program_id: programs(:albers).id, user_id: [1, 2]}).once.returns([{keyword: "sample answer text", count: 3}, {keyword: "hyderabad", count: 1}])
    assert_equal [{keyword: "sample answer text", count: 3}, {keyword: "hyderabad", count: 1}], mentee_actions_object.search_keywords_data
  end
  
end