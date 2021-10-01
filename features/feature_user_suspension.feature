Feature: User/Member Suspension
In order to verify user access restrictions when suspended at track and global level
As a track-level admin
I can suspend user only at track level and cannot reactivate globally suspended user
As a global-level admin
I can suspend and reactivate user at all levels
As a track level suspended user
I can login, reapply for the same track based on membership settings
As a globally suspended member
I cannot login, apply for membership and access any resource of the organization

Background:
  Given "Program" "term" is called as "Community" in "primary"
  Given "Program" "term_downcase" is called as "community" in "primary"
  Given "Program" "pluralized_term_downcase" is called as "communities" in "primary"

@javascript @cross-browser
Scenario: Track level suspended user experience
  Given the feature "enrollment_page" is enabled for "primary"
  Given the current program is "primary":"albers"
  Given the user with email "rahim@example.com" is suspended only in program "albers"
  When I have logged in as "rahim@example.com"
  Then I should see "Your profile in Albers Mentor Program is currently not active. To join as Mentor and Student, complete and submit the form below."
  And I should not see "Join Now"
  And I should not see view and edit profile links
  And I should not see "Albers Mentor Program" in my programs listing
  When I follow "Browse Programs"
  Then I should see "Student (Deactivated)" for program "albers" in enrollment page
  And I should see "Join Community" for program "albers" in enrollment page
  And I logout

@javascript
Scenario: Track/Global level admininstrator cannot activate globally suspended at track level
  Given the current program is "primary":"albers"
  Given the user with email "robert@example.com" is suspended globally
  When I have logged in as "ram@example.com"
  When I follow "Mentors"
  And I follow "Good unique name"
  Then I should see "Good unique name's membership has been suspended and their access has been revoked from all the communities they were part of. Please click here to reactivate the user's profile in Primary Organization."
  And I should not see "Change Roles"
  When I hover over reactivate membership
  Then I should see "Good unique name's profile was deactivated for all communities. The profile can only be reactivated at Primary Organization."

  When I follow "Manage"
  And I follow "User Views"
  Then I should see "Mentor" in the row of "user" "robert@example.com"
  And I should see "Deactivated" in the row of "user" "robert@example.com"
  When I reactivate "robert@example.com" from admin users page
  And I should see "Deactivated" in the row of "user" "robert@example.com"
  When I add "Student" role to "robert@example.com" from admin users page
  And I should not see "Student" in the row of "user" "robert@example.com"
  And I should see "Deactivated" in the row of "user" "robert@example.com"
  Then I logout

@javascript @cross-browser
Scenario: Restricting actions on globally suspended users
  Given the current program is "primary":""
  Given the user with email "robert@example.com" is suspended globally
  Then I reindex model "User"
  Then I reindex model "Member"
  When I have logged in as "ram@example.com"

  # Bulk actions - All Members
  When I follow "Manage"
  And I follow "Member Views"
  Then I should see "Deactivated" in the row of "member" "robert@example.com"
  And I should not see "No Mentor Request Program" in the row of "member" "robert@example.com"
  When I add "robert@example.com" to the program "No Mentor Request Program" as "Mentor"
  And I should not see "No Mentor Request Program" in the row of "member" "robert@example.com"

  # Individual actions
  And I follow "Good unique"
  Then I should see "Good unique name's membership has been suspended and their access has been revoked from all the communities they were part of."
  And I should not see "Add User To Program" in admin actions pane
  And I should not see "Invite User To Program" in admin actions pane
  And I should not see "Add User as Administrator" in admin actions pane
  And I should not see "Suspend Membership" in admin actions pane
  And I should see "Reactivate Membership" in admin actions pane
  And I should see "Remove Good unique name" in admin actions pane
  And I logout

  # Add user from other program
  Given the current program is "primary":"nomreqpro"
  And I give permission to admins in program "primary":"nomreqpro"
  Given "no_mreq_admin@example.com" is promoted as global admin
  When I have logged in as "no_mreq_admin@example.com"
  When I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from Primary Organization"
  And I should see the rows are sorted by "First name"
  Then I should not see "Good unique"
  And I should see "mentor_a"
  Then I logout

