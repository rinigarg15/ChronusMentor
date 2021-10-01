Feature: Making login expiry time organization specific

#A single program admin must be able to see security tab
@javascript
Scenario:
    Given the current program is "foster":"main"
    And I have logged in as "fosteradmin@example.com"
    And I follow "Manage"
    Then I follow "Program Settings"
    Then I should see "Security"

#The program admin must not see a tab
@javascript
Scenario:
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    Then I follow "Program Settings"
    Then I should not see "Security"

#If we click on the No radiobutton, I should not see the dropdown and updates must be saved
@javascript
Scenario:
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    Given the current program is "primary":""
    And I follow "Manage"
    Then I follow "Program Settings"
    And I should see "Security"
    Then I follow "Security"
    Then I check "login_exp_per_enable"
    Then I press "Save"
    Then I should see the flash "Your changes have been saved"

#If we click on the Yes radiobutton, I should see the dropdown and updates must be saved
@javascript @cross_browser
Scenario:
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    Given the current program is "primary":""
    And I follow "Manage"
    Then I follow "Program Settings"
    And I should see "Security"
    Then I follow "Security"
    Then I check "login_exp_per_enable"
    Then I select "15 mins" from "organization_security_setting_attributes_login_expiry_period"
    Then I press "Save"
    Then I should see the flash "Your changes have been saved"
    Then I should see "15 mins" selected in the dropdown