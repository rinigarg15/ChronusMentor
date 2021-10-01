@reindex
Feature: Program invitation campaign, admin sends invitation

Background: Admin logs in
  Given the current program is "primary":"albers"
  #Given I reindex model "user"
  And I have logged in as "ram@example.com"

@javascript @enrollment_scenario @cross-browser
Scenario: Admin invites user from send invites tab and see analytics in track invitation status
  And I follow "Manage"
  And I follow "Invitations"
  And I follow "Send Invites"
  And I should see "Invitations"

  And I should see "Invitation Emails"
  And I should see "Invitation to join {{subprogram_or_program_name}} {{as_role_name_articleized}}"
  And I should see "Sent Immediately"
  And I should see "You have a pending invitation to join {{subprogram_or_program_name}}"
  And I should see "Sent after 15 days"
  And I should see "Your invitation expires tomorrow!"
  And I should see "Sent after 29 days"

  And I follow "Track Invitation Status"
  And I should see "Invitations Sent"
  And I should see "1"
  And I should see "Pending"
  And I should see "1"
  And I should see "Accepted"
  And I should see "Expired"
  And I should see "Overall Email Stats"
  And I should see "4"
  And I should see "25.0%"
  And I should see "Email Stats"
  And I should see "1 - 1 of 1 items"

  #send invitation to balaji.majji@chronus.com
  And I follow "Send Invites"
  And I click "#role_assign_roles"
  And I click "input[name='assign_roles[]'][value='mentor']"
  Then I fill in "Recipient emails" with "balaji.majji@chronus.com"
  And I click "#cjs_send_invites"

  Then I should see "Invitations"
  And I should see "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly."
  And I should see "Overall Email Stats"
  And I should see "5"
  And I should see "20.0%"
  And I should see "Email Stats"
  And I should see "1 - 2 of 2 items"
  And I should see "balaji.majji@chronus.com"

@javascript @enrollment_scenario
Scenario: Admin invites already existing user from send invites tab and user gets correct mail
  And I follow "Manage"
  And I follow "Invitations"
  And I follow "Send Invites"
  And I should see "Invitations"
  And I should see "Invitation Emails"

  #send invitation email to ram@example.com with mentor role assigned
  And I follow "Send Invites"
  And I click "#role_assign_roles"
  And I click "input[name='assign_roles[]'][value='mentor']"
  Then I fill in "Recipient emails" with "ram@example.com"
  And I click "#cjs_send_invites"
  And I logout
  Then mail should go to "ram@example.com" having "I would like to invite you to join the Albers Mentor Program as a mentor"
  Then I open mail of "ram@example.com"
  And I follow "Click here" in the email
  Then I should see "Please login to join the program."
  And I sign in as "ram@example.com"
  And I logout
  

@javascript @cross-browser
Scenario: Admin create, edit and delete the invitation email
  And I follow "Manage"
  And I follow "Invitations"
  And I follow "Send Invites"
  And I should see "Invitations"

  And I should see "Add email"
  And I follow "Add email"
  Then I should see "href" attribute for link "Back" matches with "/p/albers/invite_users" within "#page_heading"
  And I should see "New Invitation Email"
  Then I fill in "Subject" with "This is a remainder mail"
  And I fill in CKEditor "campaign_management_abstract_campaign_message_mailer_template_source" with "Test Message"
  And I should see "days after user was invited"
  When I fill in a number field "#campaign_message_duration" with "12"
  Then I click "#cjs_preview_email_link"
  Then I should see "A test email has been sent to ram@example.com"
  And a mail should go to "ram@example.com" having "Test Message"

  Then I press "Save"
  And I should see "Invitation Emails"
  Then I should see "The email has been successfully created."
  And I should see "This is a remainder mail"
  And I should see "Sent after 12 days"

  # edit invitation
  When I follow "This is a remainder mail"
  Then I should see "Edit Invitation Email"
  Then I should see "href" attribute for link "Back" matches with "/p/albers/invite_users" within "#page_heading"
  Then I fill in "Subject" with "This is edited mail"
  When I fill in a number field "#campaign_message_duration" with "10"
  And I should see "days after user was invited"

  Then I press "Save"
  And I should see "Invitation Emails"
  Then I should see "The email has been successfully updated."
  And I should see "This is edited mail"
  And I should see "Sent after 10 days"

  # deleting a Invitation email
  And I click "#delete-campaign-message-link-4"
  Then I should see "Confirmation"
  And I should see "Deleting the email will also delete all the statistics related to this email"
  And I confirm popup
     
  Then I should not see "complete your profile today!"

@javascript
Scenario: Admin's landing page on-click Invitations in manage
  And I follow "Manage"

  #if invitations present then Track invitations status tab
  And I follow "Invitations"
  And I should see "Overall Email Stats"
  And I should see "4"
  And I should see "25.0%"
  And I should see "Email Stats"

  #if no invitations, landing page is send invites page
  When I logout
  Given the current program is "primary":"pbe"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Invitations"
  And I should see "Invitation Emails"
  And I should see "Invitation to join {{subprogram_or_program_name}} {{as_role_name_articleized}}"
  And I should see "Sent Immediately"
  And I should see "You have a pending invitation to join {{subprogram_or_program_name}}"
  And I should see "Sent after 15 days"
  And I should see "Your invitation expires tomorrow!"
  And I should see "Sent after 29 days"

@javascript @enrollment_scenario @cross-browser
Scenario: End user sending invitation
  And I follow "Mentors"
  And I follow "mentor_b chronus"
  And I follow "Work on Behalf"

  And I follow "Mentors"
  And I should see "Invite Mentors"
  And I follow "Invite Mentors"

  And I should see "Enter Email Addresses"
  And I check "Mentor"
  Then I fill in "Recipient emails" with "balaji.majji@chronus.com"
  And I click "#cjs_send_invites"
  And I should see "Invitations will be sent."

