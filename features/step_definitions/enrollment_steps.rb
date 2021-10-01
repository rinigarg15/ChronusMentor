Then /^I make all profile questions into membership questions in "([^"]*)":"([^"]*)"$/ do |subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  program.organization.profile_questions.each do |pq|
    pq.role_questions.each do |rq|
      rq.available_for = RoleQuestion::AVAILABLE_FOR::BOTH
      rq.save
    end
  end
end

Then /^I make the question "([^"]*)" mandatory in "([^"]*)":"([^"]*)"$/ do |question_text, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  pq = program.organization.profile_questions.find_by(question_text: question_text)
  pq.role_questions.each do |rq|
    rq.required = true
    rq.save!
  end
end

Then /^I follow enrollment page link for "([^"]*)":"([^"]*)"$/ do |subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  step "I click \"a.enrollment_popup_link_#{program.id}\""
end

Then /^I should see "([^\"]*)" for "([^"]*)":"([^"]*)"$/ do |text, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  step "I should see \"#{text}\" within \".enrollment_program_#{program.id}\""
end

Then /^I follow "([^"]*)":"([^"]*)"$/ do |subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  step "I follow \"#{program.name}\" within \".enrollment_program_#{program.id}\""
end

When /^I click on accept for the request from "([^\"]*)"$/ do |email|
  step "I follow \"Accept\""
end

Then /^I visit the all programs listing$/ do
  steps %{
    When I click "a.my_programs_listing_link"
    And I follow "Browse Programs"
  }
end

Then /^I should see header image$/ do
  page.should have_css('a.profile_header_image')
end

Then /^I should not see header image$/ do
  page.should_not have_css('a.profile_header_image')
end

And /^I open tab "([^\"]*)"$/ do |ibox_content_id|
  step "I click by xpath \"//div[contains(@id, '#{ibox_content_id}')]/../div[contains(@class, 'ibox-title')]/div[contains(@class, 'ibox-tools')]/a\""
end

Then /^email should be filled with "([^\"]*)" in landing page$/ do |email|
  step "the disabled \"membership_request_email\" field should contain \"#{email}\""
end

Then /^I fill in the following details in membership request$/ do |membership_request_hash|
  membership_request_form=membership_request_hash.rows_hash()
  steps %{
    And I fill in "membership_request_first_name" with "#{membership_request_form["FirstName"]}"
    And I fill in "membership_request_last_name" with "#{membership_request_form["LastName"]}"
    And I fill in "membership_request_password" with "#{membership_request_form["Password"]}"
    And I fill in "membership_request_password_confirm" with "#{membership_request_form["ConfirmPassword"]}"
    Then I valdiate and give my consent for terms and conditions by clicking "Submit"
  }
end

Then /^I use invite code for email "([^\"]*)"$/ do |email|
  member = Member.find_by(email: "rahim@example.com")
  member.update_attributes(email: email)
  password = Password.where(email_id: email).last
  password.destroy
end