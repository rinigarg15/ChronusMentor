class ProfileAnswerObserver < ActiveRecord::Observer
  def before_save(profile_answer)
    return if profile_answer.skip_observer
    if profile_answer.profile_question.location? && profile_answer.location
      profile_answer.answer_value = profile_answer.location.full_address
    elsif profile_answer.profile_question.education?
      profile_answer.answer_value = profile_answer.educations.to_a
    elsif profile_answer.profile_question.experience?
      profile_answer.answer_value = profile_answer.experiences.to_a
    elsif profile_answer.profile_question.publication?
      profile_answer.answer_value = profile_answer.publications.to_a
    elsif profile_answer.profile_question.manager? && profile_answer.manager
      profile_answer.answer_value = profile_answer.manager.full_data
    end
    profile_answer.not_applicable = false if profile_answer.answer_text.present? || profile_answer.answer_choices.any? || profile_answer.attachment_file_name.present?
    return nil
  end

  def after_save(profile_answer)
    reindex_user(profile_answer)
  end

  def after_destroy(profile_answer)
    reindex_user(profile_answer)
  end

  private

  def reindex_user(profile_answer)
    return unless profile_answer.new_record? || profile_answer.destroyed? || profile_answer.saved_change_to_answer_text? || profile_answer.saved_change_to_location_id? || profile_answer.ref_obj_type == Member.name
    ProfileAnswer.es_reindex(profile_answer)
  end
end