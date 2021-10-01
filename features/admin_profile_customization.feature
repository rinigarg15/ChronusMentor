@profile_customization
Feature: Admin customizes mentor and student profile forms.

Background: Set the program to albers
  Then I perform missed migrations

@javascript
  Scenario: Standalone program customization
    Given the current program is "foster":"main"
    And I have logged in as "fosteradmin@example.com"
    And "student" role "term" is called as "Bike" in "foster":"main"
    And "mentor" role "term" is called as "Car" in "foster":"main"

    Given there are questions "Hello,Great,Awesome" for "mentor" in "foster":"main"
    And there are questions "FosterQ1,FosterQ2" for "mentor" in "foster":"main"
    And there are questions "FosterStuQ1" for "student" in "foster":"main"
    And there is match config for student question "FosterStuQ1" and mentor question "FosterQ1" in "foster":"main"

    When I follow "Manage"
    And I follow "Customize"
    
    And I follow "Update Join Instructions" 
    Then I wait for ajax to complete
    Then I should see "Instructions to be given when someone requests to join the program"
    And I fill in by css "membership_request_instruction_content" with "New Instruction"
    And I press "Save" within "form.cjs-instruction-form"
    Then I wait for ajax to complete
    Then I should see "Join Instructions has been updated successfully."
    Then I should not see "Instructions to be given when someone requests to join the program"

    And I open section with header "Basic Information"
    Then I should see "Hello"
    And I should see "Great"
    And I should see "Awesome"
    When I scroll the div ".cjs-profile-question-slim-scroll"
    And I should see "FosterQ1"
    And I should see "FosterQ2"
    And I should see "FosterStuQ1"
    And I am trying to remove the field "FosterQ1" under the section "Basic Information"
    And I should see "Match score as this is associated to matching. User responses for this field will be lost." within "div.modal-dialog"
    Then I cancel modal
    And I am trying to remove the field "FosterStuQ1" under the section "Basic Information"
    And I should see "Match score as this is associated to matching. User responses for this field will be lost." within "div.modal-dialog"
    Then I cancel modal
    And I am trying to remove the field "FosterQ2" under the section "Basic Information"
    And I should not see "Match score as this is associated to matching." within "div.modal-dialog"
    And I should see "Are you sure you want to delete this field? The field will be removed from all programs and all user responses for this field, if any, will be lost." within "div.modal-dialog"
    Then I cancel modal
    And I am editing the field "FosterStuQ1"
    And I follow "Roles"
    Then I uncheck student for editing field and save the form
    And Confirmation dialog should contain "Match score as this is associated to matching."
    And Confirmation dialog should not contain "User responses for this field will be lost."
    Then I cancel popup

