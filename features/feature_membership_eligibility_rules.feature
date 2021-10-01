Feature: Users should be able to send membership requests and admin be able to accept or reject them
  In order that entry into the mentoring program is restricted
  As an admin
  I want to be able to accept or reject membership requests

Background: Admin enables Eligibility Rules
  Given the current program is "primary":"albers" 
  When I have logged in as "ram@example.com"
  And I login as super user
  Then I follow "Manage"
  Then I follow "Program Settings"
  Then I follow "Features"
  Then I should see "Membership Eligibility Rules"
  And I check "membership_eligibility_rules"
  And I press "Save"
  And I logout  

@javascript
@enrollment_scenario
Scenario: Eligibility Rules For Mentor
  Given the current program is "primary":"albers" 
  When I have logged in as "ram@example.com"
  Then I make all profile questions into membership questions in "primary":"albers"
  And I follow "Albers Mentor Program"
  Then I follow "Manage"
  Then I follow "Program Settings"
  Then I follow "Membership"
  Then I choose "join_eligibility_rules_mentor"
  Then I should see "Set eligibility rules"
  Then I follow "Set eligibility rules"

  Then I should see "Set Eligibility rules for mentor"
  Then I should see "#admin_view_profile_questions_questions_1_value" hidden
  Then I should see "#admin_view_profile_questions_questions_1_choice" hidden
  Then I select "Language" from "admin_view_profile_questions_questions_1_question"

  #popup should not close if operator is not filled
  Then I press "Save" within ".cjs_adminview_form"
  Then I should see "Set Eligibility rules for mentor"
  
  #making sure that the text box comes for in and not_in operator
  Then I select "Not Contains Any Of" from "admin_view_profile_questions_questions_1_operator"
  Then I should see "#admin_view_profile_questions_questions_1_choice" not hidden
  Then I should see "#admin_view_profile_questions_questions_1_value" hidden
  Then I select "Contains Any Of" from "admin_view_profile_questions_questions_1_operator"
  Then I should see "#admin_view_profile_questions_questions_1_choice" not hidden
  Then I should see "#admin_view_profile_questions_questions_1_value" hidden
  Then I select "Contains Any Of" from "admin_view_profile_questions_questions_1_operator"
  Then I should see "#admin_view_profile_questions_questions_1_value" not hidden
  Then I should see "#admin_view_profile_questions_questions_1_choice" hidden

  #popup should not close if a question is not filled
  Then I follow "Add one more"
  Then I select "Not Filled" from "admin_view_profile_questions_questions_2_operator"
  Then I press "Save" within ".cjs_adminview_form"
  Then I should see "Set Eligibility rules for mentor"

  #popup should not close if a field is not filled
  Then I select "Phone" from "admin_view_profile_questions_questions_2_question"
  Then I select "Filled" from "admin_view_profile_questions_questions_2_operator"
  Then I press "Save" within ".cjs_adminview_form"
  Then I should see "Set Eligibility rules for mentor"
  Then I click ".cjs_hidden_input_box_container input.select2-input"
  Then I click on select2 result "English"
  Then I press "Save" within ".cjs_adminview_form"

  #correct flash message should appear and text should change from set to edit
  Then I should see "Edit eligibility rules"
  Then I follow "Edit eligibility rules"
  
  Then I should see "Set Eligibility rules for mentor"
  Then I press "Save" within ".cjs_adminview_form"
  Then I should not see "Set Eligibility rules for mentor"
  Then I press "Save"

  #corresponding admin view should at org level
  Then I hover over "my_programs_container"
  When I select "Primary Organization" from the program selector
  Then I follow "Manage"
  Then I follow "Member Views"
  And I click on all members title
  Then I should see "Eligible Mentors for Albers Mentor Program"
  And I close the all members view dropdown
  Then I logout

  #User who satisfies the rules signs-up
  Given the current program is "primary":"albers"
  And I want to join as "mentor" with "apply_mentor@example.com"
  Then I click on the signup link sent in email to "apply_mentor@example.com"
  Then I should see "To join as Mentor, complete and submit the form below."
  Then I fill in "membership_request_first_name" with "Apply"
  Then I fill in "membership_request_last_name" with "Mentor"
  Then I fill in "membership_request_password" with "monkey"
  Then I fill in "membership_request_password_confirm" with "monkey"
  And I check "English" within "#profile_answers_16"
  Then I fill in "profile_answers_4" with "9123456789"
  Then I valdiate and give my consent for terms and conditions by clicking "Submit"
  Then I press "Submit"
  Then I should see "Welcome to Albers Mentor Program. Please complete your online profile to proceed."
  Then I logout

  #User who does not satisfy the rules signs-up
  Given the current program is "primary":"albers"
  And I want to join as "mentor" with "apply_mentor_request@example.com"
  Then I click on the signup link sent in email to "apply_mentor_request@example.com"
  Then I should see "To join as Mentor, complete and submit the form below."
  Then I fill in "membership_request_first_name" with "Apply"
  Then I fill in "membership_request_last_name" with "Mentor"
  Then I fill in "membership_request_password" with "monkey"
  Then I fill in "membership_request_password_confirm" with "monkey"
  And I check "Spanish" within "#profile_answers_16"
  Then I fill in "profile_answers_4" with "9123456789"
  Then I valdiate and give my consent for terms and conditions by clicking "Submit"
  Then I press "Submit"
  Then I should see "Based on available information, it appears you can not join the program as Mentor"

  #Suspended user who does not satisfy the eligibility rules
  Given the current program is "primary":"albers"
  Given the user with email "rahim@example.com" is suspended only in program "albers"
  And I have logged in as "rahim@example.com"
  Then I should see "To join as Mentor and Student, complete and submit the form below."
  Then I should see "Join As *"
  Then I select "Mentor" from "role_names_select"
  Then I should see "Basic Information"
  Then I fill in "profile_answers_3" with "Chennai"
  Then I fill in "profile_answers_4" with "9123456789"
  Then I press "Submit"
  Then I should see "Join As *"
  And I should see "Based on available information, it appears you can not join the program as Mentor"

