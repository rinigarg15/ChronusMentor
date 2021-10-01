require_relative './../../test_helper.rb'

class ThreeSixty::SurveyAssesseeQuestionInfoTest < ActiveSupport::TestCase
  def test_belongs_to_survey_assessee
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_1), ThreeSixty::SurveyAssesseeQuestionInfo.first.survey_assessee
  end

  def test_belongs_to_question
    assert_equal three_sixty_questions(:listening_1), ThreeSixty::SurveyAssesseeQuestionInfo.first.question
  end

  def test_belongs_to_reviewer_group
    assert_nil three_sixty_survey_assessee_question_infos(:three_sixty_survey_assessee_question_infos_1).reviewer_group
    assert_equal three_sixty_reviewer_groups(:three_sixty_reviewer_groups_1), three_sixty_survey_assessee_question_infos(:three_sixty_survey_assessee_question_infos_2).reviewer_group
  end

  def test_related_question_infos
    question_info = ThreeSixty::SurveyAssesseeQuestionInfo.first
    question = question_info.question
    question_info.related_question_infos.each do |qi|
      assert_equal question, qi.question
    end
    related_qi = ThreeSixty::SurveyAssesseeQuestionInfo.create(:survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_9), :question => question)
    unrelated_qi = ThreeSixty::SurveyAssesseeQuestionInfo.create(:survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_1), :question => three_sixty_questions(:delegating_1))
    assert_false unrelated_qi.question == question
    assert question_info.reload.related_question_infos.include?(related_qi)
    assert_false question_info.reload.related_question_infos.include?(unrelated_qi)
  end

  def test_presence_of_survey_assessee
    question_info = ThreeSixty::SurveyAssesseeQuestionInfo.new(:question => three_sixty_questions(:listening_1), :average_value => 0.0, :answer_count => 0)
    question_info.save
    assert_equal ["can't be blank"], question_info.errors[:three_sixty_survey_assessee_id]
  end

  def test_presence_of_question
    question_info = ThreeSixty::SurveyAssesseeQuestionInfo.new(:survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_1), :average_value => 0.0, :answer_count => 0)
    question_info.save
    assert_equal ["can't be blank"], question_info.errors[:three_sixty_question_id]
  end

  def test_uniqueness_of_question
    question_info = ThreeSixty::SurveyAssesseeQuestionInfo.new(:question => three_sixty_questions(:listening_1), :survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_1), :average_value => 0.0, :answer_count => 0)
    question_info.save
    assert_equal ["has already been taken"], question_info.errors[:three_sixty_question_id]

    question_info_2 = ThreeSixty::SurveyAssesseeQuestionInfo.new(:question => three_sixty_questions(:listening_1), :survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_1), :average_value => 1.0, :answer_count => 1, :reviewer_group => ThreeSixty::ReviewerGroup.last)
    question_info_2.save
    assert question_info_2.valid?

    question_info_3 = ThreeSixty::SurveyAssesseeQuestionInfo.new(:question => three_sixty_questions(:listening_1), :survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_1), :average_value => 2.0, :answer_count => 2, :reviewer_group => ThreeSixty::ReviewerGroup.last)
    question_info_3.save
    assert_equal ["has already been taken"], question_info_3.errors[:three_sixty_question_id]
  end

  def test_presence_of_average_value
    question_info = ThreeSixty::SurveyAssesseeQuestionInfo.new(:question => three_sixty_questions(:listening_1), :survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_2), :average_value => nil, :answer_count => 0)
    question_info.save
    assert_equal ["can't be blank"], question_info.errors[:average_value]
  end

  def test_presence_of_answer_count
    question_info = ThreeSixty::SurveyAssesseeQuestionInfo.new(:question => three_sixty_questions(:listening_1), :survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_2), :average_value => 0.0, :answer_count => nil)
    question_info.save
    assert_equal ["can't be blank"], question_info.errors[:answer_count]
  end
end