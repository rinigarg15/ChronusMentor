@survey
Feature: Survey setup, user participation, etc.,
  In order to perform the above steps
  As an admin
  I want to login and enter the appropriate as required

Background:
  Given the current program is "primary":"albers"

@javascript @download
Scenario: Admin downloads the survey results as csv
  Given the current program is "primary":"nomreqpro"
  And I enable "mentoring_connections_v2" feature as a super user
  And I clear the downloads folder
  And I have logged in as "no_mreq_admin@example.com"
  And I update the response date of survey responses for program "primary":"nomreqpro"
  And I follow "Manage"
  And I follow "Surveys"
  And I should see "Progress Report"
  And I should see "2 new responses this week"
  And I follow "2 new responses this week"
  Then I check "cjs_select_all_primary_checkbox"
  Then I follow "Actions"
  And I follow "Export to xls"
  Then I wait for download to complete
  Then the download folder must have "progress_report.xls"

@javascript @cross-browser
Scenario: Admin creates new program survey v2
  # Admin logs in.
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  # Engagement surveys are enabled only for v2
  Then I enable "mentoring_connections_v2" feature as a super user

  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Surveys"
  Then I should not see "Clone"
  And I follow "New Survey" within "#engagementsurvey"
  # On new survey page now
  Then I should see "New Survey"

  # Error while creating survey
  When I fill in "survey_name" with ""
  And I press "Create"
  Then I should see "Please fill all the required fields. Fields marked * are required"

  #Creating survey with Imported Questions CSV
  When I fill in "survey_name" with "About Chronus CSV Import"
  Then "#survey_due_date" should not be visible
  Then "#show_additional_option" should be visible
  Then I follow "Advanced Options"
  Then "import_questions_csv" should be visible
  And I set the attachment field "survey_questions_file" to "pic_2.png"
  Then I press "Create"
  Then I should see "Please upload a valid CSV file."
  Then I follow "Advanced Options"
  Then "import_questions_csv" should be visible
  And I set the attachment field "survey_questions_file" to "/solution_pack_import/survey_question_matrix_question.csv"
  And I press "Create"
  Then I should see "The survey has been successfully created."
  And I should see "About Chronus CSV Import"
  Then I follow "Responses (0)"
  Then I should see "There are no responses to display."
  Then I follow "Trends"
  Then I should see "No responses yet for the survey"
  Then I follow "Questions (1)"
  Then I should see "Add New Question"

  # Try again
  And I follow "Manage"
  And I follow "Surveys"
  Then I should not see "Clone"
  And I follow "New Survey" within "#engagementsurvey"

  # On new survey page now
  Then I should see "New Survey"
  When I fill in "survey_name" with "About Chronus"
  Then "#survey_due_date" should not be visible
  When I select "Program Survey" from "survey_type"
  Then "#survey_due_date" should be visible
  Then I select "Mentoring Connection Survey" from "survey_type"
  And I press "Create"
  Then I should see "The survey has been successfully created. Now you can add questions to it."
  And I should see "About Chronus"
  Then I follow "Responses (0)"
  Then I should see "There are no responses to display."
  Then I follow "Trends"
  Then I should see "This survey does not have any questions yet. Please add questions to the survey."
  Then I should see "Add to Mentoring Connection Plan Template"
  Then I should not see "Export to xls"
  Then I follow "Questions (0)"
  Then I should see "Add New Question"

  # Go to listing page
  When I follow "Manage"
  And I follow "Surveys"
  Then I should see "About Chronus"
  And I should see "0 responses"

@javascript
Scenario: Admin creates new program survey v1
  # Admin logs in.
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I disable the feature "mentoring_connections_v2" as a super user
  #And I logout as super user

  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Surveys"
  Then I should not see "Clone"
  And I follow "New Survey" within "#programsurvey"

  # On new survey page now
  Then I should see "New Survey"
  # Error while creating survey
  When I fill in "survey_name" with ""
  And I press "Create"
  Then I should see "Please fill all the required fields. Fields marked * are required"

  # Try again
  When I fill in "survey_name" with "About Chronus"
  Then I check "Mentor"
  And I press "Create"
  Then I should see "The survey has been successfully created. Now you can add questions to it."
  And I should see "About Chronus"
  Then I follow "Responses (0)"
  Then I follow "Questions (0)"
  Then I should see "Add New Question"

  # Go to listing page
  When I follow "Manage"
  And I follow "Surveys"
  Then I should see "About Chronus"
  And I should see "0 responses"

