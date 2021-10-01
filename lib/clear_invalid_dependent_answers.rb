module ClearInvalidDependentAnswers
  #To clear the invalid answers created for hidden dependent fields
  def clear_invalid_answers(object_id, object_klass, organization_id, profile_question_ids=[])
    object = object_klass.find_by(id: object_id)
    organization = Organization.find_by(id: organization_id)
    return unless object.present? && organization.present? && profile_question_ids.present?
    all_answers = object.profile_answers.includes(:profile_question)
    conditional_questions = organization.profile_questions.where(id: profile_question_ids).includes(:dependent_questions).select{|q| q.has_dependent_questions? }
    all_answers = all_answers.group_by(&:profile_question_id)
    conditional_questions.each do |cond_ques|
      cond_ques.dependent_questions.each do |dep_ques|
        dep_ques.remove_dependent_tree_answers(all_answers) unless dep_ques.conditional_text_matches?(all_answers)
      end
    end
  end
end