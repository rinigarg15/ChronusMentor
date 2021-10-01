require_relative './../../test_helper.rb'

class SurveyQuestionFilterServiceTest < ActiveSupport::TestCase

  def setup
    super
    @survey = surveys(:progress_report)
    @question1 = common_questions(:q3_name)
    @question2 = common_questions(:q3_from)
  end

  def test_filtered_response_ids
    sqfs = SurveyQuestionFilterService.new(@survey, "anything", [1,2,3,4,5])
    sqfs.stubs(:apply_survey_question_filters).with("anything").returns("something")
    assert_equal "something", sqfs.filtered_response_ids
  end

  def test_apply_survey_question_filters
    sqfs = SurveyQuestionFilterService.new(@survey, {}, [1,2,3,4,5])
    filter1 = {"field" => "answers#{@question1.id}", "operator" => SurveyResponsesDataService::Operators::CONTAINS, "value" => "mentor"}
    filter2 = {"field" => "answers#{@question2.id}", "operator" => SurveyResponsesDataService::Operators::NOT_CONTAINS, "value" => "Earth"}
    survey_filters = [filter1, filter2]
    sqfs.stubs(:responses_with_answer_that_contains).returns([1,2,3,4])
    sqfs.stubs(:responses_with_answer_that_does_not_contain).returns([3,4,5])
    assert_equal_unordered [3,4], sqfs.send(:apply_survey_question_filters, survey_filters)
  end

  def test_get_question_id_operator_and_value_from_filter
    sqfs = SurveyQuestionFilterService.new("Anything", {}, "Anything")
    filter = {"field" => "answers123", "operator" => SurveyResponsesDataService::Operators::CONTAINS, "value" => "mentor"}
    assert_equal [123, SurveyResponsesDataService::Operators::CONTAINS, "mentor"], sqfs.send(:get_question_id_operator_and_value_from_filter, filter)
  end

  def test_response_that_match_filter
    sqfs = SurveyQuestionFilterService.new(@survey, {}, "Anything")

    sqfs.stubs(:responses_with_answer_that_contains).with("value", @question1, @question1.id).once.returns(1)
    assert_equal 1, sqfs.send(:response_that_match_filter, SurveyResponsesDataService::Operators::CONTAINS, "value", @question1, @question1.id)

    sqfs.stubs(:responses_with_answer_that_does_not_contain).with("value", @question1, @question1.id).once.returns(2)
    assert_equal 2, sqfs.send(:response_that_match_filter, SurveyResponsesDataService::Operators::NOT_CONTAINS, "value", @question1, @question1.id)

    sqfs.stubs(:responses_with_answer_filled).with(@question1.id).once.returns(3)
    assert_equal 3, sqfs.send(:response_that_match_filter, SurveyResponsesDataService::Operators::FILLED, "value", @question1, @question1.id)

    sqfs.stubs(:responses_with_answer_not_filled).with(@question1.id).once.returns(4)
    assert_equal 4, sqfs.send(:response_that_match_filter, SurveyResponsesDataService::Operators::NOT_FILLED, "value", @question1, @question1.id)
  end

  def test_get_filtered_response_ids_for_choice_based_with_values
    sqfs = SurveyQuestionFilterService.new(@survey, {}, "Anything")
    a1 = common_answers(:q3_from_answer_2)
    a2 = common_answers(:q3_from_answer_1)
    assert_equal [a1.response_id], sqfs.send(:get_filtered_response_ids_for_choice_based_with_values, @question2.id, [question_choices(:q3_from_3).id])
    assert_equal [a2.response_id], sqfs.send(:get_filtered_response_ids_for_choice_based_with_values, @question2.id, [question_choices(:q3_from_1).id])
    assert_equal_unordered [a2.response_id, a1.response_id], sqfs.send(:get_filtered_response_ids_for_choice_based_with_values, @question2.id, question_choices(:q3_from_1, :q3_from_3).collect(&:id))
    assert_equal [], sqfs.send(:get_filtered_response_ids_for_choice_based_with_values, @question2.id, [question_choices(:q3_from_2).id])
  end

  def test_responses_with_answer_that_contains
    SurveyAnswer.expects(:get_es_survey_answers).with({:match_query=>{'answer_text.language_*'=>"remove"}, :filter=>{:common_question_id=>@question1.id, :survey_id=>@survey.id, :is_draft=>false}, :source_columns=>["response_id"]}).returns([Elasticsearch::Model::HashWrapper.new(response_id: 1), Elasticsearch::Model::HashWrapper.new(response_id: 2)])
    SurveyAnswer.expects(:get_es_survey_answers).with({:match_query=>{'answer_text.language_*'=>"Something that doesnt exist"}, :filter=>{:common_question_id=>@question1.id, :survey_id=>@survey.id, :is_draft=>false}, :source_columns=>["response_id"]}).returns([])
    sqfs = SurveyQuestionFilterService.new(@survey, {}, "Anything")
    assert_false CommonQuestion::Type.checkbox_filterable.include?(@question1.question_type)
    response_ids = @question1.common_answers.pluck(:response_id).uniq
    assert_equal_unordered response_ids, sqfs.send(:responses_with_answer_that_contains, "remove", @question1, @question1.id)
    assert_equal [], sqfs.send(:responses_with_answer_that_contains, "Something that doesnt exist", @question1, @question1.id)

    assert CommonQuestion::Type.checkbox_filterable.include?(@question2.question_type)
    sqfs.stubs(:get_filtered_response_ids_for_choice_based_with_values).with(@question2.id, [998, 999]).returns([1,5])
    assert_equal [1,5], sqfs.send(:responses_with_answer_that_contains, "998,999", @question2, @question2.id)
  end

  def test_responses_with_answer_that_does_not_contain
    sqfs = SurveyQuestionFilterService.new(@survey, {}, [1,2,3,4,5])
    SurveyQuestionFilterService.any_instance.stubs(:responses_with_answer_that_contains).with("something", @question1, @question1.id).returns([3,4])
    assert_equal [1,2,5], sqfs.send(:responses_with_answer_that_does_not_contain, "something", @question1, @question1.id)
  end

  def test_responses_with_answer_filled
    response_ids = @question1.common_answers.pluck(:response_id).uniq
    assert response_ids.present?
    sqfs = SurveyQuestionFilterService.new(@survey, {}, "Anything")
    assert_equal response_ids, sqfs.send(:responses_with_answer_filled, @question1.id)
  end

  def test_responses_with_answer_not_filled
    sqfs = SurveyQuestionFilterService.new(@survey, {}, [1,2,3,4,5])
    SurveyQuestionFilterService.any_instance.stubs(:responses_with_answer_filled).with(77).returns([3,4])
    assert_equal [1,2,5], sqfs.send(:responses_with_answer_not_filled, 77)
  end

end