@javascript @cross_browser
  Scenario: Standalone program Section and Question customization
    Given the current program is "foster":"main"
    And I have logged in as "fosteradmin@example.com"
    And I follow "Manage"
    Then I should see "Preview"
    And I should see "Customize"
    And I follow "Customize"
    And I click on add new section
       
    And I fill in by css "new_section_title_add_new_section_form" with "New Section"
    And I fill in by css "section_description_add_new_section_form" with "New Section description"
    And I press "Save" within "form#add_new_section_form"
    
    And I click on the last section
   
    And I click on add new question
    
    And I fill in by css "profile_question_text_0" with "New Mentor Field"
    Then I set help text to "Just a new Mentor field"
    And I press "Save" within "form#edit_profile_question_"
    Then I wait for ajax to complete
    And I follow "Roles"
    And I check "Mentor"
    
    And I click on add new question
    
    And I fill in by css "profile_question_text_0" with "New Student Field"
    And I press "Save" within "form#edit_profile_question_"
    Then I wait for ajax to complete
    And I follow "Roles"
    And I check "Student"
    Then I wait for ajax to complete
    And I click ".cjs_profile_question_edit_role_settings"
    Then I wait for ajax to complete
    When I scroll the div ".cjs-side-panel-slim-scroll"
    Then I check "Editable by administrators only"
    And I check "Mandatory" option to be disabled and unchecked
    Then I uncheck "All mentors"
    Then I uncheck "All students"
    Then I uncheck "User's mentoring connections"
    Then I uncheck "User"
    And I check options for adminstrators only for visibility
    And I press "Save"
       
    Then I am editing the field "New Student Field"
    And I follow "Roles"
    Then I click edit advanced options
    Then I check "User's mentoring connections"
    And I check "Show in profile summary" option to be disabled and unchecked
    And I check "Available for advanced search" option to be disabled and unchecked
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    Then I wait for ajax to complete
    Then I am editing the field "New Student Field"
    And I follow "Roles"
    Then I click edit advanced options
    Then I check "All mentors"
    Then I check "All students"
    Then I check "Show in profile summary"
    Then I check "Available for advanced search"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    Then I wait for ajax to complete
    Then I am editing the field "New Student Field"
    And I follow "Roles"
    Then I click edit advanced options
    Then I check "Show in profile summary" option to be enabled
    Then I check "Available for advanced search" option to be enabled
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"

    #Checking other option
    And I click on add new question
    
    And I fill in by css "profile_question_text_0" with "New Other Field"
    And I select "Pick one answer" from "profile_question_question_type_0"
    And I should not see "allow_multiple"   
    
    And I add choices "vatican,pope,rome"
    Then I check "profile_question_allow_other_option"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save" within "form#edit_profile_question_"
    And I follow "Roles"

    And I check "Mentor"

    #Checking if the help text is visible or not
    And I follow "Preview"
    And I follow "User Profile Form"
    And I check "Mentor"
    Then I follow "Preview"
    Then I wait for ajax to complete
    Then I should see "Just a new Mentor field"
 
    And I should see "New Other Field"
    And I select "Other..." from "New Other Field"

    And I follow "Manage"
    And I follow "Customize"
   
    And I click on add new section
    
    And I fill in by css "new_section_title_add_new_section_form" with "New MentorStudent Section"
    And I press "Save" within "form#add_new_section_form"
    
    And I click on the last section
    
    And I click on add new question
    
    And I fill in by css "profile_question_text_0" with "New Mentor Student Field"
    And I press "Save" within "form#edit_profile_question_"   
    Then I wait for ajax to complete
    And I follow "Roles"

    And I check "Mentor"
    Then I wait for ajax to complete
    And I check "Student"
    Then I wait for ajax to complete
    
    And I follow "Manage"
    And I follow "Customize"
    
    And I click on add new section
    
    And I fill in by css "new_section_title_add_new_section_form" with "Blank Section"
    And I press "Save" within "form#add_new_section_form"
    
    And I click on the last section

    And I click on add new question
    
    And I fill in by css "profile_question_text_0" with "New Random Field"
    And I press "Save" within "form#edit_profile_question_"
    And I follow "Roles"
    
    And I check "Mentor"
    Then I wait for ajax to complete
    And I check "Student"
    Then I wait for ajax to complete

    And I follow "Manage"
    And I follow "Preview"
    And I check "Mentor"
    And I follow "Preview"
    Then I wait for ajax to complete
    Then I should see "New Section"    
    Then I should see "New Mentor Field"
    And I should not see "New Student Field"    
    Then I should see "New Mentor Student Field"
    And I should not see "Blank mentor section"
    
    And I uncheck "Mentor"
    And I check "Student"
    And I follow "Preview"
    Then I wait for ajax to complete
    
    Then I should see "New Section"
    Then I should not see "New Mentor Field"
    And I should see "New Student Field"    
    Then I should see "New Mentor Student Field"
    And I should not see "Blank mentor section"

    And I check "Mentor"
    And I follow "Preview"
    Then I wait for ajax to complete
    
    Then I should see "New Section"
    Then I should see "New Mentor Field"
    And I should see "New Student Field"
    Then I should see "New Mentor Student Field"
    And I should not see "Blank mentor section"

    And I follow "Manage"
    And I follow "Customize"
    
    And I edit the "last" section of "foster" title to "Blank Edited Section" And description to "Blank Edited description"
    And I should not see "Blank mentor section"
    And I edit the "default" section of "foster" title to "Default Edited Section" And description to "Default Edited description"
    And I should not see "Basic Information"
    And I should see "Default Edited Section"
       
    And I click on the last section

    And I edit the last question of "foster" title to "Edited Mentor Student Field"
    
    Then I should see "Edited Mentor Student Field"
