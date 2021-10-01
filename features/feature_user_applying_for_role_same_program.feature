Feature: Existing User gets new roles via request role

Background: Enable Enrollment Feature
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And clear mail deliveries
  And I enable "enrollment_page" feature as a super user
  Then I logout

@enrollment_scenario
@javascript @cross-browser
Scenario: Admin changes program membership settings
  Given the current program is "primary":"albers"
  When I call "student" role as "Mentee" in "primary":"albers"
  When I call "mentor" role as "Super Mentor" in "primary":"albers"
  Then I add profile questions for "user" role in "primary":"albers"
  Then I add a membership question in non default section for mentor and student roles in "primary":"albers"

  #User requests to become mentor
  When I have logged in as "user_role@example.com"
  And I should not see "My Mentoring Connections"
  Then I visit the all programs listing
  Then I should not see join options for "primary":"albers"
  Then I visit the all programs listing
  And I should see "User" for "primary":"albers"
  Then I follow enrollment page link for "primary":"albers"
  And I select "Super Mentor" from "roles"
  And I press "Proceed"
  And I should see "To join as Super Mentor, complete and submit the form below."
  And I should see "About Me"
  And I fill the answer "About Me" with "I want to be a mentor"
  And I press "Submit"
  Then I should see "Your request has been sent to the program administrators. You will receive an email once the request is accepted."
  Then I visit the all programs listing
  And I should see "Super Mentor (Pending)" for "primary":"albers"
  Then I follow "Home"
  And I click on profile picture and click "Edit Profile"
  And I click on the section with header "Mentoring Profile"
  And I should see "I want to be a mentor"
  And I fill the answer "About Me" with "I want to be a mentee now"
  And I save section with header "Mentoring Profile"

  And I click on profile picture and click "View Profile"
  And I should see "I want to be a mentee now"
  Then I logout

  #Admin Rejects
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Membership Requests"

  Then I follow "Show more"
  And I should see "I want to be a mentee now"
  And I follow "user name"
  And I follow "Manage"
  And I follow "Membership Requests"

  And I "Reject" request from "user_role@example.com"
  When I reject the request from "user_role@example.com" for the reason "I reject your request for no reason"
  Then a mail should go to "user_role@example.com" having "I reject your request for no reason"
  And I logout

  #User requests to become mentee
  Given the current program is "primary":"albers"
  When I have logged in as "user_role@example.com"
  And I follow "Home"
  And I click on profile picture and click "Edit Profile"
  And I click on the section with header "Mentoring Profile"
  And I should see "I want to be a mentee now"
  And I fill the answer "About Me" with ""
  And I save section with header "Mentoring Profile"

  And I click on profile picture and click "View Profile"
  And I should not see "I want to be a mentor"
  Then I visit the all programs listing
  And I should not see "Super Mentor (Pending)"
  Then I follow enrollment page link for "primary":"albers"
  And I select "Super Mentor" from "roles"
  And I select "Mentee" from "roles"
  And I press "Proceed"
  And I fill the answer "About Me" with "I want to be a mentor now"
  And I press "Submit"
  Then I logout

  #Admin Rejects
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Membership Requests"

  Then I follow "Show more"
  And I should see "I want to be a mentor now"
  And I follow "user name"
  And I follow "Manage"
  And I follow "Membership Requests"

  And I "Reject" request from "user_role@example.com"
  When I reject the request from "user_role@example.com" for the reason "I reject your request for no reason"
  Then a mail should go to "user_role@example.com" having "I reject your request for no reason"
  And I logout

  #User cannot become student direclty
  When I make "student" role as "join_directly" in "primary":"albers"
  Given the current program is "primary":"albers"
  When I have logged in as "user_role@example.com"
  Then I visit the all programs listing
  Then I follow enrollment page link for "primary":"albers"

  #User requests to become mentor again
  And I select "Super Mentor" from "roles" within "form#enrollment_form_membership"
  And I press "Proceed" within "form#enrollment_form_membership"
  And I should see "I want to be a mentor now"
  And I press "Submit"
  Then I should see "Your request has been sent to the program administrators. You will receive an email once the request is accepted."
  And I logout

  # Admin accepting the requests
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Membership Requests"

  When I accept the request from "user_role@example.com" with message "ok"
  Then a mail should go to "user_role@example.com" having "ok"
  Then I should see "The request has been accepted. Click here to view the member's profile."
  And I logout

#User clicks mail and completes profile
  Given the current program is "primary":"albers"
  When I have logged in as "user_role@example.com"
  When I open new mail
  And I follow "Login" in the email
  And I click on profile picture and click "Edit Profile"
  Then I visit the all programs listing
  Then I should not see join options for "primary":"albers"
  And I logout

@enrollment_scenario
@javascript
Scenario: Mentor applying as a Mentor again
  Given the current program is "primary":"albers"
  When I want to join as "mentor" with "mentor_1@example.com"
  And a mail should go to "mentor_1@example.com" having "We noticed you already have login credentials."
  When I open new mail
  And I follow "Login to continue" in the email
  And I fill in "email" with "mentor_1@example.com"
  And I fill in "password" with "monkey"
  And I press "Login"
  Then I should see "You are already Mentor in Albers Mentor Program. To join as Student, complete and submit the form below."
  Then I logout

