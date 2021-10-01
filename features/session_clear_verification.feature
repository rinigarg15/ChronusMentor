@admin_mentor_steps
Feature: Admin invites (mentors,mentees) then becomes a mentor
In order to perform the above steps
  As an admin
  I want to login and enter the appropriate as required

  Background: Admin logs in
   Given the current program is "primary":"albers"
   And I have logged in as "ram@example.com"
   Then I should see "Dashboard"
@javascript @cross-browser
  Scenario: Admin invites mentors
    And I follow "Manage"
    And I follow "Invitations"
    And I follow "Send Invites"
    And I choose "role_assign_roles"
    And I check "Mentor"
    And I fill in "recipients" with "mentor1@iit.com"
    And I press "cjs_send_invites"
    And a mail should go to "mentor1@iit.com" having "I would like to invite you to join the Albers Mentor Program as a mentor."
    Then I should see "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly."
    And I follow "Manage"
    #This is just to back mark this page
    And I follow "Membership Requests"
    Then I logout

    When "mentor1@iit.com" opens the email with subject "Invitation to join Albers Mentor Program as a mentor"
    And I follow "Click here" in the email
    And I should see "Welcome! You have been invited to join Albers Mentor Program as a Mentor."
    Then I fill in "member_first_name" with "mentor"
    Then I fill in "member_last_name" with "me"
    And I fill in "member_password" with "monkey"
    And I fill in "member_password_confirmation" with "monkey"
    And element with id "#member_email" should be disabled
    Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
    And I press "Sign up »"
    Then I should see the flash "Welcome to Albers Mentor Program. Please complete your online profile to proceed."
    And I follow "Mentors"
    And I follow "Invite Mentors"
    And I check "Mentor"
    And I fill in "recipients" with "mentor2@iit.com"
    And I press "cjs_send_invites"
    And a mail should go to "mentor2@iit.com" having "You have been invited by mentor me to join Albers Mentor Program as a mentor."
    Then I should see "Invitations will be sent."