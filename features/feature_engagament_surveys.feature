@survey
Feature: Engagement and Draft Surveys

Background:
  Given the current program is "primary":"albers"
@javascript @cross_browser
Scenario: Admin creates a Engagement survey and a Program Survey and differentiates each other
  # Admin logs in.
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  # Engagement surveys are enabled only for v2
  Then I enable "mentoring_connections_v2" feature as a super user
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"

  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Surveys"
  And I follow "Meeting Feedback Survey"
  Then I should see "Meeting Feedback Survey"
  Then I follow "Manage" within "#title_actions"
  Then I should see "Edit"
  Then I should not see "Make a Copy"
  Then I should not see "Delete" 
  And I follow "Manage"
  And I follow "Surveys"
  And I follow "New Survey" within "#engagementsurvey"
  # On new survey page now
  Then I should see "New Survey"
  Then I fill in "survey_name" with "Engage Survey"
  Then "#survey_due_date" should not be visible
  And I press "Create"
  Then I follow "Manage" within "#title_actions"
  Then I should see "Add to Mentoring Connection Plan Template"
  Then I should not see "Expires"
  Then I should not see "Recepients"
  And I follow "Manage"
  And I follow "Surveys"
  And I follow "New Survey" within "#programsurvey"
  # On new survey page now
  Then I should see "New Survey"
  Then I fill in "survey_name" with "Program Survey"
  Then "#survey_due_date" should be visible
  And I check "survey_recipient_role_names_mentor"
  And I press "Create"
  Then I should see "Program Survey"
  Then I should see "Expires"
  Then I should see "Recipients"
  Then I should see "Share"
  Then I logout

@javascript @reindex @cross_browser
Scenario: Admin should be able to view responses rates box
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  # Engagement surveys are enabled only for v2
  Then I enable "mentoring_connections_v2" feature as a super user
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"

  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Surveys"
  And I follow "Meeting Feedback Survey"
  Then I should see "Meeting Feedback Survey For Mentors"
  And I follow "Trends"
  And I should see "0 Responses Received"
  And I should see "3 Pending Responses"
  And I should see "0.0% Response Rate"
  Then I click "i.cjs_collapse_icon_responses"
  Then I click "i.cjs_collapse_icon_responses"
  Then I should see "From 0 users in 0 meetings"
  Then I should see "From 1 users in 3 meetings"

  And I follow "report_date_range"
  And I select "Custom" from reports date range presets
  And I select "1" days and "3" days after "primary":"nomreqpro" program creation
  When I press "Go"
  Then I wait for ajax to complete
  Then I should see "0 Responses Received"
  And I should see "0 Pending Responses"
  And I should see "-- Response Rate"
  Then I follow "filter_report"
  And I select "Location" from "profile_question_1"
  Then I should not see "Add" within "#other_report_filters"
  And I select "Contains" from "profile_operator_1"
  Then I should see "#profile_choices_1" hidden
  Then I should see "Add" within "#other_report_filters"
  And I fill in "profile_value_1" with "New Delhi"
  # Adding new question
  And I follow "Add"
  And I select "Gender" from "profile_question_2"
  And I select "Not Filled" from "profile_operator_2"
  Then I should see "#profile_value_2" hidden
  Then I should see "#profile_choices_2" hidden
  And I press "Go"
  Then I wait for ajax to complete

@javascript
Scenario: Testing listing of different survey types
  Given I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Surveys"
  And I should see "Program Surveys"
  And I should see "Mentor Role User Experience Survey"
  And I should not see "Mentoring Connections Surveys"
  And I should not see "Meeting Surveys"
  Then I enable "mentoring_connections_v2" feature as a super user
  And I follow "Manage"
  And I follow "Surveys"
  And I should see "Mentoring Connections Surveys"
  And I should see "Mentoring Connection Activity Feedback"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I follow "Manage"
  And I follow "Surveys"
  And I should see "Meeting Surveys"
  And I should see "Meeting Feedback Survey"

@javascript
Scenario: Engagement shouldn't be shown if ongoing is disabled.
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I enable "mentoring_connections_v2" feature as a super user
  And I change engagement type of program "primary":"albers" to "career based and ongoing"
  And I follow "Manage"
  And I follow "Surveys"
  And I should see "Mentoring Connections Surveys"
  And I change engagement type of program "primary":"albers" to "career based"
  And I follow "Manage"
  And I follow "Surveys"
  And I should not see "Mentoring Connections Surveys"
  And I logout

