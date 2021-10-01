require_relative './../../../../../../test_helper'

class ThreeSixtySurveyAssesseeCompetencyInfoPopulatorTest < ActiveSupport::TestCase
  def test_add_three_sixty_survey_assessee_competency_infos
    program = programs(:albers)
    to_add_three_sixty_survey_assessee_ids = program.three_sixty_survey_assessees.pluck(:id).first(5)
    to_remove_three_sixty_survey_assessee_ids = ThreeSixty::SurveyAssesseeCompetencyInfo.pluck(:three_sixty_survey_assessee_id).uniq.last(5)
    populator_add_and_remove_objects("three_sixty_survey_assessee_competency_info", "three_sixty_survey_assessee", to_add_three_sixty_survey_assessee_ids, to_remove_three_sixty_survey_assessee_ids, {program: program, model: "three_sixty/survey_assessee_competency_info"})
  end
end