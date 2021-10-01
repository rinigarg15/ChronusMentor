@admin_steps
Feature: Admin invites (mentors,mentees), edits program overview, adds the mentors directly, add adminnotes to a user
  In order to perform the above steps
  As an admin
  I want to login and enter the appropriate as required

  Background: Admin logs in
    Given the current program is "foster":"main"
    And I have logged in as "fosteradmin@example.com"
    And there is a private theme for "foster"

  @javascript @cross_browser
  Scenario: Admin invites admins
    And I follow "Manage"
    And I follow "User Views"
    And I click "a.dropdown-toggle.btn"
    And I follow "Invite Users"
    And I should see "Invitations"
    And I choose "role_assign_roles"
    And I check "Administrator"
    And I fill in "recipients" with "admin2@iit.com"
    And I press "cjs_send_invites"
    Then I should see "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly."
    And a mail should go to "admin2@iit.com" having "Hello,  I would like to invite you to join the foster as an administrator."
    And I logout
    When I open new mail
    And I follow "Click here" in the email
    And I should see "Welcome! You have been invited to join foster as an Administrator."
    Then I fill in "member_first_name" with "mentor"
    Then I fill in "member_last_name" with "me"
    And I fill in "member_password" with "monkey"
    And I fill in "member_password_confirmation" with "monkey"
    And element with id "#member_email" should be disabled
    Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
    And I press "Sign up »"
    And I follow "Manage"
    Then I should see "Program Branding"
    And I follow "Program Branding"

@javascript
 Scenario: Admin logs out
   And I logout
   Then I should see "General Overview"

@javascript
  Scenario: Admin invites existing user of standalone program as admin so user should also become organization admin
    Given I reset the password for member with email "millad5@foster.com"
    And I visit the organization admins page
    And I should see "Freakin Admin"
    And I should not see "Artie Artie"
    And I follow "Manage"
    And I follow "Invitations"
    And I choose "role_assign_roles"
    And I check "Administrator"
    And I fill in "recipients" with "millad5@foster.com"
    And I press "cjs_send_invites"
    Then I should see "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly."
    And a mail should go to "millad5@foster.com" having "Hello,  I would like to invite you to join the foster as an administrator."
    And I logout
    When I open new mail
    And I follow "Click here" in the email
    And I should see "Welcome! You have been invited to join foster as an Administrator."
    And I fill in "member_password" with "chronus"
    And I fill in "member_password_confirmation" with "chronus"
    And I press "Sign up »"
    Then I should see the flash "Welcome to foster. Please complete your online profile to proceed."
    And I follow "Home"
    And I visit the organization admins page
    And I should see "Artie Artie"
    And I should see "Freakin Admin"