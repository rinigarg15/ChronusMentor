require_relative './../test_helper.rb'

class CommonQuestionTest < ActiveSupport::TestCase
  def test_should_have_program_question_text_question_type
    e = assert_raise(ActiveRecord::RecordInvalid) do
      CommonQuestion.create!
    end

    assert_match(/Program can't be blank/, e.message)
    assert_match(/Field Name can't be blank/, e.message)
    assert_match(/Field Type can't be blank/, e.message)
  end

  def test_should_create_common_question
    assert_difference 'CommonQuestion.count' do
      CommonQuestion.create!(
        :program => programs(:albers),
        :question_type => CommonQuestion::Type::STRING,
        :question_text => "Whats your age?")
    end

    q = CommonQuestion.last
    assert_equal "Whats your age?", q.question_text
  end

  def test_should_belong_to_proper_question_type
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :question_type, "is not included in the list") do
      create_common_question(:question_type => 123)
    end
  end

  def test_default_choices
    assert_equal([], create_common_question.default_choices)
    assert_equal(['abc', 'def'], create_common_question(question_type: CommonQuestion::Type::MULTI_CHOICE, question_choices: 'abc,def').default_choices)
    assert_equal(['zyx', 'kqr'], create_common_question(question_type: CommonQuestion::Type::SINGLE_CHOICE, question_choices: 'zyx,kqr').default_choices)
  end

  def test_question_delete_should_destory_the_answers
    mentor_q1 = create_common_question
	  mentor_q2 = create_common_question

    CommonAnswer.create(:common_question => mentor_q1, :user => users(:f_mentor), :answer_text => "abc")
    CommonAnswer.create(:common_question => mentor_q1, :user => users(:robert), :answer_text => "abc")

    CommonAnswer.create(:common_question => mentor_q2, :user => users(:f_mentor), :answer_text => "abc")
    CommonAnswer.create(:common_question => mentor_q2, :user => users(:robert), :answer_text => "abc")

    assert_difference('CommonQuestion.count', -1) do
      assert_difference('CommonAnswer.count', -2) do
        mentor_q1.destroy
      end
    end
  end

  def test_change_of_question_type_should_destroy_all_answers
    mentor_q1 = create_common_question
    mentor_q2 = create_common_question

    CommonAnswer.create(common_question: mentor_q1, user: users(:f_mentor), answer_text: "abc")
    CommonAnswer.create(common_question: mentor_q1, user: users(:robert), answer_text: "abc")

    CommonAnswer.create(common_question: mentor_q2, user: users(:f_mentor), answer_text: "abc")
    CommonAnswer.create(common_question: mentor_q2, user: users(:robert), answer_text: "abc")

    assert_difference('CommonQuestion.count', 0) do
      assert_difference('CommonAnswer.count', -2) do
        mentor_q1.update_attributes!(
          question_type: CommonQuestion::Type::MULTI_CHOICE,
          )
        mentor_q1.question_choices.create!(text: "Abc")
      end
    end
  end

  def test_change_of_question_text_should_not_destroy_answers
    mentor_q = create_common_question

    CommonAnswer.create(:common_question => mentor_q, :user => users(:f_mentor), :answer_text => "abc")
    CommonAnswer.create(:common_question => mentor_q, :user => users(:robert), :answer_text => "abc")
    assert_no_difference('CommonAnswer.count') do
      mentor_q.update_attributes(:question_text => "What is your friends name?")
    end
  end

  def test_choice_based
    q = create_common_question(question_type: CommonQuestion::Type::STRING)
    assert !q.choice_based?

    q = create_common_question(question_type: CommonQuestion::Type::TEXT)
    assert !q.choice_based?

    q = create_common_question(question_type: CommonQuestion::Type::SINGLE_CHOICE, question_choices: "A,B,C")
    assert q.choice_based?

    q = create_common_question(question_type: CommonQuestion::Type::MULTI_CHOICE, question_choices: "A,B,C")
    assert q.choice_based?

    q = surveys(:progress_report).survey_questions.new(question_type: CommonQuestion::Type::MATRIX_RATING, matrix_setting: CommonQuestion::MatrixSetting::FORCED_RANKING, program_id: programs(:no_mentor_request_program).id, question_text: "Matrix Question")
    ["Bad","Average","Good"].each_with_index{|text, pos| q.question_choices.build(text: text, position: pos+1, ref_obj: q)}
    q.row_choices_for_matrix_question = "Ability,Confidence,Talent"
    q.create_survey_question
    q.save

    assert q.choice_based?
    assert q.matrix_question_type?
  end

  def test_single_option_choice_based
    common_question = CommonQuestion.new
    single_option_choice_based_types = [CommonQuestion::Type::SINGLE_CHOICE, CommonQuestion::Type::RATING_SCALE]

    (CommonQuestion::Type.all - single_option_choice_based_types).each do |question_type|
      common_question.question_type = question_type
      assert_false common_question.single_option_choice_based?
    end
    single_option_choice_based_types.each do |question_type|
      common_question.question_type = question_type
      assert common_question.single_option_choice_based?
    end
  end

  def test_choice_but_not_matrix_type
    q = create_common_question(:question_type => CommonQuestion::Type::STRING)
    assert !q.choice_but_not_matrix_type?

    q = create_common_question(:question_type => CommonQuestion::Type::TEXT)
    assert !q.choice_but_not_matrix_type?

    q = create_common_question(:question_type => CommonQuestion::Type::SINGLE_CHOICE, :question_choices => "A,B,C")
    assert q.choice_but_not_matrix_type?

    q = create_common_question(:question_type => CommonQuestion::Type::MULTI_CHOICE, :question_choices => "A,B,C")
    assert q.choice_but_not_matrix_type?

    q = surveys(:progress_report).survey_questions.new(question_type: CommonQuestion::Type::MATRIX_RATING, matrix_setting: CommonQuestion::MatrixSetting::FORCED_RANKING, program_id: programs(:no_mentor_request_program).id, question_text: "Matrix Question")
    ["Bad","Average","Good"].each_with_index{|text, pos| q.question_choices.build(text: text, position: pos+1, ref_obj: q)}
    q.row_choices_for_matrix_question = "Ability,Confidence,Talent"
    q.create_survey_question
    q.save

    assert !q.choice_but_not_matrix_type?
  end

  def test_select_type
    q = create_common_question(:question_type => CommonQuestion::Type::STRING)
    assert !q.select_type?

    q = create_common_question(:question_type => CommonQuestion::Type::TEXT)
    assert !q.select_type?

    q = create_common_question(:question_type => CommonQuestion::Type::SINGLE_CHOICE, :question_choices => "A,B,C")
    assert q.select_type?

    q = create_common_question(:question_type => CommonQuestion::Type::MULTI_CHOICE, :question_choices => "A,B,C")
    assert q.select_type?
  end

  def test_should_sanitize_choices_on_saving
    q = create_common_question(:question_type => CommonQuestion::Type::SINGLE_CHOICE, :question_choices => "A  , \nB ,,,  C ,    \tD")
    assert_equal(%w(A B C D), q.default_choices)

    q2 = create_common_question(:question_type => CommonQuestion::Type::MULTI_CHOICE, :question_choices => "First value ,  Second value ,   THird value  ")
    assert_equal(['First value', 'Second value', 'THird value'], q2.default_choices)
  end

  def test_with_answers_scope
    question = create_common_question
    # Not answered.
    assert !CommonQuestion.with_answers.include?(question)

    CommonAnswer.create!(
      :common_question => question, :user => users(:f_student),
      :answer_text => 'hello')
    # CommonAnswered now.
    assert CommonQuestion.with_answers.include?(question)
  end

  def test_admin_only_scope
    assert_difference 'CommonQuestion.count', 2 do
      CommonQuestion.create!(
        :program => programs(:albers),
        :question_type => CommonQuestion::Type::STRING,
        :question_text => "Question 1 text",
        :is_admin_only => true)

      CommonQuestion.create!(
        :program => programs(:albers),
        :question_type => CommonQuestion::Type::STRING,
        :question_text => "Question 2 text",
        :is_admin_only => false)
    end

    q1, q2 = CommonQuestion.last(2)
    assert CommonQuestion.admin_only(true).include?(q1)
    assert_false CommonQuestion.admin_only(true).include?(q2)
    assert_false CommonQuestion.admin_only(false).include?(q1)
    assert CommonQuestion.admin_only(false).include?(q2)
  end

  def test_filterable_scope
    assert_difference 'CommonQuestion.count', 2 do
      CommonQuestion.create!(
        :program => programs(:albers),
        :question_type => CommonQuestion::Type::STRING,
        :question_text => "Question 1 text")

      CommonQuestion.create!(
        :program => programs(:albers),
        :question_type => CommonQuestion::Type::FILE,
        :question_text => "Question 2 text")
    end

    q1, q2 = CommonQuestion.last(2)
    assert CommonQuestion.filterable.include?(q1)
    assert_false CommonQuestion.filterable.include?(q2)
  end

  def test_matrix_questions_and_not_matrix_questions_scope
    assert_equal CommonQuestion.count, CommonQuestion.matrix_questions.count + CommonQuestion.not_matrix_questions.count

    assert_difference "CommonQuestion.not_matrix_questions.count", 3 do
      assert_difference "CommonQuestion.matrix_questions.count" do
        create_matrix_survey_question
      end
    end
  end

  def test_matrix_rating_questions_scope
    CommonQuestion.matrix_questions.destroy_all
    assert_equal [], CommonQuestion.matrix_rating_questions

    mq = create_matrix_survey_question
    assert_equal mq.rating_questions, CommonQuestion.matrix_rating_questions
  end

  def test_should_delete_answers_if_question_type_changes_from_text_type_to_choice_type
    question = create_common_question(:question_type => CommonQuestion::Type::STRING)
    CommonAnswer.create!(:common_question => question, :user => users(:f_mentor), :answer_text => "abc")
    CommonAnswer.create!(:common_question => question, :user => users(:robert), :answer_text => "def")

    assert_equal(2, question.reload.common_answers.size)
    assert_difference("CommonAnswer.count", -2) do
      question.question_type = CommonQuestion::Type::MULTI_CHOICE
      ["A.B","C"].each_with_index{|text, pos| question.question_choices.build(text: text, position: pos+1, ref_obj: question)}
      question.save!
    end
  end

  def test_should_delete_answers_if_question_type_changes_from_multi_choice_to_single_choice
    question = create_common_question(question_type: CommonQuestion::Type::MULTI_CHOICE, question_choices: 'abc,def,hij')
    CommonAnswer.create!(common_question: question, user: users(:f_mentor), answer_value: {answer_text: "abc", question: question})
    CommonAnswer.create!(common_question: question, user: users(:robert), answer_value: {answer_text: "def", question: question})

    assert_equal(2, question.reload.common_answers.size)
    assert_difference("CommonAnswer.count", -2) do
      question.question_type = CommonQuestion::Type::SINGLE_CHOICE
      question.save!
    end
  end

  def test_should_change_answer_type_if_question_type_changes_from_single_choice_to_multi_choice
    question = create_common_question(question_type: CommonQuestion::Type::SINGLE_CHOICE, question_choices: 'abc,def,hij')
    a1 = CommonAnswer.create!(common_question: question, user: users(:f_mentor), answer_value: {answer_text: "abc", question: question})
    a2 = CommonAnswer.create!(common_question: question, user: users(:robert), answer_value: {answer_text: "def", question: question})
    assert_equal(2, question.reload.common_answers.size)
    assert_difference("CommonAnswer.count", -1) do
      question.question_type = CommonQuestion::Type::MULTI_CHOICE
      question.question_choices.second.destroy
      question.question_choices.create!(text: "klm", position: 3)
      question.save!
    end
    assert_equal(["abc"], a1.reload.answer_value)
    # The second answer should be deleted
    assert_nil CommonAnswer.find_by(id: a2.id)
  end

  def test_should_compact_single_choice_answers
    question = create_common_question(question_type: CommonQuestion::Type::SINGLE_CHOICE, question_choices: 'abc,def,hij')
    a1 = CommonAnswer.create!(common_question: question, user: users(:f_mentor), answer_value: {answer_text: "abc", question: question})
    a2 = CommonAnswer.create!(common_question: question, user: users(:robert), answer_value: {answer_text: "def", question: question})
    a3 = CommonAnswer.create!(common_question: question, user: create_user(name: 'tmp_'),  answer_value: {answer_text: "hij", question: question})

    qc1 = question.question_choices.find_by(text: "abc").id.to_s
    qc2 = question.question_choices.find_by(text: "hij").id.to_s
    question_choice_params = {existing_question_choices_attributes: [{qc1=>{"text" => "abc"}, qc2=>{"text" =>"hij"}, "104"=>{"text" => "klm"}}], question_choices: {new_order: "#{qc1},#{qc2},104"}}
    assert_equal(3, question.reload.common_answers.size)
    assert_difference("CommonAnswer.count", -1) do
      question.update_question_choices!(question_choice_params)
    end
    assert_equal("abc", a1.reload.answer_value)
    # The second answer should be deleted
    assert_nil CommonAnswer.find_by(id: a2.id)
    assert_equal('hij', a3.reload.answer_value)
  end

  def test_should_compact_multi_choice_answers
    question = create_common_question(question_type: CommonQuestion::Type::MULTI_CHOICE, question_choices: 'abc,def,hij,xyz')
    a1 = CommonAnswer.create!(common_question: question, user: users(:f_mentor), answer_value: {answer_text: ["abc", "def"], question: question})
    a2 = CommonAnswer.create!(common_question: question, user: users(:robert), answer_value: {answer_text: ["def", "hij"], question: question})
    a3 = CommonAnswer.create!(common_question: question, user: create_user(name: 'tmp_'), answer_value: {answer_text: ["abc", "xyz"], question: question})

    assert_equal(3, question.reload.common_answers.size)
    qc1 = question.question_choices.find_by(text: "abc").id.to_s
    qc2 = question.question_choices.find_by(text: "xyz").id.to_s
    question_choice_params = {existing_question_choices_attributes: [{qc1=>{"text" => "abc"}, "102"=>{"text" =>"klm"}, qc2=>{"text" => "xyz"}, "104"=>{"text" => "tsv"}}], question_choices: {new_order: "#{qc1},102,#{qc2},104"}}


    assert_difference("CommonAnswer.count", -1) do
      question.update_question_choices!(question_choice_params)
    end
    assert_equal(["abc"], a1.reload.answer_value)
    # The second answer should be deleted
    assert_nil CommonAnswer.find_by(id: a2.id)
    assert_equal(['abc', 'xyz'], a3.reload.answer_value)
  end

  def test_common_question_save_question_info
    question = create_common_question(:question_type => CommonQuestion::Type::MULTI_CHOICE)
    question_choice_params = {existing_question_choices_attributes: [{"101"=>{"text" => "abc"}, "102"=>{"text" =>"def"}, "103"=>{"text" => "hij\r\n"}, "104"=>{"text" => "\r\njkl\n"}, "105"=>{"text" => "\r\nxyz\n"}}], question_choices: {new_order: "101,102,103,104,105"}}
    question.update_question_choices!(question_choice_params)
    assert_equal "abc,def,hij,jkl,xyz", question.default_choices.join(",")
  end

  def test_other_option
    assert_difference 'CommonQuestion.count' do
      create_common_question(:question_type => CommonQuestion::Type::SINGLE_CHOICE, :question_text => "Pick one", :question_choices => "alpha, beta, gamma")
    end
    q = CommonQuestion.last
    assert_equal "Pick one", q.question_text
    assert_equal false, q.allow_other_option?
    q.update_attributes(:allow_other_option => true )
    assert q.allow_other_option?
  end

  def test_in_health_report
    program = programs(:albers)
    survey_question = surveys(:two).survey_questions.first
    feedback_question_1 = program.feedback_survey.survey_questions.where(:question_text => "Additional feedback (Optional)").first
    feedback_question_2 = program.feedback_survey.survey_questions.find_by(question_mode: CommonQuestion::Mode::EFFECTIVENESS)

    assert_false survey_question.in_health_report?
    assert_false feedback_question_1.in_health_report?
    assert feedback_question_2.in_health_report?
  end

  def test_non_editable
    program = programs(:albers)
    feedback_survey = program.feedback_survey
    editable_survey_question = surveys(:two).survey_questions.first
    editable_feedback_question = feedback_survey.survey_questions.where(:question_text => "Additional feedback (Optional)").first
    non_editable_feedback_question = feedback_survey.survey_questions.find_by(question_mode: CommonQuestion::Mode::CONNECTIVITY)

    assert_equal 2, feedback_survey.survey_questions.non_editable.size
    assert_equal 0, surveys(:two).survey_questions.non_editable.size

    assert_false editable_survey_question.non_editable?
    assert_false editable_feedback_question.non_editable?
    assert non_editable_feedback_question.non_editable?
  end

  def test_common_question_translation_fields
    assert ProfileQuestion::Translation.column_names.include?("question_info")
    assert ProfileQuestion::Translation.column_names.include?("question_text")
    assert ProfileQuestion::Translation.column_names.include?("help_text")
  end

  def test_question_info_translations
    assert_equal "Stand,Walk,Run", common_questions(:multi_choice_common_q).default_choices.join(",")
    assert_equal "Computer,Sofa", common_questions(:single_choice_common_q).default_choices.join(",")
    assert_equal "Good,Bad,Weird", common_questions(:rating_common_q).default_choices.join(",")

    run_in_another_locale(:'fr-CA') do
      assert_equal "Supporter,Marcher,Course", common_questions(:multi_choice_common_q).default_choices.join(",")
      assert_equal "Ordinateur,Velo", common_questions(:single_choice_common_q).default_choices.join(",")
      assert_equal "Bon,Mauvais,Bizarre", common_questions(:rating_common_q).default_choices.join(",")
    end
  end

  def test_choices_should_return_choices_in_corresponding_locale
    assert_equal ["Stand", "Walk", "Run"], common_questions(:multi_choice_common_q).default_choices
    run_in_another_locale(:en) do
      assert_equal ["Stand", "Walk", "Run"], common_questions(:multi_choice_common_q).default_choices
    end
    run_in_another_locale(:'fr-CA') do
      assert_equal ["Supporter", "Marcher", "Course"], common_questions(:multi_choice_common_q).default_choices
    end
  end

  def test_values_and_choices_should_return_english_to_current_locale_mapping
    run_in_another_locale(:'fr-CA') do
      mapping = common_questions(:multi_choice_common_q).values_and_choices
      expected_hash = {question_choices(:multi_choice_common_q_1).id=>"Supporter", question_choices(:multi_choice_common_q_2).id=>"Marcher", question_choices(:multi_choice_common_q_3).id=>"Course"}
      assert_equal expected_hash, mapping
    end

    mapping = common_questions(:multi_choice_common_q).values_and_choices
    expected_hash = {question_choices(:multi_choice_common_q_1).id=>"Stand", question_choices(:multi_choice_common_q_2).id=>"Walk", question_choices(:multi_choice_common_q_3).id=>"Run"}
    assert_equal expected_hash, mapping
  end

  def test_fallback_choices
    question = common_questions(:multi_choice_common_q)

    run_in_another_locale(:'fr') do
      question.question_choices.first.update_attributes!(text: "Supporter")
      question.question_choices.last.update_attributes!(text: "Course")
      assert_equal ["Supporter", "Walk", "Course"], question.default_choices
      question.question_choices.last.translation.destroy
      assert_equal ["Supporter", "Walk", "Run"], question.reload.default_choices
    end
    assert_equal ["Stand", "Walk", "Run"], question.default_choices
  end

  def test_update_question_info_of_all_translations_should_update_all_translations
    question = common_questions(:multi_choice_common_q)
    Globalize.with_locale(:fr) do
      choices = ["GStand", "Gwalk", "Grun"]
      question.question_choices.each {|qc| qc.update_attributes!(text: choices.shift)}
    end
    assert_equal "Stand,Walk,Run", question.default_choices.join(",")
    run_in_another_locale(:'fr-CA') do
      assert_equal "Supporter,Marcher,Course", question.default_choices.join(",")
    end
    run_in_another_locale(:fr) do
      assert_equal "GStand,Gwalk,Grun", question.default_choices.join(",")
    end
  end

  def test_handle_choices_update
    common_question = common_questions(:string_connection_q)
    common_answers = common_question.common_answers
    assert common_answers.present?

    common_question.question_type = CommonQuestion::Type::SINGLE_CHOICE
    common_question.expects(:compact_single_choice_answer_choices).with(common_answers).once
    common_question.handle_choices_update

    common_question.question_type = CommonQuestion::Type::MULTI_CHOICE
    common_question.expects(:compact_multi_choice_answer_choices).with(common_answers).once
    common_question.handle_choices_update

    common_question.question_type = CommonQuestion::Type::RATING_SCALE
    common_question.expects(:compact_multi_choice_answer_choices).never
    common_question.expects(:compact_single_choice_answer_choices).with(common_answers, true).once
    common_question.handle_choices_update

    unsupported_types = (CommonQuestion::Type.all - [CommonQuestion::Type::SINGLE_CHOICE, CommonQuestion::Type::MULTI_CHOICE, CommonQuestion::Type::RATING_SCALE])
    common_question.expects(:compact_single_choice_answer_choices).never
    unsupported_types.each do |unsupported_type|
      common_question.question_type = unsupported_type
      common_question.handle_choices_update
    end
  end

  def test_matrix_rating_question_texts
    mq = create_matrix_survey_question
    assert_equal ["Leadership","Team Work","Communication"], mq.matrix_rating_question_texts

    run_in_another_locale(:de) do
      mq.rating_questions.each do |rq|
        rq.update_attributes(question_text: "#{rq.question_text}-de")
      end
      assert_equal ["Leadership-de", "Team Work-de", "Communication-de"], mq.matrix_rating_question_texts
    end
    assert_equal ["Leadership", "Team Work", "Communication"], mq.matrix_rating_question_texts
  end

  def test_acts_as_list
    # ensure all sub-types of CommonQuestion include acts_as_list for positioning
    CommonQuestion.descendants.each do |common_question_type|
      assert common_question_type.included_modules.include?(ActiveRecord::Acts::List::InstanceMethods)
    end
    assert_false CommonQuestion.included_modules.include?(ActiveRecord::Acts::List::InstanceMethods)
  end
end