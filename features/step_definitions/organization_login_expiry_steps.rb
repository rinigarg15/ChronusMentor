Then /I should see "([^\"]*)" selected in the dropdown/ do |value|
  assert_equal value, find('#organization_security_setting_attributes_login_expiry_period option[selected]').text
end
