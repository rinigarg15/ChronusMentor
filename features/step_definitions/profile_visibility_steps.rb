Given /^the Admin configures the questions with all kinds of visibility mode$/ do
  secid = Organization.where(name: "Primary Organization").first.sections.find_by(title: "Mentoring Profile").id
  progid = Program.find_by(name: "Albers Mentor Program").id
  mentorroleid = Program.find_by(name: "Albers Mentor Program").roles.find_by(name: "mentor").id
  menteeroleid = Program.find_by(name: "Albers Mentor Program").roles.find_by(name: "student").id
  userroleid = Program.find_by(name: "Albers Mentor Program").roles.find_by(name: "user").id
  suffix_for_all_mentors = "#{RoleQuestion::PRIVACY_SETTING::RESTRICTED}-#{RoleQuestionPrivacySetting::SettingType::ROLE}-#{mentorroleid}"
  suffix_for_all_mentees = "#{RoleQuestion::PRIVACY_SETTING::RESTRICTED}-#{RoleQuestionPrivacySetting::SettingType::ROLE}-#{menteeroleid}"
  suffix_for_all_users = "#{RoleQuestion::PRIVACY_SETTING::RESTRICTED}-#{RoleQuestionPrivacySetting::SettingType::ROLE}-#{userroleid}"
  suffix_for_connected_members = "#{RoleQuestion::PRIVACY_SETTING::RESTRICTED}-#{RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS}"
  steps %{
    When I have logged in as "ram@example.com"
    And I "enable" membership request customization for "#{Organization.where(name: "Primary Organization").first.subdomain}"
    Given the current program is "primary":"albers"
    And I follow "Manage"
    And I follow "Customize"
    And I click "div.cjs-section-container[data-section-id='#{secid}']"
    And I click ".cjs_profile_question_8"
    Then I wait for ajax to complete
    And I follow "Roles"
  }
  uncheck("profile_questions_#{progid}_#{secid}_8_student")
  step "I wait for ajax to complete"
  step "I click \".cjs_profile_question_edit_role_settings\""
  step "I wait for ajax to complete"
  uncheck("role_questions_private_8_#{mentorroleid}_#{suffix_for_all_mentees}")
  uncheck("role_questions_private_8_#{mentorroleid}_#{suffix_for_all_mentors}")
  uncheck("role_questions_private_8_#{mentorroleid}_#{suffix_for_all_users}")
  uncheck("role_questions_private_8_#{mentorroleid}_#{suffix_for_connected_members}")
  step "I scroll the div \".cjs-side-panel-slim-scroll\""
  check("role_questions_admin_only_editable_8_#{mentorroleid}")
  steps %{
    And I press "Save"
    Then I wait for ajax to complete
    And I click ".cjs_profile_question_9"
    Then I wait for ajax to complete
    And I follow "Roles"
  }
  uncheck("profile_questions_#{progid}_#{secid}_9_student")
  step "I wait for ajax to complete"
  step "I click \".cjs_profile_question_edit_role_settings\""
  step "I wait for ajax to complete"
  uncheck("role_questions_private_9_#{mentorroleid}_#{suffix_for_all_mentees}")
  uncheck("role_questions_private_9_#{mentorroleid}_#{suffix_for_connected_members}")
  step "I scroll the div \".cjs-side-panel-slim-scroll\""
  check("role_questions_admin_only_editable_9_#{mentorroleid}")
  step "I scroll the div \".cjs-side-panel-slim-scroll\""
  check("role_questions_in_summary_9_#{mentorroleid}")
  steps %{
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    Then I wait for ajax to complete
    And I click ".cjs_profile_question_10"
    Then I wait for ajax to complete
    And I follow "Roles"
    Then I click ".cjs_profile_question_edit_role_settings"
    Then I wait for ajax to complete
  }
  uncheck("role_questions_private_10_#{mentorroleid}_#{suffix_for_all_mentees}")
  uncheck("role_questions_private_10_#{mentorroleid}_#{suffix_for_all_mentors}")
  step "I scroll the div \".cjs-side-panel-slim-scroll\""
  check("role_questions_admin_only_editable_10_#{mentorroleid}")
  steps %{
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    Then I wait for ajax to complete
    Then I make "Career path/Specializations" question admin only visible for "mentor" in "primary":"albers"
    And I click ".cjs_profile_question_12"
    Then I wait for ajax to complete
    And I follow "Roles"
    Then I click ".cjs_profile_question_edit_role_settings"
  }
  uncheck("role_questions_private_12_#{mentorroleid}_#{suffix_for_all_mentees}")
  uncheck("role_questions_private_12_#{mentorroleid}_#{suffix_for_all_mentors}")
  uncheck("role_questions_private_12_#{mentorroleid}_#{suffix_for_all_users}")
  uncheck("role_questions_private_12_#{mentorroleid}_#{suffix_for_connected_members}")
  check("role_questions_available_for_membership_12_#{mentorroleid}")
  steps %{
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    Then I wait for ajax to complete
    And I click ".cjs_profile_question_13"
    Then I wait for ajax to complete
    And I follow "Roles"
    Then I click ".cjs_profile_question_edit_role_settings"
  }
  uncheck("role_questions_private_13_#{menteeroleid}_#{suffix_for_all_mentees}")
  uncheck("role_questions_private_13_#{menteeroleid}_#{suffix_for_connected_members}")
  check("role_questions_available_for_membership_13_#{menteeroleid}")
  check("role_questions_in_summary_13_#{menteeroleid}")
  steps %{
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    Then I wait for ajax to complete
    And I click ".cjs_profile_question_15"
    Then I wait for ajax to complete
    And I follow "Roles"
  }
  uncheck("profile_questions_#{progid}_#{secid}_15_student")
  step "I wait for ajax to complete"
  step "I click \".cjs_profile_question_edit_role_settings\""
  step "I wait for ajax to complete"
  uncheck("role_questions_private_15_#{mentorroleid}_#{suffix_for_all_mentees}")
  uncheck("role_questions_private_15_#{mentorroleid}_#{suffix_for_all_mentors}")
  uncheck("role_questions_private_15_#{mentorroleid}_#{suffix_for_all_users}")
  check("role_questions_available_for_membership_15_#{mentorroleid}")
  steps %{
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    Then I wait for ajax to complete
    And I logout
  }
