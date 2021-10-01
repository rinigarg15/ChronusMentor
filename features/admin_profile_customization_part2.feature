 @profile_customizationadmin_mes
Feature: Admin customizes mentor and student profile forms.

Background:
  And I perform missed migrations

 @javascript @p2 @cross_browser
  Scenario: Admin checking the conditional question in the add mentor directly
    Given the current program is "primary":""
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    And I should see "Customize"
    And I follow "Customize"
    And I click on add new section
    And I fill in "new_section_title_add_new_section_form" with "New Conditional Section"
    And I fill in "section_description_add_new_section_form" with "New Section description"
    And I press "Save" within "form#add_new_section_form"
    And I click on the last section
    And I click on add new question
    And I fill in "profile_question_text_0" with "New Conditional Multi Choice Field"
    And I select "Pick one answer" from "profile_question_question_type_0"
    And I should not see "allow_multiple"
    And I add choices "India,Pakistan,Brothers"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I should see "Show only if"
    Then I check "Show only if"

    And I select "Industry" from "profile_question_0_conditional_question_id"
    Then I click ".cjs_conditional_question_select_container input.select2-input"
    Then I click on select2 result "Accounting"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save" within "form#edit_profile_question_"
    Then I wait for ajax to complete

    And I configured question for "mentor" role in the program "primary" and set default visibility
    Then I wait for ajax to complete

    And I select "Albers Mentor Program" from the program selector 
    And I follow "Manage"
    Then I follow "Add Users"
    And I check "role_mentor"
    And I fill in "user_email" with "user@chronus.com"
    And I click "#cjs_add_user_next"
    Then I click on the section with header "Mentoring Profile"
    And I click on the section with header "New Conditional Section"
    And I should see question with title "New Conditional Multi Choice Field" is hidden
    And I should see question with title "Industry" is not hidden
    And I select the option "Accounting" for the question "Industry"
    And I should see question with title "New Conditional Multi Choice Field" is not hidden
    Then I logout   

  @javascript @p2
  Scenario: Admin creating a section with special characters and checking for the section collapse
    Given the current program is "primary":""
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    And I should see "Customize"
    And I follow "Customize"

    And I click ".cjs-new-field-invoker"
    And I fill in "profile_question_text_0" with "Parent"
    And I select "Pick multiple answers" from "profile_question_question_type_0"
    And I add choices "Father,Mother,Gaurdian"
    Then I press "Save"
    And I check "Mentor" within ".cjs-program-role-options-for-6"
    And I check "Student" within ".cjs-program-role-options-for-6"

    And I click ".cjs-new-field-invoker"
    And I fill in "profile_question_text_0" with "Experience1"
    And I select "Experience" from "profile_question_question_type_0"
    And I check "Show only if"
    And I select "Parent" from "profile_question_0_conditional_question_id"
    Then I click ".cjs_conditional_question_select_container input.select2-input"
    Then I click on select2 result "Father"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    And I check "Mentor" within ".cjs-program-role-options-for-6"
    And I check "Student" within ".cjs-program-role-options-for-6"

    And I click "#profile_section_2" within "#sections_list"
    And I click "#profile_question_96" within "#profile_questions_for_section_2"
    And I click ".cjs_profile_delete" within "#profile_question_96"
    Then I click ".cjs-delete-question-confirm-button"
    And I click "#profile_question_97" within "#profile_questions_for_section_2"
    And I click ".cjs_profile_delete" within "#profile_question_97"
    Then I click ".cjs-delete-question-confirm-button"

    And I click ".cjs-new-field-invoker"
    And I fill in "profile_question_text_0" with "Parent2"
    And I select "Pick multiple answers" from "profile_question_question_type_0"
    And I add choices "Father2,Mother2,Gaurdian2"
    Then I press "Save"
    And I check "Mentor" within ".cjs-program-role-options-for-6"
    And I check "Student" within ".cjs-program-role-options-for-6"

    And I click "#profile_question_7" within "#profile_questions_for_section_2"
    And I check "Show only if"
    And I select "Parent2" from "profile_question_7_conditional_question_id"
    Then I click ".cjs_conditional_question_select_container input.select2-input"
    Then I click on select2 result "Father2"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    Then I press "Save"

    And I edit the "default" section of "primary" title to "Default Edited Section" And description to "Default Edited description"  
    And I click on add new section
    And I fill in "new_section_title_add_new_section_form" with "$Test section - a & b / 'section' a % b #"
    And I press "Save" within "form#add_new_section_form"
    And I click on the last section
    Then I should see ".cjs-new-field-invoker" not hidden
    And I click on add new question
    And I fill in "profile_question_text_0" with "New Special Symbols"
    And I press "Save" within "form#edit_profile_question_"
    Then I wait for ajax to complete

    And I configured question for "mentor" role in the program "primary" and set default visibility
    Then I wait for ajax to complete

    Then I logout
    
    #First time visit
    Given the current program is "primary":"albers"
    When Admin sends program invitation email to "sarat_new@example.com" as "mentor"
    When I open new mail
    And I follow "Click here" in the email
    And element with id "#member_email" should be disabled
    And I fill in "member_first_name" with "new"
    And I fill in "member_last_name" with "mentor"
    And I fill in "member_password" with "haribol"
    And I fill in "member_password_confirmation" with "haribol"
    Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
    And I press "Sign up »"
    Then I should not see "Click here to import your experience from"
    Then I check "Father"
    And I should see "Click here to import your experience from"
    Then I uncheck "Father"
    And I press "submit_general"
    And I should not see "Click here to import your experience from"
    Then I check "Father2"
    And I should see "Click here to import your experience from"
    And I logout

    #Edit Profile
    And I have logged in as "robert@example.com"
    Then I follow "Edit Profile" within "#profile_preview"
    Then I should not see "Click here to import your experience from"
    Then I check "Father"
    And I should see "Click here to import your experience from"
    Then I uncheck "Father"
    And I click on the section with header "Work and Education"
    Then I wait for ajax to complete
    And I should not see "Click here to import your experience from"
    Then I check "Father2"
    And I should see "Click here to import your experience from"

    And I click on the section with header "$Test section - a & b / 'section' a % b #"
    Then I should see "New Special Symbols"
    And I click on profile picture and click "Edit Profile"
    And I should see "Default Edited description"
    And I logout

    And I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Membership"
    And I specify the joining option as "No approval required" for "Mentor"
    And I specify the joining option as "No approval required" for "Student"
    And I choose "program_show_multiple_role_option_true"
    And I press "Save"
    And I logout

    #Join as new mentor directly
    Then I want to join as "Mentor" with "harrypotter@test.com"
    And I open new mail
    And I follow "Complete Sign Up" in the email
    Then I should see "To join as Mentor, complete and submit the form below."
    Then email should be filled with "harrypotter@test.com" in landing page
    And I fill in the following details in membership request
    | FirstName       | Harry  |
    | LastName        | Potter |
    | Password        | monkey |
    | ConfirmPassword | monkey |
    And I press "Submit"
    Then I should see "Welcome to Albers Mentor Program. Please complete your online profile to proceed."
    Then I should not see "Click here to import your experience from"
    Then I check "Father"
    And I should see "Click here to import your experience from"
    Then I uncheck "Father"
    Then I check "Mother"
    And I press "submit_general"
    And I should not see "Click here to import your experience from"
    Then I check "Father2"
    And I should see "Click here to import your experience from"
    Then I uncheck "Father2"
    Then I check "Mother2"
    And I press "Proceed"
    Then I should see "Mentoring Profile"
    And I press "Proceed"
    Then I should see "More Information"
    And I press "Proceed"
    Then I should see "$Test section - a & b / 'section' a % b #"
    And I press "Proceed"
    Then I should see "Mentoring Preferences"
    And I press "Proceed"
    And I logout

    And I make "Parent" question available in the membership form for "mentor" in "primary":"modprog"
    And I make "Parent2" question available in the membership form for "mentor" in "primary":"modprog"
    And I make "Experience1" question available in the membership form for "mentor" in "primary":"modprog"
    And I make "Work" question available in the membership form for "mentor" in "primary":"modprog"

    #User enrolling to another program
    Given the current program is "primary":"modprog"
    And I have logged in as "harrypotter@test.com"
    And I should see the flash "To join as Mentor and Student, complete and submit the form below."
    And I select "Mentor" from "role_names_select"
    Then I should not see "Click here to import your experience from"
    Then I check "Father"
    And I should see "Click here to import your experience from"
    Then I uncheck "Father"
    And I should not see "Click here to import your experience from"
    Then I check "Father2"
    And I should see "Click here to import your experience from"
    Then I uncheck "Father2"
    And I logout

    And I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Add Users"
    And I check "role_mentor"
    And I fill in "user_email" with "valid_o'email@iit.com"
    And I click "#cjs_add_user_next"
    And I should see "Default Edited description"
    And I logout

