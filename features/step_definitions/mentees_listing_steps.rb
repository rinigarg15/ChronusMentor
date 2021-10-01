Then /^I offer mentoring for "([^"]*)" in mentees listing$/ do |mentee|
  xpath="//*[descendant::a[contains(text(),'#{mentee}')]]/../preceding-sibling::div/a[contains(text(), 'Connect')]"
  steps %{
    And I click by xpath "#{xpath}"
  }
  xpath="//*[descendant::a[contains(text(),'#{mentee}')]]/../preceding-sibling::div/a[contains(text(), 'Connect')]/following::a[contains(text(),'Offer Mentoring')]"
  steps %{
    And I click by xpath "#{xpath}"
  }
end

Then /^I click on connect for "([^"]*)" in mentees listing$/ do |mentee|
  xpath="//*[descendant::a[contains(text(),'#{mentee}')]]/preceding-sibling::*/*/a[contains(text(),'Connect')]"
  steps %{
    And I click by xpath "#{xpath}"
  }
end