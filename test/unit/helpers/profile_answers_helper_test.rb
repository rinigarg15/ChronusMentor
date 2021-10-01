require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/profile_answers_helper"

class ProfileAnswersHelperTest < ActionView::TestCase

  def setup
    super
    helper_setup
  end

  def test_edit_ordered_options_profile_answer
    create_question(:question_type => ProfileQuestion::Type::ORDERED_OPTIONS, :question_text => "Select Preference", :question_choices => ["alpha", "beta", "gamma"], :options_count => 2)
    q = ProfileQuestion.last
    ans_text = "alpha"
    answer = ProfileAnswer.create!(:ref_obj => users(:f_mentor).member, :profile_question => q, :answer_value => ans_text)
    set_response_text(edit_ordered_options_profile_answer(answer, q))
    assert_select "select[id=?]", "profile_answers_#{q.id}_0" do
      assert_select 'option[value=""]', :text => "Select..."
      assert_select 'option[value=?][selected="selected"]', "alpha"
      assert_select 'option[value=?]', "beta"
      assert_select 'option[value=?]', "gamma"
    end
    assert_select "select[id=?]", "profile_answers_#{q.id}_1" do
      assert_select 'option[value=""]', :text => "Select..."
      assert_select 'option[value=?]', "alpha"
      assert_select 'option[value=?]', "beta"
      assert_select 'option[value=?]', "gamma"
    end
    assert_no_select "select[id=#{"profile_answers_#{q.id}_2"}]"
  end

  # TODO: Add tests for all the possible cases of formatted_profile_answer
  def test_formatted_profile_answer_for_single_choice
    question = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["A", "B", "C", "D"])
    answer = ProfileAnswer.new(:profile_question => question)
    answer.answer_value = "A"
    assert_equal "A", formatted_profile_answer(answer, question)
  end

  def test_formatted_profile_answer_for_single_choice_highlight
    question = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["A", "B", "C", "D"])
    answer = ProfileAnswer.new(:profile_question => question)
    answer.answer_value = "A"
    assert_equal "<strong>A</strong>", formatted_profile_answer(answer, question, common_values: ["a"])
  end

  def test_formatted_profile_answer_for_multiple_choice_with_single_option_selected
    question = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["A", "B", "C", "D"])
    answer = ProfileAnswer.new(:profile_question => question)
    answer.answer_value = "A"
    assert_equal "A", formatted_profile_answer(answer, question)

    run_in_another_locale(:"fr-CA") do 
      question.question_choices.first.update_attributes!(text: "FA")
      question.question_choices.second.update_attributes!(text: "FB")
      question.question_choices.last.update_attributes!(text: "FC")
      assert_equal "FA", formatted_profile_answer(answer, question)
    end
  end

  def test_formatted_profile_answer_for_multiple_choice_highlight
    question = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["A", "B", "C", "D"])
    answer = ProfileAnswer.new(:profile_question => question)
    answer.answer_value = "A"
    assert_equal "<strong>A</strong>", formatted_profile_answer(answer, question, common_values: ["a", "c"])
    answer.answer_value = "B"
    assert_match "<li><strong>A</strong></li><li>B</li>", formatted_profile_answer(answer, question, common_values: ["a", "c"])
  end

  def test_formatted_profile_answer_for_date_type
    question = profile_questions(:date_question)
    answer = question.profile_answers.first
    assert_equal "June 23, 2017", formatted_profile_answer(answer, question)

    run_in_another_locale(:"fr-CA") do
      assert_equal "23 Juin 2017", formatted_profile_answer(answer, question)
    end
  end

  def test_format_date_answer
    question = profile_questions(:date_question)
    answer = question.profile_answers.first

    assert_nil format_date_answer("")
    assert_equal "June 23, 2017", format_date_answer(answer)
    assert_equal "June 23, 2017", format_date_answer(answer.answer_text)

    run_in_another_locale(:"fr-CA") do
      assert_equal "23 Juin 2017", format_date_answer(answer)
      assert_equal "23 Juin 2017", format_date_answer(answer.answer_text)
    end
  end

  def test_edit_date_field_profile_answer
    question = profile_questions(:date_question)
    answer = question.profile_answers.first
    assert_select_helper_function "input#profile_answers_#{question.id}", edit_date_field_profile_answer(answer)
  end

  def test_fetch_highlighted_answers
    other_question = profile_questions(:string_q)
    assert_equal "<strong>A</strong>", fetch_highlighted_answers("A", ["a", "b"])
    assert_equal "<strong>a</strong>", fetch_highlighted_answers("a", ["a", "b"])
    assert_equal "<strong>(Text%^!)</strong>", fetch_highlighted_answers("(Text%^!)", ["(Text%^!)".remove_braces_and_downcase, "b"])
    assert_equal "<strong class=\"some_class\">with_class</strong>", fetch_highlighted_answers("with_class", ["with_class"], class: "some_class")
    # nbsp is a replacement for \s split made in text_distance
    assert_match "<strong>A</strong>&nbsp;<strong>B</strong>&nbsp;C", fetch_highlighted_answers("A B C", ["a", "b"], question_type: ProfileQuestion::Type::STRING, other_question: other_question)
  end

  def test_fetch_formatted_profile_answers_default_name_and_email
    assert fetch_formatted_profile_answers(nil, ProfileQuestion.where(question_type: ProfileQuestion::Type::EMAIL).first, {}, 'immaterial for this test').match(/Not Specified/).present?
    assert fetch_formatted_profile_answers(nil, ProfileQuestion.where(question_type: ProfileQuestion::Type::NAME).first, {}, 'immaterial for this test').match(/Not Specified/).present?
  end

  def test_format_user_answers
    group_view = programs(:albers).group_view
    column = group_view.group_view_columns.first

    profile_questions = programs(:albers).profile_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], {skype: false, default: false})
    exp_ques = profile_questions.select{|q| q.question_type == ProfileQuestion::Type::EXPERIENCE}.first
    edu_ques = profile_questions.select{|q| q.question_type == ProfileQuestion::Type::EDUCATION}.first
    pub_ques = profile_questions.select{|q| q.question_type == ProfileQuestion::Type::PUBLICATION}.first
    manager_ques = profile_questions.select{|q| q.question_type == ProfileQuestion::Type::MANAGER}.first
    file_ques = profile_questions.select{|q| q.question_type == ProfileQuestion::Type::FILE}.first
    str_ques = profile_questions.select{|q| q.question_type == ProfileQuestion::Type::STRING}.first
    
    #For File type
    ProfileAnswersHelperTest.any_instance.expects(:format_filetype_user_answer).times(1)
    column.update_attributes!(:column_key => nil, :profile_question => file_ques, :ref_obj_type => GroupViewColumn::ColumnType::USER)
    format_user_answers([], [], column.profile_question)

    ProfileAnswersHelperTest.any_instance.expects(:format_filetype_user_answer).times(1)
    format_user_answers([], [], file_ques)

    #For Education type
    ProfileAnswersHelperTest.any_instance.expects(:format_education_user_answer).times(1)
    column.update_attributes!(:column_key => nil, :profile_question => edu_ques, :ref_obj_type => GroupViewColumn::ColumnType::USER)
    format_user_answers([], [], column.profile_question)

    ProfileAnswersHelperTest.any_instance.expects(:format_education_user_answer).times(1)
    format_user_answers([], [], edu_ques)

    #For Exp type
    ProfileAnswersHelperTest.any_instance.expects(:format_experience_user_answer).times(1)
    column.update_attributes!(:column_key => nil, :profile_question => exp_ques, :ref_obj_type => GroupViewColumn::ColumnType::USER)
    format_user_answers([], [], column.profile_question)

    ProfileAnswersHelperTest.any_instance.expects(:format_experience_user_answer).times(1)
    format_user_answers([], [], exp_ques)

    #For Publication type
    ProfileAnswersHelperTest.any_instance.expects(:format_publication_user_answer).times(1)
    column.update_attributes!(:column_key => nil, :profile_question => pub_ques, :ref_obj_type => GroupViewColumn::ColumnType::USER)
    format_user_answers([], [], column.profile_question)

    ProfileAnswersHelperTest.any_instance.expects(:format_publication_user_answer).times(1)
    format_user_answers([], [], pub_ques)

    #For Manager type
    ProfileAnswersHelperTest.any_instance.expects(:format_manager_user_answer).times(1)
    column.update_attributes!(:column_key => nil, :profile_question => manager_ques, :ref_obj_type => GroupViewColumn::ColumnType::USER)
    format_user_answers([], [], column.profile_question)

    ProfileAnswersHelperTest.any_instance.expects(:format_manager_user_answer).times(1)
    format_user_answers([], [], manager_ques)

    #For String type
    ProfileAnswersHelperTest.any_instance.expects(:format_simple_user_answer).times(1)
    column.update_attributes!(:column_key => nil, :profile_question => str_ques, :ref_obj_type => GroupViewColumn::ColumnType::USER)
    format_user_answers([], [], column.profile_question)

    ProfileAnswersHelperTest.any_instance.expects(:format_simple_user_answer).times(1)
    format_user_answers([], [], str_ques)
  end

  def test_fetch_help_text
    q1 = profile_questions(:profile_questions_1)

    role_question = q1.role_questions[0]
    role_question.update_attribute(:admin_only_editable, true)
    role_question.reload

    assert_empty fetch_help_text(q1)
    q1.update_attributes(:help_text => "help_text")
    assert_equal "<div class=\"help-block small text-muted\" id=\"question_help_text_1\">help_text</div>", fetch_help_text(q1)
    q1.update_attributes(:help_text => "<b>help text</b> <a href=\"https://www.chronus.com\"> chronus </a>")
    assert_equal "<div class=\"help-block small text-muted\" id=\"question_help_text_1\"><b>help text</b> <a href=\"https://www.chronus.com\"> chronus </a></div>", fetch_help_text(q1)
  end
end