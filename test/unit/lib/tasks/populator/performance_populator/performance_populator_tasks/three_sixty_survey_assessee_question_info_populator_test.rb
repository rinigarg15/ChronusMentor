require_relative './../../../../../../test_helper'

class ThreeSixtySurveyAssesseeQuestionInfoPopulatorTest < ActiveSupport::TestCase
  def test_add_three_sixty_survey_assessee_question_infos
    program = programs(:albers)
    to_add_three_sixty_survey_assessee_ids = program.three_sixty_survey_assessees.pluck(:id).first(5)
    to_remove_three_sixty_survey_assessee_ids = ThreeSixty::SurveyAssesseeQuestionInfo.pluck(:three_sixty_survey_assessee_id).uniq.last(5)
    populator_add_and_remove_objects("three_sixty_survey_assessee_question_info", "three_sixty_survey_assessee", to_add_three_sixty_survey_assessee_ids, to_remove_three_sixty_survey_assessee_ids, {program: program, model: "three_sixty/survey_assessee_question_info"})
  end
end