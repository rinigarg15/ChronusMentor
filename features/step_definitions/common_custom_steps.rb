Then /^clear mail deliveries$/ do
  ActionMailer::Base.deliveries.clear
end

Then /^no email is sent$/ do
  assert ActionMailer::Base.deliveries.empty?
end

When /^I attach the file at "([^\"]*)" to "([^\"]*)"$/ do |path, field|
  if ENV['BS_RUN'] == 'true'
    remote_file_detection(path)
  end  
  attach_file(field, path)
end

#When(/^I reload$/) do
#  visit response.request.url
#end
Then /^the( disabled)? "([^\"]*)" checkbox_id should be checked$/ do |field_disabled, label|
  assert page.has_checked_field?(label, disabled: (!field_disabled.nil?))
end

Then /^the "([^\"]*)" checkbox_id should not be checked$/ do |label|
  #assert !page.has_checked_field?(label)
  assert page.has_no_checked_field?(label)
end

Then /^I should see "([^\"]*)" in "([^\"]*)"$/ do |text, id|
  within (first(:css, "div##{id}")) do
    step "I should see \"#{text}\""
  end
end

Then /^I should not see "([^\"]*)" in "([^\"]*)"$/ do |text, id|
  within(first(:css, "div##{id} a")) do
    step "I should not see \"#{text}\""
  end
end

Then /^I should see the button "([^\"]*)"$/ do |arg1|
  assert page.has_css?("a", :match => :prefer_exact, :text => arg1)
end

Then /^I should see submit button "([^\"]*)"$/ do |text|
  assert page.find_button(text)
end

Then /^I close the flash$/ do
  page.find(".toast-close-button").click
end