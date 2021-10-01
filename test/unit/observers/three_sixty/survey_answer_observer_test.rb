require_relative './../../../test_helper'

class ThreeSixty::SurveyAnswerObserverTest < ActiveSupport::TestCase
  def test_after_create
    survey_assessee = three_sixty_survey_assessees(:three_sixty_survey_assessees_4)
    survey = survey_assessee.survey
    reviewer_group = three_sixty_survey_reviewers(:three_sixty_survey_reviewers_4).reviewer_group

    assert_difference "ThreeSixty::SurveyAssesseeQuestionInfo.count", 2 do
      three_sixty_survey_questions(:three_sixty_survey_questions_5).answers.create!(:survey_reviewer => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_4), :answer_value => 2.0)
    end
    assert_equal ThreeSixty::SurveyAssesseeCompetencyInfo.where("three_sixty_survey_assessee_id = #{survey_assessee.id}").count, 2
    question_infos = ThreeSixty::SurveyAssesseeQuestionInfo.last(2)
    question_infos.each do |question_info|
      assert_equal three_sixty_questions(:listening_1), question_info.question
      assert_equal survey_assessee, question_info.survey_assessee
      assert_equal 2.0, question_info.average_value
      assert_equal 1, question_info.answer_count
    end

    three_sixty_survey_questions(:three_sixty_survey_questions_10).answers.create!(:survey_reviewer => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2), :answer_value => 3.0)
    three_sixty_survey_questions(:three_sixty_survey_questions_11).answers.create!(:survey_reviewer => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2), :answer_value => 5.0)
    assert_equal 4.0, ThreeSixty::SurveyAssesseeCompetencyInfo.where("three_sixty_survey_assessee_id = 2 and three_sixty_reviewer_group_id = 1 and three_sixty_competency_id = ?", three_sixty_competencies(:leadership)).first.average_value

    assert_equal reviewer_group, question_infos.last.reviewer_group

    reviewer = survey_assessee.reviewers.create!(:name => "New reviewer", :email => "new_reviewer@example.com", :survey_reviewer_group => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_4).survey_reviewer_group)
    assert_no_difference "ThreeSixty::SurveyAssesseeQuestionInfo.count" do
      three_sixty_survey_questions(:three_sixty_survey_questions_5).answers.create!(:survey_reviewer => reviewer, :answer_value => 4.0)
    end
    question_infos.each do |question_info|
      assert_equal 3.0, question_info.reload.average_value
      assert_equal 2, question_info.answer_count
    end
    assert_equal reviewer_group, question_infos.last.reviewer_group

    rg = programs(:org_primary).three_sixty_reviewer_groups.create!(:name => "New for test", :threshold => 0)
    survey.reviewer_groups << rg
    another_reviewer = survey_assessee.reviewers.create!(:name => "Another New reviewer", :email => "another_new_reviewer@example.com", :survey_reviewer_group => survey.reload.survey_reviewer_groups.last)
    assert_difference "ThreeSixty::SurveyAssesseeQuestionInfo.count", 1 do
      three_sixty_survey_questions(:three_sixty_survey_questions_5).answers.create!(:survey_reviewer => another_reviewer, :answer_value => 5.0)
    end
    question_info = ThreeSixty::SurveyAssesseeQuestionInfo.last
    assert_equal three_sixty_questions(:listening_1), question_info.question
    assert_equal survey_assessee, question_info.survey_assessee
    assert_equal rg, question_info.reviewer_group
    assert_equal 5.0, question_info.reload.average_value
    assert_equal 1, question_info.answer_count

    assert_equal 3.67, question_infos.first.reload.average_value.round(2)
    assert_equal 3, question_infos.first.answer_count

    question = survey.competencies.last.questions.create!(:title => "new text question", :question_type => ThreeSixty::Question::Type::TEXT, :organization_id => programs(:org_primary).id)
    survey_question = survey.add_question(question)

    assert_false survey_question.question.of_rating_type?
    assert_no_difference "ThreeSixty::SurveyAssesseeQuestionInfo.count" do
      survey_question.answers.create!(:survey_reviewer => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1), :answer_value => 2.0)
    end
  end

  def test_after_update
    answer = three_sixty_survey_answers(:answer_1)
    rg = answer.survey_reviewer.reviewer_group
    question_info = ThreeSixty::SurveyAssesseeQuestionInfo.where(:three_sixty_question_id  => answer.question.id, :three_sixty_survey_assessee_id  => answer.survey_assessee.id).first
    question_info_for_rg = ThreeSixty::SurveyAssesseeQuestionInfo.where(:three_sixty_question_id  => answer.question.id, :three_sixty_survey_assessee_id  => answer.survey_assessee.id, :three_sixty_reviewer_group_id => rg.id).first

    competency_info = ThreeSixty::SurveyAssesseeCompetencyInfo.where(:three_sixty_competency_id  => ThreeSixty::Competency.find(ThreeSixty::Question.find(answer.question.id).three_sixty_competency_id), :three_sixty_survey_assessee_id  => answer.survey_assessee.id).first
    competency_info_for_rg = ThreeSixty::SurveyAssesseeCompetencyInfo.where(:three_sixty_competency_id  => ThreeSixty::Competency.find(ThreeSixty::Question.find(answer.question.id).three_sixty_competency_id), :three_sixty_survey_assessee_id  => answer.survey_assessee.id, :three_sixty_reviewer_group_id => rg.id).first

    assert_equal 3.6, question_info.average_value
    assert_equal 3.6, competency_info.average_value
    assert_equal 5, question_info.answer_count
    assert_equal 5.0, question_info_for_rg.average_value
    assert_equal 5.0, competency_info_for_rg.average_value
    assert_equal 1, question_info_for_rg.answer_count

    assert_no_difference "ThreeSixty::SurveyAssesseeQuestionInfo.count" do
      answer.update_attributes!(:answer_value => 4.0)
    end

    assert_equal 3.4, question_info.reload.average_value
    assert_equal 3.4, competency_info.reload.average_value
    assert_equal 5, question_info.answer_count
    assert_equal 4.0, question_info_for_rg.reload.average_value
    assert_equal 4.0, competency_info_for_rg.reload.average_value
    assert_equal 1, question_info_for_rg.answer_count
  end

  def test_after_destroy
    answer = three_sixty_survey_answers(:answer_1)
    competency_info = ThreeSixty::SurveyAssesseeCompetencyInfo.where(:three_sixty_competency_id  => ThreeSixty::Competency.find(ThreeSixty::Question.find(answer.question.id).three_sixty_competency_id), :three_sixty_survey_assessee_id  => answer.survey_assessee.id).first
    question_info = ThreeSixty::SurveyAssesseeQuestionInfo.where(:three_sixty_question_id  => answer.question.id, :three_sixty_survey_assessee_id  => answer.survey_assessee.id).first
    assert_equal 3.6, question_info.average_value
    assert_equal 3.6, competency_info.average_value
    assert_equal 5, question_info.answer_count
    assert_difference "ThreeSixty::SurveyAssesseeQuestionInfo.count", -1 do
      three_sixty_survey_answers(:answer_1).destroy
    end

    assert_equal 3.25, question_info.reload.average_value
    assert_equal 3.25, competency_info.reload.average_value
    assert_equal 4, question_info.answer_count

    assert_difference "ThreeSixty::SurveyAssesseeQuestionInfo.count", -1 do
      three_sixty_survey_answers(:answer_3).destroy
    end

    assert_equal three_sixty_survey_answers(:answer_5).survey_reviewer.reviewer_group, three_sixty_survey_answers(:answer_7).survey_reviewer.reviewer_group
    assert_no_difference "ThreeSixty::SurveyAssesseeQuestionInfo.count" do
      three_sixty_survey_answers(:answer_5).destroy
    end

    assert_difference "ThreeSixty::SurveyAssesseeQuestionInfo.count", -1 do
      three_sixty_survey_answers(:answer_7).destroy
    end

    assert_equal 3.0, question_info.reload.average_value
    assert_equal 3.0, competency_info.reload.average_value
    assert_equal 1, question_info.answer_count

    assert_difference "ThreeSixty::SurveyAssesseeQuestionInfo.count", -2 do
      three_sixty_survey_answers(:answer_9).destroy
    end
  end
end