require_relative './../../../../../../test_helper'

class SurveyQuestionPopulatorTest < ActiveSupport::TestCase
  def test_add_survey_questions
    program = programs(:albers)
    to_add_survey_ids = program.surveys.pluck(:id).first(5)
    to_remove_survey_ids = SurveyQuestion.pluck(:survey_id).uniq.first(5)
    populator_add_and_remove_objects("survey_question", "survey", to_add_survey_ids, to_remove_survey_ids, {program: program, additional_populator_class_options: {common: {"translation_locales" => ["fr-CA", "en"]}}})
  end

  def test_add_survey_questions_for_portal
    program = programs(:primary_portal)
    create_program_survey({program: program, recipient_role_names: [RoleConstants::EMPLOYEE_NAME]})
    to_add_survey_ids = program.reload.surveys.pluck(:id).first(5)
    to_remove_survey_ids = SurveyQuestion.pluck(:survey_id).uniq.first(5)
    populator_add_and_remove_objects("survey_question", "survey", to_add_survey_ids, to_remove_survey_ids, {program: program, additional_populator_class_options: {common: {"translation_locales" => ["fr-CA", "en"]}}})
  end
end