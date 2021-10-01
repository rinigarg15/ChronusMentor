@javascript 
Feature: Organization Profile

@javascript @cross-browser
Scenario: Admin Views All Members Listing Page
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And I enable "organization_profiles" feature as a super user
  And I follow "Manage"
  And I follow "Member Views"
  #pagination
  And I should not see "moderated_student@example.com"
  Then I follow "Go to the next page"
  Then I should see "moderated_student@example.com"
  Then I follow "Go to the previous page"
  And I should not see "moderated_student@example.com"
  #items per page
  And I should not see "student_11@example.com"
  Then I paginate table by "50" items
  Then I should see "student_11@example.com"
  Then I paginate table by "25" items
  #sort by last name
  Then I should not see "teacher_4@example.com"
  Then I sort table by "last_name"
  Then I should see "teacher_4@example.com"
  #sort by first name
  Then I should not see "robert@example.com"
  Then I sort table by "first_name"
  Then I should see "robert@example.com"

  Then I should see "Freakin"
  Then I should see "ram@example.com"
  Then I should see "Albers Mentor Program (Administrator)"
  Then I should see "Active"
  And I follow "Good unique"
  Then I should see "Basic Information"
  Then I should see "robert@example.com"
  Then I follow "Manage"
  And I follow "Albers Mentor Program"
  Then I hover over "my_programs_container"
  Then I logout
  And I have logged in as "rahim@example.com"
  When I navigate to "student_0@example.com" profile in "albers"
  Then I should see "Basic Information"
  Then I should not see "student_0@example.com"
  Then I logout

Scenario: Standalone Program
  Given the current program is "foster":""
  And I have logged in as "fosteradmin@example.com"
  And I enable "organization_profiles" feature as a super user
  And I follow "Manage"
  And I should see "Member Views"
  Then I logout

@javascript
Scenario: Error flash Message  should be displayed to dashboard
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And I login as super user
  When I follow "Manage"
  And I follow "New Program"
  And I fill in "Name of the Program" with "iitb"
  When I follow "Next"
  Then I choose "creation_way_0"
  And I click "#program_engagement_type_1"
  And I click "#program_engagement_type"
  And I press "Done"
  Then I should see "Dashboard"
  And I should see "The Program has been successfully setup!"

@javascript @cross-browser
Scenario: Updating the account settings page
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I click on profile picture and click "Account Settings"
  And I select "Asia" from "timezone_area"
  And I select "(GMT+04:00) Muscat" from "member_time_zone"
  And I press "Save Settings"
  And I should see "Your changes have been saved"
  And I change the notification setting in accounts settings page to "aggregate"
  And I press "Save Settings" within "#edit_user_1"
  And I should see "Your changes have been saved"

@javascript
Scenario: Dormant Member logs in and tries to view profile
  Given the current program is "primary":"albers"
  And there is a dormant member with email "dormantinvite@example.com"
  When I have logged in as "dormantinvite@example.com"
  Then I hover over "my_profile"
  Then I should not see "View Profile"
  Then I logout