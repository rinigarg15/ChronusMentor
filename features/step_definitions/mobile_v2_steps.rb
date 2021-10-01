When /^I visit the mobile organization setup page$/ do
  visit mobile_v2_verify_organization_path
end

Then /^I should be redirected to "([^\"]*)" site$/ do |subdomain|
  assert_equal current_url, "http://#{subdomain}.#{DEFAULT_DOMAIN_NAME}:#{Capybara.server_port}/about"
end

Then /^I should be redirected to org setup edit page$/ do
  assert_equal current_url, TEST_ASSET_HOST + mobile_v2_verify_organization_path(:edit => true)
end

Then /^I submit with organization url "([^\"]*)"$/ do |url|
  steps %{
    Then I fill in "verify_org_organization_name" with "#{url}"
    Then I press "Get Started"
    Then I wait for ajax to complete
  }
end

Then /^I submit with organization subdomain "([^\"]*)"$/ do |subdomain|
  steps %{
    Then I fill in "verify_org_organization_name" with "#{subdomain}.#{DEFAULT_DOMAIN_NAME}"
    Then I press "Get Started"
    Then I wait for ajax to complete
  }
end

And /^I should not have remember me set$/ do
  assert page.has_css?("#remember_me", count: 0)
end

And /^I reset the org setup cookie$/ do
  #removing cookie if set from previous scenarios
  page.execute_script("jQuery.cookie('#{MobileV2Constants::ORGANIZATION_SETUP_COOKIE.to_s}', null, { path: '/' });")
end

When /^I visit back arrow link$/ do
  step "I click \"i.fa-angle-left\""
end

Given /^the current browser is a mobile browser$/ do
  Browser.any_instance.stubs(:ios?).with(9).returns(true)
  Browser.any_instance.stubs(:ios?).with(8).returns(true)
  Browser.any_instance.stubs(:ios_webview?).returns(false)
end

Then /^I follow requests in mobile footer$/ do
  steps %{
    Then I click by xpath "//*[@id='page-wrapper']/nav[2]/div/div/div[1]/div[3]"
  }
end

Then /^I follow mentoring connections in mobile footer$/ do
  steps %{
    Then I click by xpath "//*[@id='page-wrapper']/nav[2]/div/div/div[1]/div[2]"
  }
end

Then /^I follow home in mobile footer$/ do
  steps %{
    Then I click by xpath "//*[@id='page-wrapper']/nav[2]/div/div/div[1]/div[1]"
  }
end

Then /^I follow more in mobile footer$/ do
  steps %{
    Then I click by xpath "//*[@id='page-wrapper']/nav[2]/div/div/div[2]/div"
  }
end