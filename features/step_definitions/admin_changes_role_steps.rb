
Then /^I suspend with the reason "([^\"]*)"$/ do |arg1|
  steps %{
    And I fill in "state_change_reason" with "Some reason"
    And I press "Suspend"
  }
end

Then /^I deactivate with the reason "([^\"]*)"$/ do |arg1|
  steps %{
    Then I should see "Reason *"
    And I fill in "state_change_reason" with "Some reason" within "#suspend_user_form"
    And I press "Deactivate"
  }
end

Then /^"([^\"]*)" role checkbox should( not)? be disabled$/ do |role, negate|
  if negate
    step "element with id \"#role_names_#{role}\" should not be disabled"
  else
    step "element with id \"#role_names_#{role}\" should be disabled"
  end
end

And /^I should see the tooltip "([^\"]*)" on hover of the suspend link$/ do |text|
  user = Member.find_by(email: "robert@example.com").users.first
  page.execute_script("jQuery('#suspend_link_#{user.id}').trigger('mouseover')")
  step "I should see \"#{text}\""
end