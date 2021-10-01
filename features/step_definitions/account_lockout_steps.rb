Then /^I block login after "([^\"]*)" maximum attempts$/ do |attempts|
  step "I fill in \"organization_security_setting_attributes_maximum_login_attempts\" with \"#{attempts}\""
end

Then /^I "([^\"]*)" send emails for account reactivation$/ do |check|
  if check.eql?("allow")
    step "I check \"organization_security_setting_attributes_reactivation_email_enabled\""
  else
    step "I uncheck \"organization_security_setting_attributes_reactivation_email_enabled\""
  end
end

Then /^I set "([^\"]*)" hours for automatic reactivate account$/ do |hours|
  step "I fill in \"organization_security_setting_attributes_auto_reactivate_account\" with \"#{hours}\""
end

Then /^I change the account locked at time to (\d+) hours prior for "([^\"]*)"$/ do |hr,email|
  member=Member.find_by(email: email)
  member.account_locked_at=Time.now-hr.to_i.hours
  member.save!
end