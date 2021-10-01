@javascript
Feature: Linkedin Imports feature

# We are not running this file in TDDIUM as accessing other sites from TDDIUM is not possible

Scenario: Linkedin Imports feature should be accesible by super user
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Features"
  Then I should see "Linkedin Imports"

Scenario: Linkedin Imports feature should be accesible by admin
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Features"
  Then I should see "Linkedin Imports"

@javascript
Scenario: Mentor imports from Linkedin if linkedin feature enabled
  Given the current program is "primary":""
  Given I update the linkedin credentials for "primary"
  And I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Features"
  And I check "Linkedin Imports"
  And I press "Save"
  And I logout
  When the current program is "primary":"albers"
  And I have logged in as "robert@example.com"
  And I click on profile picture and click "Edit Profile"
  And I click on the section with header "Work and Education"
  Then I should see "Click here to import your experience"
  Then I click on the image "Linkedin"
  Then I switch to the linkedin window and enter the credentials
  Then I should see "The experiences have been imported"
  Then I save the section "Work and Education"
  And I follow "Actions"
  And I follow "View your Profile"
  Then I should see "ABC Products Inc"
  Then I should see "Senior Executive of Telecommunication|Jan 2009 - Present"
  Then I should see "Golden Era Corp"
  Then I should see "Executive of Telecommunication|Jan 2007 - Jan 2009"
  And I logout

@javascript
Scenario: Mentor does not see "Import from linkedin" if linkedin feature disabled
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Features"
  And I uncheck "Linkedin Imports"
  And I press "Save"
  And I logout
  When the current program is "primary":"albers"
  And I have logged in as "robert@example.com"
  And I click on profile picture and click "Edit Profile"
  Then I should not see "Click here to import your experience"
  Then I should not see "Import from Linkedin"
  And I logout