@javascript
Scenario: Admin shouldn't be able to create an Engagement survey if ongoing is disabled.Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I enable "mentoring_connections_v2" feature as a super user
  And I change engagement type of program "primary":"albers" to "career based and ongoing"
  And I follow "Manage"
  And I follow "Surveys"
  And I should see "Mentoring Connections Surveys"
  And I follow "New Survey" within "#engagementsurvey"
  And I should see "Mentoring Connection Survey" within "#survey_type"
  And I change engagement type of program "primary":"albers" to "career based"
  And I follow "Manage"
  And I follow "Surveys"
  And I should not see "Mentoring Connections Surveys"
  And I follow "New Survey" within "#programsurvey"
  And I should not see "Mentoring Connection Survey" within "#survey_type"
  And I logout

@javascript @reindex @cross_browser
Scenario: Admin should be able to view responses index page and update columns
  #Then I reindex model "survey_answer"
  Given the current program is "primary":"nomreqpro"
  And I have logged in as "no_mreq_admin@example.com"
  And I enable "mentoring_connections_v2" feature as a super user
  And I update the response date of survey responses for program "primary":"nomreqpro"
  And I follow "Manage"
  And I follow "Surveys"
  And I should see "Progress Report"
  And I should see "2 new responses this week"
  And I follow "2 new responses this week"
  Then I clear table filter for "date"
  And I should not see "Location" within "div.k-grid-header"
  And I should not see "Total work experience" within "div.k-grid-header"
  And I should not see "Career path/Specializations" within "div.k-grid-header"
  And I should see "Edit Columns"
  And I should see "No Mentor Request Mentor" within "div.k-grid-content"
  And I should see "No Mentor Request Student" within "div.k-grid-content"
  Then I follow "Edit Columns"
  And I select all profile columns
  Then I should see "Date of response" within "div.k-grid-header"
  Then I should see "Mentoring Connection" within "div.k-grid-header"
  Then I should see "Name" within "div.k-grid-header"
  Then I scroll until I see "Location"
  Then I should see "Location" within "div.k-grid-header"
  Then I scroll until I see "Phone"
  Then I should see "Phone" within "div.k-grid-header"
  Then I follow "Edit Columns"
  And I remove all default columns
  Then I should not see "Date of response" within "div.k-grid-header"
  Then I should not see "Mentoring Connection" within "div.k-grid-header"
  Then I should not see "Name" within "div.k-grid-header"

@javascript @reindex @cross_browser
Scenario: Admin should be able to view responses rates box
  #Then I reindex model "survey_answer"
  Given the current program is "primary":"nomreqpro"
  And I have logged in as "no_mreq_admin@example.com"
  And I enable "mentoring_connections_v2" feature as a super user
  And I update the response date of survey responses for program "primary":"nomreqpro"
  And I follow "Manage"
  And I follow "Surveys"
  And I should see "Progress Report"
  And I should see "2 new responses this week"
  And I follow "2 new responses this week"
  And I follow "Trends"
  And I should see "2 Responses Received"
  And I should see "0 Overdue Responses"
  And I should see "100.0% Response Rate"
  And I should see "Note: There is a 0% margin of error"
  Then I click "i.cjs_collapse_icon_responses"
  Then I click "i.cjs_collapse_icon_responses"
  Then I should see "From 2 users in 1 mentoring connections"
  Then I should see "From 0 users in 0 mentoring connections"
  Then I hover over "users_connections_responses_received_text"
  Then I should see "To view these mentoring connections, visit the mentoring connections listing page and apply the survey status filter with status as Completed."
  Then I hover over "users_connections_overdue_responses_text"
  Then I should see "To view these mentoring connections, visit the mentoring connections listing page and apply the survey status filter with status as Overdue."

  And I follow "report_date_range"
  And I select "Custom" from reports date range presets
  And I select "1" days and "3" days after "primary":"nomreqpro" program creation
  When I press "Go"
  Then I wait for ajax to complete

  Then I follow "filter_report"
  Then I click "#s2id_role_choice > .select2-choices"
  And I click on select2 result "Mentor"
  And I press "Go"
  Then I should see "0 Responses Received"
  And I should see "0 Overdue Responses"
  And I should see "-- Response Rate"
  Then I follow "filter_report"
  Then I click "a.select2-search-choice-close"
  Then I click "#s2id_role_choice > .select2-choices"
  Then I click "#s2id_role_choice > .select2-choices > .select2-search-field"
  And I click on select2 result "Student"
  Then I click "a.select2-search-choice-close"
  And I select "Location" from "profile_question_1"
  Then I should not see "Add" within "#other_report_filters"
  And I select "Contains" from "profile_operator_1"
  Then I should see "#profile_choices_1" hidden
  Then I should see "Add" within "#other_report_filters"
  And I fill in "profile_value_1" with "New Delhi"
  # Adding new question
  And I follow "Add"
  And I select "Gender" from "profile_question_2"
  And I select "Not Filled" from "profile_operator_2"
  Then I should see "#profile_value_2" hidden
  Then I should see "#profile_choices_2" hidden
  And I press "Go"
  Then I wait for ajax to complete