@javascript
Scenario: Program admin customizing for sub program and program
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And "student" role "term" is called as "Bike" in "primary":"albers"
  And "mentor" role "term" is called as "Car" in "primary":"albers"

  And there are questions "AlbersQ1,AlbersQ2" for "mentor" in "primary":"albers"
  And there are questions "AlbersStuQ1" for "student" in "primary":"albers"

  When I follow "Manage"
  And I follow "Customize"
  Then I should see the program title "Albers Mentor Program"
  And I open section with header "Basic Information"
  But I should see "AlbersQ1"
  And I should see "AlbersQ2"

@javascript
Scenario: Subprogram admin customizing for sub program and viewing program questions readonly
  Given the current program is "primary":"albers"
  And I have logged in as "userram@example.com"
  And "student" role "term" is called as "Bike" in "primary":"albers"
  And "mentor" role "term" is called as "Car" in "primary":"albers"

  And there are questions "AlbersQ1,AlbersQ2" for "mentor" in "primary":"albers"
  And there are questions "AlbersStuQ1" for "student" in "primary":"albers"

  When I follow "Manage"
  And I follow "Customize"
  Then I should see the program title "Albers Mentor Program"
  And I open section with header "Basic Information"
  But I should see "AlbersQ1"
  And I should see "AlbersQ2"

