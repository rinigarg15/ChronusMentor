Feature: Mentors or Mentees should be able to add members independent of their roles
  In order to perform the above steps
  As an user
  I want to login and enter the appropriate as required

  Background: Select the program
    Given the current program is "primary":"albers"

  @javascript
  Scenario: Student should be able to add mentors
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Membership"
    And I check "student_can_invite_mentor"
    And I press "Save"
    And I logout
    Given the current program is "primary":"albers"
    And I have logged in as "rahim@example.com"
    And I follow "Mentors"
    And I should see "Invite Mentors"
    And I follow "Invite Mentors"
    And I should see the page title "Invite Friends"
    And I should see "Select role(s)"
    And I choose "role_assign_roles"
    And I check "Mentor"
    When I fill in "recipients" with "yoyo@chronus.com, no_yoyo@chronus.com"
    And I press "cjs_send_invites"
    And I should see "Invitations will be sent."
    When I open new mail
    Then I should see "Hi, I would like to invite you to join the Albers Mentor Program." in the email text part body
    And I logout

  @javascript
  Scenario: Mentor should be able to add students
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Membership"
    And I check "mentor_can_invite_student"
    And I press "Save"
    And I logout
    Given the current program is "primary":"albers"
    And I have permission to add students
    And I have logged in as "robert@example.com"
    And I follow "Students"
    And I should see "Invite Students"
    And I follow "Invite Students"
    And I should see the page title "Invite Friends"
    And I should see "Hi, I would like to invite you to join the Albers Mentor Program. Please come and register at the site by clicking on the link in this message." in the ckeditor "message"
    And I should see "Select role(s)"
    And I choose "role_assign_roles"
    And I check "Student"
    When I fill in "recipients" with "yoyo@chronus.com, no_yoyo@chronus.com"
    And I press "cjs_send_invites"
    And I should see "Invitations will be sent."
    When I open new mail
    Then I should see "Hi, I would like to invite you to join the Albers Mentor Program." in the email text part body
    And I logout

@javascript @cross-browser
  Scenario: User with both Mentor and Student role should be able to invite mentors and students
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Membership"
    And I check "mentor_can_invite_student"
    And I press "Save"
    And I logout
    Given the current program is "primary":"albers"
    And I have permission to add students
    And I have logged in as "robert@example.com"
    And I follow "Students"
    And I should see "Invite Students"
    And I follow "Invite Students"
    And I should see the page title "Invite Friends"
    And I should see "Hi, I would like to invite you to join the Albers Mentor Program. Please come and register at the site by clicking on the link in this message." in the ckeditor "message"
    When I fill in "recipients" with "yoyo@chronus.com, no_yoyo@chronus.com"
    And I choose "role_assign_roles"
    And I check "Mentor"
    And I check "Student"
    When I fill in CKEditor "message" with "Yoyo dude, you have been invited as a mentor and student"
    When I fill in "recipients" with "yoyo@chronus.com, no_yoyo@chronus.com"
    And I press "cjs_send_invites"
    And I should see "Invitations will be sent."
    And the invitations to mentors and students should be really sent
    And I logout