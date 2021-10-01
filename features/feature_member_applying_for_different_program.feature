Feature: Member applying for a different program

Background: Enable Enrollment Feature
  Given the feature "enrollment_page" is enabled for "primary"

@regression
@enrollment_scenario
@javascript @cross_browser
Scenario: User requests to join in different program
  Given membership request instruction form of "primary":"albers" is "blah blah blah"
  Given the current program is "primary":""
  When I make "student" role as "invite only" in "primary":"nomreqpro"
  When I make "mentor" role as "invite only" in "primary":"nomreqpro"
  When I call "student" role as "Mentee" in "primary":"albers"
  When I call "mentor" role as "Super Mentor" in "primary":"albers"
  Then I make all profile questions into membership questions in "primary":"albers"
  Then I make the question "About Me" mandatory in "primary":"albers"
  When I have logged in as "moderated_student@example.com"
  Then I should see "Update Your Profile"
  Then I should see "New mandatory fields have been added to the Mentoring Profile section of the profile. Please fill them out to complete your profile."
  And I should see "About Me"
  And I fill the answer "About Me" with "I want to be a mentor in your program"
  Then I press "Save & Proceed"
  Then I wait for "3" seconds
  And I click ".my_programs_listing_link"
  And I should see "Browse Programs"
  Then I follow "Browse Programs"
  Then I should see "All Programs"
  Then I should not see "No Mentor Request Program"
  And I follow "primary":"albers"
  Then I switch to latest window
  And I maximize the window
  Then I should see "Sign out"
  And I should see "Contact Administrator"
  And I should see "Messages"
  And I should not see "Sign In"
  And I should see "Join"
  And I should not see header image
  Then I visit the all programs listing
  And I should see header image
  Then I follow enrollment page link for "primary":"albers"
  And I select "Super Mentor" from "roles"
  And I press "Proceed"
  Then I should see "To join as Super Mentor, complete and submit the form below."
  And I press "Submit"
  Then I should see "Your request has been sent to the program administrators. You will receive an email once the request is accepted."
  And I follow "Primary Organization"
  And I follow "Home"
  And I click on profile picture and click "Edit Profile"
  And I open tab "collapsible_section_content_3"
  And I should see "I want to be a mentor in your program"
  And I fill the answer "About Me" with "I want to be a mentee in your program"
  And I press "Save" within "#collapsible_section_content_3"

  Then I visit the all programs listing
  Then I should see "Super Mentor (Pending)"
  Then I close the new window and switch to main window
  Then I logout

 #Admin rejects
  Given the current program is "primary":"albers"
  And I have logged in as "userram@example.com"
  Then I should see "Update Your Profile"
  Then I should see "New mandatory fields have been added to the Mentoring Profile section of the profile. Please fill them out to complete your profile."
  And I should see "About Me"
  And I fill the answer "About Me" with "I want to be a mentor in your program"
  Then I press "Save & Proceed"
  And I follow "Manage"
  And I follow "Membership Requests"

  And I should see "Moderated Student (moderated_student@example.com)"
  Then I follow "Show more"
  And I should see "I want to be a mentee in your program"
  Then I logout
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Membership Requests"

  And I follow "Moderated Student"
  Then I should see "Primary Organization"
  And I follow "Manage"
  Then I follow "Albers Mentor Program"
  And I follow "Membership Requests"

  And I "Reject" request from "moderated_student@example.com"
  When I reject the request from "moderated_student@example.com" for the reason "I reject your request for no reason"
  Then a mail should go to "moderated_student@example.com" having "I reject your request for no reason"
  And I logout

  #User joins directly in different program
  When I make "student" role as "join_directly" in "primary":"albers"
  Given the current program is "primary":"modprog"
  When I have logged in as "moderated_student@example.com"
  Then I visit the all programs listing
  Then I follow enrollment page link for "primary":"albers"
  And I select "Mentee" from "roles" within "form#enrollment_form_join"
  Then I should not see "Please fill and submit the form below to join Albers Mentor Program as Mentee."
  And I press "Proceed" within "form#enrollment_form_join"
  Then I should see "You are now a student in Albers Mentor Program"
  Then I should see "Basic Information"
  Then I logout

  #User joins directly with different role same program
  When I make "mentor" role as "join_directly" in "primary":"albers"
  Given the current program is "primary":"albers"
  And I have logged in as "rahim@example.com"
  And I fill the answer "About Me" with "Sample"
  Then I press "Save & Proceed"
  Then I wait for "3" seconds

  Then I visit the all programs listing
  Then I follow enrollment page link for "primary":"albers"
  And I select "Super Mentor" from "roles" within "form#enrollment_form_join"
  And I press "Proceed" within "form#enrollment_form_join"
  Then I should see "You are now a mentor in Albers Mentor Program"
  And I should see "Welcome student example "
  Then I logout

