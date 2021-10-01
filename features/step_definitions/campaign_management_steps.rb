Then /^I should not see campaign email link$/ do
  within "a" do
    step "I should not see \"CAMPAIGN EMAIL\""
  end
end

Then /^I should see campaign email link$/ do
  within "a" do
    step "I should see \"CAMPAIGN EMAIL\""
  end
end

Then /^I should not see campaign information link$/ do
  within "a" do
    step "I should not see \"CAMPAIGN INFORMATION\""
  end
end

Then /^I should see campaign information link$/ do
  within "a" do
    step "I should see \"CAMPAIGN INFORMATION\""
  end
end

Then /^I set the campaign message duration as "([^\"]*)"$/ do |value|
 if (ENV['BS_RUN'] == 'true')
    page.find('#campaign_message_duration').native.send_keys "#{value}"
 else
    step "I fill in \"campaign_message_duration\" with \"#{value}\""
 end
end

When /^I hover over the info icon close to schedule input and verify info text$/ do
  step "I hover over \"email_schedule\""
  step "I should see \"Email with schedule as 0 days will be sent in couple of hours from start time of the campaign.\""
end