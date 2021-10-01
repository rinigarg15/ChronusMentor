require_relative '../test_helper'

class ExplicitUserPreferenceTest < ActiveSupport::TestCase
  def test_validations
    user_1 = users(:f_student)
    role_question_1 = role_questions(:student_multi_choice_role_q)

    new_explicit_preference = ExplicitUserPreference.new
    assert_false new_explicit_preference.valid?
    assert_equal ["can't be blank"], new_explicit_preference.errors.messages[:user]
    assert_equal ["can't be blank"], new_explicit_preference.errors.messages[:role_question]

    new_explicit_preference.user = user_1
    new_explicit_preference.role_question = role_question_1
    assert_false new_explicit_preference.valid?
    assert_equal ["can't be blank"], new_explicit_preference.errors.messages[:question_choices]
    new_explicit_preference.question_choices = [question_choices(:student_multi_choice_q_1)]
    assert new_explicit_preference.valid?
    new_explicit_preference.save!

    location_role_question = user_1.roles.first.role_questions.select{|role_que| role_que.profile_question.location?}.first
    new_explicit_preference_2 = ExplicitUserPreference.new
    new_explicit_preference_2.user = user_1
    new_explicit_preference_2.role_question = location_role_question
    assert_false new_explicit_preference_2.valid?
    assert_equal ["can't be blank"], new_explicit_preference_2.errors.messages[:preference_string]
    new_explicit_preference_2.preference_string = "Chennai, Tamilnadu, India"
    assert new_explicit_preference_2.valid?
  end

  def test_associations
    user = users(:f_mentor_student)
    role_question = role_questions(:student_multi_choice_role_q)
    assert_difference 'ExplicitUserPreference.count' do
      @new_explicit_preference = ExplicitUserPreference.create!(
        { user: user,
          role_question: role_question,
          preference_weight: 5,
          question_choices: [question_choices(:student_multi_choice_q_1)]
        })
    end
    assert_equal user, @new_explicit_preference.user
    assert_equal role_question, @new_explicit_preference.role_question
    assert user.explicit_user_preferences.include?(@new_explicit_preference)
    assert role_question.explicit_user_preferences.include?(@new_explicit_preference)
    single_choice_question_choices = [question_choices(:single_choice_q_1), question_choices(:single_choice_q_2)]
    assert_difference 'UserPreferenceChoice.count', 2 do
      @new_explicit_preference_2 = ExplicitUserPreference.create!(
        { user: user,
          role_question: role_questions(:single_choice_role_q),
          question_choices: single_choice_question_choices
        })
    end
    assert_equal_unordered single_choice_question_choices, @new_explicit_preference_2.question_choices
  end

  def test_profile_question
    ep = explicit_user_preferences(:explicit_user_preference_1)
    rq = ep.role_question
    assert_equal rq.profile_question, ep.profile_question
  end

  def test_location_type
    ep = explicit_user_preferences(:explicit_user_preference_1)
    pq = ProfileQuestion.first
    ep.stubs(:profile_question).returns(pq)
    pq.stubs(:location?).returns(false)
    assert_false ep.location_type?

    pq.stubs(:location?).returns(true)
    assert ep.location_type?
  end

  def test_weight_scaled_to_one
    ep = explicit_user_preferences(:explicit_user_preference_1)
    ep.stubs(:preference_weight).returns(0)
    assert_equal 0.0, ep.weight_scaled_to_one

    ep.stubs(:preference_weight).returns(2)
    assert_equal 0.4, ep.weight_scaled_to_one

    ep.stubs(:preference_weight).returns(5)
    assert_equal 1.0, ep.weight_scaled_to_one
  end

  def test_populate_default_explicit_user_preferences_from_match_configs
    program = programs(:nwen)
    program.enable_feature(FeatureName::EXPLICIT_USER_PREFERENCES, true)
    student = users(:f_mentor_nwen_student)

    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "single choice same question", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)

    MatchConfig.create!(
      program: program,
      mentor_question: prog_mentor_question,
      student_question: prog_student_question)

    prof_q2 = create_profile_question(question_type: ProfileQuestion::Type::MULTI_CHOICE, question_text: "multi choice different question normal matching", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question2 = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q2)

    MatchConfig.create!(
      program: program,
      mentor_question: prog_mentor_question2,
      student_question: prog_student_question)

    prof_q3 = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "single choice different question set matching", question_choices: ["Choice 10", "Choice 11"], organization: programs(:org_primary))
    prog_mentor_question3 = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q3)

    MatchConfig.create!(
      program: program,
      mentor_question: prog_mentor_question3,
      student_question: prog_student_question,
      matching_type: MatchConfig::MatchingType::SET_MATCHING,
      matching_details_for_matching: {"choice 1" => ["choice 10"], "choice 2" => ["choice 11"]})

    program.organization.profile_questions.where(question_type: ProfileQuestion::Type::LOCATION).destroy_all

    prof_q4 = create_profile_question(question_type: ProfileQuestion::Type::LOCATION, question_text: "Location Question", organization: programs(:org_primary))
    prog_mentor_question4 = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q4)
    prog_student_question4 = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q4)

    MatchConfig.create!(
      program: program,
      mentor_question: prog_mentor_question4,
      student_question: prog_student_question4)

    ProfileAnswer.create!(:ref_obj => student.member, :profile_question => prof_q, :answer_value => "Choice 1")
    ProfileAnswer.any_instance.stubs(:location).returns(locations(:chennai))
    ProfileAnswer.create!(:ref_obj => student.member, :profile_question => prof_q4, :answer_text => "Chennai,Tamil Nadu,India")

    assert_difference "ExplicitUserPreference.count", 4 do
      ExplicitUserPreference.populate_default_explicit_user_preferences_from_match_configs(student, program)
    end

    assert_equal [prof_q.question_choices.first.text], prog_mentor_question.explicit_user_preferences.first.question_choices.collect(&:text)
    assert_equal [prof_q2.question_choices.first.text], prog_mentor_question2.explicit_user_preferences.first.question_choices.collect(&:text)
    assert_equal [prof_q3.question_choices.first.text], prog_mentor_question3.explicit_user_preferences.first.question_choices.collect(&:text)
    assert_equal prof_q4.profile_answers.first.location.full_city, prog_mentor_question4.explicit_user_preferences.first.preference_string
  end
end