@javascript @cross-browser
Scenario: Admin creates a new engagement survey
  # Admin logs in.
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user

  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Surveys"
  And I follow "New Survey" within "#engagementsurvey"
  # On new survey page now
  Then I should see "New Survey"

  # Try again
  When I fill in "survey_name" with "Engagement Chronus"
  Then "#survey_due_date" should not be visible
  And I press "Create"
  Then I should see "The survey has been successfully created. Now you can add questions to it."
  And I should see "Engagement Chronus"
  Then I follow "Responses (0)"
  Then I follow "Questions (0)"
  Then I should see "Add New Question"

  # Go to listing page
  When I follow "Manage"
  And I follow "Surveys"
  Then I should see "Engagement Chronus"
  And I should see "0 responses"

@javascript @cross-browser
Scenario: Student participates in survey
  # Admin adds a few questions.
  Given I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Surveys"
  And I follow "How helpful is this program"
  And I follow "Add New Question"
  
  Then I fill in "survey_question_question_text_new" with "What is your name?"
  And I select "Single line" from "common_question_type_new"
  Then I fill in "survey_question[help_text]" with "Just mention your name dear"
  Then I press "Add"
  
  And I follow "Add New Question"
  
  Then I fill in "survey_question_question_text_new" with "What is your location?"
  And I select "Single line" from "common_question_type_new"

  #Changing to Multiline Should not show warning for new question
  And I select "Multi line" from "common_question_type_new"
  Then I should not see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"

  #Changing to Multiple entries Should not show warning for new question
  And I select "Multiple entries" from "common_question_type_new"
  Then I should not see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"

  #Changing to Pick one answer Should not show warning for new question
  And I select "Pick one answer" from "common_question_type_new"
  Then I should not see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"

  #Changing to Rating Scale Should not show warning for new question
  And I select "Rating Scale" from "common_question_type_new"
  Then I should not see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"

  #Changing to Matrix Rating Scale Should not show warning for new question
  And I select "Matrix Rating Scale" from "common_question_type_new"
  Then I should not see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"

  #Changing to Pick multiple answers Should not show warning for new question
  And I select "Pick multiple answers" from "common_question_type_new"
  Then I should not see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"

  And I select "Single line" from "common_question_type_new"

 
  And I check "survey_question[required]"
  Then I press "Add"
  

  And I follow "Add New Question"
  
  Then I fill in "survey_question_question_text_new" with "Rate your skills?"
 
  And I select "Rating Scale" from "common_question_type_new"
  Then I add choices "Good,Better,Best" for survey question
  Then I press "Add"

  And I follow "Add New Question"

  Then I fill in "survey_question_question_text_new" with "Matrix Rating various skills?"

  And I select "Matrix Rating Scale" from "common_question_type_new"
  Then I add choices "Good,Better" for survey question 
  Then I press "Add"
  Then I should see "Rows can't be blank for matrix rating scale questions" 
  Then I delete choices "Good Better" for survey question
  Then I add rows "Skill,Communication,Ability" for matrix question
  Then I press "Add"
  Then I should see "Choices can't be blank for choice based questions" 
  Then I check "survey_question[matrix_setting]"
  Then I check "survey_question[required]"
  Then I add choices "Good,Better" for survey question
  Then I press "Add"
  Then I should see "To enable forced ranking, please make sure to have a greater number of choices than rows."
  Then I add choice "Best" for survey question next to "Better"
  Then I press "Add"

  And I edit the question with title "Matrix Rating various skills?"
  Then I delete rows "Ability" for matrix question "Matrix Rating various skills?" in "Albers Mentor Program"
  And I press "Save"
  Then I should see "Modifying/removing row(s) will result losing user responses for that particular row(s). Modifying/removing choice(s) will result losing user responses if any user has selected the modified/removed column(s).Do you still want to proceed?"
  Then I press "Yes"

  And I edit the question with title "Matrix Rating various skills?"
  Then I add row "Ability" for matrix question "Matrix Rating various skills?" in "Albers Mentor Program" next to "Communication"
  And I press "Save"
  Then I should not see "Modifying/removing row(s) will result losing user responses for that particular row(s). Modifying/removing choice(s) will result losing user responses if any user has selected the modified/removed column(s).Do you still want to proceed?"

  And I edit the question with title "Rate your skills?"
  Then I delete choices "Best" for survey question "Rate your skills?" in "Albers Mentor Program"
  And I press "Save"
  Then I should see "Modifying/removing choice(s) will result losing user responses if any user has selected the modified/removed column(s).Do you still want to proceed?"
  Then I press "No"
  Then I press "Save"
  Then I should see "Modifying/removing choice(s) will result losing user responses if any user has selected the modified/removed column(s).Do you still want to proceed?"
  Then I press "Yes"
  And I edit the question with title "Rate your skills?"
  Then I add choice "Best" for survey question "Rate your skills?" in "Albers Mentor Program" next to "Better"
  Then I press "Save"
  Then I should not see "Modifying/removing choice(s) will result loosing user responses if any user has select the modified/removed column(s).Do you still want to proceed?"

  And I logout

  # Admin changes question type before there are any answers
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Surveys"
  Then I should see "0 responses"
  When I visit survey config page
  Then I should see "Responses (0)"

  #Changing to Multiline Should not show warning
  And I edit the question with title "What is your location?"
  And I select "Multi line" option for question with title "What is your location?"
  Then I should not see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"

  #Changing to Multiple entries Should not show warning
  And I select "Multiple entries" option for question with title "What is your location?"
  Then I should not see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"

  #Changing to Pick one answer Should not show warning
  And I select "Pick one answer" option for question with title "What is your location?"
  Then I should not see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"
  

  #Changing to Pick multiple answers Should not show warning
  And I select "Pick multiple answers" option for question with title "What is your location?"
  Then I should not see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"
  
  #Changing to Rating Scale Should not show warning
  And I select "Rating Scale" option for question with title "What is your location?"
  Then I should not see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"

  #Changing to Matrix Rating Scale Should not show warning for new question
  And I select "Matrix Rating Scale" option for question with title "What is your location?"
  Then I should not see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"

  Then I logout

  # Student logs in and answers.
  When I have logged in as "robert@example.com"
  When I participate in the survey
  # Question#2 is required, so leaving it blank is an error.
  And I submit the answers "'Best' 'Better' 'Good' , 'Best', '', 'India'"
  Then I should see "Please fill all the required fields. Fields marked * are required"
  # Student should see the help text
  Then I should see "Just mention your name dear"
  And I submit the answers "'Best' 'Better','Good', 'is', 'India'"
  Then I should see "Please fill all the required fields. Fields marked * are required"
  # Fill properly now.
  And I submit the answers "'Best' 'Better' 'Good','Good', 'is', 'India'"
  Then I should see "All Activity"
  Then I should see "Thanks for completing How helpful is this program"
  Then I logout

  # Mentor answers
  When I have logged in as "rahim@example.com"
  And I submit the answers "'Best' 'Better' 'Good','Good', 'Appli', ''"

  Then I should see "All Activity"
  Then I should see "Thanks for completing How helpful is this program"
  Then I logout

  # Admin comes and checks the results
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Surveys"
  Then I should see "2 responses"
  When I visit survey config page
  Then I should see "Responses (2)"

  #Changing to Multiline Should not show warning
  And I edit the question with title "What is your location?"
  And I select "Multi line" option for question with title "What is your location?"
  Then I should not see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"

  #Changing to Multiple entries Should not show warning
  And I select "Multiple entries" option for question with title "What is your location?"
  Then I should not see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"

  #Changing to Pick one answer Should show warning
  And I select "Pick one answer" option for question with title "What is your location?"
  Then I should see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"
  Then I cancel popup

  #Changing to Pick multiple answers Should show warning
  And I select "Pick multiple answers" option for question with title "What is your location?"
  Then I should see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"
  Then I confirm popup

  #Changing to Rating Scale Should show warning
  # To be fixed JIRA - AP-12083
  #And I select "Rating Scale" option for question with title "What is your location?"
  #Then I should see "Changing the question type might result in loss of user responses for this question. Do you want to proceed?" within "body"
  # Updates survey name
  And I click "#title_actions .btn-group .btn"
  And I click ".cui_edit_survey"
  Then I should see "Edit Survey"
  And I fill in "survey_name" with "My new name" within "#edit"
  And I fill in "survey_due_date" with a date "March 15, 2035"
  And I check "survey_recipient_role_names_user"
  And I click ".modal_edit_survey .btn.btn-primary"
  And I should see "My new name"
  And I should see "March 15, 2035"
  And I should see "Mentor, Student and User"
  Then I logout
  #TODO-CR: Test engagement survey editing - no option for due date editing

  # Student updates his answers
  When I have logged in as "robert@example.com"
  And I submit the answers "'Best' 'Better' 'Good','Best', 'is the', 'India'"
  Then I should see "Thanks for completing My new name"
  Then I logout

  # Admin should still see 3 responses. ProgramSurvey accepts multiple responses
  When I have logged in as "ram@example.com"
  When I visit survey config page
  Then I should see "Responses (3)"
  And I logout

