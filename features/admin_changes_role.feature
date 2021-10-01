Feature: Changing User Role
  In order help in administrative work
  As an admin
  I want to add and remove administrators

  Background:
    Given the current program is "primary":"albers"

@javascript
  Scenario: Administrator suspends a user
    Given I have logged in as "ram@example.com"
    And "robert@example.com" is an active user in "primary":"albers"
    When I navigate to "robert@example.com" profile in "albers"
    Then I should see "Deactivate Membership"
    And I should see the tooltip "Clicking here will deactivate the membership of Good unique name from the program and Good unique name will no longer have access to the program" on hover of the suspend link
    Then I follow "Deactivate Membership"
    Then I should see "Reason *"
    When I fill in "state_change_reason" with "You are stupid" within "#suspend_user_form"
    And I press "Deactivate"
    Then I should see the flash "Good unique name's membership has been deactivated from this program."
    When I navigate to "robert@example.com" profile in "albers"
    Then I should see the flash "Good unique name's membership has been deactivated from this program."
    And I should not see "to deactivate the membership of Good unique name from the program"
    And I hover over "reactivate_user_link" and should see "Click to reactivate Good unique name in the program"
    And I follow "Reactivate"
    Then I confirm popup
    Then I should see the flash "Good unique name's membership has been reactivated in this program."
    Then mail should go to "robert@example.com" having "has been reactivated"

@javascript @cross_browser
  Scenario: Administrator remove a user
    Given the current program is "annauniv":""
    And I have logged in as "ceg_admin@example.com"
    And I enable "organization_profiles" feature as a super user
    And I follow "Manage"
    And I follow "Member Views"
    And I follow "mental"
    Then I should see "Remove mental mentor"
    When I hover over "remove_member_link"
    Then I should see "Click to remove mental mentor from the Anna University permanently."
    Then I follow "Remove mental mentor"
    Then I should see "You are about to remove mental mentor from all programs. Did you intend to suspend the membership instead?"
    And I press "Remove member"
    Then I should see "mental mentor's profile, any engagements and other contributions have been removed"

@javascript
  Scenario: Administrator makes himself a mentor and student and then temoves the roles
    Given I have logged in as "ram@example.com"
    And "ram@example.com" is not a student in "primary":"albers"
    And "ram@example.com" is not a mentor in "primary":"albers"
    When I navigate to "ram@example.com" profile in "albers"
    And I follow "Change Roles"
    And I check "Mentor"
    And I check "Student"
    And I press "Submit"
    Then I should see "The roles have been successfully updated"
    Then check "ram@example.com" is a student in "primary":"albers"
    And check "ram@example.com" is a mentor in "primary":"albers"
    Then I navigate to "ram@example.com" profile in "albers"
    And I follow "Change Roles"
    Then I uncheck "Mentor"
    And I uncheck "Student"
    And I press "Submit"
    Then I should see "The roles have been successfully updated"
    Then "ram@example.com" is not a student in "primary":"albers"
    And "ram@example.com" is not a mentor in "primary":"albers"

@javascript @cross_browser
 Scenario: User quits with pending profile and admin suspends and reactivates the user
    And the current program admin has added required questions for "mentor"
    And I have logged in as "ram@example.com"
    And I logout
    When Admin sends program invitation email to "pending_new@example.com" as "mentor"
    When I open new mail
    And I follow "Click here" in the email
    And I should see "Welcome! You have been invited to join Albers Mentor Program as a Mentor."
    Then I fill in "member_first_name" with "Greg"
    Then I fill in "member_last_name" with "Martin"
    And I fill in "member_password" with "monkey"
    And I fill in "member_password_confirmation" with "monkey"
    And element with id "#member_email" should be disabled
    Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
    And I press "Sign up »"
    Then I should see the flash "Welcome to Albers Mentor Program. Please complete and publish your online profile to proceed."
    And I logout

    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    When I visit the profile of "pending_new@example.com"
    Then I should see "The member has not yet published their profile"
    And I should see "Deactivate Membership"
    Then I follow "Deactivate Membership"
    When I deactivate with the reason "Some reason"
    Then I should see "Greg Martin's membership has been deactivated from this program."

    # Now reactivate. Should see the reactivation message.
    When I follow "Reactivate"
    Then I confirm popup
    Then I should see "Greg Martin's membership has been reactivated in this program"

    # Refreshing the page should show the pending message.
    When I visit the profile of "pending_new@example.com"
    Then I should see "The member has not yet published their profile"