@javascript @cross-browser
Scenario: Membership requests and globally suspended users
  Given the current program is "primary":"albers"
  When I want to join as "Mentor" with "example@chronus.com"
  And I click on the signup link sent in email to "example@chronus.com"
  And I fill the basic information and submit the membership application form
  Then I should see "Your request has been sent to the community administrators. You will receive an email once the request is accepted"

  # Global suspension - leads to deletion of membership requests
  Given I have logged in as "ram@example.com"
  When I follow "Manage"
  And I follow "Membership Requests"
  Then I should see "Abc def"
  When I follow "Abc def"
  And I follow "Suspend Membership"
  Then I should see "Please note that the member will not be able to participate in any more activities and their membership requests will also be ignored."
  When I suspend with the reason "Some reason"
  Then I should see "Abc def's membership has been suspended and their access has been revoked from all the communities they were part of."
  Given the current program is "primary":"albers"
  When I follow "Manage"
  And I follow "Membership Requests"
  Then I should not see "Abc def"
  Then I logout

  Given the current program is "primary":"albers"
  When I want to join as "Student" with "example@chronus.com"
  Then a mail should go to "example@chronus.com" having "Unfortunately, the administrator has suspended your membership in Primary Organization"

@javascript @cross-browser
Scenario: Track level suspended user trying to enroll from nonlogged in page
  Given the feature "enrollment_page" is enabled for "primary"
  Given the current program is "primary":"albers"
  Given the user with email "rahim@example.com" is suspended only in program "albers"
  When I want to join as "Mentor" with "rahim@example.com"
  And I click on the login link sent in email meant for existing users to "rahim@example.com"
  And I sign in as "rahim@example.com"
  Then I should see "Your request has been sent to the community administrators. You will receive an email once the request is accepted."
  Then I logout

@javascript @cross-browser
Scenario: Suspension and reactivation at global level should maintain states at user level
  Given the current program is "primary":"albers"
  And the current program admin has added required questions for "mentor"
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

  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  Then I visit the global profile of "pending_new@example.com"
  Then I follow "Add User To Community"
  And I select "NWEN" from "admin_view_program_id"
  Then I check "Mentor"
  Then I press "Submit"
  Then I should see "The selected user have been added to the community as Mentor successfully"
  Then I navigate to "pending_new@example.com" profile in "nwen"
  Then I should see "Deactivate Membership"
  Then I follow "Deactivate Membership"
  Then I should see "Reason *"
  Then I fill in "state_change_reason" with "Some Reason"
  Then I press "Deactivate"
  Then I should see "deactivated"

  Then I visit the global profile of "pending_new@example.com"
  Then I follow "Suspend Membership"
  Then I should see "Reason *"
  Then I fill in "state_change_reason" with "Some Reason"
  Then I press "Suspend"
  Then I should see "membership has been suspended and their access has been revoked from all the communities they were part of."
  Then I should see "Deactivated" within "#profile_side_bar"
  
  Then I follow "Reactivate Membership"
  Then I confirm popup
  Then I should see "membership has been reactivated"

  #States Maintained
  Then I navigate to "pending_new@example.com" profile in "albers"
  Then I should see "The member has not yet published their profile"
  Then I navigate to "pending_new@example.com" profile in "nwen"
  Then I should see "Greg Martin's membership has been deactivated from this community."

  Then I logout

@javascript @cross-browser
Scenario: Suspension and reactivation of a dormant user
  Given the current program is "primary":""
  And there is a dormant member with email "dormantinvite@example.com"
  And I have logged in as "ram@example.com"
  Then I visit the global profile of "dormantinvite@example.com"
  Then I follow "Suspend Membership"
  Then I should see "Suspend membership"
  Then I fill in "state_change_reason" with "Some Reason" within "#suspend_member_form"
  Then I press "Suspend"
  Then I should see "membership has been suspended and their access has been revoked from all the communities they were part of."
  Then I logout

  And I have logged in as "dormantinvite@example.com" without asserting signout
  Then I should see "You do not have access to this community. Please contact the administrator for more information."

  And I have logged in as "ram@example.com"
  Then I visit the global profile of "dormantinvite@example.com"
  Then I follow "Reactivate Membership"
  Then I confirm popup
  Then I should see "membership has been reactivated"
  Then I logout

  And I have logged in as "dormantinvite@example.com"
  And I press "Accept"
  Then I should not see "My Programs"
  Then I logout

