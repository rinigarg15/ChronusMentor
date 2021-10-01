Feature: Sales demo support

@javascript
Scenario: Admin visits the sales demo page
  When I visit default_demo_host
  And I should be redirected to super login page
  And I login as super user
  And I should see "Organization name"
  And I should see "Web Address"
  And I should see "#organization_name" not hidden
  And I should see "#organization_program_domain_subdomain" not hidden
  And I should see "#organization_subscription_type" not hidden
  And I should not see "Organization name cannot be empty"
  And I should not see "Web address cannot be empty"
  And I press "Setup Program"
  Then I should see "Organization name cannot be empty"
  And I fill in "organization_name" with "dssddsd"
  And I press "Setup Program"
  Then I should see "Web address cannot be empty"