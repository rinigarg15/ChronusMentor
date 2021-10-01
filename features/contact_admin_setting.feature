Feature: Contact Admin Settings
Background:
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"

@javascript
Scenario: Administrator Visits Contact Admin Settings page and updates the label
  And I login as super user
  And I follow "Manage"
  And I follow "Customize Contact Administrator Settings"
  Then I should see "Contact Administrator Settings"
  And I fill in "contact_admin_setting_label_name" with "Contact HR Center"
  And I choose "contact_self_link"
  And I press "Save"
  And I logout
  Given the current program is "primary":"albers"
  Then I should see "Contact HR Center"
  Then I follow "Contact HR Center"
  Then I should see "Send Message to Administrator"
  When I have logged in as "robert@example.com"
  Then I should see "Contact HR Center"
  Then I follow "Contact HR Center"
  Then I should see "Send Message to Administrator"
  And I logout
  
@javascript
Scenario: Administrator Visits Contact Admin Settings page and types in optional instructions
  And I login as super user
  And I follow "Manage"
  And I follow "Customize Contact Administrator Settings"
  Then I should see "Contact Administrator Settings"
  And I choose "contact_self_link"
  And I fill in "contact_admin_setting_content" with "Contact HR Center"
  And I press "Save"
  And I logout
  Given the current program is "primary":"albers"
  Then I follow "Contact Administrator"
  Then I should see "Contact HR Center"
  When I have logged in as "robert@example.com"
  Then I follow "Contact Administrator"
  Then I should see "Contact HR Center"
  And I logout

@javascript
Scenario: Administrator Visits Contact Admin Settings page and types in external URL
  And I login as super user
  And I follow "Manage"
  And I follow "Customize Contact Administrator Settings"
  Then I should see "Contact Administrator Settings"
  And I choose "contact_external_link"
  And I press "Save"
  Then I should not see "Settings have been saved successfully"
  And I fill in "contact_admin_setting_contact_url" with "http://www.google.com"
  And I press "Save"
  Then I should see "Settings have been saved successfully"
  And I logout
  Given the current program is "primary":"albers"
  Then I follow "Contact Administrator"
  Then I should not see "Send Message to Administrator"
  Given the current program is "primary":"albers"
  When I have logged in as "robert@example.com"
  Then I follow "Contact Administrator"
  Then I should not see "Send Message to Administrator"

@javascript
Scenario: Administrator Visits Contact Admin Settings page and updates the fields
  And I login as super user
  And I follow "Manage"
  And I follow "Customize Contact Administrator Settings"
  Then I should see "Contact Administrator Settings"
  And I fill in "contact_admin_setting_label_name" with "Contact HR Center"
  And I choose "contact_self_link"
  And I press "Save"
  Then I should see "Settings have been saved successfully"
  Then I should see "Contact Administrator Settings"
  And I fill in "contact_admin_setting_label_name" with "Contact HR Center Again"
  And I choose "contact_self_link"
  And I press "Save"
  Then I should see "Settings have been saved successfully"
  And I logout
  Given the current program is "primary":"albers"
  Then I should see "Contact HR Center Again"
  Then I follow "Contact HR Center Again"
  Then I should see "Send Message to Administrator"
  When I have logged in as "robert@example.com"
  Then I should see "Contact HR Center Again"
  Then I follow "Contact HR Center Again"
  Then I should see "Send Message to Administrator"
  And I logout