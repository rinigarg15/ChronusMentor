@mentoring_area_feature @javascript @reindex @cross_browser
Feature: Confidentiality Log 
  In order to test the working of Confidentiality Audit Log
  As an admin
  I want to have a feature for enabling or disabling mentoring connection visits by admin

Scenario:Admin enables Audit Logs and visits a group
  #Given I reindex model "group"
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  Then I should not see "Admin Audit Log"
  Then I follow "Mentoring Connections"
  Then I follow "chronus & example"
  Then I should not see "Enter a reason to view confidential area"
  Then I enable admin audit logs
  Given the current program is "primary":"albers"
  And I follow "Manage"
  Then I follow "Mentoring Connections"
  Then I follow "chronus & example"
  Then I should see "Enter a reason to view confidential area"
  Then I logout