@javascript @cross_browser
Scenario: Admin should be able to apply filters and sorting
  #Then I reindex model "survey_answer"
  #Then I reindex model "user"
  Given the current program is "primary":"nomreqpro"
  And I have logged in as "no_mreq_admin@example.com"
  And I enable "mentoring_connections_v2" feature as a super user
  And I update the response date of survey responses for program "primary":"nomreqpro"
  And I follow "Manage"
  And I follow "Surveys"
  And I should see "Progress Report"
  And I should see "2 new responses this week"
  And I follow "2 new responses this week"
  Then I clear table filter for "date"
  Then I set the focus to the main window
  And I should see "No Mentor Request Mentor" within "div.k-grid-content"
  And I should see "No Mentor Request Student" within "div.k-grid-content"
  And I should see "Smallville" within "div.k-grid-content"
  And I should see "Earth" within "div.k-grid-content"
  Then I filter table by "name" with "student"
  And I should not see "No Mentor Request Mentor" within "div.k-grid-content"
  Then I clear table filter for "name"
  And I should see "No Mentor Request Mentor" within "div.k-grid-content"
  And I should see "remove mentor" within "div.k-grid-content"
  And I should see "remove mentee" within "div.k-grid-content"
  And I should see "No Mentor Request Mentor" within "div.k-grid-content"
  And I should see "No Mentor Request Student" within "div.k-grid-content"
  And I should see "Smallville" within "div.k-grid-content"
  And I should see "Earth" within "div.k-grid-content"
  Then I filter table by "name" with "student"
  And I should not see "No Mentor Request Mentor" within "div.k-grid-content"
  Then I clear table filter for "name"
  And I should see "No Mentor Request Mentor" within "div.k-grid-content"
  And I should see "remove mentor" within "div.k-grid-content"
  And I should see "remove mentee" within "div.k-grid-content"
  Then I apply filter on first question of survey with name "Progress Report" in program "primary":"nomreqpro" with value "mentee"
  And I should not see "No Mentor Request Mentor" within "div.k-grid-content"
  And I should not see "remove mentor" within "div.k-grid-content"
  And I should see "remove mentee" within "div.k-grid-content"
  Then I clear filter on first question of survey with name "Progress Report" in program "primary":"nomreqpro"
  Then I sort table by "name"
  Then I should see "No Mentor Request Student" within "div.k-grid-content .k-alt"
  Then I should not see "No Mentor Request Mentor" within "div.k-grid-content .k-alt"
  Then I sort table by "name"
  Then I should see "No Mentor Request Mentor" within "div.k-grid-content .k-alt"
  Then I should not see "No Mentor Request Student" within "div.k-grid-content .k-alt"
  Then I sort table on first question of survey with name "Progress Report" in program "primary":"nomreqpro"
  Then I should see "remove mentor" within "div.k-grid-content .k-alt"
  Then I should not see "remove mentee" within "div.k-grid-content .k-alt"
  Then I sort table on first question of survey with name "Progress Report" in program "primary":"nomreqpro"
  Then I should see "remove mentee" within "div.k-grid-content .k-alt"
  Then I should not see "remove mentor" within "div.k-grid-content .k-alt"
  Then I scroll until I see "Where are you from?"
  Then I apply filter on "Where are you from?" with "Earth" for survey with name "Progress Report" in program "primary":"nomreqpro"
  Then I should not see "Smallville" within ".k-grid-content"

