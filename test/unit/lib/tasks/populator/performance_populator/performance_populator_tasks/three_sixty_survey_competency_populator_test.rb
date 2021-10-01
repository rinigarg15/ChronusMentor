require_relative './../../../../../../test_helper'

class ThreeSixtySurveyCompetencyPopulatorTest < ActiveSupport::TestCase
  def test_add_three_sixty_survey_competencies
    program = programs(:albers)
    to_add_three_sixty_survey_ids = program.three_sixty_surveys.pluck(:id).first(5)
    to_remove_three_sixty_survey_ids = ThreeSixty::SurveyCompetency.pluck(:three_sixty_survey_id).uniq.last(5)
    populator_add_and_remove_objects("three_sixty_survey_competency", "member", to_add_three_sixty_survey_ids, to_remove_three_sixty_survey_ids, {program: program, model: "three_sixty/survey_competency"})
  end
end