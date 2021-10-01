class AnswerChoiceObserver < ActiveRecord::Observer

  def after_destroy(answer_choice)
    return if answer_choice.marked_for_destruction?
    # Profile answer / Common Answer deletion should be handled if the question choices are destroyed.
    ref_obj = answer_choice.ref_obj
    if (!answer_choice.skip_parent_destroy) && ref_obj && ref_obj.answer_choices.empty? && ref_obj.get_question.choice_or_select_type?
      ref_obj.destroy
    end
  end

end