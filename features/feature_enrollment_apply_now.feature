Feature: User applying for membership

@enrollment_scenario
@javascript
Scenario: Super admin sets instructions for mentors and students
  When membership request instruction form of "primary":"albers" is "blah blah blah"
  Given the current program is "primary":"albers"
  When I want to join as "Student" with "cristiano.ronaldo@madrid.financial"
  Then I click on the signup link sent in email to "cristiano.ronaldo@madrid.financial"
  Then I should see "blah blah blah"
  And I should not see "Please complete the registration form provided below"
  And I should not see "You can edit your profile anytime after signing up"
  Then I should not see "Join" within "#header_actions"
  Then I should see "Login"

@not_run_on_tddium
@enrollment_scenario
@javascript
Scenario: User applying as a mentor
  Given I update the linkedin credentials for "primary"
  Then I make "Education" question available in the membership form for "mentor" in "primary":"albers"
  Given the current program is "primary":"albers"
  Given the membership mode for "Mentor" is "Apply to join"
  And I follow "Join"
  Then I should not see "Mentor and Student" within ".radio"
  Given the current program is "primary":"albers"
  And I want to join as "mentor" with "apply_mentor@example.com"
  Then I click on the signup link sent in email to "apply_mentor@example.com"
  And I hover over the lock icon of the question with text "Email" in "primary"
  Then I should not see "This field will be visible to you, users with whom you are connected, and administrators."
  Then I should see "To join as Mentor, complete and submit the form below."
  Then I fill in "membership_request_first_name" with "Apply"
  Then I fill in "membership_request_last_name" with "Mentor"
  Then I fill in "membership_request_password" with "monkey"
  Then I fill in "membership_request_password_confirm" with "monkey"
  Then I should see "Click here to import your experience"
  Then I click on the image "Linkedin"
  Then I switch to the linkedin window and enter the credentials
  Then I should see "The experiences have been imported"
  Then I valdiate and give my consent for terms and conditions by clicking "Submit"
  Then I press "Submit"
  Then I should see "Your request has been sent to the program administrators."

  #Admin accepting the request
  When I have logged in as "ram@example.com"
  Then I follow "Manage"
  Then I follow "Membership Requests"
  Then I should see "Apply Mentor"
  And I accept the request from "apply_mentor@example.com" with message "Welcome!"
  Then I logout

  #User logging in
  When I open new mail
  And I follow "Login" in the email
  And I fill in "email" with "apply_mentor@example.com"
  And I fill in "password" with "monkey"
  And I press "Login"
  Then I should see "Complete the following profile fields to improve your score."
  Then I logout

@enrollment_scenario
@javascript
Scenario: User applying as a mentee
  Given the current program is "primary":"albers"
  Given the membership mode for "Student" is "Apply to join"
  Then I update the email question help text to "Enter a valid email address" in "primary"
  When I want to join as "Student" with "apply_mentee@example.com"
  Then I click on the signup link sent in email to "apply_mentee@example.com"
  Then I should see "Enter a valid email address"
  And I hover over the lock icon of the question with text "Email" in "primary"
  Then I should not see "This field will be visible to you, users with whom you are connected, and administrators."
  And I fill the basic information and submit the membership application form
  Then I should see "Your request has been sent to the program administrators. You will receive an email once the request is accepted"

  #Admin accepting the request
  When I have logged in as "ram@example.com"
  Then I follow "Manage"
  Then I follow "Membership Requests"
  Then I should see "Abc def"
  And I accept the request from "apply_mentee@example.com" with message "Welcome!"
  Then I logout

  #User logging in
  When I open new mail
  And I follow "Login" in the email
  And I fill in "email" with "apply_mentee@example.com"
  And I fill in "password" with "monkey"
  And I press "Login"
  Then I should see "Complete the following profile fields to improve your score."
  Then I logout

@enrollment_scenario
@javascript @cross_browser
Scenario: User applying as a mentor and mentee. Admin accepting only mentee role
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
  And I accept the request from "apply_both@example.com" with message "Welcome!" as a "student"
  And I follow "Click here"
  Then I should not see "Mentor" within ".ct_name_title"
  Then I logout

  #User logging in
  When I open new mail
  And I follow "Login" in the email
  And I fill in "email" with "apply_both@example.com"
  And I fill in "password" with "monkey"
  And I press "Login"
  Then I should see "Complete the following profile fields to improve your score."
  Then I logout

@enrollment_scenario
@javascript @cross_browser
Scenario: Admin ignores a membership request
  Given the current program is "primary":"albers"
  Given a pending membership request with email "rahim@example.com" and role as "Mentor"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Membership Requests"

  And I "Ignore" request from "rahim@example.com"
  When I ignore the request from "rahim@example.com"
  Then I should see "The request was deleted."

