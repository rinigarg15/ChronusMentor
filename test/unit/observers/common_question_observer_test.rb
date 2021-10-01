require_relative './../../test_helper.rb'

class CommonQuestionObserverTest < ActiveSupport::TestCase

    # Added for AP-9532
  def test_update_french_attributes_should_just_update_the_required_french_translations_and_not_everything
    question = create_common_question(question_type: CommonQuestion::Type::MULTI_CHOICE, question_text: "Select Preference", question_choices: "alpha,beta,gamma", help_text: "Help Text")

    assert_equal "Select Preference", question.question_text
    assert_equal "Select Preference", question.question_text(:'fr-CA') #fallback
    assert_nil question.translation_for(:'fr-CA').question_text #without fallback
    assert_equal "Help Text", question.help_text(:'fr-CA') #fallback
    assert_nil question.translation_for(:'fr-CA').help_text #without fallback

    run_in_another_locale(:'fr-CA') do
      question.update_attributes!(:question_text => "Select Preference in French")
    end

    assert_equal "Select Preference", question.question_text
    assert_equal "Select Preference in French", question.question_text(:'fr-CA') #fallback
    assert_equal "Select Preference in French", question.translation_for(:'fr-CA').question_text #without fallback
    assert_nil question.translation_for(:'fr-CA').help_text #without fallback
  end

  def test_allow_empty_question_text_in_other_locale
    question = create_common_question(question_type: CommonQuestion::Type::MULTI_CHOICE, question_text: "Question1", help_text: "Help Text")
    run_in_another_locale(:'fr-CA') do
      question.update_attributes!(question_text: nil)
    end
    assert_equal "Question1", question.question_text(:'fr-CA')
    assert_nil question.translation_for(:'fr-CA').question_text
  end

  def test_allow_other_option_and_strip_question_text_before_saving
    common_question = common_questions(:common_questions_4)
    common_question.question_text = "  Question with Spacing  "
    common_question.allow_other_option = true
    common_question.save!
    assert_equal "Question with Spacing", common_question.reload.question_text
    assert_equal false, common_question.allow_other_option
  end

  def test_change_non_choice_based_to_choice_based_destroys_answers
    common_question = common_questions(:string_connection_q)
    common_answers = common_question.common_answers
    common_answers_count = common_answers.count
    assert (common_answers_count > 0)

    common_question.expects(:compact_single_choice_answer_choices).never
    common_question.expects(:compact_multi_choice_answer_choices).never
    common_question.expects(:handle_choices_update).never
    assert_difference "CommonAnswer.count", -common_answers_count do
      common_question.question_type = CommonQuestion::Type::SINGLE_CHOICE
      common_question.save!
      ["1","2","3"].each_with_index{|text, i| common_question.question_choices.create!(text: text, position: i+1)}
    end
  end

  def test_change_choice_based_to_non_choice_based_destroys_question_choices
    common_question = common_questions(:multi_choice_connection_q)
    qc_count = common_question.question_choices.count
    ac_count = common_question.question_choices.collect(&:answer_choices).flatten.count
    assert (qc_count > 0)
    assert (ac_count > 0)

    common_question.expects(:compact_single_choice_answer_choices).never
    common_question.expects(:compact_multi_choice_answer_choices).never
    common_question.expects(:handle_choices_update).never
    assert_no_difference "CommonAnswer.count" do
      assert_difference "QuestionChoice.count", -qc_count do
        assert_difference "AnswerChoice.count", -ac_count do
          common_question.question_type = CommonQuestion::Type::STRING
          common_question.save!
        end
      end
    end
  end

  def test_change_question_type_multi_to_single_choice_destroys_answers
    common_question = common_questions(:multi_choice_connection_q)
    common_answers = common_question.common_answers
    common_answers_count = common_answers.count
    assert (common_answers_count > 0)

    common_question.expects(:compact_single_choice_answer_choices).never
    common_question.expects(:compact_multi_choice_answer_choices).never
    common_question.expects(:handle_choices_update).never
    assert_difference "CommonAnswer.count", -common_answers_count do
      common_question.question_type = CommonQuestion::Type::SINGLE_CHOICE
      common_question.save!
    end
  end

  def test_change_question_type_multi_to_rating_scale_destroys_answers
    common_question = common_questions(:multi_choice_connection_q)
    common_answers = common_question.common_answers
    common_answers_count = common_answers.count
    assert (common_answers_count > 0)

    common_question.expects(:compact_single_choice_answer_choices).never
    common_question.expects(:compact_multi_choice_answer_choices).never
    common_question.expects(:handle_choices_update).never
    assert_difference "CommonAnswer.count", -common_answers_count do
      common_question.question_type = CommonQuestion::Type::RATING_SCALE
      common_question.save!
    end
  end
 
  def test_change_question_type_single_to_multi_choice
    common_question = common_questions(:single_choice_connection_q)
    common_answers = common_question.common_answers
    common_answers_count = common_answers.count
    assert (common_answers_count > 0)

    common_question.expects(:compact_single_choice_answer_choices).never
    common_question.expects(:compact_multi_choice_answer_choices).with(common_answers).once
    common_question.expects(:handle_choices_update).never
    assert_no_difference "CommonAnswer.count" do
      common_question.question_type = CommonQuestion::Type::MULTI_CHOICE
      common_question.save!
    end
  end

  def test_change_question_type_single_to_rating_scale_allow_other_option_disabled
    common_question = common_questions(:single_choice_connection_q)
    common_answers = common_question.common_answers
    common_answers_count = common_answers.count
    assert (common_answers_count > 0)
    assert_false common_question.allow_other_option?

    common_question.expects(:compact_single_choice_answer_choices).never
    common_question.expects(:compact_multi_choice_answer_choices).never
    common_question.expects(:handle_choices_update).never
    assert_no_difference "CommonAnswer.count" do
      common_question.question_type = CommonQuestion::Type::RATING_SCALE
      common_question.save!
    end
  end

  def test_change_question_type_single_to_rating_scale_allow_other_option_enabled
    common_question = common_questions(:single_choice_connection_q)
    common_answers = common_question.common_answers
    common_answers_count = common_answers.count
    assert (common_answers_count > 0)
    common_question.update_attribute(:allow_other_option, true)

    common_question.expects(:compact_single_choice_answer_choices).with(common_answers, true).once
    common_question.expects(:compact_multi_choice_answer_choices).never
    common_question.expects(:handle_choices_update).never
    assert_no_difference "CommonAnswer.count" do
      common_question.question_type = CommonQuestion::Type::RATING_SCALE
      common_question.save!
    end
  end

  def test_change_allow_other_option_to_enabled_does_not_trigger_answers_update
    common_question = common_questions(:string_connection_q)
    common_answers = common_question.common_answers
    common_answers_count = common_answers.count
    assert (common_answers_count > 0)
    assert_false common_question.allow_other_option

    common_question.expects(:compact_single_choice_answer_choices).never
    common_question.expects(:compact_multi_choice_answer_choices).never
    common_question.expects(:handle_choices_update).never
    assert_no_difference "CommonAnswer.count" do
      common_question.allow_other_option = true
      common_question.save!
    end
  end

  def test_change_allow_other_option_to_disabled_triggers_answers_update
    common_question = common_questions(:string_connection_q)
    common_answers = common_question.common_answers
    common_answers_count = common_answers.count
    assert (common_answers_count > 0)
    common_question.update_column(:allow_other_option, true)

    common_question.expects(:compact_single_choice_answer_choices).never
    common_question.expects(:compact_multi_choice_answer_choices).never
    common_question.expects(:handle_choices_update).once
    assert_no_difference "CommonAnswer.count" do
      common_question.allow_other_option = false
      common_question.save!
    end
  end

end