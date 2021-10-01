require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/common_questions_helper"

class CommonQuestionsHelperTest < ActionView::TestCase
  
  def setup
    super
    helper_setup
  end

  def test_preview_common_question_text
    q = create_common_question
    set_response_text(preview_common_question(q))
    assert_select "input[type=text]"
  end

  def test_preview_common_question_textarea
    q = create_common_question(:question_type => CommonQuestion::Type::TEXT)
    set_response_text(preview_common_question(q))
    assert_select "textarea"
  end

  def test_preview_common_question_single_choice
    q_choices = ["Test", "Answer", "Question"]
    q = create_common_question(:question_type => CommonQuestion::Type::SINGLE_CHOICE, :question_choices => q_choices, :allow_other_option => true)
    set_response_text(preview_common_question(q))
    assert_select "select" do
      assert_select "option[value=?]", "Select..."
      assert_select "option[value=?]", q_choices[0]
      assert_select "option[value=?]", q_choices[1]
      assert_select "option[value=?]", q_choices[2]
      assert_select 'option[value=?]', "other"
    end
    assert_no_select "div.find_and_select_item"
    assert_select "input[id=?]", "preview_other_option_#{q.id}"
  end

  def test_preview_common_question_multi_choice
    q_choices = ["Test", "Answer", "Question"]
    q = create_common_question(:question_type => CommonQuestion::Type::MULTI_CHOICE, :question_choices => q_choices, :allow_other_option => true)
    set_response_text(preview_common_question(q))
    assert_select "div.choices_wrapper" do
      assert_select "input[type=checkbox]", 4
    end   
    assert_no_select "div.find_and_select_item"
    assert_select "input[id=?][type='text']", "preview_other_option_#{q.id}"
  end

  def test_preview_common_question_matrix_rating
    q = surveys(:progress_report).survey_questions.new(:question_type => CommonQuestion::Type::MATRIX_RATING, :matrix_setting => CommonQuestion::MatrixSetting::FORCED_RANKING, :program_id => programs(:no_mentor_request_program).id, :question_text => "Matrix Question")
    ["Bad","Average","Good"].each_with_index{|text, i| q.question_choices.build(text: text, position: i+1, ref_obj: q)}
    q.row_choices_for_matrix_question = "Ability,Confidence,Talent"
    q.create_survey_question
    q.save

    set_response_text(preview_common_question(q, {:mobile_view => false}))

    assert_select "table.cjs_matrix_rating_container" do
      assert_select "input[type=radio]", 9
    end
  end

  def test_preview_common_question_file
    q = create_common_question(:question_type => CommonQuestion::Type::FILE)
    set_response_text(preview_common_question(q))
    assert_select "input[type=file]"
  end

  def test_preview_common_question_multi_line
    q = create_common_question(:question_type => CommonQuestion::Type::MULTI_STRING)
    set_response_text(preview_common_question(q))
    assert_select "div#preview_div_#{q.id}.multi_line" do
      assert_select "input[type=text]"
      assert_select "a.add_new_line", :text => "Add more"
    end
  end

  def test_needs_false_label_common_question
    q1 = common_questions(:string_connection_q)
    assert_equal CommonQuestion::Type::STRING, q1.question_type
    q2 = common_questions(:common_questions_3)
    q2.update_attributes(question_type: CommonQuestion::Type::RATING_SCALE)
    assert_equal CommonQuestion::Type::RATING_SCALE, q2.question_type
    q3 = common_questions(:single_choice_connection_q)
    assert_equal CommonQuestion::Type::SINGLE_CHOICE, q3.question_type
    q4 = common_questions(:multi_choice_connection_q)
    assert_equal CommonQuestion::Type::MULTI_CHOICE, q4.question_type
    q5 = create_common_question(:question_type => CommonQuestion::Type::FILE, :question_text => "Resume")
    assert_equal CommonQuestion::Type::FILE, q5.question_type
    q6 = create_common_question(:question_type => CommonQuestion::Type::MULTI_STRING, :question_text => "Phone")
    assert_equal CommonQuestion::Type::MULTI_STRING, q6.question_type
    q7 = common_questions(:common_questions_1)
    assert_equal CommonQuestion::Type::SINGLE_CHOICE, q7.question_type

    assert_false needs_false_label_common_question?(q1)
    assert needs_false_label_common_question?(q2)
    assert_false needs_false_label_common_question?(q3)
    assert needs_false_label_common_question?(q4)
    assert_false needs_false_label_common_question?(q5)
    assert needs_false_label_common_question?(q6)
    assert_false needs_false_label_common_question?(q7)
  end

  def test_preview_and_edit_common_question
    @current_program = programs(:albers)
    program = programs(:albers)
    params.merge!({controller: "survey_questions"})
    editable_question = surveys(:two).survey_questions.first
    content = preview_and_edit_common_question(editable_question)
    assert_match /edit_common_question_#{editable_question.id}/, content

    non_editable_question = program.feedback_survey.survey_questions.find_by(question_mode: CommonQuestion::Mode::EFFECTIVENESS)
    content = preview_and_edit_common_question(non_editable_question)
    assert_no_match /edit_common_question_#{non_editable_question.id}/, content
  end

  def test_get_delete_confirmation_warning
    common_question = SurveyQuestion.find_by(question_type: CommonQuestion::Type::MATRIX_RATING)
    rating_question = common_question.rating_questions.first
    assert_equal "Are you sure you want to delete this question? All user responses for this question, if any, will be lost.", get_delete_confirmation_warning(common_question)
    CommonQuestion.any_instance.stubs(:in_health_report?).returns(true)
    assert_equal "Removing this question will impact the way the health of the program is measured as it contributes to it. Do you want to still remove this question and historical tracking of Program Health Report based on it?", get_delete_confirmation_warning(common_question)
    rating_question.update_attributes!(positive_outcome_options_management_report: [1,2])
    assert_equal "Removing this question will impact the way the health of the program is measured as it contributes to it and will remove it from administrator dashboard. Do you want to still remove this question and historical tracking of Program Health Report and Program Outcomes Report based on it?", get_delete_confirmation_warning(common_question.reload)
    CommonQuestion.any_instance.stubs(:in_health_report?).returns(false)
    assert_equal "Removing this question will remove it from administrator dashboard. Do you want to still remove this question and historical tracking of Program Outcomes Report based on it?", get_delete_confirmation_warning(common_question)
    common_question.update_attributes!(positive_outcome_options: [1,2])
    assert_equal "Removing this question will remove it from administrator dashboard and from the reported positive outcomes section in the Program outcomes report. Do you want to still remove this question and historical tracking of Program Outcomes Report based on it?", get_delete_confirmation_warning(common_question)
    CommonQuestion.any_instance.stubs(:in_health_report?).returns(true)
    assert_equal "Removing this question will impact the way the health of the program is measured as it contributes to it and will remove it from administrator dashboard and from the reported positive outcomes section in the Program outcomes report. Do you want to still remove this question and historical tracking of Program Health Report and Program Outcomes Report based on it?", get_delete_confirmation_warning(common_question)
    rating_question.update_attributes!(positive_outcome_options_management_report: nil)
    assert_equal "Removing this question will impact the way the health of the program is measured as it contributes to it and will remove it from the reported positive outcomes section in the Program outcomes report. Do you want to still remove this question and historical tracking of Program Health Report and Program Outcomes Report based on it?", get_delete_confirmation_warning(common_question.reload)
    CommonQuestion.any_instance.stubs(:in_health_report?).returns(false)
    assert_equal "Removing this question will remove it from the reported positive outcomes section in the Program outcomes report. Do you want to still remove this question and historical tracking of Program Outcomes Report based on it?", get_delete_confirmation_warning(common_question)
  end

  def test_get_checked_and_disabled_summary_question_values
    common_question = common_questions(:string_connection_q)
    summary = summaries(:string_connection_summary_q)
    common_question.stubs(:file_type?).returns(true)
    assert_equal [false, true], get_checked_and_disabled_summary_question_values(common_question, summary)
    
    common_question.stubs(:file_type?).returns(false)
    assert_equal [true, false], get_checked_and_disabled_summary_question_values(common_question, summary)

    common_question = common_questions(:required_string_connection_q)
    summary = summaries(:string_connection_summary_q)
    assert_equal [false, true], get_checked_and_disabled_summary_question_values(common_question, summary)

    common_question = common_questions(:required_string_connection_q)
    summary = nil
    assert_equal [false, false], get_checked_and_disabled_summary_question_values(common_question, summary)
  end

  private

  def _Program
    "Program"
  end

  def _program
    "program"
  end
end