@javascript
Scenario: See responses of Survey Question
  When I have logged in as "ram@example.com"
  And I add questions to survey
  And members have participated in the survey
  When I visit survey config page
  Then I follow "Questions (3)"
  Then I follow "Trends"
  And I should see "Hello\" 10 times
  Then I should see "See All 23 Responses"
  And I follow "See All 23 Responses"
  And I should see "What is your name?"
  And I should see "All 23 Responses"
  And I should see "Hello\" within "#all_responses"
  And I should see "Hello\" 32 times
  And I should not see "Good unique name"
  And I should not see "Mentor Studenter"
  And I should not see "mentor_a chronus"
  And I should not see "Non requestable mentor"
  And I click ".modal-header .close"
  And I follow "Responses (23)"
  And I should see "Hello\" 10 times
  Then I check "cjs_select_all_primary_checkbox"
  Then I follow "Actions"
  And I follow "Export to xls"
  Then I wait for download to complete
  Then the download folder must have "progress_report.xls"

@javascript @p2
Scenario: Student participates in survey with other forced ranking enabled for matrix rating survey questions
  # Admin adds a few questions.
  Given I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Surveys"
  And I follow "How helpful is this program"

  And I follow "Add New Question"

  Then I fill in "survey_question_question_text_new" with "Matrix Rating various skills Two?"
  And I select "Matrix Rating Scale" from "common_question_type_new"
  Then I add rows "Skill,Communication,Ability" for matrix question
  Then I check "survey_question[matrix_setting]"
  Then I add choices "Good,Better" for survey question
  Then I press "Add"
  Then I should see "To enable forced ranking, please make sure to have a greater number of choices than rows."
  Then I add choice "Best" for survey question next to "Better"
  Then I press "Add"

  And I logout

  # Student logs in and answers.
  When I have logged in as "robert@example.com"
  When I participate in the survey
  Then I logout

