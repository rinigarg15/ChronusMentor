And /^I click article grey flag$/ do
  #page.execute_script("jQuery('a.cjs_grey_flag').click()")
  step "I follow \"Report Content\""
end

Then /^I click the red flag$/ do
  page.execute_script("jQuery('a.cjs_red_flag').click()")
end

And /^I fill in the reason$/ do
  page.execute_script("jQuery('textarea#flag_reason').val('reason')")
end

Then /^I click report button$/ do
  page.execute_script("jQuery('.cjs_popup_flag_content_button').click()")
end

Then /I click on the ibox dropdown action/ do
  within ("div#logged_in") do
    step "I click \"span.caret\""
  end
end