@javascript
Scenario: User suspended at all tracks should still be able to login at global level
  Given the current program is "primary":""
  Given the user with email "rahim@example.com" is suspended only in program "albers"
  Given the user with email "rahim@example.com" is suspended only in program "nwen"
  Given the user with email "rahim@example.com" is suspended only in program "pbe"
  When I have logged in as "rahim@example.com"
  Then I should not see "My Programs" within "#header_actions"
  Then I logout

@javascript @cross-browser
Scenario: Deactivated Mentor applying for both roles
  Given the current program is "primary":"albers"
  Given the membership mode for "Student" is "Join Directly"
  Given the membership mode for "Mentor" is "Join Directly"
  When I have logged in as "ram@example.com"
  When I follow "Manage"
  And I follow "Community Settings"
  Then I follow "Membership"
  And I choose "program_show_multiple_role_option_true"
  And I press "Save"
  Then I navigate to "rahim@example.com" profile in "albers"
  Then I should see "Deactivate Membership"
  Then I follow "Deactivate Membership"
  Then I should see "Reason *"
  Then I fill in "state_change_reason" with "Some Reason"
  Then I press "Deactivate"
  Then I should see "deactivated"
  Then I logout

  Given the current program is "primary":"albers"
  And I want to join as "mentor__student" with "rahim@example.com"
  Then I click on the login link sent in email meant for existing users to "rahim@example.com"
  And I sign in as "rahim@example.com"
  Then I should see "Your request has been sent to the community administrators. You will receive an email once the request is accepted."
  Then I logout

  When I have logged in as "ram@example.com"
  When I follow "Manage"
  Then I should see "Membership Requests"
  And I follow "Membership Requests"
  Then I should see state "Deactivated" for request from "rahim@example.com"
  And I accept the request from the deactivated user "rahim@example.com" with message "Welcome!"
  And element with id "#student_role" should be readonly
  Then I press "Accept"
  Then I navigate to "rahim@example.com" profile in "albers"
  Then I should see "Student" within ".ct_name_title"
  Then I logout

@javascript @cross-browser
Scenario: Deactivated User applying for a track with Eligibility Rules to join
  #Eligibility Rules
  Given the current program is "primary":"albers" 
  When I have logged in as "ram@example.com"
  And I login as super user
  Then I follow "Manage"
  Then I follow "Community Settings"
  Then I follow "Features"
  Then I should see "Membership Eligibility Rules"
  And I check "membership_eligibility_rules"
  And I press "Save"
  Then I make all profile questions into membership questions in "primary":"albers"
  And I follow "Albers Mentor Program"
  Then I follow "Manage"
  Then I follow "Community Settings"
  Then I follow "Membership"
  Then I choose "join_eligibility_rules_mentor"
  Then I set eligibilty rules for "mentor" in "Albers Mentor Program"
  Then I choose "join_eligibility_rules_student"
  Then I set eligibilty rules for "student" in "Albers Mentor Program"
  
  Then I follow "Edit eligibility rules"
  Then I select "Not Filled" from "admin_view_profile_questions_questions_2_operator"
  Then I press "Save" within ".cjs_adminview_form"
  And I choose "program_show_multiple_role_option_true"
  And I press "Save"

  #Deactivating User
  Then I navigate to "rahim@example.com" profile in "albers"

  Then I should see "Deactivate Membership"
  Then I follow "Deactivate Membership"
  Then I should see "Reason *"
  Then I fill in "state_change_reason" with "Some Reason"
  Then I press "Deactivate"
  Then I should see "deactivated"
  Then I logout

  Given the current program is "primary":"albers"
  And I want to join as "mentor__student" with "rahim@example.com"
  Then I click on the login link sent in email meant for existing users to "rahim@example.com"
  And I sign in as "rahim@example.com"
  Then I press "Submit"
  Then I should see the flash "Not eligible to join"
  Then I fill in "profile_answers_4" with "9123456789"
  And I check "English" within "#profile_answers_16"
  Then I press "Submit"
  Then I should see "Your request has been sent to the community administrators. You will receive an email once the request is accepted."