Then /^I "([^"]*)" the request (?:from|for) "([^"]*)"$/ do |action,user|
  xpath="//div[h4[descendant::a[contains(text(),'#{user}')]]]/../../preceding-sibling::div/*/a[contains(text(),'Actions')]"
  steps %{
    And I click by xpath "#{xpath}"
  }
  xpath="//div[h4[descendant::a[contains(text(),'#{user}')]]]/../../preceding-sibling::div/*/a[contains(text(),'Actions')]/following::a[text()='#{action}']"
  steps %{
    And I click by xpath "#{xpath}"
  }
end

Then /^I request mentoring connection from "([^"]*)" using quick connect box$/ do |mentor|
  xpath="//div[descendant::div[descendant::a[contains(text(),'#{mentor}')]]]/following-sibling::*/*/*/a[@title='Request Mentoring Connection']"
  steps %{
    And I click by xpath "#{xpath}"
  }
end

Then /^I click connect from "([^"]*)" using quick connect box$/ do |mentor|
  page.execute_script %Q[jQuery("a:contains('#{mentor}')").closest(".slick_box").find(".cjs_home_quick_connect_button").click();]
end

Then /^I "([^"]*)" the offer (?:from|for) "([^"]*)"$/ do |action,user|
  xpath="//div[h4[descendant::a[contains(text(),'#{user}')]]]/../../preceding-sibling::div/*/a[contains(text(),'Actions')]"
  steps %{
    And I click by xpath "#{xpath}"
  }
  xpath="//div[h4[descendant::a[contains(text(),'#{user}')]]]/../../preceding-sibling::div/*/a[contains(text(),'Actions')]/following::a[text()='#{action}']"
  steps %{
    And I click by xpath "#{xpath}"
  }
end

Then /^I wait for "([^"]*)" Elastic Search Reindex$/ do |model|
  refresh_es_index(model.constantize, nil, false)
end

Before("@refresh_mentoring_requests_es_Index") do
  refresh_es_index(MentorRequest, nil, false)
end

Then /^I choose the value "([^"]*)" for "([^"]*)"$/ do |value, radio_or_check_box|
  choose(radio_or_check_box, option: value)
end