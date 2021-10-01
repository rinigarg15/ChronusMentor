Feature: Customizes student and mentor profile

@javascript @cross-browser
  Scenario: Admin creates conditional fields and user fills in answer
    Given the current program is "primary":"main"
    Then I perform missed migrations
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    Then I should see "Preview"
    And I should see "Customize"
    And I follow "Customize"

    And I click on add new section

    And I fill in "new_section_title_add_new_section_form" with "New Conditional Section"
    And I fill in "section_description_add_new_section_form" with "New Section description"
    And I press "Save" within "form#add_new_section_form"
    And I click on the last section

    #New Question with condition for 'show only if' depending on a question in different section
    And I click on add new question

    And I fill in "profile_question_text_0" with "New Conditional Single Choice Field"
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

    #New Question with condition for show only if depending on a multi choice question
    And I click on add new question

    And I fill in "profile_question_text_0" with "Question Depending on multi answer"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I should see "Show only if"
    Then I check "Show only if"
    And I select "New Conditional Single Choice Field" from "profile_question_0_conditional_question_id"
    Then I click ".cjs_conditional_question_select_container input.select2-input"
    Then I click on select2 result "India"
    Then I click ".cjs_conditional_question_select_container input.select2-input"
    Then I click on select2 result "Brothers"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save" within "form#edit_profile_question_"

    Then I wait for ajax to complete
    And I configured question for "mentor" role in the program "primary" and set default visibility

    And I click on add new question
    And I fill in "profile_question_text_0" with "Conditional Question field Experience"
    And I select "Experience" from "profile_question_question_type_0"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I should see "Show only if"
    Then I check "Show only if"
    And I select "New Conditional Single Choice Field" from "profile_question_0_conditional_question_id"
    Then I click ".cjs_conditional_question_select_container input.select2-input"
    Then I click on select2 result "India"
    Then I click ".cjs_conditional_question_select_container input.select2-input"
    Then I click on select2 result "Brothers"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save" within "form#edit_profile_question_"

    Then I wait for ajax to complete
    And I configured question for "mentor" role in the program "primary" and set default visibility

    And I logout

    #User views the conditional behaviour in Edit profile
    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    And I follow "Edit Profile"

    And I click on the section with header "New Conditional Section"
    And I should see question with title "New Conditional Single Choice Field" is hidden
    And I should see question with title "Question Depending on multi answer" is hidden
    And I click on the section with header "Mentoring Profile"
    And I should see "Industry"
    And I select the option "Accounting" for the question "Industry"
    And I save the section "Mentoring Profile"
    And I reload the page

    And I click on the section with header "New Conditional Section"
    And I should see question with title "New Conditional Single Choice Field" is not hidden
    And I should see question with title "Question Depending on multi answer" is hidden
    And I should see question with title "Conditional Question field Experience" is hidden
    And I select the option "India" for the question "New Conditional Single Choice Field"
    And I should see question with title "Question Depending on multi answer" is not hidden
    And I should see question with title "Conditional Question field Experience" is not hidden
    And I select the option "Pakistan" for the question "New Conditional Single Choice Field"
    And I should see question with title "Question Depending on multi answer" is hidden
    And I should see question with title "Conditional Question field Experience" is hidden
    And I select the option "Brothers" for the question "New Conditional Single Choice Field"
    And I should see question with title "Question Depending on multi answer" is not hidden
    And I should see question with title "Conditional Question field Experience" is not hidden

    And I save the section "New Conditional Section"
    Then I reload the page
    And I click on the section with header "New Conditional Section"
    And I should see question with title "Question Depending on multi answer" is not hidden
    And I should see question with title "Conditional Question field Experience" is not hidden

