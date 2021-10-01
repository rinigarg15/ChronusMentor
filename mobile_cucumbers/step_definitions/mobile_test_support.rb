And /^I should see in mobile "([^\"]*)"$/ do |text|
  wait_for_text_to_exist text
end

Then /^I sleep in mobile for "([^\"]*)" seconds$/ do |number|
  sleep(number.to_i)
end

When /^(?:|I )fill in mobile in "([^\"]*)" with "([^\"]*)"$/ do |field, value|
   fill_in_text(field,value)
end

Then /^I click in mobile on "([^\"]*)"$/ do |field|
  click_on_button field
end	