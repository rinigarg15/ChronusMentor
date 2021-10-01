require_relative '../test_helper'

class UserPreferenceChoiceTest < ActiveSupport::TestCase
  def test_validations
    new_user_preference_choice = UserPreferenceChoice.new
    assert_false new_user_preference_choice.valid?
    assert_equal ["can't be blank"], new_user_preference_choice.errors.messages[:explicit_user_preference]
    assert_equal ["can't be blank"], new_user_preference_choice.errors.messages[:question_choice]

    new_user_preference_choice.explicit_user_preference = explicit_user_preferences(:explicit_user_preference_1)
    new_user_preference_choice.question_choice = question_choices(:single_choice_q_1)
    assert new_user_preference_choice.valid?

    new_user_preference_choice.save!
  end

  def test_associations
    explicit_user_preference_1 = explicit_user_preferences(:explicit_user_preference_2)
    question_choice_1 = question_choices(:single_choice_q_1)
    assert_difference 'UserPreferenceChoice.count' do
      @new_user_preference_choice = UserPreferenceChoice.create!(
        { explicit_user_preference: explicit_user_preference_1,
          question_choice: question_choice_1,
        })
    end
    assert_equal explicit_user_preference_1, @new_user_preference_choice.explicit_user_preference
    assert_equal question_choice_1, @new_user_preference_choice.question_choice
  end

  def test_cleanup_explicit_user_preferences
    program = programs(:albers)
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2", "Choice 3"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    question_choice_1 = prof_q.question_choices.first
    question_choice_2 = prof_q.question_choices.second
    ExplicitUserPreference.create!(
      { user: users(:f_student),
        role_question: prog_mentor_question,
        question_choices: [question_choice_1, question_choice_2]
      })
    assert prog_mentor_question.explicit_user_preferences.present?
    question_choice_1.destroy
    assert prog_mentor_question.explicit_user_preferences.present?
    question_choice_2.destroy
    assert prog_mentor_question.reload.explicit_user_preferences.empty?
  end
end