@javascript @reindex
Scenario: Forced ranking matrix question should work fine when survey opened from provide feedback option
  Given the current program is "primary":"albers"
  And I add matrix forced ranking question to survey
  And I have logged in as "ram@example.com"
  Then I enable "mentoring_connections_v2" feature as a super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Mentoring Connection Settings"
  And I select "Mentoring Relationship Health" from "program_feedback_survey_id"
  And I press "Save"
  And I logout
  And I have logged in as "robert@example.com"
  Then I should see "name & madankumarrajan"
  And I follow "name & madankumarrajan"
  Then I follow "Provide Feedback"
  Then I answer matrix question with "Bad" of "1"
  Then I answer matrix question with "Bad" of "2"
  Then I should see matrix answer with "Bad" of "2"
  Then I should not see matrix answer with "Bad" of "1"
  Then I should not see matrix answer with "Bad" of "3"
  Then I answer matrix question with "Average" of "1"
  Then I answer matrix question with "Good" of "3"
  And I fill the answers "'Good', 'Yes', 'Good', '', ''" of "Mentoring Relationship Health"
  Then I press "Submit"
  Then I should see "Thank you for your feedback"

@javascript @p2
Scenario: Student participates in survey with other option enabled for survey questions
  # Admin adds a few questions.
  Given I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Surveys"
  And I follow "How helpful is this program"

  And I follow "Add New Question"
 
  Then I fill in "survey_question_question_text_new" with "Pick your favourite"
  And I select "Pick one answer" from "common_question_type_new"
  Then I add choices "chrome,firefox,safari" for survey question
  Then I check "survey_question[allow_other_option]"
  Then I press "Add"
  And I logout

  # Student logs in and answers.
  When I have logged in as "robert@example.com"
  And I participate in the survey
  And I fill in other field with "opera"
  And I press "Submit"
  Then I should see "Thanks for completing How helpful is this program"

  When I participate in the survey
  Then I should see "Other..."
  And I should see "opera" as the other answer
  And I logout

  #Now edit the survey
  Given the current program is "primary":"albers"
  Given I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Surveys"
  And I follow "How helpful is this program"
  And I edit the question with title "Pick your favourite"
  Then I fill in "Field Name" with "Write a few lines about your favorite browser"
  And I select "Single line" from "survey_question[question_type]"
  Then I press "Save"
  And I logout

  #Login as same user who completed the survey
  When I have logged in as "robert@example.com"
  And I participate in the survey
  Then I should see "Write a few lines about your favorite browser"
  And I should not see "Pick your favourite"
  Then I fill in "Write a few lines about your favorite browser" with "Chrome is the best!"
  And I press "Submit"
  And I logout

  #Check Responses now
  Given the current program is "primary":"albers"
  Given I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Surveys"
  And I follow "How helpful is this program"
  Then I follow "Trends"
  Then I wait for animation to complete
  Then I should see "opera"
  And I should see "Chrome is the best!"
  Then I logout

  #Deleting a Survey When Outcome report is set
  Given the current program is "primary":"albers"
  Given I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user
  Then I enable "program_outcomes_report" feature as a super user

  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Surveys"
  And I update "Where do you live?" postive outcome options
  And I follow "Introduce yourself"
  When I delete the question with title "Where do you live?"
  Then I should see "Removing this question will remove it from the reported positive outcomes section in the Program outcomes report. Do you want to still remove this question and historical tracking of Program Outcomes Report based on it?"
  And I cancel popup
  When I click "#title_actions .btn-group .btn"
  And I click ".cui_delete_survey"
  Then I should see "Before deleting, please ensure that the survey 'Introduce yourself' is not an active survey and is not accessible to users through e-mails, facilitation messages or announcements. Any responses to the survey will be deleted. Also, deleting this will affect the Program Outcomes Report. Do you want to proceed?"
  And I cancel popup
  Then I logout

  #Deleting a Survey
  Given the current program is "primary":"albers"
  Given I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I disable the feature "program_outcomes_report" as a super user

  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Surveys"
  And I follow "How helpful is this program"
  When I follow "Questions (1)"
  And I click "#title_actions .btn-group .btn"
  And I click ".cui_delete_survey"
  Then I should see "Before deleting, please ensure that the survey 'How helpful is this program' is not an active survey and is not accessible to users through e-mails, facilitation messages or announcements. Any responses to the survey will be deleted. Do you want to proceed?"
  Then I click ".cancel"
  And I follow "Manage"
  And I follow "Surveys"
  And I follow "How helpful is this program"
  And I click "#title_actions .btn-group .btn"
  And I click ".cui_delete_survey"
  Then I should see "Before deleting, please ensure that the survey 'How helpful is this program' is not an active survey and is not accessible to users through e-mails, facilitation messages or announcements. Any responses to the survey will be deleted. Do you want to proceed?"
  Then I confirm popup
  Then I should see "The survey has been deleted"
  Then I logout

