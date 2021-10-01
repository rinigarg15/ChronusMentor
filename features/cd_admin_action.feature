@reindex @manage_career_development @javascript

Feature: Manage Career Development Portals
  In order to setup a Career Development Portal
  I want to create a portal as Super Admin and manage the portal as admin

  Background:
    Given the current program is "nch":""
    And I have logged in as "nch_admin@example.com"

  Scenario: Program settings for portals
    Given the current program is "nch":"portal"
    And I login as super user
    And I follow "Manage"
    And I follow "Program Settings"
    And I should not see "Matching Settings"
    And I should not see "Connection Settings"
    But I should see "Features"
    And I should see "General Settings"
    And I should see "Membership"
    And I should see "Terminology"
    And I logout
    And I have logged in as "nch_admin@example.com"
    And I follow "Manage"
    And I follow "Program Settings"
    And I should not see "Matching Settings"
    And I should not see "Connection Settings"
    And I should not see "Features" within "div.inner_tabs"
    And I should not see "Terminology"
    And I should see "General Settings"
    And I should see "Membership"
    And I should see "Permissions"

    Given the current program is "nch":"main"
    And I login as super user
    And I follow "Manage"
    And I follow "Program Settings"
    And I should see "Matching Settings"
    And I should see "Connection Settings"
    But I should see "Features"
    And I should see "General Settings"
    And I should see "Membership"
    And I should see "Terminology"
    And I logout
    And I have logged in as "nch_admin@example.com"
    And I follow "Manage"
    And I follow "Program Settings"
    And I should see "Matching Settings"
    And I should see "Connection Settings"
    And I should not see "Features" within "div.inner_tabs"
    And I should not see "Terminology"
    And I should see "General Settings"
    And I should see "Membership"
    And I should see "Permissions"
    And I login as super user
    And I change engagement type of program "nch":"main" to ""
    And I follow "Manage"
    And I follow "Program Settings"
    And I should not see "Matching Settings"
    And I should not see "Connection Settings"
    But I should see "Features"
    And I should see "General Settings"
    And I should see "Membership"
    And I should see "Terminology"

  Scenario: Permission to Publish Article
    Given the current program is "nch":"portal"
    And I login as super user
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Permissions"
    And I should see "Employees can publish Articles"
    And I check "Employees can publish Articles"
    And I press "Save"
    And I should see "Your changes have been saved"
    
    Given the current program is "nch":"main"
    And I login as super user
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Permissions"
    And I should see "Students can publish Articles "
    And I check "Students can publish Articles"
    And I press "Save"
    And I should see "Your changes have been saved"
  
  @javascript
  Scenario: Admin invite and add user popup should load properly from member's profile for portal
    Then I add "invite_employees" permission for "admin" role in "nch":"portal"
    And I follow "Manage"
    And I follow "Member Views"
    Then I should see "Mentee"
    Then I should see "nch_mentee@example.com"
    Then I follow "Mentee"
    Then I follow "Invite User To Program"
    Then I should see "Invite User To Program"
    Then I should see "Primary Career Portal"
    And I should see "Administrator"
    And I should see "Employee"

    When I select "NCH Mentoring Program" from "invite_users_to_program_program_id"
    Then I should see "Assign role(s) to users"
    And I choose "role_assign_roles"
    And I check "Mentor"
    And I check "Student"
    Then I should see "Allow users to select role(s)"
    And I press "Submit"

    Then I follow "Add User To Program"
    Then I should see "Add to Program"
    Then I should see "Primary Career Portal"
    And I should see "Employee"
    And I should see "Administrator"
    When I select "NCH Mentoring Program" from "admin_view_program_id"
    And I should see "Mentor"
    And I should see "Student"
    Then I follow "Cancel"

  @javascript
  Scenario: Admin invites multiple users to program  
    And I follow "Manage"
    And I follow "Member Views"
    Then I select member with email "nch_mentee@example.com" in all members page
    Then I select member with email "nch_mentor@example.com" in all members page
    And I follow "Actions"
    And I follow "Invite to Program"
    Then I should see "Invitation will be sent to the following members:"
    Then I should see "Nch mentor, Nch Mentee" 
    And I select "NCH Mentoring Program" from "admin_view_program_id"
    And I choose "role_assign_roles"
    And I check "Mentor"
    And I check "Student"
    And I should see "The users selected would receive the invitation emails customized for the selected program."
    Then I follow "Cancel"
    And I follow "Actions"
    And I follow "Add to Program"
    Then I should see "Following members will be added to the program:"
    Then I should see "Nch mentor, Nch Mentee"
    Then I should see "Mentor"
    Then I should see "Student"

  @javascript
  Scenario: Admin invitation link should always be visible even if admin doesn't have permission of invite
    Given the current program is "nch":"portal"
    Then I add "invite_employees" permission for "admin" role in "nch":"portal"
    Then I follow "Manage"
    And I should see "Invitations"
    And I follow "Invitations"
    Then I should see "Invitation to join {{subprogram_or_program_name}} {{as_role_name_articleized}}"
    And I should see "You have a pending invitation to join {{subprogram_or_program_name}}"
    And I should see "Your invitation expires tomorrow!"
    Then I should see "Provide user details to invite"
    And I should see "Employee"
    And I should see "Administrator"
    And I check "Employee"
    And I fill in "Recipient emails" with "new_test@example.com"
    Then I press "Send Invites"
    Then I follow "Track Invitation Status"
    Then I should see "new_test@example.com" within ".k-grid-content"
    Then I should see "Employee" within ".k-grid-content"
    Then I should see "Freakin Admin" within ".k-grid-content"
    Then I should see "Sent" within ".k-grid-content"
    Then I remove "invite_employees" permission for "admin" role in "nch":"portal"
    Then I remove "invite_admins" permission for "admin" role in "nch":"portal"
    Then I follow "Manage"
    And I should see "Invitations"

    @javascript
    Scenario: Admin sending invitation to user from all member page and user signing up
      Given the current program is "nch":"portal"
      Then I add "invite_employees" permission for "admin" role in "nch":"portal"
      Then I follow "Manage"
      And I should see "Invitations"
      And I follow "Invitations"
      Then I should see "Provide user details to invite"
      And I should see "Employee"
      And I should see "Administrator"
      And I check "Employee"
      And I check "Administrator"
      And I fill in "Recipient emails" with "new_test@example.com"
      Then I press "Send Invites"
      Then I should see "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly."
      Then "new_test@example.com" should receive an email
      And I logout
      When I open new mail
      Then I should see "Invitation to join Primary Career Portal as an administrator and employee" in the email subject
      And I follow "Click here" in the email
      And I should see " Welcome! You have been invited to join Primary Career Portal as an Administrator and Employee."
      And I fill in "member_first_name" with "Test"
      And I fill in "member_last_name" with "user"
      And I fill in "member_password" with "chronus"
      And I fill in "member_password_confirmation" with "chronus"
      Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
      And I press "Sign up »"
      Then I should see the flash "Welcome to Primary Career Portal. Please complete your online profile to proceed."

  Scenario: Super Admin should not be able to see term for Career Development for organizations where career development is disabled
    When I login as super user
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Terminology"
    Then I should see "Term for Career development"
    And I disable the feature "career_development" as a super user
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Terminology"
    Then I should not see "Term for Career development"
  