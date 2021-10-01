class ThreeSixty::SurveyAnswerObserver < ActiveRecord::Observer
  def after_create(survey_answer)
    return unless survey_answer.question.of_rating_type?
    update_question_info_after_create(survey_answer)
    update_competency_info_after_create(survey_answer)
  end

  def after_update(survey_answer)
    return unless survey_answer.question.of_rating_type?
    update_question_info_after_update(survey_answer)
    update_competency_info_after_update(survey_answer)
  end

  # We call handle_destroy from target_deletion script to run the callbacks.
  # Please add any new changes in survey_answer.handle_destroy to maintain integrity.
  def after_destroy(survey_answer)
    survey_answer.handle_destroy
  end

  private

  def update_question_info_after_create(survey_answer)
    # For creating/updating question info for all evaluators
    question_info = survey_answer.question.survey_assessee_question_infos.find_or_initialize_by(three_sixty_survey_assessee_id: survey_answer.survey_assessee.id)
    update_question_info_on_answer_create(question_info, survey_answer)

    # For creating/updating question info for the particular reviewer group
    question_info_for_reviewer_group = survey_answer.question.survey_assessee_question_infos.find_or_initialize_by(three_sixty_survey_assessee_id: survey_answer.survey_assessee.id, three_sixty_reviewer_group_id:  survey_answer.survey_reviewer.reviewer_group.id)
    update_question_info_on_answer_create(question_info_for_reviewer_group, survey_answer)
  end

   def update_question_info_after_update(survey_answer)
    # For updating question info for all evaluators
    question_info = survey_answer.get_question_info
    update_question_info_on_answer_update(question_info, survey_answer)

    # For updating question info for the particular reviewer group
    question_info_for_reviewer_group = survey_answer.get_question_info(survey_answer.survey_reviewer.reviewer_group)
    update_question_info_on_answer_update(question_info_for_reviewer_group, survey_answer)
  end

  def update_competency_info_after_create(survey_answer)
    # For updating competency info for all evaluators
    competency_info = survey_answer.get_competency_info
    update_competency_info_on_answer_create(competency_info, survey_answer)

    # For updating competency info for the particular reviewer group
    competency_info = survey_answer.get_competency_info(survey_answer.survey_reviewer.reviewer_group)
    update_competency_info_on_answer_create(competency_info, survey_answer)
  end

  def update_competency_info_after_update(survey_answer)
    # For updating competency info for all evaluators
    competency_info = survey_answer.get_competency_info
    update_competency_info_on_answer_update(competency_info, survey_answer)

    # For updating competency info for the particular reviewer group
    competency_info = survey_answer.get_competency_info(survey_answer.survey_reviewer.reviewer_group)
    update_competency_info_on_answer_update(competency_info, survey_answer)
  end

  def update_question_info_on_answer_create(question_info, survey_answer)
    new_average_rating = ((question_info.average_value * question_info.answer_count) + survey_answer.answer_value)/(question_info.answer_count + 1)
    question_info.update_attributes!(:average_value => new_average_rating, :answer_count => question_info.answer_count + 1)
  end

  def update_competency_info_on_answer_create(competency_info, survey_answer)
    new_average_rating = ((competency_info.average_value * competency_info.answer_count) + survey_answer.answer_value)/(competency_info.answer_count + 1)
    competency_info.update_attributes!(:average_value => new_average_rating, :answer_count => competency_info.answer_count + 1)
  end

  def update_question_info_on_answer_update(question_info, survey_answer)
    new_average_rating = ((question_info.average_value * question_info.answer_count) + survey_answer.answer_value - survey_answer.answer_value_before_last_save)/question_info.answer_count
    question_info.update_attributes!(:average_value => new_average_rating)
  end

  def update_competency_info_on_answer_update(competency_info, survey_answer)
    new_average_rating = ((competency_info.average_value * competency_info.answer_count) + survey_answer.answer_value - survey_answer.answer_value_before_last_save)/competency_info.answer_count
    competency_info.update_attributes!(:average_value => new_average_rating)
  end

end