@javascript @p2 @cross-browser
Feature: Admin configuring the different visibility modes and end users viewing the impact

Background: Set the program to albers
  Given the current program is "primary":""
  Then I perform missed migrations
  Given the Admin configures the questions with all kinds of visibility mode

Scenario: Mentor logs in and checks his profile
  Given the current program is "primary":"albers"
  Then I perform missed migrations
  When I have logged in as "robert@example.com"
  And I click on profile picture and click "Edit Profile"
  And I click on the section with header "Mentoring Profile"
  Then I should not see the admin editable fields
  And I should see the user editable fields 
  Then I follow "Students" within "nav#sidebarLeft"
  And I should see the profile summary fields based on the visibility mode as a mentor
  And I logout
  When I have logged in as "mkr@example.com"
  And I click on profile picture and click "Edit Profile"
  Then I click on the section with header "Mentoring Profile"
  And I should see the user editable fields as a mentee
  And I follow "Mentors" within "nav#sidebarLeft"
  And I should see the profile summary fields based on the visibility mode as a mentee
  And I visit the profile of "userrobert@example.com"
  Then I should not see the user mentoring connection visibility field
  And I visit the profile of "robert@example.com"
  Then I should see the user mentoring connection visibility field
  Then I logout
  Given the current program is "primary":"albers"
  When I want to join as "Mentor" with "example@chronus.com"
  Then I click on the signup link sent in email to "example@chronus.com"
  Then I should not see the admin editable fields
  And I should see the user editable fields
  When I have logged in as "ram@example.com"
  When I visit the profile of "robert@example.com"
  And I follow "Edit Good unique name's profile"
  Then I click on the section with header "Mentoring Profile"
  Then I should see both admin editable and user editable fields
  Then I logout