@javascript @p2 @cross_browser
  Scenario: Admin deleting a section/question
    #login as non-admin
    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    Then I follow "Edit Profile" within "#profile_preview"
    Then I should see "Work and Education"
    And I click on the section with header "Mentoring Profile"
    Then I should see "About Me"
    And I logout

    And I have logged in as "ram@example.com"
    Then I hover over "my_programs_container"
    When I select "Primary Organization" from the program selector
    And I follow "Manage"
    And I should see "Customize"
    And I follow "Customize"
    And I click "div.cjs-section-container[data-section-id='3']"
    #delete question : Mentoring Profile - About Me
    And I click ".cjs-profile-question-click-handle-element"
    Then I click the first delete icon
    Then I should see "all user responses for this field, if any, will be lost"
    Then I click ".cjs-delete-question-confirm-button"
    #delete section : Work and Education
    And I click "div.cjs-section-container[data-section-id='2']"
    Then I click the first section-delete icon
    Then I should see "Are you sure you want to delete this section? This will also delete all the fields in the section."
    And I confirm popup  
    Then I logout
    #login as non-admin
    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    Then I follow "Edit Profile" within "#profile_preview"
    Then I should not see "Work and Education"
    And I click on the section with header "Mentoring Profile"
    Then I should not see "About Me"
    And I logout