@javascript @cross-browser
  Scenario: On clicking on cancel in a section, user should not be redirected and section should get closed.
    Given the current program is "primary":"albers"
    Then I perform missed migrations
    And I have logged in as "robert@example.com"
    And I follow "Edit Profile"

    And I follow "Actions"
    And I should see "View your Profile"
    And I click on the section with header "Mentoring Profile"
    And I should see "#collapsible_section_content_3_content" not hidden
    And I follow "Cancel" within "div#collapsible_section_content_3"
    And I should see "#collapsible_section_content_3_content" hidden
    And I follow "Actions"
    And I should see "View your Profile"
    And I follow "Settings"
    And I follow "Cancel" within "#settings_section_general"
    And I follow "Actions"
    And I should see "View your Profile"

@not_run_on_tddium
@javascript
Scenario: Mentee edit the profile picture
    Given the current program is "primary":"albers"
    Then I perform missed migrations
    And I have logged in as "mkr@example.com"
    And I follow "Edit Profile"
    When I follow "Edit photo"
    When I upload a picture
    And I follow "Edit photo"
    Then I should see image "pic_2.png"
    Then I follow "enter link to picture »"
    Then I upload a picture url
    When I follow "Edit photo"
    Then I should see image "big-logo.png"
    And I logout

@javascript @cross-browser
  Scenario: More than one quicksearch boxes in a page
    Given the current program is "primary":"main"
    Then I perform missed migrations
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    Then I should see "Preview"
    And I should see "Customize"
    And I follow "Customize"

    And I click on add new section

    And I fill in "new_section_title_add_new_section_form" with "New Section"
    And I press "Save" within "form#add_new_section_form"

    And I click on the last section
    # Add first quicksearch box

    And I click on add new question

    And I fill in "profile_question_text_0" with "New Multi Choice Field 1"
    And I select "Pick multiple answers" from "profile_question_question_type_0"

    And I add choices "English, Hindi, French, Spanish, Telugu, Malyalam, Bengali, Tamil, Urdu, Japanese, Korean, Tulu, Kannada, Arabic"
    Then I wait for ajax to complete
    Then I check "profile_question_allow_other_option"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save" within "form#edit_profile_question_"

    Then I wait for ajax to complete
    And I configured question for "mentor" role in the program "primary" and set default visibility

    # Add second quicksearch box
    And I click on add new question

    And I fill in "profile_question_text_0" with "New Multi Choice Field 2"
    And I select "Pick multiple answers" from "profile_question_question_type_0"
    And I add choices "Game of Thrones, Suits, Prison Break, White Collar, Newsroom, Lost, Sherlock, Walking Dead, House MD, Doctor Who, Homeland, Fringe, Vampire Diaries"
    Then I check "profile_question_allow_other_option"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save" within "form#edit_profile_question_"

    Then I wait for ajax to complete
    And I configured question for "mentor" role in the program "primary" and set default visibility
    And I logout

    # Check functionality of quicksearch and see it doesn't search in other quick searches in same page
    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    And I follow "Edit Profile"
    And I click on the section with header "New Section"
    Then I should see "New Multi Choice Field 1"
    Then I should see "New Multi Choice Field 2"
    Then I quicksearch for "ga" in "New Multi Choice Field 2" question
    Then I wait for "2" seconds
    Then I should see "Game of Thrones" in "New Multi Choice Field 2" question
    And I should not see "Vampire" in "New Multi Choice Field 2" question
    And I should see "Tulu" in "New Multi Choice Field 1" question
    # check searching other field
    Then I quicksearch for "other" in "New Multi Choice Field 1" question

    And I fill in other option with "Dothraki" in "New Multi Choice Field 1" question
    Then I save the section "New Section"

    And I click on the section with header "New Section"

    And I quicksearch for "Dothraki" in "New Multi Choice Field 1" question

    Then I should see other option not hidden in "New Multi Choice Field 1" question

 @javascript @p2 @cross-browser
 Scenario: User edit the profile with manager type question
    Given the current program is "primary":"albers"
    Then I perform missed migrations
    And I have logged in as "mentor_2@example.com"
    And I follow "Edit Profile"
    Then I click ".fa-eye-slash" within ".profile_status_box"
    Then I follow "Hide for the session"
    Then I should not see "Complete your profile" within ".profile_status_box"
    And I click on the section with header "Work and Education"
    And I fill in manager_question of "primary":"albers" with "Dee,Princeton,manageredit@example.com"
    And I save the section "Work and Education"
    Then I should not see "Complete your profile"
    And I follow "Actions"
    Then I follow "View your Profile"
    And I should see "manageredit@example.com"
    Then I logout
    And I have logged in as "mentor_2@example.com"
    And I follow "Edit Profile"
    Then I should see "Complete your profile" within ".profile_status_box"
    Then I logout

