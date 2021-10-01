require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/explicit_user_preferences_helper.rb"

class ExplicitUserPreferencesHelperTest < ActionView::TestCase

  def test_question_choices_or_location_preference_display_string
    explicit_preference = explicit_user_preferences(:explicit_user_preference_1)
    assert_equal "<span>" + explicit_preference.question_choices.first.text + "</span>", question_choices_or_location_preference_display_string(explicit_preference)
    explicit_preference = explicit_user_preferences(:explicit_user_preference_4)
    assert_equal "<span>" + explicit_preference.preference_string + "</span>", question_choices_or_location_preference_display_string(explicit_preference)
  end

  def test_get_explicit_preference_configuration_for_user
    assert get_explicit_preference_configuration_for_user(users(:arun_albers))
    assert_false get_explicit_preference_configuration_for_user(users(:f_student))
  end
end