@javascript @reindex @cross_browser
Scenario: Admin should be able to visit response show page
  #Then I reindex model "survey_answer"
  Given the current program is "primary":"nomreqpro"
  And I have logged in as "no_mreq_admin@example.com"
  And I enable "mentoring_connections_v2" feature as a super user
  And I update the response date of survey responses for program "primary":"nomreqpro"
  And I follow "Manage"
  And I follow "Surveys"
  And I should see "Progress Report"
  And I should see "2 new responses this week"
  And I follow "2 new responses this week"
  Then I clear table filter for "date"
  Then I should see "Edit Columns"
  Then I hover over class "cjs_sr_header" with text "What is your name?" and should see tooltip
  Then I sort table by "name"
  Then I should see "No Mentor Request Student"
  Then I should see "No Mentor Request Mentor"
  Then I open the first individual survey
  Then I should see "No Mentor Request Student"
  Then I should see "Email this report"
  Then I should not see "Edit Columns"
  Then I should see "Submitted On"
  Then I should see "Mentoring Connection: No mentor request group"
  Then I should see "What is your name"
  Then I should see "remove mentee"
  Then I should see "Where are you from?"
  Then I should see "Earth"
  Then I follow the back link
  Then I should not see "Email this report"
  Then I should not see "Back to Individual Responses"
  Then I should see "No Mentor Request Mentor"
  Then I should see "Edit Columns"
  Then I open the first individual survey
  Then I should see "Email this report"
  Then I should see "Export to xls"
  Then follow "Email this report"
  Then I should see "Subject"
  Then I fill in "member_recipient" with "student example <rahim@example.com>"
  Then I press "Add"
  Then I fill in "member_recipient" with "rahim1@example.com"
  Then I press "Add"
  Then I press "Send"
  Then mails should go to "rahim1@example.com" and "rahim@example.com" having "I'd like to share the results "
  Then mail should have "excel" attachment with name "progress_report.xls"
  And first attachment should have content "Where are you from"
  And first attachment should have content "What is your name"
  Then I logout

@javascript @cross_browser
Scenario: Student saves survey response as a draft And Admin views then shares the report
  # Admin adds a few questions.
  Given I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Surveys"
  And I follow "How helpful is this program"
  And I follow "Add New Question"
  Then I fill in "survey_question_question_text_new" with "What is your name?"
  And I select "Single line" from "common_question_type_new"
  Then I fill in "survey_question[help_text]" with "Just mention your name dear"
  Then I set the focus to the main window
  And I check "Mandatory"
  Then I press "Add"
  And I follow "Add New Question"
  Then I fill in "survey_question_question_text_new" with "What is your Address?"
  And I select "Multi line" from "common_question_type_new"
  Then I press "Add"
  And I follow "Add New Question"
  Then I fill in "survey_question_question_text_new" with "Your hobbies?"
  And I select "Multiple entries" from "common_question_type_new"
  Then I press "Add"
  And I follow "Add New Question"
  Then I fill in "survey_question_question_text_new" with "What kind of movies you like?"
  And I select "Pick one answer" from "common_question_type_new"
  Then I add choices "English,Hindi,Tamil" for survey question
  Then I check "survey_question[allow_other_option]"
  Then I press "Add"
  And I follow "Add New Question"
  Then I fill in "survey_question_question_text_new" with "Your Favourite passtime?"
  And I select "Pick multiple answers" from "common_question_type_new"
  Then I add choices "Movies,Books,Cricket" for survey question
  Then I press "Add"
  And I follow "Add New Question"
  Then I fill in "survey_question_question_text_new" with "Rate yourself"
  And I select "Rating Scale" from "common_question_type_new"
  And I add choices "1,2,3,4,5" for survey question
  Then I press "Add"
  Then I logout

  # Student logs in and answers.
  When I have logged in as "robert@example.com"
  And I participate in the survey
  And I fill the answers "'', '', '', '', 'Hyderabad', ''"
  Then I follow "Save as draft"
  Then I should see "Home"
  And I should see "Your draft for the survey 'How helpful is this program' has been saved successfully."
  And I should see "Complete Surveys"
  Then I should see "How helpful is this program"
  Then I follow "Complete Survey"
  Then I should see the answer "Hyderabad" for the question "What is your Address?"
  Then I press "Submit"
  Then I should see "Please fill all the required fields. Fields marked * are required"
  And I fill the answers "'5', 'Books', 'English','Reading', 'Hyderabad', 'Robert'"
  Then I press "Submit"
  Then I should see "Thanks for completing How helpful is this program"
  And I should not see "Complete Surveys"
  Then I logout

