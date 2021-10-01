@javascript
Feature: Login Management & Externally Authenticated User

Background:
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Login Management"

Scenario: Customize Sections
  Then I should see "Default Logins"
  And I should not see "Custom Logins"
  When I follow "Customize" of "Default" logins section
  Then I should not see "Show on Top"
  When I add a "SOAP" login from backend
  And I follow "Cancel"
  Then I should see "Custom Logins"
  When I follow "Customize" of "Custom" logins section
  Then I should see "Show on Top" checked in login section customization
  When I fill in "custom" login section title and description with "CT" and "CD"
  And I press "Save"
  Then I should see the flash "The 'Custom Logins' section has been customized successfully."
  When I follow "Customize" of "Default" logins section
  Then I should see "Show on Top" unchecked in login section customization
  When I fill in "default" login section title and description with "DT" and "DD"
  And I check "Show on Top" in login section customization
  And I press "Save"
  Then I should see the flash "The 'Default Logins' section has been customized successfully."
  When I follow "Customize" of "Custom" logins section
  Then I should see "Show on Top" unchecked in login section customization
  When I logout
  And I follow "Login"
  Then I ensure the default login section appears before custom login section
  And I should see "CT"
  And I should see "CD"
  And I should see "DT"
  And I should see "DD"

Scenario: Edit Password Policy
  Then I should see the action "Password Policy" available for "Email" login
  And I should not see the action "Password Policy" available for "LinkedIn" login
  And I should not see the action "Password Policy" available for "Google" login
  When I follow "Password Policy"
  And I fill in password regex and message as ".{92,}" and "Should be more than 92 characters"
  And I press "Save"
  Then I should see the flash "Password Policy has been set for the 'Email' login successfully."
  When I click on profile picture and click "Account Settings"
  Then I should see "Should be more than 92 characters"

Scenario: Enable/Disable Logins
  Then I should not see the action "Disable" available for "Email" login
  And I should not see the action "Enable" available for "Email" login
  And I should see the action "Enable" available for "LinkedIn" login
  And I should not see the action "Disable" available for "LinkedIn" login
  When I follow the action "Enable" available for "LinkedIn" login
  Then I should see "Are you sure you want to enable 'LinkedIn' login?"
  When I confirm popup
  Then I should see the flash "'LinkedIn' login has been enabled successfully."
  And I should see the action "Disable" available for "LinkedIn" login
  And I should not see the action "Enable" available for "LinkedIn" login
  When I follow the action "Disable" available for "Email" login
  Then I should see "Are you sure you want to disable 'Email' login?"
  When I confirm popup
  Then I should see the flash "'Email' login has been disabled successfully."
  And I should not see the action "Disable" available for "LinkedIn" login

Scenario: Delete Logins
  Given I add a "SOAP" login from backend
  When I reload the page
  Then I should see the action "Delete" available for "SOAP" login
  And I should not see the action "Disable" available for "SOAP" login
  And I should not see the action "Delete" available for "Email" login
  And I should not see the action "Delete" available for "LinkedIn" login
  And I should not see the action "Delete" available for "Google" login
  When I follow the action "Disable" available for "Email" login
  And I confirm popup
  Then I should not see the action "Delete" available for "SOAP" login
  When I follow the action "Enable" available for "Email" login
  And I confirm popup
  And I follow the action "Delete" available for "SOAP" login
  Then I should see "Users will no longer be able to login using 'SOAP Login'. Do you want to continue?"
  And I confirm popup
  Then I should see the flash "'SOAP Login' login has been removed successfully."
  And I should not see "Custom Logins"

Scenario: Customize Logins
  Given I add a "SAML" login from backend
  When I reload the page
  Then I should see the action "Customize" available for "SAML" login
  And I should not see the action "Customize" available for "Email" login
  And I should not see the action "Customize" available for "LinkedIn" login
  And I should not see the action "Customize" available for "Google" login
  When I follow the action "Customize" available for "SAML" login
  And I fill in the login title and logo with "Employee Signon" and "test_pic.png"
  And I press "Save"
  Then I should see the flash "'Employee Signon' login has been customized successfully."
  When I follow the action "Customize" available for "Employee Signon" login
  Then I should see "test_pic.png"
  When I remove the login logo
  And I press "Save"
  And I follow the action "Customize" available for "Employee Signon" login
  Then I should not see "test_pic.png"

Scenario: SAML Login
  Then I should see "Add SAML 2.0 Login"
  And I should not see the action "Configure" available for "Email" login
  And I should not see the action "Configure" available for "LinkedIn" login
  And I should not see the action "Configure" available for "Google" login
  When I add a "SAML" login from backend
  And I add a "SOAP" login from backend
  And I reload the page
  Then I should not see "Add SAML 2.0 Login"
  And I should see the action "Configure" available for "SAML" login
  And I should not see the action "Configure" available for "SOAP" login

Scenario: Externally authenticated user
  When I logout
  Then I should see "Login"
  And I should not see "Sign out"
  Given I am an externally authenticated user
  When I reload the page
  Then I should not see "Login"
  And I should see "Sign out"
  When I change to mobile view
  And I click on the hamburger icon
  Then I should not see "Login"
  And I should see "Sign out"