require_relative './../../test_helper.rb'

class FirstVisitSectionQuestionsTest < ActiveSupport::TestCase
  include FirstVisitSectionQuestions

  def test_conditional_question_answered
    member = members(:f_mentor)
    answered_profile_questions = member.answered_profile_questions.group_by(&:id)
    question = profile_questions(:string_q)
    assert_false conditional_question_answered?(question, answered_profile_questions)

    parent_question, question, _member, _profile_answer = create_data_for_conditional_question_testing
    answered_profile_questions = member.answered_profile_questions.group_by(&:id)
    assert conditional_question_answered?(question, answered_profile_questions)

    answered_profile_questions.delete(parent_question.id)
    assert_false conditional_question_answered?(question, answered_profile_questions)
  end

  def test_handle_answered_and_conditional_questions
    profile_questions = [profile_questions(:string_q), profile_questions(:single_choice_q), profile_questions(:multi_choice_q)]
    answered_profile_questions = [profile_questions(:string_q), profile_questions(:single_choice_q)]
    unanswered_profile_questions = profile_questions - answered_profile_questions
    profile_answers_per_question = members(:f_mentor).profile_answers.group_by(&:profile_question_id)
    self.stubs(:handle_conditional_questions).with(unanswered_profile_questions, profile_answers_per_question, profile_questions.collect(&:id)).returns([])
    assert_equal [], handle_answered_and_conditional_questions(members(:f_mentor), profile_questions, answered_profile_questions)

    self.stubs(:handle_conditional_questions).with(unanswered_profile_questions, profile_answers_per_question, profile_questions.collect(&:id)).returns([profile_questions(:multi_choice_q)])
    assert_equal [profile_questions(:multi_choice_q)], handle_answered_and_conditional_questions(members(:f_mentor), profile_questions, answered_profile_questions)
  end

  def test_handle_conditional_questions
    profile_questions = [profile_questions(:string_q), profile_questions(:single_choice_q), profile_questions(:multi_choice_q)]
    profile_question_ids = profile_questions.collect(&:id)
    answered_profile_questions = [profile_questions(:string_q), profile_questions(:single_choice_q)]
    unanswered_profile_questions = profile_questions - answered_profile_questions
    profile_answers_per_question = members(:f_mentor).profile_answers.group_by(&:profile_question_id)

    question = profile_questions(:multi_choice_q)
    question.conditional_question_id = profile_questions(:single_choice_q).id
    question.conditional_match_text = "opt_1"
    question.save!
    question.reload

    self.stubs(:conditional_question_unanswered_in_other_section_or_not_available?).with(question, profile_answers_per_question, profile_question_ids).returns(false)
    self.stubs(:conditional_question_unanswered_in_other_section_or_not_available?).with(profile_questions(:single_choice_q), profile_answers_per_question, profile_question_ids).returns(false)
    assert_equal [profile_questions(:multi_choice_q), profile_questions(:single_choice_q)], handle_conditional_questions([question], profile_answers_per_question, profile_question_ids)

    self.stubs(:conditional_question_unanswered_in_other_section_or_not_available?).with(question, profile_answers_per_question, profile_question_ids - [profile_questions(:single_choice_q).id]).returns(false)
    self.stubs(:conditional_question_unanswered_in_other_section_or_not_available?).with(profile_questions(:single_choice_q), profile_answers_per_question, profile_question_ids - [profile_questions(:single_choice_q).id]).returns(false)
    assert_equal [profile_questions(:multi_choice_q)], handle_conditional_questions([question], profile_answers_per_question, profile_question_ids - [profile_questions(:single_choice_q).id])

    question.update_attributes!(section_id: 2)
    question.reload
    self.stubs(:conditional_question_unanswered_in_other_section_or_not_available?).with(question, profile_answers_per_question, profile_question_ids).returns(false)
    assert_equal [profile_questions(:multi_choice_q)], handle_conditional_questions([question], profile_answers_per_question, profile_question_ids)

    self.stubs(:conditional_question_answered?).with(question, profile_answers_per_question).returns(false)
    assert_equal [profile_questions(:multi_choice_q)], handle_conditional_questions(unanswered_profile_questions, profile_answers_per_question, profile_question_ids)

    self.stubs(:conditional_question_answered?).with(question, profile_answers_per_question).returns(true)
    question.stubs(:conditional_text_matches?).with(profile_answers_per_question).returns(false)
    assert_equal [], handle_conditional_questions(unanswered_profile_questions, profile_answers_per_question, profile_question_ids)

    question.stubs(:conditional_text_matches?).with(profile_answers_per_question).returns(true)
    assert_equal [profile_questions(:multi_choice_q)], handle_conditional_questions([question], profile_answers_per_question, profile_question_ids)

    self.stubs(:conditional_question_unanswered_in_other_section_or_not_available?).with(question, profile_answers_per_question, profile_question_ids).returns(true)
    self.stubs(:conditional_question_answered?).with(question, profile_answers_per_question).returns(false)
    assert_equal [], handle_conditional_questions([question], profile_answers_per_question, profile_question_ids)
  end

  def test_conditional_question_available_and_in_same_section
    question = profile_questions(:multi_choice_q)
    question.conditional_question_id = profile_questions(:single_choice_q).id
    question.conditional_match_text = "opt_1"
    question.save!
    question.reload

    assert conditional_question_available_and_in_same_section?(question, [profile_questions(:single_choice_q).id])
    assert_false conditional_question_available_and_in_same_section?(question, [profile_questions(:multi_choice_q).id])

    question.update_attributes!(section_id: 2)
    question.reload
    assert_false conditional_question_available_and_in_same_section?(question, [profile_questions(:single_choice_q).id])
  end

  def test_conditional_question_unanswered_in_other_section_or_not_available
    member = members(:f_mentor)
    answered_profile_questions = member.answered_profile_questions.group_by(&:id)
    question = profile_questions(:string_q)
    question_ids = [profile_questions(:multi_choice_q).id]
    assert_false conditional_question_unanswered_in_other_section_or_not_available?(question, answered_profile_questions, question_ids)

    parent_question, question, _member, _profile_answer = create_data_for_conditional_question_testing
    assert_false conditional_question_unanswered_in_other_section_or_not_available?(question, answered_profile_questions, question_ids)

    answered_profile_questions = answered_profile_questions.except![parent_question.id]
    assert_false conditional_question_unanswered_in_other_section_or_not_available?(question.reload, answered_profile_questions, question_ids)
    assert conditional_question_unanswered_in_other_section_or_not_available?(question.reload, answered_profile_questions, [])

    parent_question.update_attributes!(section_id: sections(:section_albers_students).id)
    assert conditional_question_unanswered_in_other_section_or_not_available?(question.reload, answered_profile_questions, question_ids)
  end

  private

  def create_data_for_conditional_question_testing
    parent_question = profile_questions(:multi_choice_q)
    question = profile_questions(:string_q)
    question.conditional_question_id = parent_question.id
    question.save!

    question.conditional_match_choices.create!(question_choice_id: question_choices(:multi_choice_q_3).id)
    member = members(:f_mentor)
    profile_answer = member.profile_answers.where(profile_question_id: parent_question.id).first
    [parent_question, question, member, profile_answer]
  end
end