@javascript @p2
  Scenario: Admin Preview User Profile Form 
    Given the current program is "primary":""
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    Then I follow "Preview Profile Form"
    And I select "Albers Mentor Program" from "program_select_user_profile"
    # Then I click "#sub_title_navig div.dropdown-toggle"
    # And I follow "Albers Mentor Program"
    Then I check "Mentor"
    And I follow "Preview"
    Then I wait for ajax to complete
    Then I should see "Basic Information"
    Then I should see "Work and Education"
    Then I should see "Mentoring Profile"
    Then I should see "More Information"
    Then I should see "What is your favorite location stop"
    Then I should not see "More Information Students"
    Then I check "Student"
    And I follow "Preview"
    Then I wait for ajax to complete
    Then I should see "More Information Students"
    Then I uncheck "Mentor"
    Then I uncheck "Student"
    Then I check "Student"
    And I follow "Preview"
    Then I wait for ajax to complete
    Then I should not see "What is your favorite location stop"
    Then I should see "More Information Students"
    Then I logout

@javascript @p2
Scenario: Validation checks while editing profile
    Given the current program is "primary":"albers"
    And I set help text as "Name help text" for name question in organization "primary"
    And I have logged in as "robert@example.com"
    When I follow "Edit Profile" within "#profile_preview"
    And I fill in "First name" with ""
    Then I fill in "Last name" with ""
    And I should see "Name help text"
    And I press "Save"
    Then I should see "Please fill the highlighted fields with appropriate values to proceed"
    
    And I fill in "First name" with "Ramya123"
    Then I fill in "Last name" with "!@#$%"
    And I press "Save"
    And I should see "Name help text"
    And I should see "Please correct the below error(s) highlighted in red."
    And I should see "contains numeric characters"
    
    And I fill in "First name" with "Ashley"
    Then I fill in "Last name" with "Williams"
    And I should see "Name help text"
    And I press "Save"
    #Email Validation
    Then I wait for ajax to complete
    And I click on the section with header "Basic Information"
    Then I wait for ajax to complete
    Then I should see "Email"
    Then I fill in "Email" with "ram@example.com"
    And I press "Save"
    And I should see "Please correct the below error(s) highlighted in red."
    And I should see "has already been taken"
    Then I follow "Cancel"
    Then I logout

