@javascript @not_run_on_tddium
Feature: SSO Automation Scenarios using Linkedin, Google & SAML

Background:
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Login Management"

Scenario: Admin Enabling Linkedin & Google Authentication and Users linking their profiles using those external authentication.
  Given I update the linkedin credentials for "primary"
  When I follow the action "Enable" available for "LinkedIn" login
  Then I should see "Are you sure you want to enable 'LinkedIn' login?"
  When I confirm popup
  When I follow the action "Enable" available for "Google" login
  Then I should see "Are you sure you want to enable 'Google' login?"
  When I confirm popup
  And I logout
  Then I follow "Login"
  Then I should see "LinkedIn"
  Then I should see "Google"
  And I follow "LinkedIn"
  Given I enter the linkedin credentials
  Then I should see "You are not a member of this program"
  Then I logout
  Then I follow "Login"
  And I follow "Email"
  Given I sign in as "ram@example.com"
  And I click on profile picture and click "Account Settings"
  Then I follow "Link"
  Then I should see "Successfully authenticated."
  Then I follow "Link"
  Given I enter the Gmail Credentials
  Then I should see "Successfully authenticated."
  Then I logout
  And I clear the Gmail cookies
  And I clear the LinkedIn cookies

Scenario: New User Added directly by the Admin uses LinkedIn SSO to sign up.  
  Given I update the linkedin credentials for "primary"
  When I follow the action "Enable" available for "LinkedIn" login
  Then I should see "Are you sure you want to enable 'LinkedIn' login?"
  When I confirm popup
  Given the current program is "primary":"albers"
  When I follow "Mentors"
  And I follow "Add Mentors Directly" for the group "action_1"
  And I fill in "user_email" with "NewMentor@iit.com"
  And I click "#cjs_add_user_next"
  And I click on the section with header "Work and Education"
  And I click on the section with header "Mentoring Profile"
  And I fill in "user_member_first_name" with "New"
  And I fill in "user_member_last_name" with "Mentor"
  And I press "save_and_finish"
  And a mail should go to "NewMentor@iit.com" having "You have been invited by Freakin Admin \(Administrator\) to join Albers Mentor Program as a mentor."
  And I open new mail
  And I follow "Accept and sign up" in the email
  Then I should see "Welcome, New Mentor!"
  Then I follow "LinkedIn"
  Given I enter the linkedin credentials
  Then I should see "Sign up with LinkedIn"
  Then the disabled "member_email" field should contain "NewMentor@iit.com"
  Then the "member_first_name" field should contain "New"
  Then the "member_last_name" field should contain "Mentor"
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "Sign up"
  Then I should see "Welcome to Albers Mentor Program. Please complete your online profile to proceed"
  Then I should see "Basic Information"
  Then I logout
  And I clear the LinkedIn cookies

Scenario: New User Joining Directly using Google SSO
  When I follow the action "Enable" available for "Google" login
  Then I should see "Are you sure you want to enable 'Google' login?"
  When I confirm popup 
  Given the current program is "primary":"albers"
  Then I follow "Manage"
  And I follow "Program Settings"
  Then I follow "Membership"
  And I choose "join_directly_mentor"
  Then I choose "join_directly_student"
  And I press "Save"
  Then I logout
  And I follow "Join"
  Then I choose "roles_mentor"
  Then I follow "Google"
  Given I enter the Gmail Credentials
  Then I should see "Verified as"
  And I should see "Ramya Chronus"
  Then I check "signup_terms"
  And I press "Submit"
  Then I should see "Welcome"
  Then I logout
  And I clear the Gmail cookies