@javascript @cross_browser
  Scenario: Profile fields listing customizing for standalone program conditional fields
    Given the current program is "foster":"main"
    And I have logged in as "fosteradmin@example.com"
    When I follow "Manage"
    And I follow "Customize"
    
    And I should see "Sections (4)"
    And I click on add new section
       
    And I fill in by css "new_section_title_add_new_section_form" with "New Conditional Section"
    And I fill in by css "section_description_add_new_section_form" with "New Section description"
    And I press "Save" within "form#add_new_section_form"
   
    And I click on the last section
    And I should see "Sections (5)"
    And I should see "New Conditional Section (0)"
    And I should see "Profile Fields (0)"

    #New Question with condition for 'show only if' depending on a multi choice question
    And I click on add new question
    
    And I fill in by css "profile_question_text_0" with "New Conditional Multi Choice Field"
    And I select "Education" from "profile_question_question_type_0"
    Then I should not see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"
    And I select "Pick one answer" from "profile_question_question_type_0"
    And I should not see "allow_multiple"
    Then I should not see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"
    And I add choices "India,Pakistan,Brothers"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I should see "Show only if"
    And I check "Show only if"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I select "Industry" from "profile_question_0_conditional_question_id"
    Then I click ".cjs_conditional_question_select_container input.select2-input"
    Then I click on select2 result "Accounting"
    And I press "Save" within "form#edit_profile_question_"
    Then I wait for ajax to complete
    And I follow "Roles"

    And I check "Mentor"
    Then I wait for ajax to complete

    Then I click edit advanced options
    And I check "Mandatory" option to be enabled
    When I scroll the div ".cjs-side-panel-slim-scroll"
    Then I uncheck "Editable by administrators only"
    And I check "Mandatory" option to be enabled
    
    And I press "Save"
    Then I wait for ajax to complete
    And I should see "New Conditional Section (1)"
    And I should see "Profile Fields (1)"

    #New Question with condition for show only if depending on a multi choice question
    And I click on add new question
    
    And I fill in by css "profile_question_text_0" with "Question Depending on multi answer"
    And I should see "Show only if"
    And I check "Show only if"
    And I select "New Conditional Multi Choice Field" from "profile_question_0_conditional_question_id"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    Then I click ".cjs_conditional_question_select_container input.select2-input"
    Then I click on select2 result "India"
    And I press "Save"
    Then I wait for ajax to complete
    And I follow "Roles"
    And I check "Mentor"
    Then I wait for ajax to complete

    #Checking that the new added question has been dynamically added to the conditional list
    And I click on add new question
    
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I should see "Show only if"
    And I check "Show only if"
    And I should see "New Conditional Multi Choice Field" within "#profile_question_0_conditional_question_id"
    And I follow "Cancel" within "form#edit_profile_question_"
    
    Then I reload the page
    And I click on the last section
    
    And I click on "Delete" inside the "New Conditional Multi Choice Field" question in "foster"
    And I should see "The following item(s) may get impacted on removing this profile field. 'Show only if' setting of the following field(s): Question Depending on multi answer User responses for this field will be lost. It is suggested that you check the above item(s) before you proceed." within "div.modal-dialog"
    And I should not see "Match score as this is associated to matching." within "div.modal-dialog"
    And I cancel modal
    And I click on "Edit" inside the "New Conditional Multi Choice Field" question in "foster"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    And Confirmation dialog should contain "The following item(s) may get impacted on editing or removing this profile field for any role in any program. 'Show only if' setting of the following field(s): Question Depending on multi answer It is suggested that you check the above item(s) before you proceed."
    And Confirmation dialog should not contain "Match score as this is associated to matching."
    And I confirm popup

    #Checking for the conditional behaviour in preview form
    And I follow "Preview"
    Then I wait for ajax to complete
    And I follow "User Profile Form"
    And I check "Mentor"
    And I follow "Preview"
    Then I wait for ajax to complete
    And I should see "New Conditional Multi Choice Field" hidden
    And I should see "Question Depending on multi answer" hidden
    And I should see "Industry"
    And I select "Accounting" from "Industry"
    And I should see "New Conditional Multi Choice Field" not hidden
    And I should see "Question Depending on multi answer" hidden
    And I check "Hindi"
    And I should see "Question Depending on multi answer" not hidden

  @javascript
  Scenario: Admin customized choice-based questions
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I select "Primary Organization" from the program selector
    And I follow "Manage"
    And I follow "Customize"
    And I open section with header "Basic Information"
    And I click on add new question
    And I fill in by css "profile_question_text_0" with "Who will win WC 2016?"
    And I select "Pick one answer" from "profile_question_question_type_0"
    And I should not see "allow_multiple"

    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    Then I should see "Choices can't be blank for choice based questions"
    And I add choices "India,WI,England,NZ"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    When I click on "Edit" inside the "Who will win WC 2016?" question in "primary"
    Then I see choices "India WI England NZ" in order

    # Add choices with + button
    And I add choice "Australia" next to "WI"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    Then Confirmation dialog should contain "User response for this field, as it will become empty if any user has previously selected the removed/modified choice(s)."
    And I confirm popup
    When I click on "Edit" inside the "Who will win WC 2016?" question in "primary"
    Then I see choices "India WI Australia England NZ" in order

    # Replace all choices

    And I replace choices "Ireland,Kenya,Pakistan,India"
    Then I wait for ajax to complete
    Then I see choices "Ireland Kenya Pakistan India" in order
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    Then Confirmation dialog should contain "User response for this field, as it will become empty if any user has previously selected the removed/modified choice(s)."
    And I confirm popup
    When I click on "Edit" inside the "Who will win WC 2016?" question in "primary"
    Then I see choices "Ireland Kenya Pakistan India" in order

    # Delete options with trash button
    Then I delete choices "Ireland Kenya Pakistan" for question "Who will win WC 2016?" in "Primary Organization"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    Then Confirmation dialog should contain "User response for this field, as it will become empty if any user has previously selected the removed/modified choice(s)."
    And Confirmation dialog should not contain "Match score as this is associated to matching."
    And I confirm popup

    When I click on "Edit" inside the "Who will win WC 2016?" question in "primary"
    Then I don't see choices "Ireland Kenya Pakistan India" in order
    Then I see choices "India" in order

    # Edit a choice directly
    Then I edit choice "India" inside the "Who will win WC 2016?" question in "Primary Organization" to "Indian Union"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    And I confirm popup
    When I click on "Edit" inside the "Who will win WC 2016?" question in "primary"
    Then I don't see choices "India" in order
    Then I see choices "Indian Union" in order


    # Error cases
    And I add choice "Imagination" next to "Indian Union"
    Then I edit choice "Indian Union" inside the "Who will win WC 2016?" question in "Primary Organization" to "Imagination"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    And I confirm popup
    Then I should see "choice has already been taken"