@javascript
@enrollment_scenario
Scenario: Eligibility Rules For Mentee
  Given the current program is "primary":"albers" 
  When I have logged in as "ram@example.com"
  Then I make all profile questions into membership questions in "primary":"albers"
  And I follow "Albers Mentor Program"
  Then I follow "Manage"
  Then I follow "Program Settings"
  Then I follow "Membership"
  Then I choose "join_eligibility_rules_student"
  Then I set eligibilty rules for "student" in "Albers Mentor Program"
  
  

  #corresponding admin view should at org level
  Then I hover over "my_programs_container"
  When I select "Primary Organization" from the program selector
  Then I follow "Manage"
  Then I follow "Member Views"
  And I click on all members title
  Then I should see "Eligible Students for Albers Mentor Program"
  And I close the all members view dropdown
  Then I logout

  #User who satisfies the rules signs-up
  Given the current program is "primary":"albers"
  When I want to join as "student" with "apply_mentee@example.com"
  Then I click on the signup link sent in email to "apply_mentee@example.com"
  Then I should see "To join as Student, complete and submit the form below."
  Then I fill in "membership_request_first_name" with "Apply"
  Then I fill in "membership_request_last_name" with "Mentee"
  Then I fill in "membership_request_password" with "monkey"
  Then I fill in "membership_request_password_confirm" with "monkey"
  And I check "English" within "#profile_answers_16"
  Then I fill in "profile_answers_4" with "9123456789"
  Then I valdiate and give my consent for terms and conditions by clicking "Submit"
  Then I press "Submit"
  Then I should see "Welcome to Albers Mentor Program. Please complete your online profile to proceed."
  Then I logout

  #User who does not satisfy the rules signs-up
  Given the current program is "primary":"albers"
  And I want to join as "student" with "apply_mentee_request@example.com"
  Then I click on the signup link sent in email to "apply_mentee_request@example.com"
  Then I should see "To join as Student, complete and submit the form below."
  Then I fill in "membership_request_first_name" with "Apply"
  Then I fill in "membership_request_last_name" with "Mentee"
  Then I fill in "membership_request_password" with "monkey"
  Then I fill in "membership_request_password_confirm" with "monkey"
  And I check "Spanish" within "#profile_answers_16"
  Then I valdiate and give my consent for terms and conditions by clicking "Submit"
  Then I press "Submit"
  Then I should see "Not eligible to join"

@javascript @cross_browser
@enrollment_scenario
Scenario: User applies for both role but satisfies just one role
  Given the current program is "primary":"albers" 
  When I have logged in as "ram@example.com"
  Then I make all profile questions into membership questions in "primary":"albers"
  And I follow "Albers Mentor Program"
  Then I follow "Manage"
  Then I follow "Program Settings"
  Then I follow "Membership"
  Then I choose "join_eligibility_rules_mentor"
  Then I set eligibilty rules for "mentor" in "Albers Mentor Program"
  Then I choose "join_eligibility_rules_student"
  Then I set eligibilty rules for "student" in "Albers Mentor Program"
  
  Then I follow "Edit eligibility rules"
  Then I select "Not Filled" from "admin_view_profile_questions_questions_2_operator"
  Then I press "Save" within ".cjs_adminview_form"
  Then I should not see "Set Eligibility rules for mentor"
  And I choose "program_show_multiple_role_option_true"
  And I press "Save"
  Then I logout

  Given the current program is "primary":"albers"
  And I want to join as "mentor__student" with "apply_both_fail@example.com"
  Then I click on the signup link sent in email to "apply_both_fail@example.com"
  Then I should see the flash "To join as Mentor and Student, complete and submit the form below."
  Then I fill in "membership_request_first_name" with "Apply"
  Then I fill in "membership_request_last_name" with "Both"
  Then I fill in "membership_request_password" with "monkey"
  Then I fill in "membership_request_password_confirm" with "monkey"
  And I check "English" within "#profile_answers_16"
  Then I fill in "profile_answers_4" with "9123456789"
  Then the "signup_terms" checkbox_id should not be checked
  Then I check "signup_terms"
  Then the "signup_terms" checkbox_id should be checked
  Then I press "Submit"
  Then I should see "Welcome to Albers Mentor Program. Please complete your online profile to proceed. However you are not allowed to join as a mentor."
  Then I logout