@javascript @cross-browser
Scenario:Deleting a Question in the Survey
  Given I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Surveys"
  And I follow "Mentor Role User Experience Survey"
  And I delete the question with title "How long have you been a member of this mentoring program?"
  Then I click on the "icon-trash" icon
  Then I should see "Are you sure you want to delete this question? All user responses for this question, if any, will be lost."
  Then I confirm popup
 
  Then I should not see "How long have you been a member of this mentoring program?"

@javascript
Scenario: Publish a Survey via Announcements
  Given I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Surveys"
  And I follow "Mentee Role User Experience Survey"
  And I follow "Share"
  Then I should see "Share link via announcement"
  And I follow "Create an announcement"
  Then I should see "New Announcement"
  Then I fill in "Title" with "Announcement"
  And I select "Immediately" from "announcement_email_notification"
  And I press "Post"
  Then I should see "The announcement has been published."

@javascript 
Scenario: Clone an Engagement survey
  # Admin logs in.
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  # Engagement surveys are enabled only for v2
  Then I enable "mentoring_connections_v2" feature as a super user

  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Surveys"
  And I follow "New Survey" within "#engagementsurvey"
  # On new survey page now
  Then I should see "New Survey"
  Then I fill in "survey_name" with "Engage Survey"
  Then "#survey_due_date" should not be visible
  And I press "Create"
  Then I should see "The survey has been successfully created. Now you can add questions to it."
  And I close the flash
  Then I follow "Manage" within "#title_actions"
  Then I should see "Add to Mentoring Connection Plan Template"
  Then I should not see "Expires"
  Then I should not see "Recepients"
  And I follow "Make a Copy"
  And I should see "Name the clone survey" within "div#modal_clone_survey_name_popup_form"
  And I press "Create"
  Then I should see "Survey has been cloned successfully."
  And I close the flash
  Then I should see "Copy of Engage Survey"
  Then I follow "Manage" within "#title_actions"
  Then I should see "Add to Mentoring Connection Plan Template"
  Then I should not see "Expires"
  Then I should not see "Recepients"
  Then I logout

