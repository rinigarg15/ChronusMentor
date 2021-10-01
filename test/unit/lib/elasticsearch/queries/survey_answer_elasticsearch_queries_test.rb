require_relative './../../../../test_helper'

class SurveyAnswerElasticsearchQueriesTest < ActiveSupport::TestCase

  def test_get_es_survey_answers
    survey = surveys(:progress_report)
    options = {filter: {survey_id: survey.id, is_draft: false, user_id: [users(:no_mreq_student).id], response_id: [1, 2]}, source_columns: ["response_id"]}
    result = SurveyAnswer.get_es_survey_answers(options)
    assert_equal [2, 2], result.collect(&:response_id)
    # with sort
    options = {filter: {survey_id: survey.id, response_id: [1, 2], common_question_id: common_questions(:q3_name).id, is_draft: false}, sort: [{answer_text_sortable: "desc"}], source_columns: ["response_id"]}
    result = SurveyAnswer.get_es_survey_answers(options)
    assert_equal_unordered [1, 2], result.collect(&:response_id)
    # with match query
    options = {match_query: {"answer_text.language_*" => "remove"}, filter: {common_question_id: common_questions(:q3_name).id, survey_id: survey.id, is_draft: false}, source_columns: ["response_id"]}
    result = SurveyAnswer.get_es_survey_answers(options)
    assert_equal_unordered [2, 1], result.collect(&:response_id)

    start_time = Date.parse("3 June 2016").to_datetime.change(offset: Time.current.strftime("%z")).strftime(ElasticsearchConstants::DATE_RANGE_FORMATS::FORMATS_HASH["yyyy-MM-dd HH:mm:ss ZZ"])
    end_time = Time.now.to_datetime.end_of_day.change(offset: Time.current.strftime("%z")).strftime(ElasticsearchConstants::DATE_RANGE_FORMATS::FORMATS_HASH["yyyy-MM-dd HH:mm:ss ZZ"])
    options = {filter: {survey_id: survey.id, is_draft: false, last_answered_at: start_time..end_time, es_range_formats: {last_answered_at: "yyyy-MM-dd HH:mm:ss ZZ"}, user_id: [users(:no_mreq_admin), users(:no_mreq_student), users(:no_mreq_mentor)].map(&:id), response_id: [1, 2]}, source_columns: ["response_id"]}
    result = SurveyAnswer.get_es_survey_answers(options)
    assert_equal_unordered [1, 1], result.collect(&:response_id)
  end
end