@javascript
  Scenario: Admin creates a Publication type question    
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    And I select "Primary Organization" from the program selector
    Then I follow "Manage"
    And I follow "Customize"
    
    And I click on add new section
    
    And I fill in "new_section_title_add_new_section_form" with "Publications"
    And I press "Save" within "form#add_new_section_form"
    
    And I click on the last section
    
    And I click on add new question
    
    And I fill in "profile_question_text_0" with "Ur publications"
    And I select "Publication" from "profile_question_question_type_0"
    And I press "Save" within "form#edit_profile_question_"
    Then I wait for ajax to complete

    And I configured question for "mentor" role in the program "primary" and set default visibility
    Then I wait for ajax to complete

    Then I click edit advanced options
    Then I check "Show in profile summary"
    
    And I press "Save" within "form"
    And I logout
    #User logs in and fills his profile
    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    When I follow "Edit Profile" within "#profile_preview"
   
    And I click on the section with header "Publications"
    And I should see "Ur publications"
   
    And I fill in publication_question of "primary":"albers" with "My Story,Harrison,Danny Lee Silk"
    And I save the section "Publications"
    And I click on profile picture and click "View Profile"
    And I should see "My Story"
    And I should see "Harrison"
    And I should see "Authors:Danny Lee Silk"
    And I logout

@javascript
  Scenario: Question with more than 0 answers should show data-loss warning
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    And I select "Primary Organization" from the program selector
    Then I follow "Manage"
    And I follow "Customize"
    
    And I click on section with title "Work and Education"
    Then I click on "Edit" inside the "Current Manager" question in "primary"
    
    Then I change the type of "Current Manager" question in "Primary Organization" to "Text Entry"
    Then I should see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"
    Then I confirm popup
    And I press "Save"
    And I logout

    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    And I select "Primary Organization" from the program selector
    Then I follow "Manage"
    And I follow "Customize"
    
    And I click on section with title "Work and Education"
    Then I click on "Edit" inside the "Current Manager" question in "primary"
   
    Then I change the type of "Current Manager" question in "Primary Organization" to "Pick one answer"
    Then I should not see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"
    Then I add choices for "Current Manager" question in "Primary Organization"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    And I logout

@javascript @cross_browser
  Scenario: Question with more than 0 answers should show data-loss warning and should revert back the choice on clicking No
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    And I select "Primary Organization" from the program selector
    Then I follow "Manage"
    And I follow "Customize"
    
    And I click on section with title "Work and Education"
    Then I click on "Edit" inside the "Current Manager" question in "primary"
   
    Then I change the type of "Current Manager" question in "Primary Organization" to "Text Entry"
    Then I should see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"
    Then I cancel popup
    And I press "Save"
    And I logout

    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    And I select "Primary Organization" from the program selector
    Then I follow "Manage"
    And I follow "Customize"
    
    And I click on section with title "Work and Education"
    Then I click on "Edit" inside the "Current Manager" question in "primary"
    
    Then I change the type of "Current Manager" question in "Primary Organization" to "Pick one answer"
    Then I should see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"
    And I press "No"