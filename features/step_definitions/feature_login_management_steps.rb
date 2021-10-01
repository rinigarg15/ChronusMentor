When /^I follow \"Customize\" of "([^\"]*)" logins section$/ do |section|
  step "I click by xpath \"//h5[contains(text(), '#{section} Logins')]/following-sibling::a\""
end

When /^I add a "([^\"]*)" login from backend$/ do |auth_type|
  organization = Program::Domain.get_organization(DEFAULT_HOST_NAME, "primary")
  organization.auth_configs.create!(auth_type: "AuthConfig::Type::#{auth_type}".constantize)
end

Then /^I should see \"Show on Top\" checked in login section customization$/ do
  steps %{
    And I should see "Show on Top"
    And the "auth_config_setting_show_on_top" checkbox_id should be checked
  }
end

Then /^I should see \"Show on Top\" unchecked in login section customization$/ do
  steps %{
    And I should see "Show on Top"
    And the "auth_config_setting_show_on_top" checkbox_id should not be checked
  }
end

And /^I check \"Show on Top\" in login section customization$/ do
  step "I check \"auth_config_setting_show_on_top\""
end

When /^I fill in "([^\"]*)" login section title and description with "([^\"]*)" and "([^\"]*)"$/ do |section, title, description|
  steps %{
    And I fill in "auth_config_setting_#{section}_section_title" with "#{title}"
    And I fill in CKEditor "auth_config_setting_#{section}_section_description" with "#{description}"
  }
end

And /^I ensure the default login section appears before custom login section$/ do
  page.evaluate_script(%Q[jQuery("h3#fc-custom-login-section-title").offset().top > jQuery("h3#fc-default-login-section-title").offset().top])
end

Then /^I should see the action "([^\"]*)" available for "([^\"]*)" login$/ do |action, login|
  page.should have_xpath(xpath_for_login_action(action, login))
end

Then /^I should not see the action "([^\"]*)" available for "([^\"]*)" login$/ do |action, login|
  page.should_not have_xpath(xpath_for_login_action(action, login))
end

And /^I follow the action "([^\"]*)" available for "([^\"]*)" login$/ do |action, login|
  step "I click by xpath \"#{xpath_for_login_action(action, login)}\""
end

And /^I fill in password regex and message as "([^\"]*)" and "([^\"]*)"$/ do |regex, message|
  steps %{
    And I fill in "auth_config_regex_string" with "#{regex}"
    And I fill in CKEditor "cjs_auth_config_password_message" with "#{message}"
  }
end

And /^I fill in the login title and logo with "([^\"]*)" and "([^\"]*)"$/ do |title, logo|
  steps %{
    And I fill in "auth_config_title" with "#{title}"
    And I set the attachment field "auth_config_logo" to "#{logo}"
  }
end

When /^I remove the login logo$/ do
  step "I click by xpath \"//a[contains(@class, 'cjs_auth_config_remove_logo')]\""
end

Given /^I am an externally authenticated user$/ do
  cookies = Capybara.current_session.driver.browser.manage.all_cookies
  session_id = cookies.find { |cookie| cookie[:name] == Rails.application.config.session_options[:key] }[:value]
  session = ActiveRecord::SessionStore::Session.find_by(session_id: session_id)
  session.data[:new_custom_auth_user] = {}
  session.data[:new_custom_auth_user][Program::Domain.get_organization(DEFAULT_HOST_NAME, "primary").id] = 1
  session.save!
end

Given /^I enter the Gmail Credentials$/ do
  CucumberWait.retry_until_element_is_visible { fill_in("identifier", :with => "ramyachronus@gmail.com", :match => :prefer_exact, :visible => true) }
  step "I click \"div#identifierNext\""
  step "I wait for \"2\" seconds"
  CucumberWait.retry_until_element_is_visible { fill_in("password", :with => "chronus123", :match => :prefer_exact, :visible => true) }
  step "I click \"div#passwordNext\""
  step "I wait for \"2\" seconds"
end  

Then /^I clear the Gmail cookies$/ do
  visit("https://www.google.com/accounts/optintoaccountchooser?optout=1")
  visit("http://mail.google.com")
  browser = Capybara.current_session.driver.browser
  browser.manage.delete_all_cookies
end

Then /^I clear the LinkedIn cookies$/ do
  visit("http://www.linkedin.com")
  browser = Capybara.current_session.driver.browser
  browser.manage.delete_all_cookies
end

private

def xpath_for_login_action(action, login)
  if action.in? ["Password Policy", "Customize", "Configure"]
    "//td[contains(text(), '#{login}')]/following-sibling::td/a[contains(text(), '#{action}')]"
  else
    "//td[contains(text(), '#{login}')]/following-sibling::td/a[descendant::span[contains(text(), '#{action}')]]"
  end
end