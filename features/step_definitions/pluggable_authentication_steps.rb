Given /^"([^\"]*)" organization supports additional authentication mode$/ do |subdomain|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  org.auth_configs.create!(auth_type: AuthConfig::Type::SOAP, title: "External Login")
end

And /^I set users can join directly in "([^\"]*)":"([^\"]*)"$/ do |subdomain, root|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  prog = org.programs.find_by(root: root)
  add_roles_to_join_directly_only_with_sso(prog, "mentor,student")
end

Given /^"([^\"]*)" organization is uses email as uuid$/ do |subdomain|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  org.auth_configs.first.update_attributes(:use_email => true)
end

Then /^the "([^\"]*)" should be present in both "([^\"]*)":"([^\"]*)" and "([^\"]*)":"([^\"]*)"$/ do |arg1, subdomain_1, prog_root_1, subdomain_2, prog_root_2|
  prog_1 = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain_1).programs.find_by(root: prog_root_1)
  prog_2 = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain_2).programs.find_by(root: prog_root_2)

  assert User.find_by_email_program(arg1, prog_1)
  assert User.find_by_email_program(arg1, prog_2)
end

And /^invite "([^\"]*)" as a mentor and mail is sent$/ do |email|
  steps %{
    And I follow "Invite Mentors"
    And I choose "role_assign_roles"
    And I check "Mentor"
    And I fill in "recipients" with "#{email}"
    And I press "cjs_send_invites"
    Then I should see "Your invitations are being sent"
    And a mail should go to "#{email}" having "I would like to invite you to join the Albers Mentor Program as a mentor"
  }
end

And /^there is a dormant member with email "([^\"]*)"$/ do |email|
  me = Member.new(:first_name => "Test", :last_name => "user", :email => email)
  me.organization_id = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME, "primary").id
  me.state = Member::Status::DORMANT
  me.password = "monkey"
  me.password_confirmation = "monkey"
  me.save!
end

And /^I send invitation to the dormant member$/ do
  memid = Member.last.id
  visit("http://primary.#{DEFAULT_HOST_NAME}:#{Capybara.server_port}/members/#{memid}")
  steps %{
    Then I follow "Invite User To Program"
    And I select "Albers Mentor Program" from "program_id"
    And I choose "role_allow_roles"
    And I check "Mentor"
    And I check "Student"
    And I press "Submit"
  }
end