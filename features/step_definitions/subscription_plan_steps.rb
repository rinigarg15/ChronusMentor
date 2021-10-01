Given /^the program subscription type is "([^"]*)" for "([^"]*)"$/ do |subscription_type, subdomain|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  org.organization_features.map(&:destroy)
  org.subscription_type = subscription_type.to_i
  org.save!
  org.make_subscription_changes
  org.programs.each{|p| p.make_subscription_changes}
end

Then /^I click the mentoring connections dropdown$/ do
	step "I click by xpath \"//div[@id='action_1']/div/a[@data-toggle='dropdown']\""
end