@enrollment_scenario
@javascript @cross_browser
Scenario: Admin creating conditional fields for membership request and user viewing the conditional behaviour
  Given the current program is "primary":"main"
  Then I perform missed migrations
  And I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  Then I should see "Preview"
  And I should see "Customize"
  And I follow "Customize"
  And I click on add new section
  And I fill in "new_section_title_add_new_section_form" with "New Conditional Section"
  And I fill in "section_description_add_new_section_form" with "New Section description"
  And I press "Save" within "form#add_new_section_form"

  And I click on the last section
  # New Question with condition for 'show only if' depending on a question in different section
  And I click on add new question
  And I fill in "profile_question_text_0" with "New Membership Field"
  And I select "Pick one answer" from "profile_question_question_type_0"
  And I should not see "allow_multiple"
  And I add choices "India,Pakistan,Brothers"
  When I scroll the div ".cjs-side-panel-slim-scroll"
  And I press "Save" within "form#edit_profile_question_"
  Then I wait for ajax to complete
  And I configured question for "mentor" role in the program "primary" and set default visibility
  And I click ".cjs_profile_question_edit_role_settings"
  And I check "Membership Form"
  When I scroll the div ".cjs-side-panel-slim-scroll"
  And I press "Save"
  Then I wait for ajax to complete

  And I click on add new question
  And I fill in "profile_question_text_0" with "New Dependent Field"
  And I check "Show only if"
  And I select "New Membership Field" from "profile_question_0_conditional_question_id"
  Then I click ".cjs_conditional_question_select_container input.select2-input"
  Then I click on select2 result "India"
  When I scroll the div ".cjs-side-panel-slim-scroll"
  And I press "Save" within "form#edit_profile_question_"
  Then I wait for ajax to complete
  And I configured question for "mentor" role in the program "primary" and set default visibility
  And I click ".cjs_profile_question_edit_role_settings"
  And I check "Membership Form"
  When I scroll the div ".cjs-side-panel-slim-scroll"
  And I press "Save"
  Then I wait for ajax to complete

  And I click on add new section
  And I fill in "new_section_title_add_new_section_form" with "New Section For First time"
  And I fill in "section_description_add_new_section_form" with "New Section description"
  And I press "Save" within "form#add_new_section_form"

  And I click on the last section
  And I click on add new question
  And I fill in "profile_question_text_0" with "Dependent Field 1"
  And I check "Show only if"
  And I select "New Membership Field" from "profile_question_0_conditional_question_id"
  Then I click ".cjs_conditional_question_select_container input.select2-input"
  Then I click on select2 result "India"
  When I scroll the div ".cjs-side-panel-slim-scroll"
  And I press "Save" within "form#edit_profile_question_"
  Then I wait for ajax to complete
  And I configured question for "mentor" role in the program "primary" and set default visibility

  And I click on add new question
  And I fill in "profile_question_text_0" with "Dependent Field 2"
  And I check "Show only if"
  And I select "New Membership Field" from "profile_question_0_conditional_question_id"
  Then I click ".cjs_conditional_question_select_container input.select2-input"
  Then I click on select2 result "Pakistan"
  When I scroll the div ".cjs-side-panel-slim-scroll"
  And I press "Save" within "form#edit_profile_question_"
  Then I wait for ajax to complete
  And I configured question for "mentor" role in the program "primary" and set default visibility
  And I logout

  # User sending membership request as mentor
  Given the current program is "primary":"albers"
  Given all membership questions are not mandatory
  When I want to join as "Mentor" with "example1@chronus.com"
  Then I click on the signup link sent in email to "example1@chronus.com"
  And I should see "New Membership Field"
  And I should see question with title "New Dependent Field" is hidden
  And I select the option "India" for the question "New Membership Field"
  And I should see question with title "New Dependent Field" is not hidden
  And I fill the basic information and submit the membership application form
  Then I should see "Your request has been sent to the program administrators. You will receive an email once the request is accepted"

  # Admin accepting the requests
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Membership Requests"

  When I accept the request from "example1@chronus.com" with message ""
  Then a mail should go to "example1@chronus.com" having ""
  Then I should see "The request has been accepted. Click here to view the member's profile."
  And I logout

  # User coming from email checks conditional fields during first time profile completion
  When I open new mail
  And I follow "Login" in the email
  Then I should see "Login"
  Then I sign in as "example1@chronus.com"
  And I press "Save"
  And I click on the section with header "New Section For First time"
  And I should see question with title "Dependent Field 1" is not hidden
  And I should see question with title "Dependent Field 2" is hidden

@enrollment_scenario
@javascript @cross_browser
Scenario: Back-end validation of membership questions
  Given the current program is "primary":"albers"
  And I add a membership question in non default section for mentor and student roles in "primary":"albers"
  When I want to join as "Student" with "example@chronus.com"
  And I click on the signup link sent in email to "example@chronus.com"
  Then I should see "About Me"
  And I should not see "About Me *"
  When I make the question "About Me" mandatory in "primary":"albers"
  And I fill the basic information and submit the membership application form
  Then I should see "Answer text can't be blank" within "#sections_list"
  And I should see "About Me *"
  When I fill the answer "About Me" with "I am NOT the DANGER!"
  And I fill the password and submit the membership application form
  Then I should see "Your request has been sent to the program administrators."