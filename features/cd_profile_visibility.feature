@reindex @manage_career_development @javascript
Feature: A Career Development Admin configuring the different visibility modes and end users viewing the impact

Background: Set the program to albers
  Given the current program is "nch":""
  Then I perform missed migrations
  Given the CD Admin configures the questions with all kinds of visibility modes

Scenario: Employee logs in and checks his profile
  Given the current program is "nch":"portal"
  Then I perform missed migrations
  When I have logged in as "nch_employee@example.com"
  Then I follow "Edit Profile" within "#profile_preview"
  And I click on the section with header "Work and Education"
  And I should see "Current Education"
  Then I click on the section with header "More Information"
  And I should see "How old are you?"
  And I should not see "What is your interest?"
  And I logout

  When I have logged in as "nch_admin@example.com"
  And I follow "Employees" within "#sidebarLeft"
  Then I should see "American boys school"
  And I should not see "How old are you?"
  And I should not see "What is your interest?"
  And I visit the profile of "nch_employee@example.com"
  Then I should see "Current Education"
  And I should see "American boys school"
  And I should see "How old are you?"
  And I should see "What is your interest?"
