class RoleQuestionObserver < ActiveRecord::Observer
  def before_save(question)
    question.filterable = false if question.private?
		return nil
  end

  def before_validation(role_question)
    return unless role_question.new_record?
    profile_question = role_question.profile_question
    if profile_question.file_type? || profile_question.email_type? ||  profile_question.skype_id_type?
      role_question.filterable = false
    end
		return nil
  end

  def after_save(role_question)
    if !role_question.new_record? && role_question.saved_change_to_private?
      role_question.privacy_settings.each(&:destroy) unless role_question.private == RoleQuestion::PRIVACY_SETTING::RESTRICTED
    end
  end

  def after_update(role_question)
    role_question.profile_question.profile_answers.not_applicable.delete_all if role_question.saved_change_to_required? && role_question.required?
    cleanup_explicit_user_preferences(role_question)
  end

  private

  def cleanup_explicit_user_preferences(role_question)
    if !role_question.filterable || role_question.available_for == RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS
      ExplicitUserPreference.destroy_invalid_records(role_question)
    end
  end
end