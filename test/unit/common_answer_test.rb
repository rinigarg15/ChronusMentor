require_relative './../test_helper.rb'

class CommonAnswerTest < ActiveSupport::TestCase
  def test_should_not_create_answer_without_user_and_question
    e = assert_raise(ActiveRecord::RecordInvalid) do
      CommonAnswer.create!
    end

    assert_match("Question can't be blank", e.message)
    assert_match("User can't be blank", e.message)
  end

  def test_should_create_answer
    assert_difference('CommonAnswer.count') do
      CommonAnswer.create!(
        :answer_text => 'hello',
        :common_question => create_common_question, :user => users(:f_student))
    end
  end

  def test_for_question_scope
    q1 = create_common_question
    q2 = create_common_question
    a1 = CommonAnswer.create!(:answer_text => 'hello', :common_question => q1, :user => users(:f_student))
    a2 = CommonAnswer.create!(:answer_text => 'hello', :common_question => q1, :user => users(:f_mentor))
    assert_equal [a1, a2], CommonAnswer.for_question(q1)
    assert CommonAnswer.for_question(q2).empty?
    assert_equal [a1, a2], CommonAnswer.for_question_ids([q1.id])
    assert CommonAnswer.for_question_ids([q2.id]).empty?
    assert_equal CommonAnswer.all, CommonAnswer.for_question_ids(nil)
  end

  def test_should_assign_to_answer
    q = create_common_question(question_type: CommonQuestion::Type::MULTI_CHOICE, question_choices: "A,B,C,D")
    a = CommonAnswer.new(common_question: q)
    a.answer_value = {answer_text: ["B", "C"], question: q}
    assert_equal("B, C", a.answer_text)
    assert_equal("B, C", a.selected_choices_to_str)

    create_common_question(question_type: CommonQuestion::Type::MULTI_CHOICE, question_choices: "A,B,C,D")
    a1 = CommonAnswer.new(common_question: q)
    a1.answer_text = {answer_text: "B, C", question: q, from_import: true}
    assert_equal(["B", "C"], a.answer_value)

    b = CommonAnswer.new(common_question: create_common_question)
    b.answer_value = "Abcdef"
    assert_equal("Abcdef", b.answer_text)

    file_ans = CommonAnswer.new(common_question: create_common_question(question_type: CommonQuestion::Type::FILE))
    file_ans.answer_value = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    assert file_ans.attachment?
    assert_equal("some_file.txt", file_ans.attachment_file_name)
    assert_equal file_ans.attachment, file_ans.answer_value

    multi_line_ans = CommonAnswer.new(common_question: create_common_question(question_type: CommonQuestion::Type::MULTI_STRING))
    multi_line_ans.answer_value = ["I am ", "very good", " boy ", "        "]
    assert_equal("I am\n very good\n boy" , multi_line_ans.answer_text)
  end

  def test_answer_should_be_a_split_up_of_answer_text
    q = create_common_question(question_type: CommonQuestion::Type::MULTI_CHOICE, question_choices: "A,B,C,D")
    a = CommonAnswer.new(common_question: q)
    a.answer_value = {answer_text: "B, C", question: q, from_import: true}
    assert_equal(["B", "C"], a.answer_value)
  end

  def test_answer_should_be_a_split_up_of_answer_text_multi_line
    q = create_common_question(:question_type => CommonQuestion::Type::MULTI_STRING)
    a = CommonAnswer.new(:common_question => q)
    a.answer_text = "B\n C"
    assert_equal(["B", "C"], a.answer_value)
    a.answer_text = nil
    assert_equal([], a.answer_value)
  end

  def test_answer_should_be_answer_text_for_non_multichoice_type_questions
    q = create_common_question
    a = CommonAnswer.new(:common_question => q, :answer_text => 'quit123')
    assert_equal('quit123', a.answer_value)
  end

  def test_should_not_save_an_answer_with_an_invalid_answer_for_single_choice_question
    q = create_common_question(question_choices: "A,B,C", question_type: CommonQuestion::Type::SINGLE_CHOICE)
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, 'contains an invalid choice') do
      CommonAnswer.create!(common_question: q, user: users(:f_student), answer_value: {answer_text: "Zellow", question: q})
    end

    # Do not save empty answer.
    assert_nothing_raised do
      assert_no_difference 'CommonAnswer.count' do
        CommonAnswer.create!(common_question: q, user: users(:f_student), answer_value: {answer_text: "", question: q})
      end
    end
  end

  def test_should_not_save_an_answer_with_an_invalid_answer_for_multi_choice_question
    q = create_common_question(question_choices: "A,B,C", question_type: CommonQuestion::Type::MULTI_CHOICE)
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, 'contains an invalid choice') do
      CommonAnswer.create!(common_question: q, user: users(:f_student), answer_value: {answer_text: ["B", "C", "Zellow"], question: q})
    end

    # Do not save empty answer.
    assert_nothing_raised do
      assert_no_difference 'CommonAnswer.count' do
        CommonAnswer.create!(common_question: q, user: users(:f_student), answer_value: {answer_text: "", question: q})
      end
    end

    # Answer with few choices correct and few wrong.
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, 'contains an invalid choice') do
      CommonAnswer.create!(common_question: q, user: users(:f_student), answer_value: {answer_text: ["B", "hello"], question: q})
    end
  end

  def test_should_not_save_if_answer_is_blank_in_case_required_question
    q = create_common_question(question_choices: "A,B,C", required: 1)
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, "can't be blank") do
      CommonAnswer.create!(common_question: q, user: users(:f_student),  answer_value: {answer_text: "", question: q})
    end

    CommonAnswer.create!(common_question: q, user: users(:f_student), answer_value: {answer_text: "", question: q}, is_draft: true)
  end

  def test_destroy_answer_for_optional_question_if_update_with_empty
    optional_single_q = create_common_question(
      question_type: CommonQuestion::Type::SINGLE_CHOICE, question_choices: "A,B,C")
    optional_multiple_q = create_common_question(
      question_type: CommonQuestion::Type::MULTI_CHOICE, question_choices: "A,B,C")
    optional_string_q = create_common_question(question_type: CommonQuestion::Type::STRING)
    optional_file_q = create_common_question(question_type: CommonQuestion::Type::FILE)
    required_single_q = create_common_question(
      question_type: CommonQuestion::Type::SINGLE_CHOICE, question_choices: "A,B,C", required: 1)
    required_multiple_q = create_common_question(
      question_type: CommonQuestion::Type::MULTI_CHOICE, question_choices: "A,B,C", required: 1)
    required_string_q = create_common_question(question_type: CommonQuestion::Type::STRING, required: 1)
    required_file_q = create_common_question(question_type: CommonQuestion::Type::FILE, required: 1)
    assert_difference 'CommonAnswer.count', 8 do
      @ans_1 = CommonAnswer.create!(common_question: optional_single_q, user: users(:f_student), answer_value: {answer_text: "A", question: optional_single_q})
      @ans_2 = CommonAnswer.create!(common_question: optional_multiple_q, user: users(:f_student), answer_value: {answer_text: "A", question: optional_multiple_q})
      @ans_3 = CommonAnswer.create!(common_question: optional_string_q, user: users(:f_student), answer_text: "A")
      @ans_4 = CommonAnswer.create!(common_question: optional_file_q, user: users(:f_student), attachment: fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'))
      @req_ans_1 = CommonAnswer.create!(common_question: required_single_q, user: users(:f_student), answer_value: {answer_text: "A", question: required_single_q})
      @req_ans_2 = CommonAnswer.create!(common_question: required_multiple_q, user: users(:f_student), answer_value: {answer_text: "A", question: required_multiple_q})
      @req_ans_3 = CommonAnswer.create!(common_question: required_string_q, user: users(:f_student), answer_text: "A")
      @req_ans_4 = CommonAnswer.create!(common_question: required_file_q, user: users(:f_student), attachment: fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'))
    end

    # Should destroy the answers in the following cases
    assert_difference 'CommonAnswer.count', -4 do
      @ans_1.answer_value = ""
      @ans_1.save!
      @ans_2.answer_value = [""]
      @ans_2.save!
      @ans_3.answer_value = ""
      @ans_3.save!
      @ans_4.answer_value = nil
      @ans_4.save!
    end

    assert_no_difference 'CommonAnswer.count' do
      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, "can't be blank") do
        @req_ans_1.answer_value = ""
        @req_ans_1.save!
      end

      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, "can't be blank") do
        @req_ans_2.answer_value = [""]
        @req_ans_2.save!
      end

      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, "can't be blank") do
        @req_ans_3.answer_value = ""
        @req_ans_3.save!
      end

      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :attachment, "can't be blank") do
        @req_ans_4.answer_value = nil
        @req_ans_4.save!
      end
    end

    #Should destroy if the answer is a drafted one
    assert_difference 'CommonAnswer.count', -1 do
      @req_ans_1.is_draft = true
      @req_ans_1.save!
    end
  end

  def test_answer_unanswered
    ans = CommonAnswer.create!(:common_question => create_common_question, :user => users(:f_student))
    assert ans.unanswered?

    ans2 = CommonAnswer.create!(:common_question => create_common_question, :user => users(:f_student), :answer_text => "alsjdad")
    assert !ans2.unanswered?

    file_ans1 = CommonAnswer.create!(
      :common_question => create_common_question(:question_type => CommonQuestion::Type::FILE),
      :user => users(:f_student))
    assert file_ans1.unanswered?

    file_ans2 = CommonAnswer.create!(
      :common_question => create_common_question(:question_type => CommonQuestion::Type::FILE),
      :user => users(:f_student),
      :attachment => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'))
    assert !file_ans2.unanswered?
  end

  def test_should_not_save_blank_answers_for_multiple_choice_questions
    q = create_common_question(question_choices: "A,B,C", question_type: CommonQuestion::Type::MULTI_CHOICE)
    a = CommonAnswer.new(common_question: q, user: users(:f_student))
    a.answer_value = {answer_text: ["A", "B", ""], question: q}
    a.save!
    assert_equal(["A", "B"], a.reload.answer_value)
  end

  def test_answered
    CommonAnswer.destroy_all
    CommonAnswer.create!(:common_question => create_common_question, :user => users(:f_student))
    CommonAnswer.create!(:common_question => create_common_question, :user => users(:f_student), :answer_text => '')
    ans2 = CommonAnswer.create!(:common_question => create_common_question, :user => users(:f_student), :answer_text => "alsjdad")
    CommonAnswer.create!(
      :common_question => create_common_question(:question_type => CommonQuestion::Type::FILE),
      :user => users(:f_student))

    file_ans2 = CommonAnswer.create!(
      :common_question => create_common_question(:question_type => CommonQuestion::Type::FILE),
      :user => users(:f_student),
      :attachment => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'))
    assert_equal [ans2, file_ans2], CommonAnswer.answered
  end

  def test_should_not_create_answer_if_file_size_gt_20mb
    file_question = create_common_question(:question_type => CommonQuestion::Type::FILE)
    assert_no_difference("CommonAnswer.count") do
      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :attachment) do
        file_question.common_answers.create!(
          :user => users(:f_student), :attachment_file_name => 'temp.txt',
          :attachment_file_size => 21.megabytes)
      end
    end
  end

  def test_should_create_answer_with_file
    file_question = create_common_question(:question_type => CommonQuestion::Type::FILE)
    assert_difference("CommonAnswer.count") do
      file_question.common_answers.create!(
        :user => users(:f_student), :attachment_file_name => 'temp.txt',
        :attachment_file_size => 1.megabytes)
    end
  end

  def test_should_create_answer_with_special_characters_in_file_name
    file_ans = CommonAnswer.new(:common_question => create_common_question(:question_type => CommonQuestion::Type::FILE))
    file_ans.answer_value = fixture_file_upload(File.join('files', 'SOMEspecialcharacters@#$%\'123_test.txt'), 'text/text')
    assert_equal "SOMEspecialcharacters123_test.txt" , file_ans.attachment_file_name
  end

  def test_answer_text_not_required_if_file_type
    file_question = create_common_question(
      :question_type => CommonQuestion::Type::FILE, :required => true)

    assert_no_difference("CommonAnswer.count") do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :attachment do
        file_question.common_answers.create!(:user => users(:f_student))
      end
    end

    assert_difference("CommonAnswer.count") do
      assert_nothing_raised do
        file_question.common_answers.create!(
          :user => users(:f_student), :attachment_file_name => 'temp.txt',
          :attachment_file_size => 1.megabytes)
      end
    end
  end

  def test_single_choice_answer_should_successfully_compact_answer_on_changing_question_type_to_multi_choice
    q = create_common_question(:question_choices => "A,B,C", :question_type => CommonQuestion::Type::SINGLE_CHOICE)
    a = CommonAnswer.new(:common_question => q, :user => users(:f_student))
    a.answer_value = {answer_text: "A", question: q}
    a.save!
    assert_equal("A", a.reload.answer_value)

    q.question_type = CommonQuestion::Type::MULTI_CHOICE
    q.save!
    assert_equal(["A"], a.reload.answer_value)
  end

  def test_single_choice_answer_compacting
    q = create_common_question(:question_choices => "A,B,C", :question_type => CommonQuestion::Type::SINGLE_CHOICE)
    a = CommonAnswer.new(:common_question => q, :user => users(:f_student))
    a.answer_value = {answer_text: "A", question: q}
    a.save!
    assert_equal("A", a.reload.answer_value)

    # By adding a choice, the existing answer should not change
    assert_difference("CommonAnswer.count", 0) do
      q.question_choices.create!(text: "Z", position: 4, is_other: false)
    end
    assert_equal("A", a.reload.answer_value)

    # When removing a choice, the existing answer should be deleted
    assert_difference("CommonAnswer.count", -1) do
      q.question_choices.first.destroy
      q.question_choices.create!(text: "D", position: 5, is_other: false)
    end
  end

  def test_answer_text_should_always_be_stored_in_english_but_to_be_rendered_in_current_locale
    question = common_questions(:multi_choice_common_q)
    answer = CommonAnswer.new(:common_question => question, :user => users(:f_student))
    answer.answer_value = {answer_text: ["Stand", "Walk"], question: question}
    answer.save!
    assert_equal "Stand, Walk", answer.answer_text
    assert_equal "Stand, Walk", answer.selected_choices_to_str
    run_in_another_locale(:'fr-CA') do
      assert_equal "Supporter, Marcher", answer.selected_choices_to_str
    end

    question = common_questions(:single_choice_common_q)
    answer = CommonAnswer.new(:common_question => question, :user => users(:f_student))
    answer.answer_value = {answer_text: "Computer", question: question}
    answer.save!
    assert_equal "Computer", answer.answer_text
    assert_equal "Computer", answer.selected_choices_to_str
    run_in_another_locale(:'fr-CA') do
      assert_equal "Ordinateur", answer.selected_choices_to_str
    end

    question = common_questions(:rating_common_q)
    answer = CommonAnswer.create!(:common_question => question, :user => users(:f_student), :answer_value =>{answer_text: "Bad", question: question})
    assert_equal "Bad", answer.answer_value
    run_in_another_locale(:'fr-CA') do
      assert_equal "Mauvais", answer.answer_value
    end
  end

  def test_answer_text_created_in_current_locale_should_also_get_stored_in_english
    question = common_questions(:multi_choice_common_q)
    answer = ""

    run_in_another_locale(:'fr-CA') do
      answer = CommonAnswer.create!(:common_question => question, :user => users(:f_student), :answer_value => {answer_text: ["Supporter", "Marcher"], question: question})
    end
    assert_equal "Stand, Walk", answer.selected_choices_to_str
  end

  def test_answer_text_overrides_should_work_fine_for_other_field_types_in_another_languages
    optional_string_q = create_common_question(:question_type => CommonQuestion::Type::STRING)
    answer = CommonAnswer.create!(:common_question => optional_string_q, :user => users(:f_student), :answer_text => "A")
    answer.destroy
    run_in_another_locale(:'fr-CA') do
      assert_nothing_raised do
        answer = CommonAnswer.create!(:common_question => optional_string_q, :user => users(:f_student), :answer_text => "French A")
      end
    end
  end

  def test_multi_choice_answer_compacting
    q = create_common_question(:question_choices => "A,B,C", :question_type => CommonQuestion::Type::MULTI_CHOICE)
    a = CommonAnswer.new(:common_question => q, :user => users(:f_student))
    a.answer_value = {answer_text: ["A", "B"], question: q}
    a.save!
    assert_equal(["A", "B"], a.reload.answer_value)

    # By adding a choice, the existing answer should not change
    assert_difference("CommonAnswer.count", 0) do
      q.question_choices.create!(text: "Z", position: 4, is_other: false)
      q.question_choices.create!(text: "Y", position: 5, is_other: false)
    end
    assert_equal(["A", "B"], a.reload.answer_value)

    # When removing a choice, the existing answer choice should be deleted
    assert_difference("CommonAnswer.count", 0) do
      q.question_choices.first.destroy
    end
    assert_equal(["B"], a.reload.answer_value)

    # When removing all answer choices, the existing answer should be deleted
    assert_difference("CommonAnswer.count", -1) do
      q.question_choices.destroy_all
      "L,M,N".split(",") do |text|
        q.question_choices.create!(text: text)
      end
    end
  end

end
