require_relative './../../../test_helper.rb'

class ThreeSixty::SurveyAnswerServiceTest < ActiveSupport::TestCase
  def test_process_answers
    sq_1 = three_sixty_survey_questions(:three_sixty_survey_questions_1)
    sq_2 = three_sixty_survey_questions(:three_sixty_survey_questions_2)
    sq_3 = three_sixty_survey_questions(:three_sixty_survey_questions_3)
    ThreeSixty::SurveyAnswer.destroy_all

    assert_no_difference "ThreeSixty::SurveyAnswer.count" do
      ThreeSixty::SurveyAnswerService.new(three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1)).process_answers([])
    end

    assert_difference "ThreeSixty::SurveyAnswer.count", 2 do
      ThreeSixty::SurveyAnswerService.new(three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1)).process_answers({ "#{sq_1.id}" => "1", "#{sq_2.id}" => "", "#{sq_3.id}" => "Answer to OEQ"})
    end
    assert_equal  1, ThreeSixty::SurveyAnswer.first.answer_value
    assert_nil  ThreeSixty::SurveyAnswer.first.answer_text

    assert_difference "ThreeSixty::SurveyAnswer.count", 1 do
      ThreeSixty::SurveyAnswerService.new(three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1)).process_answers({ "#{sq_2.id}" => "some text"})
    end
    assert_equal  "some text", ThreeSixty::SurveyAnswer.last.answer_text
    assert_nil  ThreeSixty::SurveyAnswer.last.answer_value

    assert_difference "ThreeSixty::SurveyAnswer.count", -2 do
      ThreeSixty::SurveyAnswerService.new(three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1)).process_answers({ "#{sq_2.id}" => "", "#{sq_3.id}" => ""})
    end
    assert_equal  1, ThreeSixty::SurveyAnswer.last.answer_value
    assert_nil  ThreeSixty::SurveyAnswer.last.answer_text

    assert_difference "ThreeSixty::SurveyAnswer.count", 1 do
      ThreeSixty::SurveyAnswerService.new(three_sixty_survey_reviewers(:three_sixty_survey_reviewers_1)).process_answers({ "#{sq_1.id}" => "5", "#{sq_2.id}" => "some other text"})
    end
    assert_equal  5, ThreeSixty::SurveyAnswer.first.answer_value
    assert_nil  ThreeSixty::SurveyAnswer.first.answer_text
    assert_equal  "some other text", ThreeSixty::SurveyAnswer.last.answer_text
    assert_nil  ThreeSixty::SurveyAnswer.last.answer_value
  end
end