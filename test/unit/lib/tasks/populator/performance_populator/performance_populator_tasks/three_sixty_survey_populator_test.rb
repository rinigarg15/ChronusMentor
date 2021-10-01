require_relative './../../../../../../test_helper'

class ThreeSixtySurveyPopulatorTest < ActiveSupport::TestCase
  def test_add_three_sixty_surveys
    org = programs(:org_primary)
    to_add_program_ids = org.programs.pluck(:id).first(5)
    to_remove_program_ids = ThreeSixty::Survey.pluck(:program_id).uniq.last(5)
    populator_add_and_remove_objects("three_sixty_survey", "program", to_add_program_ids, to_remove_program_ids, {organization: org, model: "three_sixty/survey"})
  end
end