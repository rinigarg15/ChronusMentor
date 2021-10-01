Feature: Admin Should be able to Invite users to program

Background: Admin logs in
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    When I hover over "my_programs_container"
    And I select "Primary Organization" from the program selector

@javascript
  Scenario: Admin invites one user to program
    And I follow "Manage"
    And I follow "Member Views"
    Then I should see "Freakin"
    Then I should see "Admin"
    Then I should see "ram@example.com"
    And I follow "Actions"
    Then I should see "Invite to Program"
    And I follow "Invite to Program"
    Then I should see "Please select at least one user"
    Then I should not see "Student, Mentor" in the row "ct_admin_view_checkbox_40"
    Then I check "ct_admin_view_checkbox_40"
    And I follow "Actions"
    And I follow "Invite to Program"
    Then I should see "Invitation will be sent to the following member:"
    Then I should see "arun albers"
    And I should see "The users selected would receive the invitation emails customized for the selected program."
    Then I should see "click here"
    Then I should see "Invitation will be sent to the following member:"
    And I select "NWEN" from "admin_view_program_id"
    And I choose "role_assign_roles"
    And I check "Mentor"
    And I check "Student"
    And I press "Submit"
    Then I should not see "Invitation will be sent to the following member:"
    Then I should see "Invitations will be sent to all the selected member(s). Click here to visit 'Invitations Sent' listing page which will get updated shortly with the list of sent invitation(s) with it's status. Please note that we won't be able to send emails to the email addresses that are either invalid or who may correspond to existing users"
    When I open new mail
    Then I should see "Hello,  I would like to invite you to join the NWEN as a mentor and student." in the email text part body
    Then I should see "Once you do that, you can fill out your profile (which we use to match you up with other participants with similar interests and goals) and participate in the program activities.  I look forward to your participation!" in the email text part body

  @javascript @cross_browser
  Scenario: Admin invites multiple users to program
    And I follow "Manage"
    And I follow "Member Views"
    Then I check "ct_admin_view_checkbox_40"
    Then I check "ct_admin_view_checkbox_66"
    And I follow "Actions"
    And I follow "Invite to Program"
    Then I should see "Invitation will be sent to the following members:"
    Then I should see "arun albers, Assistant User"
    And I select "NWEN" from "admin_view_program_id"
    And I choose "role_assign_roles"
    And I check "Mentor"
    And I check "Student"
    And I should see "The users selected would receive the invitation emails customized for the selected program."
    And I press "Submit"
    Then I should see "Invitations will be sent to all the selected member(s). Click here to visit 'Invitations Sent' listing page which will get updated shortly with the list of sent invitation(s) with it's status. Please note that we won't be able to send emails to the email addresses that are either invalid or who may correspond to existing users"
    Then "2" email should be triggered
    When I open new mail
    Then I should see "Hello,  I would like to invite you to join the NWEN as a mentor and student." in the email text part body
    Then I should see "Once you do that, you can fill out your profile (which we use to match you up with other participants with similar interests and goals) and participate in the program activities.  I look forward to your participation!" in the email text part body

@javascript
  Scenario: Admin invites user to program from show page
    And I follow "Manage"
    And I follow "Member Views"
    And I follow "Assistant"
    Then I should see "Invite User To Program"
    And I follow "Invite User To Program"
    And I press "Submit"
    And I select "NWEN" from "program_id"
    And I choose "role_assign_roles"
    And I check "Mentor"
    And I check "Student"
    And I press "Submit"
    Then I should see "is invited to join NWEN"

    Then I should see "Invite User To Program"
    And I follow "Invite User To Program"
    And I select "NWEN" from "program_id"
    And I choose "role_assign_roles"
    And I check "Mentor"
    And I check "Student"
    And I press "Submit"
    Then I should see "is invited to join NWEN"
    When I open new mail
    Then I should see "Hello,  I would like to invite you to join the NWEN as a mentor and student." in the email text part body
    Then I should see "Once you do that, you can fill out your profile (which we use to match you up with other participants with similar interests and goals) and participate in the program activities.  I look forward to your participation!" in the email text part body

  @javascript @cross_browser
  Scenario: Admin invites non registered member (admin added profile or dormant member) to program
    Given the current program is "primary":"albers"
    And "dormant@example.com" is made the member of "albers"
    And I reset the password for member with email "dormant@example.com"
    When I follow "Manage"
    And I follow "Invitations"
    And I follow "Send Invites"
    And I choose "role_assign_roles"
    And I check "Mentor"
    And I fill in "recipients" with "dormant@example.com"
    And I press "cjs_send_invites"
    Then I should see "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly."
    And a mail should go to "dormant@example.com" having "I would like to invite you to join the Albers Mentor Program as a mentor."
    And I logout
    When I open new mail
    And I follow "Click here" in the email
    And I should see "Welcome! You have been invited to join Albers Mentor Program as a Mentor."
    And I fill in "member_password" with "chronus"
    And I fill in "member_password_confirmation" with "chronus"
    And I press "Sign up »"
    Then I should see the flash "Welcome to Albers Mentor Program. Please complete your online profile to proceed."

  @javascript
  Scenario: Admin invite and add user popup should load properly from member's profile
    And I follow "Manage"
    And I follow "Member Views"
    Then I should see "arun"
    Then I should see "arun@albers.com"
    Then I follow "arun"
    Then I follow "Invite User To Program"
    Then I should see "Invite User To Program"
    Then I should see "Albers Mentor Program"
    Then I should see "Assign role(s) to users"
    Then I should see "Allow users to select role(s)"
    Then I should see "href" attribute for link "click here" matches with "/p/albers/invite_users"
    Then I choose "Assign role(s) to users"
    And I should see "Mentor"
    And I should see "Administrator"
    And I should see "Student"

    Then I choose "Allow users to select role(s)"
    And I should see "Mentor"
    And I should see "Student"
    When I select "NWEN" from "invite_users_to_program_program_id"
    Then I should see "href" attribute for link "click here" matches with "/p/nwen/invite_users"
    Then I should see "Assign role(s) to users"
    Then I should see "Allow users to select role(s)"
    Then I cancel modal

    Then I follow "Add User To Program"
    Then I should see "Add to Program"
    Then I should see "Albers Mentor Program"
    And I should see "Mentor"
    And I should see "Student"
    Then I should see "href" attribute for link "click here" matches with "p/albers/mailer_templates/category_mails?category=1"
    When I select "NWEN" from "admin_view_program_id"
    Then I should see "href" attribute for link "click here" matches with "p/nwen/mailer_templates/category_mails?category=1"
    And I should see "Mentor"
    And I should see "Student"
    Then I cancel modal

  @javascript
  Scenario: Admin invites multiple users to program
    And I follow "Manage"
    And I follow "Member Views"
    Then I check "ct_admin_view_checkbox_40"
    Then I check "ct_admin_view_checkbox_66"
    And I follow "Actions"
    And I follow "Invite to Program"
    Then I should see "Invitation will be sent to the following members:"
    Then I should see "arun albers, Assistant User"
    And I select "NWEN" from "admin_view_program_id"
    And I choose "role_assign_roles"
    And I check "Mentor"
    And I check "Student"
    And I should see "The users selected would receive the invitation emails customized for the selected program."
    Then I cancel modal
    And I follow "Actions"
    And I follow "Add to Program"
    Then I should see "Following members will be added to the program:"
    Then I should see "arun albers, Assistant User"
    Then I should see "Mentor"
    Then I should see "Student"