@javascript @cross_browser
  Scenario: Administrator makes a student into mentor
    Given I have logged in as "ram@example.com"
    And "student_14@example.com" is a student in "primary":"albers"
    And "student_14@example.com" is not a mentor in "primary":"albers"
    When I navigate to "student_14@example.com" profile in "albers"
    And I follow "Change Roles"

    And "student" role checkbox should be disabled
    When I hover over "change_mentor_role"
    Then I should not see "User must have at least one role"
    When I hover over "change_student_role"
    Then I should see "User must have at least one role"
    Then I check "role_names_mentor"
    And "student" role checkbox should not be disabled

    Then I uncheck "role_names_mentor"
    And "student" role checkbox should be disabled
    When I hover over "change_student_role"
    Then I should see "User must have at least one role"

    And I press "Submit"
    Then I should see "Please Add/Remove roles before submitting"

    Then I check "role_names_mentor"
    Then I uncheck "role_names_student"
    And "mentor" role checkbox should be disabled
    When I hover over "change_mentor_role"
    Then I should see "User must have at least one role"
    And I fill in "role_change_reason_text" with "Roles updated as you requested"
    And I press "Submit"
    Then I should see "The roles have been successfully updated"
    Then "student_14@example.com" is not a student in "primary":"albers"
    And check "student_14@example.com" is a mentor in "primary":"albers"
    Then I logout

@javascript
  Scenario: Administrator makes a student into administrator
    Given I have logged in as "ram@example.com"
    And "student_14@example.com" is a student in "primary":"albers"
    And "student_14@example.com" is not an administrator in "primary":"albers"
    When I navigate to "student_14@example.com" profile in "albers"
    And I follow "Change Roles"

    And "student" role checkbox should be disabled
    When I hover over "change_admin_role"
    Then I should not see "User must have at least one role"
    When I hover over "change_student_role"
    Then I should see "User must have at least one role"
    Then I check "role_names_admin"
    And "student" role checkbox should not be disabled

    Then I uncheck "role_names_student"
    And "admin" role checkbox should be disabled
    When I hover over "change_admin_role"
    Then I should see "User must have at least one role"
    And I fill in "role_change_reason_text" with "Roles updated as you requested"
    And I press "Submit"
    Then I should see "The roles have been successfully updated"
    Then "student_14@example.com" is not a student in "primary":"albers"
    Then "student_14@example.com" should be an administrator in "primary":"albers"
    Then I logout

@javascript @p2
Scenario: Checking the cases where Administrator cannot change role

  Given I have logged in as "ram@example.com"
  When I navigate to "robert@example.com" profile in "albers"
  And I follow "Change Roles"
  And "mentor" role checkbox should be disabled
  When I hover over "change_mentor_role"
  Then I should see "Has an ongoing Mentoring Connection"
  And I should see "Has 11 pending mentor requests"
  When I navigate to "rahim@example.com" profile in "albers"
  Then I should see "Change Roles"
  And I follow "Deactivate Membership"
  Then I should see "Reason *"
  When I fill in "state_change_reason" with "You are stupid"
  And I press "Deactivate"
  Then I should see "Change Roles"
  Then I follow "Reactivate Membership"
  Then I confirm popup
  Then I should see "Change Roles"
  Then I logout

@javascript @p2
  Scenario: Checking the cases where admin role can not be changed

    Given I have logged in as "ram@example.com"
    When I navigate to "ram@example.com" profile in "albers"
    And I follow "Change Roles"
    And "admin" role checkbox should be disabled
    When I hover over "change_admin_role"
    Then I should not see "User must have at least one role"
    And I logout
