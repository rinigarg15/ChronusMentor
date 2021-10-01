Then /^I switch to the linkedin window and enter the credentials$/ do
  count = page.driver.browser.window_handles.size
  main = page.driver.browser.window_handles[count-2]
  popup = page.driver.browser.window_handles[count-1]
  page.driver.browser.switch_to.window (popup)
  steps %{
    Then I fill in "session_key" with "aw600001@gmail.com"
    And I fill in "session_password" with "aw600001aw"
    Then I press "Sign In"
    And I wait for "3" seconds
  }
  page.driver.browser.switch_to.window (main)
end

Given /^I update the linkedin credentials for "([^\"]*)"$/ do |subdomain|
  organization = get_organization(subdomain)
  security_setting = organization.security_setting
  security_setting.linkedin_token = "75cg43gz7djjcu"
  security_setting.linkedin_secret = "B591GwWomeDeClbo"
  security_setting.save!
end

Given /^I enter the linkedin credentials$/ do
  steps %{
    Then I fill in "session_key-login" with "aw600001@gmail.com"
    And I fill in "session_password-login" with "aw600001aw"
    Then I press "Sign In"
  }
end  