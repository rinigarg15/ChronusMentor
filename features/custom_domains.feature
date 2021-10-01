# encoding: utf-8

Feature: Custom Domains
  In order to make use of my mentoring program and enjoy additional customization
  As a user
  I want to be able to access site over custom domains

# We are not running this file in TDDIUM as accessing other sites from TDDIUM is not possible

Background: Cross domain login
  Given the current program is "mentor.customtest.com":"main"

@not_run_on_tddium @javascript
Scenario: Admin invites mentors
  When I have logged in as "custom@admin.com"
  Then I should see the program title "Custom Domain Program"
  Then I follow "Mentors"
  And I click "#title_actions .dropdown-toggle"
  When I follow "Invite Mentors"
  Then I should see "Invitations"
  And I choose "role_assign_roles"
  And I check "Mentor"
  And I fill in "recipients" with "mentor1@custom.com"
  And I press "cjs_send_invites"
  Then I should see "Your invitations are being sent"
  And I logout 
  Then a mail should go to "mentor1@custom.com" having "I would like to invite you to join the Custom Domain Program as a mentor"

  # Mentor opens mail
  When I open new mail
  And I follow "Click here" in the email
  And I should see "Welcome! You have been invited to join Custom Domain Program as a Mentor."
  Then I fill in "member_first_name" with "mentor"
  Then I fill in "member_last_name" with "me"  
  And I fill in "member_password" with "monkey"
  And I fill in "member_password_confirmation" with "monkey"
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "Sign up"
  Then I should see "Welcome to Custom Domain Program. Please complete your online profile to proceed."
  And I press "Proceed »"  
  Then I should see "You have successfully completed your basic profile. Please follow up by completing your full profile."
  And I press "Proceed »"
  Then I should see "Mentoring Profile"  
  
@not_run_on_tddium
Scenario: Admin adds mentee directly
  When I have logged in as "custom@admin.com"
  And I follow "Students"
  And I follow "Add Students Profiles"
  And I should see "Please fill out the details of the Student. A program invitation email will be sent to the Student."
  And I fill in "user_member_first_name" with "New"
  And I fill in "user_member_last_name" with "Student"
  And I fill in "user_member_email" with "newstud@custom.com"
  And I fill the location and experience values with "chennai, temp_company"
  And I press "Save"
  And a mail should go to "newstud@custom.com" having "You have been added as a student"
  
  # Mentee opens mail
  When I open new mail
  And I follow "Click here" in the email
  And I should see "Welcome New Student. Please sign up to proceed."
  Then I fill in "member_first_name" with "student"
  Then I fill in "member_last_name" with "me"
  And I fill in "member_password" with "monkey"
  And I fill in "member_password_confirmation" with "monkey"
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "Sign up"
  Then I should see "Welcome to Custom Domain Program. Please complete your online profile to proceed."
  And I press "Proceed »"
  Then I should see "You have successfully completed your basic profile. Please follow up by completing your full profile."
  And I press "Proceed »"
  Then I should see "Mentoring Profile"
  And I press "Proceed »"
  And I should see "Edit Profile"