end

Then /^I should not see the admin editable fields$/ do
  page.should_not have_css("textarea#profile_answers_8")
  page.should_not have_css("select#profile_answers_9")
  page.should_not have_css("select#profile_answers_10")
  page.should_not have_css("div#question_11")
end

And /^I should see the user editable fields$/ do
  assert page.has_css?("textarea#profile_answers_12")
  assert page.has_css?("select#profile_answers_15")
end

And /^I should see the user editable fields as a mentee$/ do
  assert page.has_css?("input#quick_find_profile_answer_13")
end

And /^I should see the profile summary fields based on the visibility mode as a mentor$/ do
  step "I should see \"Career path interests\" within \"div#page_canvas\""
end

And /^I should see the profile summary fields based on the visibility mode as a mentee$/ do
  steps %{
    Then I should not see "Gender" within "div#page_canvas"
    And I follow "Students" within "nav#sidebarLeft"
  }
end

Then /^I should not see the user mentoring connection visibility field$/ do
  steps %{
    Then I should not see "About me" within "div#mentor_profile"
    Then I should not see "Gender" within "div#mentor_profile"
    Then I should not see "Industry" within "div#mentor_profile"
    Then I should not see "Career path/Specializations" within "div#mentor_profile"
    Then I should not see "Expertise" within "div#mentor_profile"
    Then I should not see "Total work experience" within "div#mentor_profile"
  }
end

Then /^I should see the user mentoring connection visibility field$/ do
  steps %{
    Then I should not see "About me" within "div#mentor_profile"
    Then I should not see "Gender" within "div#mentor_profile"
    Then I should see "Industry" within "div#mentor_profile"
    Then I should not see "Career path/Specializations" within "div#mentor_profile"
    Then I should not see "Expertise" within "div#mentor_profile"
    Then I should see "Total work experience" within "div#mentor_profile"
  }
end

Then /^I should see both admin editable and user editable fields$/ do
  assert page.has_css?("textarea#profile_answers_8")
  assert page.has_css?("select#profile_answers_9")
  assert page.has_css?("select#profile_answers_10")
  assert page.has_css?("div#question_11")
  assert page.has_css?("textarea#profile_answers_12")
  assert page.has_css?("select#profile_answers_15")
end

Then /^I follow "([^"]*)" for "([^"]*)" in customize user profile fields$/ do |link,field|
  xpath="//li[contains(@class, 'question_answer')]/descendant::*[contains(text(), '#{field}')]/../following-sibling::*/descendant::a[contains(text(), '#{link}')]"
  steps %{
    And I click by xpath "#{xpath}"
  }
end

And /^I click on profile question with question text "([^"]*)"$/ do |question_text|
  profile_question = ProfileQuestion.find_by(question_text: question_text)
  step "I click \".cjs_profile_question_#{profile_question.id}\""
end