@enrollment_scenario
@javascript
Scenario: Mentee applying as a Mentee again and has a pending request for mentor
  Given the current program is "primary":"albers"
  When I want to join as "student" with "student_1@example.com"
  And a mail should go to "student_1@example.com" having "We noticed you already have login credentials."
  When I open new mail
  And I follow "Login to continue" in the email
  And I fill in "email" with "student_1@example.com"
  And I fill in "password" with "monkey"
  And I press "Login"
  Then I should see the flash "You are already Student in Albers Mentor Program. Your request to join Albers Mentor Program as Mentor is currently under review."
  Then I logout

@enrollment_scenario
@javascript @cross-browser
Scenario: User with both roles applying for both roles again
  #Allowing users to apply to join for more than one role
  Given the current program is "primary":"albers"
  Given the membership mode for "Student" is "Apply to join"
  Given the membership mode for "Mentor" is "Apply to join"
  When I have logged in as "ram@example.com"
  When I follow "Manage"
  And I follow "Program Settings"
  Then I follow "Membership"
  And I choose "program_show_multiple_role_option_true"
  And I press "Save"
  Then I logout

  Given the current program is "primary":"albers"
  And I want to join as "mentor__student" with "apply_both@example.com"
  Then I click on the signup link sent in email to "apply_both@example.com"
  Then I should see "To join as Mentor and Student, complete and submit the form below."
  Then I fill in "membership_request_first_name" with "Apply"
  Then I fill in "membership_request_last_name" with "Both"
  Then I fill in "membership_request_password" with "monkey"
  Then I fill in "membership_request_password_confirm" with "monkey"
  Then I valdiate and give my consent for terms and conditions by clicking "Submit"
  Then I press "Submit"
  Then I should see "Your request has been sent to the program administrators."

  #Admin accepting only as a student
  When I have logged in as "ram@example.com"
  Then I follow "Manage"
  Then I follow "Membership Requests"
  Then I should see "Apply Both"
  And I accept the request from "apply_both@example.com" with message "Welcome!"
  And I follow "Click here"
  Then I logout

  #User logging in
  When I open new mail
  And I follow "Login" in the email
  And I fill in "email" with "apply_both@example.com"
  And I fill in "password" with "monkey"
  And I press "Login"
  Then I should see "Complete the following profile fields to improve your score."
  Then I logout

  When I want to join as "mentor__student" with "apply_both@example.com"
  And a mail should go to "apply_both@example.com" having "We noticed you already have login credentials."
  When I open new mail
  And I follow "Login to continue" in the email
  And I fill in "email" with "apply_both@example.com"
  And I fill in "password" with "monkey"
  And I press "Login"
  Then I should see "You are already Mentor and Student in Albers Mentor Program."
  Then I logout

  @enrollment_scenario
  @javascript @cross-browser
  Scenario: Admin allows user to add role without approval
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Program Settings"
    And I should see "Membership"
    And I follow "Membership"
    And I should see "Role Settings"
    Then I should see "Allow users to add roles without administrator approval"
    Then I hover over "auto_approval_for_mentor_help_icon"
    Then I should see "Lets users with current role as mentor add student role without administrator approval"
    Then I hover over "auto_approval_for_student_help_icon"
    Then I should see "Lets users with current role as student add mentor role without administrator approval"
    Then I should see "Student Role"
    Then I should see "Mentor Role"
    Then I enable "become_student" permission for "mentor" role
    Then I enable "become_mentor" permission for "student" role
    Then I press "Save"
    Then I logout

    When I have logged in as "rahim@example.com"
    And I should see "Would you like to join the program as a mentor as well?"
    And I follow "Click here"
    Then I should see "Addition of role: confirm"
    Then I should see "Please confirm if you would like to join the program as a mentor as well?"
    Then I press "Confirm"
    And I should not see "Would you like to join the program as a mentor as well?"
    And I follow "View Profile"
    Then I should see "Student and Mentor"
    Then I logout

    When I have logged in as "robert@example.com"
    And I should see "Would you like to join the program as a student as well?"
    And I follow "View Profile"
    Then I should see "Mentor"
    And I follow "Actions"
    And I follow "Become a Student"
    Then I should see "Addition of role: confirm"
    Then I should see "Please confirm if you would like to join the program as a student as well?"
    Then I press "Confirm"
    And I should not see "Would you like to join the program as a student as well?"
    And I follow "View Profile"
    Then I should see "Mentor and Student"
    Then I logout

    When I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Program Settings"
    And I should see "Membership"
    And I follow "Membership"
    And I should see "Role Settings"
    Then I should see "Allow users to add roles without administrator approval"
    Then I disable "become_student" permission for "mentor" role
    Then I disable "become_mentor" permission for "student" role