@javascript @cross-browser
Scenario: Clone an Program survey
  # Admin logs in.
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  # Engagement surveys are enabled only for v2
  Then I enable "mentoring_connections_v2" feature as a super user

  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Surveys"
  And I follow "New Survey"
  # On new survey page now
  Then I should see "New Survey"
  Then I fill in "survey_name" with "Program Survey"
  When I select "Program Survey" from "survey_type"
  Then "#survey_due_date" should be visible
  And I check "survey_recipient_role_names_mentor"
  And I press "Create"
  Then I should see "Program Survey"
  Then I should see "Expires"
  Then I should see "Recipients"
  And I click "#title_actions .btn-group .btn"
  And I follow "Make a Copy"
  And I should see "Name the clone survey" within "div#modal_clone_survey_name_popup_form"
  And I press "Create"
  Then I should see "Survey has been cloned successfully."
  And I close the flash
  Then I should see "Copy of Program Survey"
  Then I should see "Expires"
  Then I should see "Recipients"
  Then I follow "Manage" within "#title_actions"
  Then I should see "Make a Copy"
  Then I logout


@javascript @reindex @cross-browser
Scenario: Apply date range filter on survey report
  Given the current program is "primary":"nomreqpro"
  And I have logged in as "no_mreq_admin@example.com"
  And I enable "mentoring_connections_v2" feature as a super user
  And I follow "Manage"
  And I follow "Surveys"
  Then I follow "Progress Report"
  Then I follow "Trends"
  And I follow "report_date_range"
  And I select "Custom" from reports date range presets
  And I select "1" days and "3" days after "primary":"nomreqpro" program creation
  When I press "Go"
  Then I wait for ajax to complete
  Then I should see "No responses yet for the survey"
  Then I should see "1" days and "3" days after program creation as the selected date range

