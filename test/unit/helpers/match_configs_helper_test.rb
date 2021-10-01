require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/match_configs_helper"

class MatchConfigsHelperTest < ActionView::TestCase
  def setup
    super
    Matching.expects(:perform_program_delta_index_and_refresh).at_least(0)
    @current_program = programs(:albers)
    @mentor_questions = programs(:albers).
      role_questions_for([RoleConstants::MENTOR_NAME], fetch_all: true).
      joins(:profile_question).
      where(profile_questions: { question_type: RoleQuestion::MatchType::MATCH_TYPE_FOR_QUESTION_TYPE.keys })
    prof_q1 = create_profile_question(:organization => programs(:org_primary))
    prof_q2 = create_profile_question(:organization => programs(:org_primary))
    prof_q3 = create_profile_question(:organization => programs(:org_primary), question_type: ProfileQuestion::Type::NAME)
    @student_questions = [
      create_role_question(:profile_question => prof_q1, :role_names => [RoleConstants::STUDENT_NAME]),
      create_role_question(:profile_question => prof_q2, :role_names => [RoleConstants::STUDENT_NAME]),
      create_role_question(:profile_question => prof_q3, :role_names => [RoleConstants::STUDENT_NAME])
    ]
    make_question_admin_only_editable_and_viewable
    programs(:albers).match_configs.destroy_all
    @matchable_pair = MatchConfig.create!(
      :program => programs(:albers),
      :mentor_question => role_questions(:string_role_q),
      :student_question => @student_questions.first,
      :weight => 0.3
    )

    programs(:albers).reload
  end

  def test_mentor_question_form_column
    text = mentor_question_form_column(@matchable_pair)
    set_response_text text
    assert_select 'select[name=?]', 'match_config[mentor_question_id]' do
      @mentor_questions.each do |mentor_q|
        if mentor_q == @matchable_pair.mentor_question
          assert_select "option[value=\"#{mentor_q.id}\"][selected=selected]", :text => mentor_q.question_text
        else
          assert_select "option[value=\"#{mentor_q.id}\"]", :text => mentor_q.question_text
        end
      end
    end
  end

  def test_mentor_question_form_column_for_supplementary_pair
    text = mentor_question_form_column(nil, label: "supplementary_matching_pair[mentor_role_question_id]", supplementary_scope: true)
    set_response_text text
    assert_select 'select[name=?]', 'supplementary_matching_pair[mentor_role_question_id]'
    assert_match profile_questions(:publication_q).question_text, text
    assert_match profile_questions(:manager_q).question_text, text

    text = mentor_question_form_column(nil, label: "supplementary_matching_pair[mentor_role_question_id]", supplementary_scope: false)
    set_response_text text
    assert_no_match profile_questions(:publication_q).question_text, text
    assert_no_match profile_questions(:manager_q).question_text, text
  end

  def test_mentor_question_form_column_new_match_config
    text = mentor_question_form_column(MatchConfig.new)
    set_response_text text
    assert_select "select[name=?]", 'match_config[mentor_question_id]' do
      @mentor_questions.each do |mentor_q|
        assert_select "option[value=\"#{mentor_q.id}\"]", :text => mentor_q.question_text
      end
    end
  end

  def test_student_question_form_column
    text = student_question_form_column(@matchable_pair)
    set_response_text text
    assert_select 'select[name=?]', 'match_config[student_question_id]' do
      assert_select "option[value='#{@student_questions[0].id}'][selected=selected]", :text => @student_questions[0].question_text
      assert_select "option[value='#{@student_questions[1].id}']", :text => @student_questions[1].question_text
      assert_no_select "option[value='#{@student_questions[2].id}']"
    end
  end

  def test_student_question_form_column_for_supplementary_pair
    publication_question = profile_questions(:publication_q)
    create_role_question(:profile_question => publication_question, :role_names => [RoleConstants::STUDENT_NAME])
    text = student_question_form_column(nil, label: "supplementary_matching_pair[student_role_question_id]", supplementary_scope: true)
    set_response_text text
    assert_select 'select[name=?]', 'supplementary_matching_pair[student_role_question_id]'
    assert_match publication_question.question_text, text

    text = student_question_form_column(nil, label: "supplementary_matching_pair[student_role_question_id]", supplementary_scope: false)
    set_response_text text
    assert_no_match publication_question.question_text, text
  end

  def test_student_question_form_column_new_match_config
    text = student_question_form_column(MatchConfig.new)
    set_response_text text
    assert_select 'select[name=?]', 'match_config[student_question_id]' do
      @student_questions[0,2].each do |student_q|
        assert_select "option[value=\"#{student_q.id}\"]", :text => student_q.question_text
      end
    end
  end
  
  def test_weight_form_column
    @matchable_pair.weight = 0.4
    text = weight_form_column(@matchable_pair)
    set_response_text text
    assert_select 'select[name=?]', 'match_config[weight]' do
      weight_values = %w[1.00 0.90 0.80 0.70 0.60 0.50 0.40 0.30 0.20 0.10 0.00 -0.10 -0.20 -0.30 -0.40 -0.50 -0.60 -0.70 -0.80 -0.90 -1.00]
      weight_values.each do |weight|
        if weight == ('%.2f' % @matchable_pair.weight)
          assert_select "option[value=\"#{weight}\"][selected=selected]", text: weight
        else
          assert_select "option[value=\"#{weight}\"]", text: weight
        end
      end
    end
  end

  private

  def make_question_admin_only_editable_and_viewable    
    [role_questions(:string_role_q), @student_questions.first].each do |role_question|
      role_question.admin_only_editable = true
      role_question.private = RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE
      role_question.save!
    end
  end
end
