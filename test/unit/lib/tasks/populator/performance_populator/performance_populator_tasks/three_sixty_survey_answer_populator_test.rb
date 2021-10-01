require_relative './../../../../../../test_helper'

class ThreeSixtySurveyAnswerPopulatorTest < ActiveSupport::TestCase
  def test_add_three_sixty_survey_answers
    program = programs(:albers)
    three_sixty_survey = ThreeSixty::Survey.first
    to_add_three_sixty_survey_reviewer_ids = three_sixty_survey.reviewers.pluck(:id)
    to_remove_three_sixty_survey_reviewer_ids = ThreeSixty::SurveyAnswer.pluck(:three_sixty_survey_reviewer_id).uniq.last(5)
    populator_add_and_remove_objects("three_sixty_survey_answer", "three_sixty_survey_reviewer", to_add_three_sixty_survey_reviewer_ids, to_remove_three_sixty_survey_reviewer_ids, {program: program, three_sixty_survey: three_sixty_survey, model: "three_sixty/survey_answer"})
  end
end