@javascript @not_run_on_bs
Scenario: Student skip profile questions
  # Mark N/A and Undo cannot be performed quickly since remote browser
  Given the current program is "primary":"albers"
  Then I perform missed migrations
  And I have logged in as "rahim@example.com"
  And I follow "Edit Profile"
  Then I should see "rahim@example.com" score in the profile score box
  And I should see "Skype ID" within ".cjs_visible_answers"
  And I should see "Work" hidden
  And I "Mark N/A" "Skype ID" question
  And I should see "Skype ID" hidden
  And I should see "Work" not hidden
  Then I should see "rahim@example.com" score in the profile score box
  And I "Mark N/A" and "Undo" "Work" question
  And I should see "Work" within ".cjs_visible_answers"

@javascript @cross-browser
Scenario: Student hides progress bar
  Given the current program is "primary":"albers"
  Then I perform missed migrations
  And I have logged in as "rahim@example.com"
  # Hide for the session
  And I follow "Edit Profile"
  Then ".profile_status_box" should be visible
  And I follow "Actions"
  And I follow "View your Profile"
  Then ".profile_status_box" should be visible
  And I click ".fa-eye-slash"
  And I follow "Hide for the session"
  And I follow "Home"
  Then ".profile_status_box" should be visible
  And I should not see ".profile_status_box"

  And I follow "Edit Profile"
  And I should not see ".profile_status_box"
  And I follow "Actions"
  And I follow "View your Profile"
  And I should not see ".profile_status_box"
  And I follow "Home"
  And I should not see ".profile_status_box"
  And I logout
  # Hide forever
  And I have logged in as "rahim@example.com"
  And I follow "Edit Profile"
  Then ".profile_status_box" should be visible
  And I follow "Actions"
  And I follow "View your Profile"
  And I click ".fa-eye-slash"
  And I follow "Hide forever"
  Then ".profile_status_box" should be visible
  And I follow "Home"
  Then ".profile_status_box" should be visible
  And I should not see ".profile_status_box"
  And I logout
  And I have logged in as "rahim@example.com"
  And I follow "Edit Profile"
  And I should not see ".profile_status_box"
  And I follow "Actions"
  And I follow "View your Profile"
  And I should not see ".profile_status_box"
  And I follow "Home"
  And I should not see ".profile_status_box"

@javascript @cross-browser
Scenario: User views his profile activity
  Given the current program is "primary":"albers"
  Then I perform missed migrations
  And I have logged in as "robert@example.com"
  And I follow "View Profile"

  And I should see "Activity Overview" within "#program_role_info"
  And I should see "Ongoing mentoring connections" within "#program_role_info"
  And I should see "Past mentoring connections" within "#program_role_info"
  And I should see "Mentoring Connection availability slot" within "#program_role_info"
  And I should see "Average request response time" within "#program_role_info"
  And I should see "Pending mentor requests" within "#program_role_info"
  And I should not see "Profile completeness score" within "#program_role_info"

@javascript @cross-browser
Scenario: Admin seeing global dashboard
  Given the current program is "primary":""
  Then I perform missed migrations
  And I have logged in as "ram@example.com"
  Then I should see "6 Ongoing Mentoring Connections"