class CommonQuestionObserver < ActiveRecord::Observer

  def after_update(common_question)
    cleanup_answers(common_question)
  end

  def before_save(common_question)
    default_locale_question_text = common_question.translations.find_by(locale: I18n.default_locale).try(:question_text)
    common_question.question_text = common_question.question_text.to_s.strip unless common_question.question_text == default_locale_question_text
    common_question.allow_other_option = false unless common_question.select_type?
    true
  end

  private

  def cleanup_answers(common_question)
    if common_question.saved_change_to_question_type?
      if !was_choice_based?(common_question) && common_question.choice_based?
        # If the question was earlier non-choice based and now its choice based, delete all answers
        common_question.common_answers.destroy_all
        return
      elsif CommonQuestion::Type.choice_based_types.include?(common_question.question_type_before_last_save) && !CommonQuestion::Type.choice_based_types.include?(common_question.question_type)
        # If the question was earlier choice based and now its non-choice based, delete all question_choices
        common_question.question_choices.destroy_all
      elsif (common_question.question_type_before_last_save == CommonQuestion::Type::SINGLE_CHOICE) && (common_question.question_type == CommonQuestion::Type::MULTI_CHOICE)
        # Single choice => multi choice. Compact the answers
        common_question.compact_multi_choice_answer_choices(common_question.common_answers)
        return
      elsif (common_question.question_type_before_last_save == CommonQuestion::Type::SINGLE_CHOICE) && (common_question.question_type == CommonQuestion::Type::RATING_SCALE) && common_question.allow_other_option_before_last_save
        # Single choice => Rating scale. Remove other options as rating scale questions do not support allow_other_option
        common_question.compact_single_choice_answer_choices(common_question.common_answers, true)
        return
      elsif (common_question.question_type_before_last_save == CommonQuestion::Type::MULTI_CHOICE) && ([CommonQuestion::Type::SINGLE_CHOICE, CommonQuestion::Type::RATING_SCALE].include?(common_question.question_type))
        # Multi choice => Single choice, Rating Scale. Cant do much. Destroy the answers
        common_question.common_answers.destroy_all
        return
      end
    end

    update_choices = false
    update_choices ||= (common_question.saved_change_to_allow_other_option? && common_question.allow_other_option_before_last_save)
    common_question.handle_choices_update if update_choices
  end

  def was_choice_based?(common_question)
    [CommonQuestion::Type::SINGLE_CHOICE, CommonQuestion::Type::MULTI_CHOICE, CommonQuestion::Type::RATING_SCALE].include? common_question.question_type_before_last_save
  end
end