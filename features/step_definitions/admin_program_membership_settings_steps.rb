Then /^I make "([^\"]*)" role as "([^\"]*)" in "([^\"]*)":"([^\"]*)"$/ do |role_name, setting, subdomain, prog_root|
	program = get_program(prog_root, subdomain)
	role = program.find_role(role_name)
	update_join_setting_for_role(role,setting)
end

Then /^I accept the pending membership requests for "([^\"]*)"/ do |root|
  program = Program.find_by(root: root)
  program.membership_requests.pending.update_all("status = #{MembershipRequest::Status::ACCEPTED}")
end

Given /^I specify the joining option as "([^"]*)" for "([^"]*)"$/ do |joining_option,role|
  xpath="//h3[contains(text(),'#{role}')]/following-sibling::*/descendant::*/*[contains(text(),'#{joining_option}')]/input"
  steps %{
    And I click by xpath "#{xpath}"
    Then I press "Save"
    And I wait for ajax to complete
  }
end