class SurveyQuestionFilterService
  def initialize(survey, filter_params, response_ids)
    @survey = survey
    @filter_params = filter_params
    @response_ids = response_ids
  end

  def filtered_response_ids
    apply_survey_question_filters(@filter_params)
  end

  private

  def apply_survey_question_filters(survey_filters)
    response_ids = @response_ids
    survey_filters.each do |filter|
      question_id, operator, value = get_question_id_operator_and_value_from_filter(filter)
      survey_question = @survey.survey_questions_with_matrix_rating_questions.find_by(id: question_id)
      response_ids = response_that_match_filter(operator, value, survey_question, question_id) & response_ids
    end
    response_ids
  end

  def get_question_id_operator_and_value_from_filter(filter)
    question_id = filter["field"].split("answers").last.to_i
    return [question_id, filter["operator"], filter["value"]]
  end

  def response_that_match_filter(operator, value, survey_question, question_id)
    case operator
    when SurveyResponsesDataService::Operators::CONTAINS
      return responses_with_answer_that_contains(value, survey_question, question_id)
    when SurveyResponsesDataService::Operators::NOT_CONTAINS
      return responses_with_answer_that_does_not_contain(value, survey_question, question_id)
    when SurveyResponsesDataService::Operators::FILLED
      return responses_with_answer_filled(question_id)
    when SurveyResponsesDataService::Operators::NOT_FILLED
      return responses_with_answer_not_filled(question_id)
    end
  end

  def responses_with_answer_that_contains(value, survey_question, question_id)
    if CommonQuestion::Type.checkbox_filterable.include?(survey_question.question_type)
      filtered_question_choices = value.split(",").map(&:to_i)
      get_filtered_response_ids_for_choice_based_with_values(question_id, filtered_question_choices)
    else
      SurveyAnswer.get_es_survey_answers(match_query: {"answer_text.language_*" => QueryHelper::EsUtils.sanitize_es_query(value.strip)}, filter: {common_question_id: question_id, survey_id: @survey.id, is_draft: false}, source_columns: ["response_id"]).collect(&:response_id)
    end
  end

  def responses_with_answer_that_does_not_contain(value, survey_question, question_id)
    @response_ids - responses_with_answer_that_contains(value, survey_question, question_id)
  end

  def responses_with_answer_filled(survey_question_id)
    @survey.survey_answers.where(common_question_id: survey_question_id).pluck(:response_id)
  end

  def responses_with_answer_not_filled(survey_question_id)
    @response_ids - responses_with_answer_filled(survey_question_id)
  end

  def get_filtered_response_ids_for_choice_based_with_values(survey_question_id, filtered_question_choices)
    response_ids = []
    response_answer_hash = @survey.survey_answers.includes(:answer_choices).select([:id, :response_id, :common_question_id]).where(:common_question_id => survey_question_id).group_by(&:response_id)
    response_answer_hash.each do |response_id, survey_answer|
      response_ids << response_id if survey_answer.first.answer_choices.any?{|ac| filtered_question_choices.include?(ac.question_choice_id)}
    end
    response_ids.uniq
  end
end