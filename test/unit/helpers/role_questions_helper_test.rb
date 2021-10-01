require_relative './../../test_helper.rb'

class RoleQuestionsHelperTest < ActionView::TestCase

  def test_private_question_help_text
    q1 = profile_questions(:profile_questions_1)
    self.expects(:current_user_or_member).at_least(0).returns(User.first)
    program = programs(:albers)
    mentor_role = program.get_role(RoleConstants::MENTOR_NAME)
    mentee_role = program.get_role(RoleConstants::STUDENT_NAME)
    user_role = program.get_role("user")
    self.stubs(:wob_member).returns(members(:f_admin))

    role_question1 = q1.role_questions.where(role_id: mentor_role.id).first
    role_question2 = q1.role_questions.where(role_id: mentee_role.id).first

    role_question1.update_attributes!(private: RoleQuestion::PRIVACY_SETTING::ALL)
    role_question2.update_attributes!(private: RoleQuestion::PRIVACY_SETTING::ALL)
    assert_nil private_question_help_text(q1, program, "mentor_student")

    role_question2.update_attributes!(private: RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    assert_nil private_question_help_text(q1, program, "mentor")
    assert_nil private_question_help_text(q1, program, "mentor_student")
    assert_equal "This field will be visible only to the program administrators", private_question_help_text(q1, program, RoleConstants::STUDENT_NAME)

    role_question1.update_attributes!(private: RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY)
    assert_equal "This field will be visible to user and administrators.", private_question_help_text(q1, program, "mentor_student")
    assert_equal "This field will be visible to user and administrators.", private_question_help_text(q1, program, RoleConstants::MENTOR_NAME)
    assert_equal "This field will be visible only to the program administrators", private_question_help_text(q1, program, RoleConstants::STUDENT_NAME)

    role_question1.privacy_settings.build(setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS)
    role_question1.update_attributes(:private => RoleQuestion::PRIVACY_SETTING::RESTRICTED)
    assert_equal "This field will be visible to user, users with whom they are connected, and administrators.", private_question_help_text(q1, program, "mentor_student")
    assert_equal "This field will be visible to user, users with whom they are connected, and administrators.", private_question_help_text(q1, program, RoleConstants::MENTOR_NAME)
    assert_equal "This field will be visible only to the program administrators", private_question_help_text(q1, program, RoleConstants::STUDENT_NAME)

    role_question2.privacy_settings.build(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentor_role.id)
    role_question2.update_attributes(:private => RoleQuestion::PRIVACY_SETTING::RESTRICTED)
    assert_equal "This field will be visible to user, users with whom they are connected, mentors, and administrators.", private_question_help_text(q1, program, "mentor_student")
    assert_equal "This field will be visible to user, users with whom they are connected, and administrators.", private_question_help_text(q1, program, RoleConstants::MENTOR_NAME)
    assert_equal "This field will be visible to user, mentors, and administrators.", private_question_help_text(q1, program, RoleConstants::STUDENT_NAME)

    role_question1.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentee_role.id)
    role_question1.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: user_role.id)
    assert_nil private_question_help_text(q1, program, "mentor_student")
    assert_equal "This field will be visible to user, users with whom they are connected, students, users, and administrators.", private_question_help_text(q1, program, RoleConstants::MENTOR_NAME)
    assert_equal "This field will be visible to user, mentors, and administrators.", private_question_help_text(q1, program, RoleConstants::STUDENT_NAME)

    self.stubs(:wob_member).returns(members(:f_student))
    assert_nil private_question_help_text(q1, program, "mentor_student")
    assert_equal "This field will be visible to you, users with whom you are connected, students, users, and administrators.", private_question_help_text(q1, program, RoleConstants::MENTOR_NAME)
    assert_equal "This field will be visible to you, mentors, and administrators.", private_question_help_text(q1, program, RoleConstants::STUDENT_NAME)

    self.stubs(:wob_member).returns(members(:f_admin))
    @is_self_view = true
    assert_nil private_question_help_text(q1, program, "mentor_student")
    assert_equal "This field will be visible to you, users with whom you are connected, students, users, and administrators.", private_question_help_text(q1, program, RoleConstants::MENTOR_NAME)
    assert_equal "This field will be visible to you, mentors, and administrators.", private_question_help_text(q1, program, RoleConstants::STUDENT_NAME)
  end

  def test_private_question_help_text_for_portals
    q1 = profile_questions(:nch_string_q)
    self.expects(:current_user_or_member).at_least(0).returns(User.first)
    program = programs(:primary_portal)
    employee_role = program.get_role(RoleConstants::EMPLOYEE_NAME)
    self.stubs(:wob_member).returns(members(:f_admin))

    role_question = q1.role_questions.where(role_id: employee_role.id).first

    role_question.update_attributes!(private: RoleQuestion::PRIVACY_SETTING::ALL)
    assert_nil private_question_help_text(q1, program, RoleConstants::EMPLOYEE_NAME)

    role_question.update_attributes!(private: RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    assert_equal "This field will be visible only to the program administrators", private_question_help_text(q1, program, RoleConstants::EMPLOYEE_NAME)

    role_question.update_attributes!(private: RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY)
    assert_equal "This field will be visible to user and administrators.", private_question_help_text(q1, program, RoleConstants::EMPLOYEE_NAME)

    role_question.privacy_settings.build(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: employee_role.id)
    role_question.update_attributes(:private => RoleQuestion::PRIVACY_SETTING::RESTRICTED)
    assert_nil private_question_help_text(q1, program, RoleConstants::EMPLOYEE_NAME)
  end

  def test_set_check_and_disabled
    role_question = RoleQuestion.new
    assert_equal [true, true], set_check_disabled({}, role_question, ProfileQuestion::Type::NAME)
    assert_equal [true, true], set_check_disabled({privacy_type: RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE}, role_question, nil)
    assert_equal [true, true], set_check_disabled({privacy_type: RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY}, role_question, nil)
    assert_equal [true, false], set_check_disabled({privacy_type: RoleQuestion::PRIVACY_SETTING::RESTRICTED}, role_question, nil)

    role_question = role_questions(:string_role_q)
    assert_equal [true, true], set_check_disabled({privacy_type: RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY}, role_question, nil)

    role_question.update_attributes!(private: RoleQuestion::PRIVACY_SETTING::RESTRICTED)
    assert_equal [true, true], set_check_disabled({privacy_type: RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY}, role_question, nil)

    role_question.update_attributes!(private: RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    assert_equal [false, false], set_check_disabled({privacy_type: RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY}, role_question, nil)
    assert_equal [false, false], set_check_disabled({privacy_type: RoleQuestion::PRIVACY_SETTING::RESTRICTED, privacy_setting: {setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS}}, role_question, nil)

    role_question.private = RoleQuestion::PRIVACY_SETTING::RESTRICTED
    role_question.privacy_settings.build(setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS)
    role_question.save!
    assert_equal [true, false], set_check_disabled({privacy_type: RoleQuestion::PRIVACY_SETTING::RESTRICTED, privacy_setting: {setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS}}, role_question, nil)

    role_question.update_attributes!(private: RoleQuestion::PRIVACY_SETTING::ALL)
    assert_equal [true, false], set_check_disabled({privacy_type: RoleQuestion::PRIVACY_SETTING::RESTRICTED, privacy_setting: {setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS}}, role_question, nil)
  end

  def test_get_privacy_settings_hash
    program = programs(:albers)
    profile_question = profile_questions(:string_q)
    role_question = role_questions(:string_role_q)
    mentor_role = program.roles.with_name(RoleConstants::MENTOR_NAME).first
    mentee_role = program.roles.with_name(RoleConstants::STUDENT_NAME).first
    user_role = program.roles.with_name("user").first
    expected_output = {
      "Administrators" => {
        checked: true,
        name: "role_questions[#{mentor_role.id}][privacy_settings][#{RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE}]",
        options: {
          class: "role_questions_private",
          id: "role_questions_private_#{profile_question.id}_#{mentor_role.id}_#{RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE}",
          value: 1,
          onchange: "CustomizeProfileQuestions.updateOptions('#{profile_question.id}','#{mentor_role.id}', #{profile_question.question_type})",
          disabled: true
        }
      },
      "User" => {
        checked: true,
        name: "role_questions[#{mentor_role.id}][privacy_settings][#{RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY}]",
        options: {
          class: "role_questions_private",
          id: "role_questions_private_#{profile_question.id}_#{mentor_role.id}_#{RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY}",
          value: 1,
          onchange: "CustomizeProfileQuestions.updateOptions('#{profile_question.id}','#{mentor_role.id}', #{profile_question.question_type})",
          disabled: true
        }
      },
      "User's mentoring connections" => {
        checked: true,
        name: "role_questions[#{mentor_role.id}][privacy_settings][#{RoleQuestion::PRIVACY_SETTING::RESTRICTED}][#{RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS}]",
        options: {
          class: "role_questions_private role_questions_private_#{profile_question.id}_#{mentor_role.id}_restricted",
          id: "role_questions_private_#{profile_question.id}_#{mentor_role.id}_#{RoleQuestion::PRIVACY_SETTING::RESTRICTED}-#{RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS}",
          value: 1,
          onchange: "CustomizeProfileQuestions.updateOptions('#{profile_question.id}','#{mentor_role.id}', #{profile_question.question_type})",
          disabled: false
        }
      },
      "All mentors" => {
        checked: true,
        name: "role_questions[#{mentor_role.id}][privacy_settings][#{RoleQuestion::PRIVACY_SETTING::RESTRICTED}][#{RoleQuestionPrivacySetting::SettingType::ROLE}][#{mentor_role.id}]",
        options: {
          class: "role_questions_private role_questions_private_#{profile_question.id}_#{mentor_role.id}_restricted role_questions_private_#{profile_question.id}_#{mentor_role.id}_restricted_role",
          id: "role_questions_private_#{profile_question.id}_#{mentor_role.id}_#{RoleQuestion::PRIVACY_SETTING::RESTRICTED}-#{RoleQuestionPrivacySetting::SettingType::ROLE}-#{mentor_role.id}",
          value: 1,
          onchange: "CustomizeProfileQuestions.updateOptions('#{profile_question.id}','#{mentor_role.id}', #{profile_question.question_type})",
          disabled: false
        }
      },
      "All students" => {
        checked: true,
        name: "role_questions[#{mentor_role.id}][privacy_settings][#{RoleQuestion::PRIVACY_SETTING::RESTRICTED}][#{RoleQuestionPrivacySetting::SettingType::ROLE}][#{mentee_role.id}]",
        options: {
          class: "role_questions_private role_questions_private_#{profile_question.id}_#{mentor_role.id}_restricted role_questions_private_#{profile_question.id}_#{mentor_role.id}_restricted_role",
          id: "role_questions_private_#{profile_question.id}_#{mentor_role.id}_#{RoleQuestion::PRIVACY_SETTING::RESTRICTED}-#{RoleQuestionPrivacySetting::SettingType::ROLE}-#{mentee_role.id}",
          value: 1,
          onchange: "CustomizeProfileQuestions.updateOptions('#{profile_question.id}','#{mentor_role.id}', #{profile_question.question_type})",
          disabled: false
        }
      },
      "All users" => {
        checked: true,
        name: "role_questions[#{mentor_role.id}][privacy_settings][#{RoleQuestion::PRIVACY_SETTING::RESTRICTED}][#{RoleQuestionPrivacySetting::SettingType::ROLE}][#{user_role.id}]",
        options: {
          class: "role_questions_private role_questions_private_#{profile_question.id}_#{mentor_role.id}_restricted role_questions_private_#{profile_question.id}_#{mentor_role.id}_restricted_role",
          id: "role_questions_private_#{profile_question.id}_#{mentor_role.id}_#{RoleQuestion::PRIVACY_SETTING::RESTRICTED}-#{RoleQuestionPrivacySetting::SettingType::ROLE}-#{user_role.id}",
          value: 1,
          onchange: "CustomizeProfileQuestions.updateOptions('#{profile_question.id}','#{mentor_role.id}', #{profile_question.question_type})",
          disabled: false
        }
      }
    }
    assert_equal expected_output, get_privacy_settings_hash(program, profile_question.id, role_question.role_id, profile_question.question_type, role_question, profile_question)
  end

private

  def _program
    "program"
  end

end