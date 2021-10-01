When /^I visit the reset password page$/ do
  r = Password.last
  visit "/change_password?reset_code=#{r.reset_code}"
end

And /^I set the password message for "([^\"]*)"$/ do |subdomain|
  org = Program::Domain.get_organization(DEFAULT_HOST_NAME, subdomain)
  password_message = "<div class=help-block><ul><li>Should contain only numeric characters</li><li>Must satisfy the above condition</li></ul></div>"
  org.chronus_auth.update_attributes!(password_message: password_message)
end

And /^I set the number password regex for "([^\"]*)"$/ do |subdomain|
  org = Program::Domain.get_organization(DEFAULT_HOST_NAME, subdomain)
  org.chronus_auth.update_attributes!(regex_string: "[0-9]+")
end

And /^I create SAML Auth for "([^\"]*)"$/ do |subdomain|
  org = Program::Domain.get_organization(DEFAULT_HOST_NAME, subdomain)
  org.auth_configs.create!(auth_type: "SAMLAuth")
end
