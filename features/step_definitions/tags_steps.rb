Then /^I remove tag$/ do
  step "I should see submit button \"Save\""
  page.execute_script %Q[jQuery('.select2-search-choice-close').first().click();]
  step "I should not see \"tag3\""
end