Then /^I delete the invite sent to "([^\"]*)"$/ do |email|
  invite = ProgramInvitation.find_by(sent_to: email)
  within("tr#invite_#{invite.id}") do
    steps %{
      And I follow "Delete"
      And I confirm popup
    }
  end
end

Then /^I resend the invite sent to "([^\"]*)"$/ do |email|
  invite = ProgramInvitation.find_by(sent_to: email)
  within("tr#invite_#{invite.id}") do
    steps %{
      And I follow "Resend"
      And I press "Resend"
    }
  end
end

Given /^I customize user profile form$/ do
  xpath="//div/*[contains(text(),'Profile')]/following::a[@title='Customize']"
  step "I click by xpath \"#{xpath}\""
end