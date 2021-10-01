module FirstVisitSectionQuestions

  def handle_answered_and_conditional_questions(profile_member, profile_questions, answered_profile_questions)
    unanswered_profile_questions = profile_questions - answered_profile_questions
    profile_answers_per_question = profile_member.profile_answers.group_by(&:profile_question_id)
    handle_conditional_questions(unanswered_profile_questions, profile_answers_per_question, profile_questions.collect(&:id))
  end

  def handle_conditional_questions(unanswered_profile_questions, profile_answers_per_question, available_question_ids)
    rejected_questions = []
    unanswered_profile_questions.each do |question|
      next if rejected_questions.include?(question.id)
      rejected_questions += question.dependent_questions_tree if conditional_question_unanswered_in_other_section_or_not_available?(question, profile_answers_per_question, available_question_ids)
      next unless conditional_question_answered?(question, profile_answers_per_question)
      conditional_text_matched = question.conditional_text_matches?(profile_answers_per_question)
      if !conditional_text_matched
        rejected_questions += question.dependent_questions_tree
      elsif conditional_question_available_and_in_same_section?(question, available_question_ids)
        unanswered_profile_questions << question.conditional_question
      end
    end
    unanswered_profile_questions.reject!{|q| rejected_questions.include?(q.id)}
    unanswered_profile_questions
  end

  def conditional_question_available_and_in_same_section?(question, available_question_ids)
    (question.section_id == question.conditional_question.section_id) && (available_question_ids.include?(question.conditional_question_id))
  end

  def conditional_question_answered?(question, profile_answers_per_question)
    conditional_question_id = question.conditional_question_id
    conditional_question_id.present? && profile_answers_per_question[conditional_question_id].present?
  end

  def conditional_question_unanswered_in_other_section_or_not_available?(question, profile_answers_per_question, available_question_ids)
    parent_question = question.conditional_question
    parent_question.present? && profile_answers_per_question[parent_question.id].blank? && (parent_question.section_id != question.section_id || !available_question_ids.include?(parent_question.id))
  end
end