@javascript @enrollment_scenario @cross-browser
Scenario: End user sends invitation and allows the user to select roles
  And I set the password message for "primary"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Membership"
  And I specify the joining option as "Allow Mentors to invite" for "Student"
  And I choose "program_show_multiple_role_option_true"
  And I press "Save"
  And I follow "Mentors"
  And I follow "mentor_b chronus"
  And I follow "Work on Behalf"

  And I follow "Students"
  And I should see "Invite Students"
  And I follow "Invite Students"
  And I should see "Enter Email Addresses"
  And I choose "role_allow_roles"
  And I check "Mentor"
  And I check "Student"
  Then I fill in "Recipient emails" with "albus@test.com"
  And I click "#cjs_send_invites"
  And I should see "Invitations will be sent."
  And I logout
  And I open new mail
  And I follow "Accept and Sign-up" in the email
  Then I should see "You have been invited to join Albers Mentor Program."
  And I should see "Should contain only numeric characters"
  And I should see "Must satisfy the above condition"
  And I fill in "member_first_name" with "Albus"
  And I fill in "member_last_name" with "Dumbledore"
  And element with id "#member_email" should be disabled
  And I fill in "member_password" with "monkey"
  And I fill in "member_password_confirmation" with "monkey"
  And I check "Mentor"
  And I check "Student"
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "Sign up"
  Then I should see "Welcome to Albers Mentor Program. Please complete your online profile to proceed"
  Then I should see "Basic Information"
  And I fill in "Phone" with "001-125845-78"
  And I fill in "Skype ID" with "Another.mentor"
  And I fill in "Location" with "Chennai, Tamil Nadu, India"
  And I press "submit_general"
  And I should see "Work and Education"
  And I should see "Click here to import your experience"
  And I press "Proceed"
  Then I should see "Mentoring Profile"
  And I press "Proceed"
  Then I should see "More Information"
  And I press "Proceed"
  Then I should see "More Information Students"
  And I press "Proceed"
  Then I should see "Mentoring Preferences"
  And I press "Proceed"
  Then I should see "Messages"
  Then I should see "All Activity"

@javascript @enrollment_scenario
Scenario: Password confirmation instructions from invitation signup
  And I set the password message for "primary"
  And I set the number password regex for "primary"
  And I create SAML Auth for "primary"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Membership"
  And I specify the joining option as "Allow Mentors to invite" for "Student"
  And I choose "program_show_multiple_role_option_true"
  And I press "Save"
  And I follow "Mentors"
  And I follow "mentor_b chronus"
  And I follow "Work on Behalf"

  And I follow "Students"
  And I should see "Invite Students"
  And I follow "Invite Students"
  And I should see "Enter Email Addresses"
  And I choose "role_allow_roles"
  And I check "Mentor"
  And I check "Student"
  Then I fill in "Recipient emails" with "albus@test.com"
  And I click "#cjs_send_invites"
  And I should see "Invitations will be sent."
  And I logout
  And I open new mail
  And I follow "Accept and Sign-up" in the email
  When I follow "Email"
  And I should see "Should contain only numeric characters"
  And I should see "Must satisfy the above condition"
  And I fill in "member_first_name" with "Albus"
  And I fill in "member_last_name" with "Dumbledore"
  And I fill in "member_password" with "monkey"
  And I fill in "member_password_confirmation" with "monkey"
  And I check "Mentor"
  And I check "Student"
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "Sign up"
  Then I should see "Should contain only numeric characters"
  And I should see "Must satisfy the above condition"

@javascript @enrollment_scenario @cross-browser
Scenario: Allow users to select role from invitations page and the user joins, completes his profile

  And I follow "Manage"
  And I follow "Invitations"
  And I follow "Send Invites"
  And I should see "Invitations"
  And I should see "Invitation Emails"
  And I should see "Invitation to join {{subprogram_or_program_name}} {{as_role_name_articleized}}"
  And I should see "Sent Immediately"
  And I should see "You have a pending invitation to join {{subprogram_or_program_name}}"
  And I should see "Sent after 15 days"
  And I should see "Your invitation expires tomorrow!"
  And I should see "Sent after 29 days"

  And I choose "role_allow_roles"
  And I check "Mentor"
  And I check "Student"
  Then I fill in "Recipient emails" with "albus@test.com"
  And I click "#cjs_send_invites"
  Then I should see "Invitations"
  And I should see "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly."
  And I should see "albus@test.com"
  And I logout
  And I open new mail
  And I follow "Click here" in the email
  Then I should see "You have been invited to join Albers Mentor Program."
  And I fill in "member_first_name" with "Albus"
  And I fill in "member_last_name" with "Dumbledore"
  And element with id "#member_email" should be disabled
  And I fill in "member_password" with "monkey"
  And I fill in "member_password_confirmation" with "monkey"
  And I check "Mentor"
  And I check "Student"
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "Sign up"
  Then I should see "Welcome to Albers Mentor Program. Please complete your online profile to proceed"
  Then I should see "Basic Information"
  And I fill in "Phone" with "001-125845-78"
  And I fill in "Skype ID" with "Another.mentor"
  And I fill in "Location" with "Chennai, Tamil Nadu, India"
  And I press "submit_general"
  And I should see "Work and Education"
  And I should see "Click here to import your experience"
  And I press "Proceed"
  Then I should see "Mentoring Profile"
  And I press "Proceed"
  Then I should see "More Information"
  And I press "Proceed"
  Then I should see "More Information Students"
  And I press "Proceed"
  Then I should see "Mentoring Preferences"
  And I press "Proceed"
  Then I should see "Messages"
  Then I should see "All Activity"