@javascript @cross_browser
Scenario: Admin managing default profile questions
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I select "Primary Organization" from the program selector
    And I follow "Manage"
    And I follow "Customize"
    And I open section with header "Basic Information"
    When I click on "Edit" inside the "Name" question in "primary"
    And I follow "Programs"    
    Then I click edit advanced options
    Then I check "Editable by administrators only" option to be disabled and unchecked
    And I logout

@javascript @cross_browser
Scenario: Hovering number of programs should display programs list
    Given the current program is "primary":""
    When I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Customize"
    And I open section with header "More Information Students"
    And I click on profile question with question text "What is your hobby"
    Then I should see "1 Program"
    Then I hover over visible class "cjs_no_of_programs"
    And I should see ".cjs_no_of_programs_tooltip" not hidden
    Then I should see "Albers Mentor Program"

    And I click on add new section
       
    And I fill in by css "new_section_title_add_new_section_form" with "New Dummy Section"
    And I press "Save" within "form#add_new_section_form"
   
    And I click on the last section

    #New Question to test number of programs tooltip
    And I click on add new question
    And I fill in by css "profile_question_text_0" with "New Question to check number of programs tooltip"
    And I press "Save"
    Then I wait for ajax to complete
    Then I should see "0 Programs"
    Then I hover over visible class "cjs_no_of_programs"
    And I should not see ".cjs_no_of_programs_tooltip"

  @javascript
  Scenario: Admin managing 3 chained conditional profile fields
    Given the current program is "foster":"main"
    And I have logged in as "fosteradmin@example.com"
    When I follow "Manage"
    And I follow "Customize"
    And I click on add new section
    And I fill in by css "new_section_title_add_new_section_form" with "New Conditional Section"
    And I fill in by css "section_description_add_new_section_form" with "New Section description"
    And I press "Save" within "form#add_new_section_form"
    And I click on the last section

    #New Question with condition for 'show only if' depending on a multi choice question
    And I click on add new question
    And I fill in by css "profile_question_text_0" with "New Conditional Multi Choice Field"
    And I select "Pick one answer" from "profile_question_question_type_0"
    And I add choices "India,Pakistan,Brothers"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I should see "Show only if"
    And I check "Show only if"
    And I select "Industry" from "profile_question_0_conditional_question_id"
    Then I click ".cjs_conditional_question_select_container input.select2-input"
    Then I click on select2 result "Accounting"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    Then I wait for ajax to complete
    Then I follow "Roles"
    And I check "Mentor"

    #New Question with condition for show only if depending on a multi choice question
    And I click on add new question
    And I fill in by css "profile_question_text_0" with "Question Depending on multi answer"
    And I should see "Show only if"
    And I check "Show only if"
    And I select "New Conditional Multi Choice Field" from "profile_question_0_conditional_question_id"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    Then I click ".cjs_conditional_question_select_container input.select2-input"
    Then I click on select2 result "India"
    And I press "Save"
    Then I wait for ajax to complete
    Then I follow "Roles"
    And I check "Mentor"
    Then I wait for ajax to complete
    Then I reload the page
    And I click on the last section

    #checking the functionality
    And I follow "Preview"
    Then I wait for ajax to complete
    And I follow "User Profile Form"
    And I check "Mentor"
    And I follow "Preview"
    Then I wait for ajax to complete
    And I should see "New Conditional Multi Choice Field" hidden
    And I should see "Question Depending on multi answer" hidden
    And I should see "Industry"
    And I select "Accounting" from "Industry"
    And I should see "New Conditional Multi Choice Field" not hidden
    And I should see "Question Depending on multi answer" hidden
    And I select "India" from "New Conditional Multi Choice Field"
    And I should see "Question Depending on multi answer" not hidden
    And I select "Aviation" from "Industry"
    And I should see "New Conditional Multi Choice Field" hidden
    And I should see "Question Depending on multi answer" hidden
    And I select "Accounting" from "Industry"
    And I should see "New Conditional Multi Choice Field" not hidden
    And I should see "Question Depending on multi answer" not hidden
