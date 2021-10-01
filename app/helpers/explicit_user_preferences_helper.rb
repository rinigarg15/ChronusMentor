module ExplicitUserPreferencesHelper
  def question_choices_or_location_preference_display_string(explicit_preference)
    content = explicit_preference.question_choices.present? ? explicit_preference.question_choices.collect(&:text).join(", ") : explicit_preference.preference_string
    render_more_less(h(content), ExplicitUserPreference::QUESTION_CHOICES_TRUNCATE_LENGTH, class: 'cjs_stop_propagation')
  end

  def get_explicit_preference_configuration_for_user(user)
    return unless user
    user.explicit_user_preferences.present?
  end
end