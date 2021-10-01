require_relative './../../test_helper.rb'

class ThreeSixty::SurveyAnswerTest < ActiveSupport::TestCase
  def test_belongs_to_survey_question
    assert_equal three_sixty_survey_questions(:three_sixty_survey_questions_1), three_sixty_survey_answers(:answer_1).survey_question
  end

  def test_belongs_to_survey_reviewer
    assert_equal three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1), three_sixty_survey_answers(:answer_1).survey_reviewer
  end

  def test_presence_of_survey_question
    answer = ThreeSixty::SurveyAnswer.new(:survey_reviewer => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1), :answer_value => 4)
    answer.save
    assert_equal ["can't be blank"], answer.errors[:three_sixty_survey_question_id] 
  end

  def test_presence_of_survey_reviewer
    answer = ThreeSixty::SurveyAnswer.new(:survey_question => three_sixty_survey_questions(:three_sixty_survey_questions_1), :answer_value => 4)
    answer.save
    assert_equal ["can't be blank"], answer.errors[:three_sixty_survey_reviewer_id] 
  end

  def test_uniqueness_of_survey_question_wrt_survey_reviewer
    answer = ThreeSixty::SurveyAnswer.new(:survey_question => three_sixty_survey_questions(:three_sixty_survey_questions_1), :answer_value => 4, :survey_reviewer => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1))
    answer.save
    assert_equal ["has already been taken"], answer.errors[:three_sixty_survey_question_id]
  end

  def test_answer_text_or_value_present
    answer = ThreeSixty::SurveyAnswer.create(:survey_question => three_sixty_survey_questions(:three_sixty_survey_questions_1), :survey_reviewer => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1))
    assert_equal ["answer text or answer value must be present"], answer.errors[:answer]
  end

  def test_scope_of_rating_type
    assert three_sixty_survey_answers(:answer_1).question.of_rating_type?
    assert_false three_sixty_survey_answers(:answer_2).question.of_rating_type?
    assert three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1).answers.of_rating_type.include?(three_sixty_survey_answers(:answer_1))
    assert_false three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1).answers.of_rating_type.include?(three_sixty_survey_answers(:answer_2))

    three_sixty_survey_answers(:answer_2).question.update_attribute(:question_type, ThreeSixty::Question::Type::RATING)
    assert three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1).answers.of_rating_type.include?(three_sixty_survey_answers(:answer_2))
  end

  def test_scope_of_text_type
    assert three_sixty_survey_answers(:answer_1).question.of_rating_type?
    assert_false three_sixty_survey_answers(:answer_2).question.of_rating_type?
    assert_false three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1).answers.of_text_type.include?(three_sixty_survey_answers(:answer_1))
    assert three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1).answers.of_text_type.include?(three_sixty_survey_answers(:answer_2))

    three_sixty_survey_answers(:answer_1).question.update_attribute(:question_type, ThreeSixty::Question::Type::TEXT)
    assert three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1).answers.of_text_type.include?(three_sixty_survey_answers(:answer_1))
  end

  def test_question
    assert_equal three_sixty_questions(:listening_1), three_sixty_survey_answers(:answer_1).question
  end

  def test_survey
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_1), three_sixty_survey_answers(:answer_1).survey_assessee
  end
end