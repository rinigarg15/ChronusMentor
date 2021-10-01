Then /^I change password to automatically expire after "([^\"]*)" days$/ do |days|
  steps %{
    And I check "auto_password_expiry"
    And I fill in "organization_security_setting_attributes_password_expiration_frequency" with "#{days}"
  }
end

Then /^I expire the password for "([^\"]*)" by changing the password updated at to (\d+) days ago$/ do |email, ndays|
  member = Member.find_by(email: email)
  member.password_updated_at = Time.now - ndays.to_i.days
  member.save!
end