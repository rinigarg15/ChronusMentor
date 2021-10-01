Given /^the CD Admin configures the questions with all kinds of visibility modes$/ do
  org = Organization.where(name: "Nation Wide Children Hospital Org").first
  program = org.programs.find_by(name: "Primary Career Portal")

  section1 = org.sections.find_by(title: "Work and Education")
  section2 = org.sections.find_by(title: "More Information")

  current_education_profile_q = org.profile_questions.find_by(question_text: "Current Education")
  age_profile_q = org.profile_questions.find_by(question_text: "How old are you?")
  interest_profile_q = org.profile_questions.find_by(question_text: "What is your interest?")

  employee_role = program.roles.with_name(RoleConstants::EMPLOYEE_NAME).first
  suffix_for_all_employees = "#{RoleQuestion::PRIVACY_SETTING::RESTRICTED}-#{RoleQuestionPrivacySetting::SettingType::ROLE}-#{employee_role.id}"
  suffix_for_show_user = "#{RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY}"

  steps %{
    When I have logged in as "nch_admin@example.com"
    And I "enable" membership request customization for "#{org.subdomain}"
    And I list all the programs
    And I follow "Primary Career Portal"
    And I follow "Manage"
    And I follow "Customize"
    And I click "div.cjs-section-container[data-section-id='#{section1.id}']"
    And I click ".cjs_profile_question_#{current_education_profile_q.id}"
    Then I wait for ajax to complete
    And I follow "Roles"
  }
  step "I click \".cjs_profile_question_edit_role_settings\""
  check("role_questions_in_summary_#{current_education_profile_q.id}_#{employee_role.id}")
  steps %{
    And I press "Save"
    Then I wait for ajax to complete
    And I click "div.cjs-section-container[data-section-id='#{section2.id}']"
    And I click ".cjs_profile_question_#{age_profile_q.id}"
    Then I wait for ajax to complete
    And I follow "Roles"
  }
  step "I click \".cjs_profile_question_edit_role_settings\""
  uncheck("role_questions_private_#{age_profile_q.id}_#{employee_role.id}_#{suffix_for_all_employees}")
  steps %{
    And I press "Save"
    Then I wait for ajax to complete
    And I click ".cjs_profile_question_#{interest_profile_q.id}"
    Then I wait for ajax to complete
    And I follow "Roles"
  }
  step "I click \".cjs_profile_question_edit_role_settings\""
  uncheck("role_questions_private_#{interest_profile_q.id}_#{employee_role.id}_#{suffix_for_all_employees}")
  uncheck("role_questions_private_#{interest_profile_q.id}_#{employee_role.id}_#{suffix_for_show_user}")
  steps %{
    And I press "Save"
    Then I wait for ajax to complete
    And I logout
  }
end