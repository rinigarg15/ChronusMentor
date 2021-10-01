Then /^I fill in students field with "([^\"]*)"$/ do |name| 
	org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,'primary')
	program =  org.programs.find_by(root: 'albers')
	role_id = program.roles.find_by(name: "student").id
	step "I fill in \"member_filters_#{role_id}\" with \"#{name}\""
end

Then /^I filter on student field$/ do
  steps %{
    Then I click on "Student" header
    When I fill in students field with "student_c example"
    And I press "Go" inside "Student" content
  }
end

And /^the page should not have the link with title "([^\"]*)"$/ do |link_title|
  page.has_no_link?(link_title)
end

Then /^I add a new closure reason as "([^"]*)" with "([^"]*)" for consider completed$/ do |reason, complete|
  steps %{
    And I follow "Add another reason"
    And I fill in "new_group_closure_reasons[0][reason]" with "#{reason}"
  }
  if(complete.include?("yes"))
    step "I check \"new_group_closure_reasons[0][is_completed]\""
  end
end