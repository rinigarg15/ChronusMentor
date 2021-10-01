class ProfileQuestionObserver < ActiveRecord::Observer

  def after_update(profile_question)
    answers_updated = cleanup_answers(profile_question)

    if profile_question.saved_change_to_question_type? || answers_updated
      profile_question.delta_index_matching
    end
    
    profile_question.diversity_reports.destroy_all if profile_question.saved_change_to_question_type? && (!profile_question.with_question_choices?)
  end

  def before_save(profile_question)
    default_locale_question_text = profile_question.translations.find_by(locale: I18n.default_locale).try(:question_text)
    profile_question.question_text = profile_question.question_text.to_s.strip unless profile_question.question_text == default_locale_question_text
    profile_question.allow_other_option = false unless profile_question.select_type?
    return true
  end

  private

  def cleanup_answers(profile_question)
    if profile_question.saved_change_to_question_type?
      if RoleQuestion::MatchType.match_type_for(profile_question.question_type).blank? && RoleQuestion::MatchType.match_type_for(profile_question.question_type_before_last_save).present?
        cleanup_match_configs(profile_question)
      end

      if ProfileQuestion::Type.set_matching_types.include?(profile_question.question_type_before_last_save) && !ProfileQuestion::Type.set_matching_types.include?(profile_question.question_type)
        reset_match_configs(profile_question)
      end

      cleanup_explicit_user_preferences(profile_question)

      if ProfileQuestionExtension.destroy_all_answers?(profile_question.question_type_before_last_save, profile_question.question_type)
        profile_question.profile_answers.destroy_all
        if ProfileQuestionExtension.choice_based_to_non_choice_based?(profile_question.question_type_before_last_save, profile_question.question_type)
          profile_question.question_choices.destroy_all
        end
        return
      elsif ProfileQuestionExtension.compact_ordered_answers?(profile_question.question_type_before_last_save, profile_question.question_type)
        # Ordered Option => Single choice (retain first answer), Multi Choice (retain all answers).
        profile_question.handle_ordered_options_to_choice_type_conversion
        return
      elsif ProfileQuestionExtension.compact_answers?(profile_question.question_type_before_last_save, profile_question.question_type)
        # Single choice => multi choice. Compact the answers
        profile_question.compact_multi_choice_answer_choices(profile_question.profile_answers)
        return
      elsif ProfileQuestionExtension.keep_first_answer?(profile_question.question_type_before_last_save, profile_question.question_type)
        if profile_question.question_type == ProfileQuestion::Type::EDUCATION
          profile_question.profile_answers.each do |answer|
            next if answer.reload.educations.count <=1
            answer.educations[1..-1].map(&:destroy)
          end
        elsif profile_question.question_type == ProfileQuestion::Type::EXPERIENCE
          profile_question.profile_answers.each do |answer|
            next if answer.reload.experiences.count <=1
            answer.experiences[1..-1].map(&:destroy)
          end
        elsif profile_question.question_type == ProfileQuestion::Type::PUBLICATION
          profile_question.profile_answers.each do |answer|
            next if answer.reload.publications.count <=1
            answer.publications[1..-1].map(&:destroy)
          end
        end
        return
      elsif ProfileQuestionExtension.choice_based_to_non_choice_based?(profile_question.question_type_before_last_save, profile_question.question_type)
        profile_question.question_choices.destroy_all
        return
      end
    end

    update_choices = false
    update_choices ||= (profile_question.saved_change_to_allow_other_option? && profile_question.allow_other_option_before_last_save)
    update_choices ||= (profile_question.ordered_options_type? && profile_question.saved_change_to_options_count? && (profile_question.options_count_before_last_save.to_i > profile_question.options_count.to_i))
    profile_question.handle_choices_update if update_choices
    return update_choices
  end

  def cleanup_match_configs(profile_question)
    profile_question.role_questions.collect(&:delete_match_configs)
  end

  def reset_match_configs(profile_question)
    role_question_ids = profile_question.role_questions.pluck(:id).uniq
    configs = MatchConfig.where("mentor_question_id in (?) OR student_question_id in (?)",role_question_ids, role_question_ids).distinct
    configs.each do |conf|
      conf.save
    end
  end

  def cleanup_explicit_user_preferences(profile_question)
    if (ProfileQuestion::Type.choice_based_types.include?(profile_question.question_type_before_last_save) && !ProfileQuestion::Type.choice_based_types.include?(profile_question.question_type)) || (profile_question.question_type_before_last_save == ProfileQuestion::Type::LOCATION && profile_question.question_type != ProfileQuestion::Type::LOCATION)
      ExplicitUserPreference.destroy_invalid_records(profile_question)
    end
  end
end