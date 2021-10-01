require_relative './../../../../../../test_helper'

class SurveyAnswerPopulatorTest < ActiveSupport::TestCase
  def test_add_survey_answers
    program = programs(:albers)
    survey_ids = program.surveys.pluck(:id).sort.first(5)
    to_add_survey_question_ids =  SurveyQuestion.where(:survey_id => survey_ids).pluck(:id)
    to_remove_survey_question_ids = SurveyAnswer.pluck(:common_question_id).uniq.last(5)
    SurveyAnswer.unscoped do
      populator_add_and_remove_objects("survey_answer", "survey_question", to_add_survey_question_ids, to_remove_survey_question_ids, {program: program})
    end
  end
end