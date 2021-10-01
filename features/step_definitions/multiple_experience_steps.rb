Given /^there are some mandatory multiple experience fields$/ do
  secid = Organization.where(name: "Primary Organization").first.sections.find_by(title: "Work and Education").id
  qid = Organization.where(name: "Primary Organization").first.profile_questions.find_by(question_text: "Work Experience").id
	roleid = Program.find_by(name: "Albers Mentor Program").roles.find_by(name: "Mentor").id
  steps %{
    And I "enable" membership request customization for "#{Organization.where(name: "Primary Organization").first.subdomain}"
  	When I hover over "my_programs_container"
    When I select "Albers Mentor Program" from the program selector
  	Then I follow "Manage"
  	And I follow "Customize"
  	And I click "div.cjs-section-container[data-section-id='#{secid}']"
  	And I click ".cjs_profile_question_#{qid}"
    Then I wait for ajax to complete
  	And I follow "Roles"
    And I click ".cjs_profile_question_edit_role_settings"
  }
	check("role_questions_required_#{qid}_#{roleid}")
	check("role_questions_available_for_membership_#{qid}_#{roleid}")
  step "I scroll the div \".cjs-side-panel-slim-scroll\""
	step "I press \"Save\""
end

Then /^I remove mandatory experience field$/ do
  qid = Organization.where(name: "Primary Organization").first.profile_questions.find_by(question_text: "Work Experience").id
  steps %{
    Then I click by xpath "//div[@id='exp_cur_list_#{qid}']//button[@class='close']/i"
    Then I should see "At least one required"
    And I press "OK"
    Then I follow "Add another position" within "div#edit_experience_#{qid}"
    Then I click by xpath "//div[@id='exp_cur_list_#{qid}']//button[@class='close']/i"
    Then I should see "Are you sure you want to delete?"
    Then I confirm popup
    Then I click by xpath "//div[@id='exp_cur_list_#{qid}']//button[@class='close']/i"
    Then I should see "At least one required"
    And I press "OK"
  }
end

Then /^I remove filled mandatory experience field$/ do
  qid = Organization.where(name: "Primary Organization").first.profile_questions.find_by(question_text: "Work Experience").id
  steps %{
    Then I click by xpath "//div[@id='exp_cur_list_#{qid}']//button[@class='close']/i"
    Then I should see "Are you sure you want to delete?"
    Then I confirm popup
    Then I click by xpath "//div[@id='exp_cur_list_#{qid}']//button[@class='close']/i"
    Then I should see "At least one required"
    And I press "OK"
  }
end

Then /^I remove non-mandatory education field$/ do
  qid = Organization.where(name: "Primary Organization").first.profile_questions.find_by(question_text: "Entire Education").id
  steps %{
    Then I click by xpath "//div[@id='edu_cur_list_#{qid}']//button[@class='close']/i"
    Then I should see "Are you sure you want to delete?"
    Then I confirm popup
  }
end

Given /^I visit "([^\"]*)" first time profile completion in "([^\"]*)":"([^\"]*)"$/ do |email, subdomain, prog|
  domain = DEFAULT_HOST_NAME
  member = Organization.first.members.find_by(email: email)
  visit("http://#{subdomain}.#{domain}:#{Capybara.server_port}/p/#{prog}/members/#{member.id}/edit?first_visit=true")
end	

