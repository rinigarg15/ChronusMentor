require_relative './../../test_helper.rb'

class RoleQuestionObserverTest < ActiveSupport::TestCase

  def test_privacy_settings_on_private_changes
    role_question = role_questions(:private_role_q)

    assert_difference 'RoleQuestionPrivacySetting.count', -1 do
      role_question.private = RoleQuestion::PRIVACY_SETTING::ALL
      role_question.save!
    end
  end

  def test_filterable_on_private_changes
    role_question = role_questions(:string_role_q)
    role_question.filterable = true
    role_question.save!
    assert role_question.filterable

    role_question.private = RoleQuestion::PRIVACY_SETTING::RESTRICTED
    role_question.save!
    assert_false role_question.filterable

    role_question = RoleQuestion.new(profile_question_id: profile_questions(:string_q).id, role_id: programs(:albers).roles.with_name(RoleConstants::STUDENT_NAME).first.id)
    role_question.filterable = true
    role_question.private = RoleQuestion::PRIVACY_SETTING::ALL
    role_question.save!
    assert role_question.filterable

    role_question.destroy
    role_question = RoleQuestion.new(profile_question_id: profile_questions(:string_q).id, role_id: programs(:albers).roles.with_name(RoleConstants::STUDENT_NAME).first.id)
    role_question.filterable = true
    role_question.private = RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY
    role_question.save!
    assert_false role_question.filterable
  end

  def test_cleanup_explicit_user_preferences
    program = programs(:albers)
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    ExplicitUserPreference.create!(
      { user: users(:f_student),
        role_question: prog_mentor_question,
        question_choices: [prof_q.question_choices.first]
      })
    assert prog_mentor_question.explicit_user_preferences.present?
    prog_mentor_question.filterable = false
    prog_mentor_question.save!
    assert prog_mentor_question.reload.explicit_user_preferences.empty?
  end
end
