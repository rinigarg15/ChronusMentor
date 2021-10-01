require_relative './../../test_helper.rb'

class ChoicesUpdateHandlerTest < ActiveSupport::TestCase
  def test_profile_question_methods
    profile_question = ProfileQuestion.first
    profile_answers = profile_question.profile_answers

    assert_nothing_raised do
      profile_question.compact_single_choice_answer_choices(profile_answers)
      profile_question.compact_multi_choice_answer_choices(profile_answers)
      profile_question.compact_answers_for_ordered_options_to_single_choice_conversion(profile_answers)
      profile_question.compact_answers_for_ordered_options_to_multi_choice_conversion(profile_answers)
    end
  end

  def test_common_question_methods
    common_question = CommonQuestion.first
    common_answers = common_question.common_answers

    assert_nothing_raised do
      common_question.compact_single_choice_answer_choices(common_answers)
      common_question.compact_multi_choice_answer_choices(common_answers)
    end
    assert_raise NoMethodError do
      common_question.compact_answers_for_ordered_options_to_single_choice_conversion(common_answers)
    end
    assert_raise NoMethodError do
      common_question.compact_answers_for_ordered_options_to_multi_choice_conversion(common_answers)
    end
  end

  def test_compact_single_choice_answers
    profile_question = profile_questions(:single_choice_q)
    profile_answer_1 = profile_answers(:single_choice_ans_1)
    profile_answer_2 = profile_answers(:single_choice_ans_2)
    profile_answers = profile_question.profile_answers
    assert_equal_unordered [profile_answer_1, profile_answer_2], profile_answers

    assert_equal_unordered ["opt_1", "opt_2", "opt_3"], profile_question.default_choices
    assert_false profile_question.allow_other_option
    assert_equal "opt_1", profile_answer_1.answer_value(profile_question)
    assert_equal "opt_3", profile_answer_2.answer_value(profile_question)

    profile_question.question_choices.find_by(text: "opt_1").destroy
    profile_question.question_choices.reload
    profile_question.compact_single_choice_answer_choices(profile_answers)
    assert_raise(ActiveRecord::RecordNotFound) { profile_answer_1.reload }
    assert_equal "opt_3", profile_answer_2.reload.answer_value(profile_question)

    profile_question.question_choices.find_by(text: "opt_3").destroy
    profile_question.allow_other_option = true
    profile_answer_2 = ProfileAnswer.new(profile_answers(:single_choice_ans_2).attributes.except("id"))
    profile_answer_2.answer_value = {answer_text: "opt_3", question: profile_question}
    profile_answer_2.save!
    profile_question.compact_single_choice_answer_choices(profile_answers.reload)
    assert_equal "opt_3", profile_answer_2.reload.answer_value(profile_question)
  end

  def test_compact_single_choice_common_answers
    common_question = common_questions(:single_choice_connection_q)
    common_answer = common_answers(:single_choice_ans_1_connection)
    common_answers = common_question.common_answers
    assert_equal [common_answer], common_answers

    assert_equal_unordered ["opt_1", "opt_2", "opt_3"], common_question.default_choices
    assert_false common_question.allow_other_option
    assert_equal "opt_1", common_answer.answer_value

    common_question.allow_other_option = true
    question_choice_params = {existing_question_choices_attributes: [{}], question_choices: {new_order: ""}}
    common_question.update_question_choices!(question_choice_params)
    assert_equal "opt_1", common_answer.reload.answer_value

    common_question.allow_other_option = false
    common_question.update_question_choices!(question_choice_params)
    assert_raise(ActiveRecord::RecordNotFound) { common_answer.reload }
  end

  def test_compact_single_choice_answers_ignoring_allow_other_option
    common_question = common_questions(:single_choice_connection_q)
    common_answer = common_answers(:single_choice_ans_1_connection)
    common_answers = common_question.common_answers
    assert_equal [common_answer], common_answers

    common_question.update_attribute(:allow_other_option, true)
    common_answer.update_attributes!(answer_value: {answer_text: "new_opt", question: common_question})
    assert_equal "new_opt", common_answer.reload.answer_value

    common_question.compact_single_choice_answer_choices(common_answers.reload, true)
    assert_raise(ActiveRecord::RecordNotFound) { common_answer.reload }
  end

  def test_compact_multi_choice_answers
    profile_question = profile_questions(:multi_choice_q)
    profile_answer_1 = profile_answers(:multi_choice_ans_1)
    profile_answer_2 = profile_answers(:multi_choice_ans_2)
    profile_answers = profile_question.profile_answers
    assert_equal_unordered [profile_answer_1, profile_answer_2], profile_answers

    assert_equal_unordered ["Stand", "Walk", "Run"], profile_question.default_choices
    assert_false profile_question.allow_other_option
    assert_equal_unordered ["Stand", "Run"], profile_answer_1.answer_value(profile_question)
    assert_equal ["Walk"], profile_answer_2.answer_value(profile_question)

    profile_question.question_choices.find_by(text: "Run").destroy
    profile_question.compact_multi_choice_answer_choices(profile_answers)
    assert_equal ["Stand"], profile_answer_1.reload.answer_value(profile_question)
    assert_equal ["Walk"], profile_answer_2.reload.answer_value(profile_question)

    profile_question.question_choices.find_by(text: "Walk").destroy
    profile_question.compact_multi_choice_answer_choices(profile_answers.reload)
    assert_equal ["Stand"], profile_answer_1.reload.answer_value(profile_question)
    assert_raise(ActiveRecord::RecordNotFound) { profile_answer_2.reload }

    profile_question.question_choices.find_by(text: "Stand")
    profile_question.question_choices.create!(text: "New")
    profile_question.allow_other_option = true
    profile_answer_1 = profile_answers(:multi_choice_ans_1)
    profile_answer_1.answer_value = ["Stand"]
    profile_answer_1.save!
    profile_question.compact_multi_choice_answer_choices(profile_answers.reload)
    assert_equal ["Stand"], profile_answer_1.reload.answer_value(profile_question)
  end

  def test_compact_multi_choice_common_answers
    common_question = common_questions(:multi_choice_connection_q)
    common_answer = common_answers(:multi_choice_ans_1_connection)
    common_answers = common_question.common_answers
    assert_equal [common_answer], common_answers

    assert_equal_unordered ["Stand", "Run", "Walk"], common_question.default_choices
    assert_false common_question.allow_other_option
    assert_equal_unordered ["Stand", "Run"], common_answer.answer_value

    choices_hash = common_question.question_choices.index_by(&:text)
    common_question.allow_other_option = true
    question_choice_params = {existing_question_choices_attributes: [{"#{choices_hash['Stand'].id}"=>{"text" => "Stand"}}], question_choices: {new_order: "#{choices_hash['Stand'].id}"}}
    common_question.update_question_choices!(question_choice_params)

    assert_equal_unordered ["Stand", "Run"], common_answer.reload.answer_value

    common_question.allow_other_option = false
    question_choice_params = {existing_question_choices_attributes: [{ "#{choices_hash['Stand'].id}"=>{"text" => "Stand"}}], question_choices: {new_order: "#{choices_hash['Stand'].id}"}}
    common_question.update_question_choices!(question_choice_params)
    assert_equal ["Stand"], common_answer.reload.answer_value
  end

  def test_compact_multi_choice_answers_for_single_to_multi_choice_conversion
    profile_question = profile_questions(:single_choice_q)
    profile_answer_1 = profile_answers(:single_choice_ans_1)
    profile_answer_2 = profile_answers(:single_choice_ans_2)
    profile_answers = profile_question.profile_answers
    assert_equal_unordered [profile_answer_1, profile_answer_2], profile_answers

    assert_equal_unordered ["opt_1", "opt_2", "opt_3"], profile_question.default_choices
    assert_equal "opt_1", profile_answer_1.answer_value(profile_question)
    assert_equal "opt_3", profile_answer_2.answer_value(profile_question)

    profile_question.question_type = ProfileQuestion::Type::MULTI_CHOICE
    profile_question.question_choices.find_by(text: "opt_1").destroy
    profile_question.compact_multi_choice_answer_choices(profile_answers)
    assert_raise(ActiveRecord::RecordNotFound) { profile_answer_1.reload }
    assert_equal ["opt_3"], profile_answer_2.reload.answer_value(profile_question)

    profile_question.question_choices.find_by(text: "opt_3").destroy
    profile_question.allow_other_option = true
    profile_answer_2 = ProfileAnswer.new(profile_answers(:single_choice_ans_2).attributes.except("id"))
    profile_answer_2.answer_value = {answer_text: ["opt_3"], question: profile_question}
    profile_answer_2.save!
    profile_question.compact_single_choice_answer_choices(profile_answers.reload)
    assert_equal ["opt_3"], profile_answer_2.reload.answer_value(profile_question)
  end

  def test_compact_ordered_options_answers
    profile_question = create_profile_question(question_type: ProfileQuestion::Type::ORDERED_OPTIONS, question_choices: ["A", "B", "C", "D" ,"E"], options_count: 3)
    profile_answer_1 = profile_question.profile_answers.create!(answer_value: {answer_text: ["A", "B"], question: profile_question}, ref_obj: members(:f_mentor))
    profile_answer_2 = profile_question.profile_answers.create!(answer_value: {answer_text: ["C", "D", "E"], question: profile_question}, ref_obj: members(:f_student))
    profile_answers = profile_question.profile_answers

    assert_equal_unordered ["A", "B", "C", "D", "E"], profile_question.default_choices
    assert_false profile_question.allow_other_option
    assert_equal_unordered ["A", "B"], profile_answer_1.answer_value(profile_question)
    assert_equal ["C", "D", "E"], profile_answer_2.answer_value(profile_question)

    profile_question.question_choices.where(text: ["A", "E"]).destroy_all
    profile_question.question_choices.reload
    profile_question.compact_multi_choice_answer_choices(profile_answers.reload, profile_question.options_count)
    assert_equal ["B"], profile_answer_1.reload.answer_value(profile_question)
    assert_equal ["C", "D"], profile_answer_2.reload.answer_value(profile_question)

    profile_question.question_choices.where(text: ["C", "D"]).destroy_all
    profile_question.question_choices.reload
    profile_question.allow_other_option = true
    profile_answer_2 = profile_question.profile_answers.create!(answer_value: {answer_text: ["C", "D"], question: profile_question}, ref_obj: members(:f_student))
    profile_question.compact_multi_choice_answer_choices(profile_answers.reload, profile_question.options_count)
    assert_equal ["B"], profile_answer_1.reload.answer_value(profile_question)
    assert_equal ["C", "D"], profile_answer_2.reload.answer_value(profile_question)

    profile_question.options_count = 1
    profile_question.compact_multi_choice_answer_choices(profile_answers.reload, profile_question.options_count)
    assert_equal ["B"], profile_answer_1.reload.answer_value(profile_question)
    assert_equal ["C"], profile_answer_2.reload.answer_value(profile_question)

    profile_question.allow_other_option = false
    profile_question.compact_multi_choice_answer_choices(profile_answers.reload, profile_question.options_count)
    assert_equal ["B"], profile_answer_1.reload.answer_value(profile_question)
    assert_raise(ActiveRecord::RecordNotFound) { profile_answer_2.reload }
  end

  def test_compact_answers_for_ordered_options_to_single_choice_conversion
    profile_question = create_profile_question(question_type: ProfileQuestion::Type::ORDERED_OPTIONS, question_choices: ["A", "B", "C", "D" ,"E"], options_count: 3)
    profile_answer_1 = profile_question.profile_answers.create!(answer_value: {answer_text: ["A", "B"], question: profile_question}, ref_obj: members(:f_mentor))
    profile_answer_2 = profile_question.profile_answers.create!(answer_value: {answer_text: ["C", "D", "E"], question: profile_question}, ref_obj: members(:f_student))
    profile_answers = profile_question.profile_answers

    profile_question.question_type = ProfileQuestion::Type::SINGLE_CHOICE
    profile_question.question_choices.where(text: ["A", "B"]).destroy_all
    profile_question.question_choices.reload

    profile_question.allow_other_option = true
    profile_answer_1 = profile_question.profile_answers.create!(answer_value: {answer_text: ["A", "B"], question: profile_question}, ref_obj: members(:f_mentor))
    profile_answers = profile_question.profile_answers
    profile_question.compact_answers_for_ordered_options_to_single_choice_conversion(profile_answers)
    assert_equal "A", profile_answer_1.reload.answer_value(profile_question)
    assert_equal "C", profile_answer_2.reload.answer_value(profile_question)

    profile_question.allow_other_option = false
    profile_question.compact_answers_for_ordered_options_to_single_choice_conversion(profile_answers.reload)
    assert_raise(ActiveRecord::RecordNotFound) { profile_answer_1.reload }
    assert_equal "C", profile_answer_2.reload.answer_value(profile_question)
  end

  def test_compact_answers_for_ordered_options_to_multi_choice_conversion
    profile_question = create_profile_question(question_type: ProfileQuestion::Type::ORDERED_OPTIONS, question_choices: ["A", "B", "C", "D" ,"E"], options_count: 3)
    profile_answer_1 = profile_question.profile_answers.create!(answer_value: {answer_text: ["A", "B"], question: profile_question}, ref_obj: members(:f_mentor))
    profile_answer_2 = profile_question.profile_answers.create!(answer_value: {answer_text: ["C", "D", "E"], question: profile_question}, ref_obj: members(:f_student))

    profile_answers = profile_question.profile_answers

    profile_question.question_type = ProfileQuestion::Type::MULTI_CHOICE

    profile_question.question_choices.where(text: ["A", "B", "D"]).destroy_all
    profile_question.question_choices.reload
    profile_question.allow_other_option = true
    profile_answer_1 = profile_question.profile_answers.create!(answer_value: {answer_text: ["A", "B"], question: profile_question}, ref_obj: members(:f_mentor))
    profile_answer_2.answer_value = ["C", "D", "E"]
    profile_answer_2.save
    profile_answers = profile_question.profile_answers.reload
    profile_question.compact_answers_for_ordered_options_to_multi_choice_conversion(profile_answers)
    assert_equal ["A", "B"], profile_answer_1.answer_value(profile_question)
    assert_equal ["C", "E", "D"], profile_answer_2.answer_value(profile_question)
    profile_question.allow_other_option = false
    profile_question.compact_answers_for_ordered_options_to_multi_choice_conversion(profile_answers)
    assert_raise(ActiveRecord::RecordNotFound) { profile_answer_1.reload }
    assert_equal ["C", "E"], profile_answer_2.reload.answer_value(profile_question)
  end

  def test_compact_answers_for_ordered_options_to_single_choice_conversion_different_locale
    profile_question = create_profile_question(question_type: ProfileQuestion::Type::ORDERED_OPTIONS, question_choices: ["A", "B", "C", "D" ,"E"], allow_other_option: true, options_count: 3)
    profile_answer = profile_question.profile_answers.create!(answer_value: {answer_text: ["F", "B"], question: profile_question}, ref_obj: members(:f_mentor))
    profile_answers = profile_question.profile_answers

    GlobalizationUtils.run_in_locale("fr-CA") do
      profile_question.question_choices.first.update_attributes!(text: 1)
      profile_question.question_choices.second.update_attributes!(text: 2)
      profile_question.question_choices.third.update_attributes!(text: 3)
      profile_question.question_choices.fourth.update_attributes!(text: 4)
      profile_question.question_choices.last.update_attributes!(text: 5)
      assert_equal_unordered ["F", "2"], profile_answer.answer_value(profile_question)

      profile_question.question_type = ProfileQuestion::Type::SINGLE_CHOICE
      profile_question.compact_answers_for_ordered_options_to_single_choice_conversion(profile_answers)
      assert_equal "F", profile_answer.reload.answer_value(profile_question)

      profile_question.allow_other_option = false
      profile_question.compact_answers_for_ordered_options_to_single_choice_conversion(profile_answers.reload)
      assert_raise(ActiveRecord::RecordNotFound) { profile_answer.reload }
    end
  end

  def test_compact_answers_for_ordered_options_to_multi_choice_conversion_different_locale
    profile_question = create_profile_question(question_type: ProfileQuestion::Type::ORDERED_OPTIONS, question_choices: ["A", "B", "C", "D" ,"E"], allow_other_option: true, options_count: 3)
    profile_answer = profile_question.profile_answers.create!(answer_value: {answer_text: ["F", "B"], question: profile_question}, ref_obj: members(:f_mentor))
    profile_answers = profile_question.profile_answers

    GlobalizationUtils.run_in_locale("fr-CA") do
      profile_question.question_choices.first.update_attributes!(text: 1)
      profile_question.question_choices.second.update_attributes!(text: 2)
      profile_question.question_choices.third.update_attributes!(text: 3)
      profile_question.question_choices.fourth.update_attributes!(text: 4)
      profile_question.question_choices.last.update_attributes!(text: 5)
      assert_equal_unordered ["F", "2"], profile_answer.answer_value(profile_question)

      profile_question.question_type = ProfileQuestion::Type::MULTI_CHOICE
      profile_question.compact_answers_for_ordered_options_to_multi_choice_conversion(profile_answers)
      assert_equal ["F", "2"], profile_answer.answer_value(profile_question)

      profile_answer.answer_value = {answer_text: "F, B", from_import: true}
      profile_answer.save
      profile_question.allow_other_option = false
      profile_question.compact_answers_for_ordered_options_to_multi_choice_conversion(profile_answers)
      assert_equal ["2"], profile_answer.answer_value(profile_question)
    end
  end
end