@javascript @reindex @cross_browser
Scenario: Admin should be able to visit response show page
  #Then I reindex model "survey_answer"
  Given the current program is "primary":"nomreqpro"
  And I have logged in as "no_mreq_admin@example.com"
  And I enable "mentoring_connections_v2" feature as a super user
  And I update the response date of survey responses for program "primary":"nomreqpro"
  And I follow "Manage"
  And I follow "Surveys"
  And I should see "Progress Report"
  And I should see "2 new responses this week"
  And I follow "2 new responses this week"
  Then I check "cjs_select_all_primary_checkbox"
  Then I follow "Actions"
  Then I should see "Email report"
  Then I follow "Email report"
  Then I should see "Subject"
  Then I fill in "member_recipient" with "student example <rahim@example.com>"
  Then I press "Add"
  Then I fill in "member_recipient" with "rahim1@example.com"
  Then I press "Add"
  Then I press "Send"
  Then mails should go to "rahim1@example.com" and "rahim@example.com" having "I'd like to share the results "
  Then mail should have "excel" attachment with name "progress_report.xls"
  And first attachment should have content "Where are you from"
  And first attachment should have content "Smallville"
  And first attachment should have content "Earth"
  Then I logout

  @javascript @cross-browser
  Scenario: Admin creates new engagement survey with progress reports enabled
    # Admin logs in.
    When I have logged in as "ram@example.com"
    When I hover over "my_programs_container"
    And I select "Primary Organization" from the program selector
    # Engagement surveys are enabled only for v2
    Then I enable "mentoring_connections_v2" feature as a super user
    Then I enable "share_progress_reports" feature as a super user

    Given the current program is "primary":"albers"
    And I follow "Manage"
    And I follow "Surveys"
    And I follow "New Survey" within "#engagementsurvey"
    # On new survey page now
    Then I should see "New Survey"

    When I fill in "survey_name" with "New Progres Reports"
    Then I follow "Advanced Options"
    And I check "survey_progress_report"
    And the "survey_progress_report" checkbox_id should be checked
    Then I should see "Allow respondent to share the response with other mentoring connection members"
    And I press "Create"

    And I click "#title_actions .btn-group .btn"
    And I click ".cui_edit_survey"
    Then I should see "Edit Survey"
    Then I should see "Allow respondent to share the response with other mentoring connection members"
    And the "survey_progress_report" checkbox_id should be checked
    And I press "Save"

  @javascript @reindex
    Scenario: Member share progress reports survey in engagement area
    When I have logged in as "ram@example.com"
    And I select "Primary Organization" from the program selector
    Then I enable "mentoring_connections_v2" feature as a super user
    Then I enable "share_progress_reports" feature as a super user
    Given the current program is "primary":"albers"
    And I follow "Manage"
    And I follow "Surveys"
    And I follow "Mentoring Relationship Health"
    And I click "#title_actions .btn-group .btn"
    And I click ".cui_edit_survey"
    Then I should see "Edit Survey"
    Then I should see "Allow respondent to share the response with other mentoring connection members"
    And I check "survey_progress_report"
    And the "survey_progress_report" checkbox_id should be checked
    And I press "Save"
    And I create overdue survey task
    Then I logout
    And I have logged in as "robert@example.com"
    And I follow "name & madankumarrajan" subtab inside opened navigation header
    Then I should see "task title - Mentoring Relationship Health"
    Then I should see "The Mentoring Relationship Health is overdue. Please fill in the survey below."
    Then I press "Submit"
    Then I should see "task title - Mentoring Relationship Health"
    Then I should see "Please fill all the required fields. Fields marked * are required"
    Then I follow "Cancel"
    And I follow "Students"
    And I follow "name & madankumarrajan" subtab inside opened navigation header
    Then I should not see "task title - Mentoring Relationship Health"
    Then I should not see "The Mentoring Relationship Health is overdue. Please fill in the survey below."
    Then I logout
    And I have logged in as "robert@example.com"
    And I follow "name & madankumarrajan" subtab inside opened navigation header
    Then I should see "task title - Mentoring Relationship Health"
    Then I should see "The Mentoring Relationship Health is overdue. Please fill in the survey below."
    And I fill the answers "'Good', 'Yes', 'Good', '', ''" of "Mentoring Relationship Health"
    Then I should see "Send a copy of my response to others in the mentoring connection"
    And the "share_progress_report" checkbox_id should be checked
    Then I follow "Save as draft"
    Then I should see "Your draft for the survey 'Mentoring Relationship Health' has been saved successfully. Please note that the response is not shared yet"
    Then I logout
    And I have logged in as "robert@example.com"
    And I stubs s3 and pdf for progress reports
    And I follow "name & madankumarrajan" subtab inside opened navigation header
    Then I should see "task title - Mentoring Relationship Health"
    Then I should see "The Mentoring Relationship Health is overdue. Please fill in the survey below."
    Then I should see "Send a copy of my response to others in the mentoring connection"
    And the "share_progress_report" checkbox_id should be checked
    Then I press "Submit"
    Then I should see "Thanks for completing Mentoring Relationship Health"
