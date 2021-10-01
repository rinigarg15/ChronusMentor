Then /^I make "([^"]*)" question admin only editable for "([^"]*)" in "([^"]*)":"([^"]*)"$/ do |question_text, role_name, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  role = program.find_role(role_name)
  org = program.organization
  question = org.profile_questions.where(:question_text => question_text).first.role_questions.where(:role_id => role.id).first
  question.admin_only_editable = true
  question.save!
end

Then /^I make "([^"]*)" question available in the membership form for "([^"]*)" in "([^"]*)":"([^"]*)"$/ do |question_text, role_name, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  role = program.find_role(role_name)
  org = program.organization
  profile_question = org.profile_questions.where(:question_text => question_text).first
  question = profile_question.role_questions.where(role_id: role.id).first
  question ||= profile_question.role_questions.create!(role: role)
  question.available_for = RoleQuestion::AVAILABLE_FOR::BOTH
  question.save!
end

Then /^I update the email question help text to "([^"]*)" in "([^"]*)"$/ do |help_text, subdomain|
  org = get_organization(subdomain)
  org.email_question.update_attributes!(help_text: help_text)
end

And /^I hover over the lock icon of the question with text "([^"]*)" in "([^"]*)"$/ do |question_text, subdomain|
  org = get_organization(subdomain)
  profile_question = org.profile_questions_with_email_and_name.find_by(question_text: question_text)
  steps %{
    Then I hover over "question_private_icon_#{profile_question.id}"
  }
end

Then /^I make "([^"]*)" question text only in "([^"]*)"$/ do |question_text, subdomain|
  organization = get_organization(subdomain)
  question = organization.profile_questions.find_by(question_text: question_text)
  question.update_attributes!(question_type: ProfileQuestion::Type::MULTI_STRING, text_only_option: true)
end

Then /^I make "([^"]*)" question admin only visible for "([^"]*)" in "([^"]*)":"([^"]*)"$/ do |question_text, role_name, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  role = program.find_role(role_name)
  org = program.organization
  question = org.profile_questions.where(:question_text => question_text).first.role_questions.where(:role_id => role.id).first
  question.private = RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE
  question.admin_only_editable = true
  question.save!
end

Then /^"([^"]*)" question in section "([^"]*)" under "([^"]*)" role should not be disabled in "([^"]*)":"([^"]*)"$/ do |question_text, section_id, role_name, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  role = program.find_role(role_name)
  org = program.organization
  question = org.profile_questions.where(:question_text => question_text).first
  id = "#role_questions_available_for_membership_#{question.id}_#{role.id}"
  steps %{
    And I click ".cjs_profile_question_#{question.id}"
    Then I wait for ajax to complete
    And I follow "Roles"
    Then I wait for ajax to complete
    And I click edit advanced options
    Then element with id "#{id}" should not be disabled
  }
end

Then /^"([^"]*)" question in section "([^"]*)" under "([^"]*)" role should be disabled in "([^"]*)":"([^"]*)"$/ do |question_text, section_id, role_name, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  role = program.find_role(role_name)
  org = program.organization
  question = org.profile_questions.where(:question_text => question_text).first
  id = "#role_questions_available_for_membership_#{question.id}_#{role.id}"
  steps %{
    And I click ".cjs_profile_question_#{question.id}"
    Then I wait for ajax to complete
    And I follow "Roles"
    Then I wait for ajax to complete
    And I click edit advanced options
    Then element with id "#{id}" should be disabled
  }
end

And /^I set the allowed email domain to "([^"]*)" in "([^"]*)"$/ do |email_domain, subdomain|
  security_setting = get_organization(subdomain).security_setting
  security_setting.email_domain = email_domain
  security_setting.save!
end

Then /^element with id "([^\"]*)" should be disabled$/ do |id|
  assert page.has_css?("input#{id}[disabled]")
end

Then /^element with the id "([^\"]*)" should be disabled$/ do |id|
  assert page.evaluate_script("jQuery('#{id}').prop('disabled')")
end

Then /^element with the id "([^\"]*)" should not be disabled$/ do |id|
  assert_false page.evaluate_script("jQuery('#{id}').prop('disabled')")
end



Then /^element with id "([^\"]*)" should be readonly$/ do |id|
  assert page.has_css?("input#{id}[readonly]")
end

Then /^element with id "([^\"]*)" should not be disabled$/ do |id|
  #assert page.has_selector?('input', :id => id)
  #assert_false page.has_css?("input#{id}[disabled]")
  assert_false page.all("input#{id}[disabled]").any?
end