@javascript @reindex @cross-browser
Scenario: Apply survey question filter on survey report
  Given the current program is "primary":"nomreqpro"
  And I have logged in as "no_mreq_admin@example.com"
  And I enable "mentoring_connections_v2" feature as a super user
  And I follow "Manage"
  And I follow "Surveys"
  Then I follow "Progress Report"
  Then I follow "Trends"
  Then I should see "remove mentor"
  Then I should see "remove mentee"
  Then I follow "filter_report"
  Then I should see "Survey Responses"

  # Apply filter
  And I select "What is your name?" from "survey_question_1"
  Then I should not see "Add" within "#other_report_filters"
  And I select "Contains" from "survey_operator_1"
  Then I should see "#survey_choices_1" hidden
  Then I should see "Add" within "#other_report_filters"
  And I fill in "survey_value_1" with "remove mentor"
  # Adding new question
  And I follow "Add"
  And I select "Where are you from?" from "survey_question_2"
  And I select "Contains" from "survey_operator_2"
  Then I should see "#survey_value_2" hidden
  # Fill select2-choices
  Then I click "#s2id_survey_choices_2 > .select2-choices"
  And I click on select2 result "Smallville"
  And I press "Go"
  Then I wait for ajax to complete
  Then I should see "remove mentor"
  Then I should not see "remove mentee"
  # Delete a question
  Then I follow "filter_report"
  And I click ".cjs_delete_question"
  Then I should not see "remove mentor" within "#other_report_filters"
  And I select "Filled" from "survey_operator_2"
  Then I should see "#survey_value_2" hidden
  Then I should see "#survey_choices_2" hidden
  And I press "Go"
  Then I wait for ajax to complete
  Then I should see "remove mentor"
  # You wont see mentee still due to bad date
  Then I should not see "remove mentee"
  Then I should see "#survey_operator_2" hidden
  # Reset filter
  Then I follow "filter_report"
  And I follow "Reset"
  Then I should see "remove mentor"
  Then I should not see "remove mentee"

@javascript @reindex @cross-browser
Scenario: Apply profile question filter on survey report
  Given the current program is "primary":"nomreqpro"
  And I have logged in as "no_mreq_admin@example.com"
  And I enable "mentoring_connections_v2" feature as a super user
  And I follow "Manage"
  And I follow "Surveys"
  Then I follow "Progress Report"
  Then I follow "Trends"
  Then I should see "remove mentor"
  Then I should see "remove mentee"
  Then I follow "filter_report"
  Then I should see "User Profile"

  # Apply filter
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
  Then I should not see "remove mentor"
  # Bad date
  Then I should not see "remove mentee"
  # Delete a question
  Then I follow "filter_report"
  And I click ".cjs_delete_question"
  Then I should not see "remove mentor" within "#other_report_filters"
  And I select "Filled" from "profile_operator_2"
  And I press "Go"
  Then I wait for ajax to complete
  Then I should see "No responses yet for the survey"
  # Reset filter
  Then I follow "filter_report"
  Then I follow "Reset"
  Then I should see "remove mentor"
  Then I should not see "remove mentee"

@javascript @reindex @cross-browser
Scenario: Apply role filter on survey report
  Given the current program is "primary":"nomreqpro"
  And I have logged in as "no_mreq_admin@example.com"
  And I enable "mentoring_connections_v2" feature as a super user
  And I follow "Manage"
  And I follow "Surveys"
  Then I follow "Progress Report"
  Then I follow "Trends"
  Then I should see "remove mentor"
  Then I should see "remove mentee"
  Then I follow "filter_report"
  Then I should see "User Role"

  # Apply filter
  Then I click "#s2id_role_choice > .select2-choices"
  And I click on select2 result "Student"
  And I press "Go"
  Then I should not see "remove mentor"
  Then I should not see "remove mentee"

  Then I follow "filter_report"
  Then I click "#s2id_role_choice > .select2-choices"
  And I click on select2 result "Mentor"
  And I press "Go"
  Then I should see "remove mentor"
  Then I should not see "remove mentee"

@javascript @reindex @download @not_run_on_jenkins
Scenario: Admin export pdf report
  Given the current program is "primary":"nomreqpro"
  And I have logged in as "no_mreq_admin@example.com"
  And I enable "mentoring_connections_v2" feature as a super user
  And I clear the downloads folder
  And I follow "Manage"
  And I follow "Surveys"
  Then I follow "Progress Report"
  Then I follow "Trends"
  Then I should see "remove mentor"
  Then I should see "remove mentee"
  Then I follow "cjs_reports_export"
  Then I wait for download to complete
  Then the pdf file should have been downloaded with name "Progress Report-Summary"