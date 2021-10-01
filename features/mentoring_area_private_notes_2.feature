Feature: Mentoring Connection Journal
In order to log their personal notes
Connected members should be able to add/remove/edit journal entries

Background: Enable admin audit logs
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  Then I enable admin audit logs
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user
  And I logout

@javascript
Scenario: Read-only journal mode for expired connection
  When "mkr@example.com" has only one expired connection
  Given the current program is "primary":"albers"
  When I have logged in as "mkr@example.com"
  And I follow "name & madankumarrajan"
  And I follow "Journal"
  Then I should see "I did the assignment yesterday; it was tough"
  And I should see "My second note." within "#private_notes"
  And I should see "My third note." within "#private_notes"

  # New entry form should not be there.
  But I should not see "Add New Note"

  # Editing not supported
  And I should not see "Edit" within "#private_notes"
  And I should not see "Delete" within "#private_notes"

@javascript
Scenario: Do not show any private note to administrator
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I visit the mentoring connection of "mkr@example.com"
  And I give confidentiality reason as "some reason"
  But I should not see "Private Journal"

@javascript
Scenario: Should see unpaginated list of entries
  When there are "15" journal entries for "mkr@example.com"
  Given the current program is "primary":"albers"
  When I have logged in as "mkr@example.com"
  And I follow "name & madankumarrajan"
  And I follow "Journal"
  Then I should see "1 - 10 of 18"

@javascript
Scenario: Do not show any private note to administrator when working on behalf of mentor
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  Then I enable WOB in "primary"
  And I follow "Mentors"
  And I follow "Good unique"
  And I follow "Work on Behalf"
  Then I should see "You are currently working on behalf of Good unique name"
  And I visit the mentoring connection of "robert@example.com"
  But I should not see "Private Journal"

@javascript
Scenario: Do not show any private note when the feature is disabled in the program
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Connection Settings"
  Then I should not see "Allow private journals for mentoring connection"
  Then I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Connection Settings"
  And I follow "Advanced Options"
  Then I should see "Allow private journals for Mentoring Connection"
  And I should see the radio button "program_allow_private_journals_true" selected
  And I choose "program_allow_private_journals_false"
  And I press "Save"
  Then I logout as super user
  Then I logout

  Given the current program is "primary":"albers"
  When I have logged in as "mkr@example.com"
  And I follow "name & madankumarrajan"


  Then I should not see "Private Journal"
