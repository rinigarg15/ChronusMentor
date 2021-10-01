# encoding: utf-8
Feature: Admin adds users directly

Background: Admin logs in
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I login as super user
  And clear mail deliveries

@javascript
Scenario: Admin logs in and adds admin directly
  When I follow "Manage"
  And I follow "Add Users"
  And I check "role_admin"
  And I fill in by css "user_email" with "NewAdmin@iit.com"
  And I click "#cjs_add_user_next"
  And I fill in by css "user_member_first_name" with "New"
  And I fill in by css "user_member_last_name" with "Admin"
  And I press "save_and_add"
  And I should see the flash "New Admin (Administrator) has been added as an Administrator. You can continue adding the next Administrator."
  And a mail should go to "NewAdmin@iit.com" having "Freakin Admin \(Administrator\) has invited you to join Albers Mentor Program as an administrator."

@javascript
Scenario: Admin adding a user
  When I follow "Manage"
  And I follow "Add Users"
  And I check "role_admin"
  And I fill in by css "user_email" with "valid_o'email@iit.com"
  And I click "#cjs_add_user_next"
  And I check "role_mentor"

@javascript @enrollment_scenario @cross_browser
Scenario: Admin logs in and adds mentors directly. The user signs up and verifies the details
  And I give permission to admins in program "primary":"nwen"
  Then I hover over "my_programs_container"
  And I select "NWEN" from the program selector
  And I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from Primary Organization"
  When I set filter by program "primary":"albers"
  Then I should see "na@chronus.com"
  And I should see "Actions"

  Given I reset the password for member with email "na@chronus.com"
  When I select "na@chronus.com" from the sub-program user import selector
  Then I follow "Add to Program" in the bulk actions
  And I click "#Mentor"
  And I press "Submit"
  Then I should see "The selected user (in Active state) has been imported to this program as Mentor"
  Then I logout
  And a mail should go to "na@chronus.com" having "You have been invited by Freakin Admin \(Administrator\) to join NWEN as a mentor"
  And I open new mail
  And I follow "Accept and sign up" in the email
  Then I should see "Sign up with Password"

@javascript @enrollment_scenario
Scenario: Admin logs in and adds mentors directly. The user signs up and verifies the details
  Then I logout
  And I have logged in as "mkr@example.com"
  Then I logout
  And I have logged in as "ram@example.com"
  And I give permission to admins in program "primary":"nwen"
  Then I hover over "my_programs_container"
  And I select "NWEN" from the program selector
  And I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from Primary Organization"
  When I set filter by program "primary":"albers"
  Then I should see "mkr@example.com"
  And I should see "Actions"

  When I select "mkr@example.com" from the sub-program user import selector
  Then I follow "Add to Program" in the bulk actions
  And I click "#Mentor"
  And I press "Submit"
  Then I should see "The selected user (in Active state) has been imported to this program as Mentor"
  Then I logout
  And a mail should go to "mkr@example.com" having "You have been invited by Freakin Admin \(Administrator\) to join NWEN as a mentor"
  And I open new mail
  And I follow "Accept and sign up" in the email
  Then I should see "Login"