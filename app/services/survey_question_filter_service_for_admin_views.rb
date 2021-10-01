class SurveyQuestionFilterServiceForAdminViews
  def initialize(filter_params, user_ids)
    @filter_params = filter_params
    @user_ids = user_ids
  end

  def filtered_user_ids
    apply_survey_question_filters(@filter_params)
  end

  private

  def apply_survey_question_filters(survey_filters)
    user_ids = @user_ids
    survey_filters.each_pair do |key, filter|
      survey, survey_question, operator, value = get_question_operator_and_value_from_filter(filter)
      if survey.present? && survey_question.present? && operator.present?
        user_ids = user_that_match_filter(survey, operator, value, survey_question) & user_ids
      end
    end
    user_ids
  end

  def get_question_operator_and_value_from_filter(filter)
    survey = Survey.find_by(:id => filter[:survey_id].to_i)
    question_id = filter[:question].present? ? filter[:question].split("answers").last.to_i : ""
    survey_question = survey.present? ? survey.survey_questions_with_matrix_rating_questions.find_by(id: question_id) : "" 
    value = survey_question.present? ? (survey_question.choice_based? ? filter[:choice] : filter[:value]) : "" 
    return [survey, survey_question, filter[:operator], value ]
  end

  def user_that_match_filter(survey, operator, value, survey_question)
    case operator
    when AdminViewsHelper::QuestionType::WITH_VALUE.to_s 
      return users_with_answer_that_contains(survey, survey_question, value)
    when AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s
      return users_with_answer_that_does_not_contain(survey, survey_question, value)
    when AdminViewsHelper::QuestionType::ANSWERED.to_s
      return users_with_answer_filled(survey, survey_question)
    when AdminViewsHelper::QuestionType::NOT_ANSWERED.to_s
      return users_with_answer_not_filled(survey, survey_question)
    end
  end

  def users_with_answer_that_contains(survey, survey_question, value)
    if CommonQuestion::Type.checkbox_filterable.include?(survey_question.question_type)
      filtered_question_choices = value.split(",").map(&:to_i)
      get_filtered_user_ids_for_choice_based_with_values(survey, survey_question.id, filtered_question_choices)
    else
      SurveyAnswer.get_es_survey_answers(match_query: {"answer_text.language_*" => QueryHelper::EsUtils.sanitize_es_query(value.strip)}, filter: {common_question_id: survey_question.id, survey_id: survey.id, is_draft: false}, source_columns: ["user_id"]).collect(&:user_id)
    end
  end

  def users_with_answer_that_does_not_contain(survey, survey_question, value)
    @user_ids - users_with_answer_that_contains(survey, survey_question, value)
  end

  def users_with_answer_filled(survey, survey_question)
    survey.survey_answers.where(common_question_id: survey_question.id).pluck(:user_id).uniq
  end

  def users_with_answer_not_filled(survey, survey_question)
    @user_ids - users_with_answer_filled(survey, survey_question)
  end

  def get_filtered_user_ids_for_choice_based_with_values(survey, survey_question_id, filtered_question_choices)
    user_ids = []
    user_answer_hash = survey.survey_answers.includes(:answer_choices).select([:id, :user_id, :common_question_id]).where(:common_question_id => survey_question_id).group_by(&:user_id)
    user_answer_hash.each do |user_id, survey_answers|
      survey_answers.each do |survey_answer|
        user_ids << user_id if survey_answer.answer_choices.any?{|ac| filtered_question_choices.include?(ac.question_choice_id)}
      end
    end
    user_ids.uniq
  end
end