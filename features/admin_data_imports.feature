@javascript
Feature: Admin Data Imports  

Scenario: Admin visits Data Imports from Standalone Program
  Given the current program is "foster":"main"
  And I have logged in as "fosteradmin@example.com"  
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Features"
  Then I should see "Data Import Log"
  And I check "data_import"  
  And I press "Save"    
  And I logout as super user

  Given the current program is "foster":"main"
  And I follow "Manage"
  And I follow "Data Import Summary"
  Then I should see "Data Import Summary"
  And I should see "No data imports yet."
  And I should see the tab "Manage" selected

Scenario: Admin visits Data Imports from Non-Standalone Program
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"  
  And I enable "data_import" feature as a super user

  Given the current program is "primary":""
  And I follow "Manage"
  And I follow "Data Import Summary"
  Then I should see "Data Import Summary"
  And I should see "No data imports yet."
  And I should see the tab "Manage" selected