@not_run_on_tddium
@enrollment_scenario
@javascript
Scenario: User requests to join in different program with text only field
  # Basic profile
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And I login as super user
  Then I follow "My Programs"
  And I follow "Primary Organization"
  And I follow "Manage"
  Then I should see "Preview"
  And I should see "Customize"
  And I follow "Customize"

  And I open section with header "Basic Information"

  When I follow "Add new field"

  And I fill in "profile_question_text_0" with "New Text Field"
  And I select "Text Entry" from "profile_question_question_type_0"
  And I check "profile_question_text_only_option"
  And I check "Student"
  Then I click edit advanced options
  And I check "Membership Form"

  And I press "Save" within "#new_profile_question"
  And I logout

  Given membership request instruction form of "primary":"albers" is "blah blah blah"
  Given the current program is "primary":""
  When I call "student" role as "Mentee" in "primary":"albers"
  When I call "mentor" role as "Super Mentor" in "primary":"albers"
  Then I make all profile questions into membership questions in "primary":"albers"
  Then I make the question "About Me" mandatory in "primary":"albers"
  When I have logged in as "ram@example.com"
  Then I visit the all programs listing
  Then I follow enrollment page link for "primary":"albers"
  And I select "Mentee" from "roles"
  And I press "Proceed"
  And I fill the answer "About Me" with "I want to be a mentee in your program"
  And I fill the answer "New Text Field" with "test988"
  And I press "Submit"
  Then I should see "cannot contain digits"

  And I fill the answer "New Text Field" with "test text type"
  And I fill the answer "About Me" with "I want to be a mentor in your program"
  And I press "Submit"
  Then I should see "Your request has been sent to the program administrators. You will receive an email once the request is accepted."

@enrollment_scenario
@javascript
Scenario: Member part of a single program accesses the enrollment page
  Given the current program is "primary":"albers"
  And I have logged in as "userram@example.com"
  Then I visit the all programs listing
  Then I follow enrollment page link for "primary":"albers"
  Then I should see ".cui_edit_first_last_name controls" hidden

@enrollment_scenario
@javascript @cross_browser
Scenario: User applies for both mentor and mentee roles
  #Enable allow user to apply for both roles
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  When I follow "Manage"
  And I follow "Program Settings"
  Then I follow "Membership"
  Then I choose "program_show_multiple_role_option_true"
  And I press "Save"
  Then I logout

  #User sends a request
  Given the current program is "primary":""
  When I have logged in as "moderated_student@example.com"
  Then I visit the all programs listing
  Then I follow enrollment page link for "primary":"albers"
  And I check "Mentor"
  And I check "Student"
  And I press "Proceed"
  Then I should see "Your request has been sent to the program administrators. You will receive an email once the request is accepted."
  Then I logout

  #Admin accepts request - by default - accept as both mentor and mentee selected in dropdown
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Membership Requests"
  When I click on accept for the request from "moderated_student@example.com"

  And I press "Accept"
  Then I should see "The request has been accepted. Click here to view the member's profile."
  Then I logout

  And a mail should go to "moderated_student@example.com" having "Freakin Admin has accepted your request to join Albers Mentor Program"
  And I open new mail
  And I follow "Login" in the email
  And I sign in as "moderated_student@example.com"
  Then I visit the all programs listing
  Then I should see "Mentor" for "primary":"albers"
  Then I should see "Student" for "primary":"albers"
  Then I logout