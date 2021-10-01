######################################################################
#Running SFTP feed and Import CSV users parallely might create duplicate other choice records. So cleaning other choice records post imports with # cleanup_duplicate_other_choices
#######################################################################
class QuestionChoiceObserver < ActiveRecord::Observer

  def after_destroy(question_choice)
    update_or_destroy_answer(question_choice, true)
  end

  def after_update(question_choice)
    update_or_destroy_answer(question_choice, false) if question_choice.saved_change_to_text?

    if question_choice.ref_obj.is_a?(ProfileQuestion) && !question_choice.is_other_before_last_save && question_choice.is_other
      question_choice.conditional_match_choices.destroy_all
    end
  end


  private

  def update_or_destroy_answer(question_choice, is_destroy)
    if question_choice.ref_obj.is_a?(ProfileQuestion)
      ProfileAnswer.update_or_destroy_answer_text(question_choice, is_destroy)
      question_choice.ref_obj.role_questions.collect(&:refresh_role_questions_match_config_cache)
    elsif question_choice.ref_obj.is_a?(CommonQuestion)
      CommonAnswer.update_or_destroy_answer_text(question_choice, is_destroy)
    end
  end

end