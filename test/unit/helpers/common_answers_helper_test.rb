require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/common_answers_helper"

class CommonAnswersHelperTest < ActionView::TestCase
  include CommonQuestionsHelper

  def setup
    super
    helper_setup
  end

  def test_edit_text_field_common_answer
    q = create_common_question
    ans_text = "Answer"
    answer = CommonAnswer.create!(:user => users(:f_mentor), :common_question => q, :answer_text => ans_text)
    set_response_text(edit_text_field_common_answer(answer))
    assert_select "textarea[name=?]", "common_answers[#{q.id}]", ans_text
  end

  def test_edit_string_field_common_answer
    q = create_common_question
    ans_text = "Answer"
    answer = CommonAnswer.create!(:user => users(:f_mentor), :common_question => q, :answer_text => ans_text)
    set_response_text(edit_string_field_common_answer(answer))
    assert_select "input[type=text][name=?][value=?]", "common_answers[#{q.id}]", ans_text
  end

  def test_edit_single_choice_field_type
    q_choices = ["Test", "Answer", "Question"]
    q = create_common_question(question_type: CommonQuestion::Type::SINGLE_CHOICE, question_choices: q_choices, allow_other_option: true)
    ans_text = "Answer"
    answer = CommonAnswer.create!(user: users(:f_mentor), common_question: q, answer_value: {answer_text: ans_text, question: q})
    set_response_text(edit_single_choice_field_type(answer))
    # The answer text should be selected
    assert_select "select[name=?]", "common_answers[#{q.id}]" do
      assert_select 'option[value=""]', :text => "Select..."
      assert_select "option[value=?]", q_choices[0]
      assert_select "option[value=?][selected=selected]", q_choices[1]
      assert_select "option[value=?]", q_choices[2]
      assert_select 'option[value="other"]', :text => "Other..."
    end
  end

  def test_edit_multi_choice_field_type
    q_choices = ["Test", "Answer", "Question", "Another", "Again", "Final", "Exam", "Profile", "Strawberry", "Mango"]
    q = create_common_question(:question_type => CommonQuestion::Type::MULTI_CHOICE, :question_choices => q_choices, :allow_other_option => true)
		# The answer contains 2 valid choices.
    ans_text = "Answer, Another"
    answer = CommonAnswer.create!(user: users(:f_mentor), common_question: q, answer_value: {answer_text: ans_text, question: q})
    set_response_text(edit_multi_choice_field_type(answer))

    # Dynamic text filter
    assert_select "div.cui_find_and_select_item" do
      assert_select "input#quick_find_common_answer_#{q.id}", :name => "quick_find", :type => "text"
      assert_select "div.input-group-btn" do
        assert_select "button.dropdown-toggle", :text => "Show"
        assert_select "a.show_selected", :text => "Selected"
        assert_select "a", :text => "All"
      end
    end

		# The two answers should be checked. The rest, unchecked.
    control_name = "common_answers[#{q.id}][]"
    assert_select "div#common_answers_#{q.id}" do
      assert_select "input[type=checkbox][name=?][value=?][checked=checked]", control_name, 'Answer'
      assert_select "input[type=checkbox][name=?][value=?][checked=checked]", control_name, 'Another'
      assert_select "input[type=checkbox][name=?][value=?]", control_name, 'Test'
      assert_select "input[type=checkbox][name=?][value=?]", control_name, 'Question'
      assert_select "input[type=checkbox][name=?][value=?]", control_name, 'other'
      assert_select "input[type=hidden][name=?]", control_name
    end
  end

  def test_edit_multi_choice_field_type_for_an_answer_with_no_answer_text
    q_choices = ["Test", "Answer", "Question", "Another"]
    q = create_common_question(:question_type => CommonQuestion::Type::MULTI_CHOICE, :question_choices => q_choices)
    answer = CommonAnswer.new(:common_question => q)
    set_response_text(edit_multi_choice_field_type(answer))
    control_name = "common_answers[#{q.id}][]"
		# No field should be checked
    assert_select "input[type=checkbox][name=?][checked=checked]", control_name, 0
    assert_no_select "div.find_and_select_item"
  end

  def test_edit_other_option_type
    q_choices = ["Test", "Answer", "Question"]
    q = create_common_question(:question_type => CommonQuestion::Type::SINGLE_CHOICE, :question_choices => q_choices, :allow_other_option => true)
    ans_text = "other"
    answer = CommonAnswer.create!(user: users(:f_mentor), common_question: q, answer_value: {answer_text: ans_text, question: q})
    set_response_text(edit_single_choice_field_type(answer))

    assert_select "select[name=?]", "common_answers[#{q.id}]" do
      assert_select 'option[value=""]', :text => "Select..."
      assert_select "option[value=?]", q_choices[0]
      assert_select "option[value=?]", q_choices[1]
      assert_select "option[value=?]", q_choices[2]
      assert_select 'option[value="other"][selected=selected]', :text => "Other..."
    end
    assert_select "input[type=text][value=?][id=?]","other","preview_#{q.id}"
  end

  def test_edit_multi_line_field_type
    q = create_common_question(:question_type => CommonQuestion::Type::MULTI_STRING)
		# The answer cotains 2 valid choices.
    ans_text = "Answer\n Another\n text"
    answer = CommonAnswer.create!(:user => users(:f_mentor), :common_question => q, :answer_text => ans_text)
    set_response_text(edit_multi_string_field_common_answer(answer))

		# The two answers should be checked. The rest, unchecked.
    control_name = "common_answers[#{q.id}][]"
    assert_select "div#common_answers_#{q.id}.multi_line" do
      assert_select "input[type=text][name=?][value=?]", control_name, 'Answer'
      assert_select "script", /MultiLineAnswer.addAnswer.*add_new_#{q.id}.*Another/
      assert_select "script", /MultiLineAnswer.addAnswer.*add_new_#{q.id}.*text/
    end
  end

  def test_edit_file_field_type_with_answer
    q = create_common_question(:question_type => CommonQuestion::Type::FILE)
    answer = SurveyAnswer.new({
      :common_question => q,
      :attachment_file_name => 'temp.txt',
      :attachment_file_size => 1.megabytes
    })
    set_response_text(edit_file_type(answer))
    assert_select 'small.ans_file', :text => "(edit)"
    assert_select "input[id=?][type=file][name=?]", "common_answers_#{q.id}", "survey_answers[#{q.id}]"
  end

  def test_edit_file_field_type_without_answer
    q = create_common_question(:question_type => CommonQuestion::Type::FILE)
    answer = SurveyAnswer.new(:common_question => q)
    set_response_text(edit_file_type(answer))
    assert_no_select "small.ans_file"
    assert_select "input[id=?][type=file][name=?]", "common_answers_#{q.id}", "survey_answers[#{q.id}]"
 end

  def test_formatted_common_answer
    assert_equal "<i class=\"text-muted\">Not specified</i>", formatted_common_answer(nil, nil)

		# All fields except Multi choice should return answer_text
    answer = CommonAnswer.new(common_question: create_common_question(question_type: CommonQuestion::Type::STRING), answer_text: "This text")
    assert_equal("This text", formatted_common_answer(answer))

    answer = CommonAnswer.new(common_question: create_common_question(question_type: CommonQuestion::Type::TEXT), answer_text: "That text")
    assert_equal("<p>That text</p>", formatted_common_answer(answer))

    answer = CommonAnswer.new(common_question: (q = create_common_question(question_type: CommonQuestion::Type::SINGLE_CHOICE, question_choices: "Jk, LO, Lk", allow_other_option: true)), answer_value: {answer_text: "Again this", question: q})
    assert_equal("Again this", formatted_common_answer(answer))

    # Multi choice should have a whitespace after comma
    answer = CommonAnswer.new(common_question: (q = create_common_question(question_type: CommonQuestion::Type::MULTI_CHOICE, question_choices: "Jk, LO, Lk", allow_other_option: true)))
    answer.answer_value = {answer_text: %w(This that forever), question: q}
    assert_equal("<ul><li>This</li><li>that</li><li>forever</li></ul>", formatted_common_answer(answer))

    answer.answer_choices.destroy_all
    answer.answer_value = {answer_text: %w(This), question: q}
    assert_equal("This", formatted_common_answer(answer))

    # Multi line should have a whitespace after comma
    answer = CommonAnswer.new(:common_question => create_common_question(:question_type => CommonQuestion::Type::MULTI_STRING))
    answer.answer_value = %w(This that forever)
    assert_equal("<ul><li>This</li><li>that</li><li>forever</li></ul>", formatted_common_answer(answer))

    answer.answer_value = %w(This)
    assert_equal("This", formatted_common_answer(answer))

    file_ans = CommonAnswer.new(:common_question => create_common_question(:question_type => CommonQuestion::Type::FILE))
    file_ans.answer_value = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    text = formatted_common_answer(file_ans)
    set_response_text(text)
    assert_match file_ans.attachment_file_name, text
    assert_select 'small.ans_file' do
      assert_select 'a[href=?]', file_ans.attachment.url, :text => 'download'
    end
  end

  def test_display_answer_type
    string_answer = create_common_answer(:common_question => create_common_question(:question_type => CommonQuestion::Type::STRING))
    text_answer = create_common_answer(:common_question => create_common_question(:question_type => CommonQuestion::Type::TEXT))
    single_choice_answer = create_common_answer(common_question: (q = create_common_question(question_type: CommonQuestion::Type::SINGLE_CHOICE, question_choices: "A,B,C")), answer_value: {answer_text: "A", question: q})
    multi_choice_answer = create_common_answer(common_question: (q = create_common_question(question_type: CommonQuestion::Type::MULTI_CHOICE, question_choices: "A,B,C")), answer_value: {answer_text: "A", question: q})

    assert_equal(edit_string_field_common_answer(string_answer), edit_common_answer_field(string_answer))
    assert_equal(edit_text_field_common_answer(text_answer), edit_common_answer_field(text_answer))
    assert_equal(edit_single_choice_field_type(single_choice_answer), edit_common_answer_field(single_choice_answer))
    assert_equal(edit_multi_choice_field_type(multi_choice_answer), edit_common_answer_field(multi_choice_answer))
  end

  def test_edit_common_answer_field_matrix_rating
    q = surveys(:progress_report).survey_questions.new(:question_type => CommonQuestion::Type::MATRIX_RATING, :matrix_setting => CommonQuestion::MatrixSetting::FORCED_RANKING, :program_id => programs(:no_mentor_request_program).id, :question_text => "Matrix Question")
    ["Bad","Average","Good"].each_with_index{|text, i| q.question_choices.build(text: text, position: i+1, ref_obj: q)}
    q.row_choices_for_matrix_question = "Ability,Confidence,Talent"
    q.create_survey_question
    q.save
    
    a = create_survey_answer
    a.survey_question = q
    a.save

    set_response_text(edit_common_answer_field(a, q, {:matrix_question_answers_map => {}, :mobile_view => false}))

    assert_select "table.cjs_matrix_rating_container" do
      assert_select "input[type=radio]", 9
    end
  end

  def test_common_answer_label
    q = create_common_question(:question_text => "Q1")
    assert_equal "<label class=\"control-label \" for=\"common_answers_#{q.id}\">Q1</label>", common_answer_label(q)

    q = create_common_question(:question_text => "Q1", :required => 1)
    assert_equal "<label class=\"control-label \" for=\"common_answers_#{q.id}\">Q1 <abbr title=\"required\">*<\/abbr></label>", common_answer_label(q)

    q_choices = ["Test", "Answer", "Question"]
    q = create_common_question(:question_text => "Q1", :required => 1, :question_type => CommonQuestion::Type::MULTI_CHOICE, :question_choices => q_choices)
    assert_equal "<label class=\"control-label false-label m-b-xs \">Q1 <abbr title=\"required\">*<\/abbr></label>", common_answer_label(q)
  end

  def test_answer_field_prefix
    common_answer = create_common_answer
    assert_equal 'common_answers', answer_field_prefix(common_answer)
    survey_answer = create_survey_answer
    assert_equal 'survey_answers', answer_field_prefix(survey_answer)
    feedback_answer = Feedback::Answer.new
    assert_equal 'feedback_answers', answer_field_prefix(feedback_answer)
  end
  
  def test_edit_rating_scale_hidden_field
    q_choices = "Strongly Agree, Agree, Disagree"
    q = create_survey_question(:question_type => CommonQuestion::Type::RATING_SCALE, :question_choices => q_choices)
    answer = SurveyAnswer.new(:user => users(:f_mentor), :common_question => q, answer_value: {answer_text: "Strongly Agree", question: q})
    set_response_text(edit_rating_scale_type(answer))
    assert_select "div.ratings_wrapper" do
      assert_select "input#survey_answers_#{q.id}[type=hidden]"
      assert_select "label.radio", "Strongly Agree" do
        assert_select "input#common_answers_#{q.id}_strongly_agree[type=radio][checked=checked]"
      end
      assert_select "label.radio", "Agree" do
        assert_select "input#common_answers_#{q.id}_agree[type=radio]"
      end
      assert_select "label.radio", "Disagree" do
        assert_select "input#common_answers_#{q.id}_disagree[type=radio]"
      end
    end
  end

  private
  def create_common_answer(opts = {})
    question = opts[:common_question] || create_common_question
    answer_text = opts[:answer_text] || "Random answer"
    user = opts[:user] || users(:f_student)

    CommonAnswer.create!(:user => user, :answer_text => answer_text,
      :common_question => question)
  end
end
