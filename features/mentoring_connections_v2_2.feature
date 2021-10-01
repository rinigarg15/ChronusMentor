@javascript
Feature: Mentoring Connections V2

Background: Enable Mentoring Connections V2 Feature
  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  Given the current program is "primary":""
  Then I enable "mentoring_connections_v2" feature as a super user
  And I logout
  And I stub chronus s3 utils

@javascript @cross-browser
Scenario: Enabling facilitation messages should allow admins to add facilitation messages. Facilitation messages can be updated or deleted.
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  And I follow "CONFIGURE FEATURES"
  And I check "cjs_mentoring_model_admin_manage_mm_goals"
  And I press "Save and proceed to Add Content »"
  Then I should see "Customize Goals"
  And I should see "Add New Goal"
  And I follow "CONFIGURE FEATURES"
  Then the disabled "cjs_mentoring_model_admin_manage_mm_messages" checkbox_id should be checked
  And I press "Save and proceed to Add Content »"
  Then I should see "Add a new action"
  When I click ".add-action-opener"
  And I follow "New Facilitation Message"

  And I fill in "mentoring_model_facilitation_template_subject" with "TEST FACILITATION MESSAGE TITLE"
  And I should see "Sample Email"
  And I should see "Click here to send a test email. The salutation and signature will be appended to the body before sending the email."
  And I should see "Note: This feature should be used to test copy and layout. It will not generate content for placeholders correctly, so expect some missing data. For example, you may see a fake term or blank space in place of {{tag}}. Web hyperlinks also may not work. Rest assured that in real scenarios, placeholders and links will work correctly."
  Then I follow "Click here"
  And a mail should go to "ram@example.com" having "Please enter mandatory details for this message here."

  And I press "Save Message"
  Then I should not see "Sample Email"
  Then I should see "TEST FACILITATION MESSAGE TITLE"
  And I should see "MENTOR AND STUDENT"
  And I should see "due 1 week after start of mentoring connection"
  Then I click on dropdown toggle within ".cjs-facilitation-template-header"
  And I follow "Edit"
  And I wait for ajax to complete
  And I fill in "mentoring_model_facilitation_template_subject" with "TEST FACILITATION MESSAGE UPDATED TITLE"

  And I press "Save Message"
  And I wait for ajax to complete
  Then I should not see "TEST FACILITATION MESSAGE TITLE"
  And I should see "TEST FACILITATION MESSAGE UPDATED TITLE"

  And I click on profile picture and click "Edit Profile"
  Then I follow "Settings"
  Then I select "America" from "timezone_area"
  Then I select "New York" from "user_member_time_zone"
  Then I press "Save"

  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  Then I click on dropdown toggle within ".cjs-facilitation-template-header"
  And I follow "Edit"
  Then I select "Specific Date" from "mentoring_model_facilitation_template_date_assigner"
  Then I select "10" days after program creation as due date for "mentoring_model_facilitation_template_specific_date"
  And I press "Save Message"
  And I wait for ajax to complete

  And I click on profile picture and click "Edit Profile"
  Then I follow "Settings"
  Then I select "America" from "timezone_area"
  Then I select "Los Angeles" from "user_member_time_zone"
  Then I press "Save"

  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  Then I click on dropdown toggle within ".cjs-facilitation-template-header"
  And I follow "Edit"
  Then I should see "9" days after program creation as due date for "mentoring_model_facilitation_template_specific_date"
  And I press "Save Message"
  Then I press "Save"

  # should not allow invalid tags
  Then I click on dropdown toggle within ".cjs-facilitation-template-header"
  And I follow "Edit"
  And I wait for ajax to complete
  Then I fill in CKEditor "mentoring_model_facilitation_template_message" with "{{invalid_source_tag_1}} {{invalid_source_tag_2}}"
  And I press "Save Message"
  Then I should see "Facilitation Message contains invalid tags: {{invalid_source_tag_1}},{{invalid_source_tag_2}}"
  Then I fill in CKEditor "mentoring_model_facilitation_template_message" with "{{user_firstname}}"
  And I press "Save Message"
  Then I should not see "Facilitation Message contains invalid tags: {{user_firstname}}"
  And I wait for ajax to complete

  When I delete the facilitation task
  And I confirm popup
  Then I should not see "TEST FACILITATION MESSAGE TITLE"
  When I click ".add-action-opener"
  And I follow "New Facilitation Message"

  And I press "Save Message"
  Then I should see "Mentoring Insight"
  And I logout

@javascript @p2 @cross-browser
Scenario: Creating a new Group With Feature Mentoring Connections V2 Enabled With only Admin tasks.
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  And I follow "CONFIGURE FEATURES"
  Then the disabled "cjs_mentoring_model_admin_manage_mm_tasks" checkbox_id should be checked
  And I uncheck "cjs_mentoring_model_admin_manage_mm_goals"
  And I uncheck "cjs_mentoring_model_users_manage_mm_goals"
  And I press "Save and proceed to Add Content »"
  And I should not see "Add New Goal"
  But I should see "Add a new action"
  When I click ".add-action-opener"
  And I follow "New Task"
  Then I should see "Assign To"
  And I fill in "mentoring_model_task_template_title" with "HELLO TASK TITLE" within "#cjs_new_mentoring_model_task_template_new"
  And I press "Save Task"
  Then I should see "HELLO TASK TITLE"
  And I follow "Manage"
  Then I follow "Mentoring Connections"
  And I follow "Create New Mentoring Connection"
  Then I should see "Create a New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>" within "#new_group"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>" within "#new_group"
  And I should see "Your message will not be saved when you draft mentoring connections"
  And I click "#create_and_publish" within "#new_group"

  Then I should see "name & example"
  And I follow "name & example"
  Then I should see "HELLO TASK TITLE"
  Then I should not see "Goals"
  And I logout

  Given the current program is "primary":"albers"
  When I have logged in as "robert@example.com"
  Then I should see "name & example"
  And I follow "name & example"
  Then I should not see "Goals"
  And I should not see "Add Milestone"
  And I should see "HELLO TASK TITLE"
  Then I should see "Add New Task"
  And I logout

@javascript @p2 @cross-browser
Scenario: Creating a new Group With Feature Mentoring Connections V2 Enabled With only end-user tasks.
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  And I follow "CONFIGURE FEATURES"

  Then I uncheck "mentoring_model_check_box_allow_messaging"
  Then I check "mentoring_model_check_box_allow_forum"
  Then I should see "Welcome to the discussion board! Ask questions, debate ideas, and share articles. You can follow conversations you like, expand a conversation to view the posts, or get a new conversation started!" within "#mentoring_model_forum_help_text"
  When I fill in "mentoring_model_forum_help_text" with "Updated forum help text!"
  Then the disabled "cjs_mentoring_model_users_manage_mm_tasks" checkbox_id should be checked
  And I uncheck "cjs_mentoring_model_admin_manage_mm_goals"
  And I uncheck "cjs_mentoring_model_users_manage_mm_goals"
  And I press "Save and proceed to Add Content »"
  And I should not see "Add New Goal"
  When I click ".add-action-opener"
  Then I should see "New Task"

  And I follow "Manage"
  Then I follow "Mentoring Connections"
  And I follow "Create New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>" within "#new_group"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>" within "#new_group"
  And I click "#create_and_publish" within "#new_group"
  And I should see "Tasks Progress"
  And I should see "Tasks not yet defined."

  When I follow "name & example"
  Then I should see "Discussion Board"
  When I follow "Discussion Board"
  Then I should see "Updated forum help text!" within "#group_side_pane"

  When I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  And I follow "CONFIGURE FEATURES"
  Then the disabled "mentoring_model_check_box_allow_forum" checkbox_id should be checked
  Then I should see "There are ongoing/closed mentoring connections using this mentoring connection template. Clone this template to create a new template or remove all the ongoing/closed mentoring connections to disable discussion boards." on hovering forum tooltip
  Then the "mentoring_model_check_box_allow_messaging" checkbox_id should not be checked
  Then I check "mentoring_model_check_box_allow_messaging"
  And I press "Save and proceed to Add Content »"
  And I logout as super user
  And I logout

  Given the current program is "primary":"albers"
  When I have logged in as "robert@example.com"
  Then I should see "name & example"
  And I follow "name & example"
  And I should see "Discussions"
  And I should not see "Discussion Board"
  And I should not see "Messages" within "div#content_wrapper"
  When I follow "Discussions"
  Then I should see "Discussion Board"
  Then I should see "Messages"
  Then I should not see "Goals"
  And I should not see "Add Milestone"
  And I follow "Add New Task"
  Then I should see "Assign To"
  And I fill in "mentoring_model_task_title" with "END USER TASK"
  And I press "Save Task"
  And I should see "END USER TASK"
  And I logout

@javascript @cross-browser
Scenario: Export Mentoring Connection
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  Then I follow "Mentoring Connections"
  Then I should see "Visit Mentoring Connection"
  And I follow "Visit Mentoring Connection"
  Then I should see "Edit Mentoring Connection Name and Picture"
  Then I should see "Export Mentoring Connection"
  Then I follow "Export Mentoring Connection"
  Then I should see "This mentoring connection is being exported. You will receive an email shortly with the exported information."
  And a mail should go to "ram@example.com" having "mentoring connection information you exported is attached to this email as a PDF"
  Then mail should have "pdf" attachment with name "Mentoring Connection"
  Then I logout

@javascript @cross-browser
Scenario: Mentor must be able to checkin for a task
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  Then I enable "contract_management" feature as a super user
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  Then I follow "CONFIGURE FEATURES"
  Then the disabled "cjs_mentoring_model_users_manage_mm_tasks" checkbox_id should be checked
  And I check "cjs_mentoring_model_admin_manage_mm_milestones"
  And I check "cjs_mentoring_model_admin_manage_mm_goals"
  And I press "Save and proceed to Add Content »"
  And I should see "Add New Goal"
  When I click ".cjs_add_new_goal"
  Then I should see "Cancel"
  And I fill in "mentoring_model_goal_template_title" with "Divergent" within "#cjs-mentoring-model-goal-template-form-new"
  And I press "Save" within "#cjs-mentoring-model-goal-template-form-new"
  Then I should see "Divergent"

  When I click "#cjs_add_milestone_template"
  Then I should see "Cancel"
  And I fill in "cjs_milestone_template_form_title_" with "Level 1" within "#new_mentoring_model_milestone_template"
  And I press "Save" within "#new_mentoring_model_milestone_template"
  Then I should see "Level 1"

  And I follow "Expand or Collapse" within ".cjs_milestone_template_entity"

  When I click ".add-action-opener"
  And I follow "New Task"
  Then I should see "Assign To"
  And I fill in "mentoring_model_task_template_title" with "Pass the simulation" within "#cjs_new_mentoring_model_task_template_new"
  And I assign the task to "Mentor"
  And I check "mentoring_model_task_template_required"
  And I align the task to the goal "Divergent"
  And I press "Save Task"
  Then I should see "Pass the simulation"

  And I follow "Manage"
  And I follow "Mentoring Connections"
  Then I should see "Ongoing"
  And I follow "Ongoing"
  And I follow "Create New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>" within "#new_group"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>" within "#new_group"
  And I click "#create_and_publish" within "#new_group"
  Then I should see "name & example"
  And I logout

  And I have logged in as "robert@example.com"
  Then I follow "name & example"
  Then I should see "Pass the simulation"
  Then I click on dropdown toggle within ".cjs-edit-content-header"
  And I follow "Check-in" within ".cjs-edit-content-header"
  Then I wait for ajax to complete
  And I checkin with the following details "0","30"
  Then I should see "checked in"
  Then I should see "checked in 30 minutes"

@javascript @p2 @cross-browser
Scenario: Checking preview of a mentoring model template
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  Then I should see "Preview"

  And I follow "Edit"
  And I follow "CONFIGURE FEATURES"
  And I check "cjs_mentoring_model_admin_manage_mm_milestones"
  And I press "Save and proceed to Add Content »"

  Then I should see "Preview Plan"
  And I click "#cjs_add_milestone_template"
  And I fill in "mentoring_model_milestone_template[title]" with "TEST MILESTONE"
  And I fill in "mentoring_model_milestone_template[description]" with "TEST DESCRIPTION"
  And I click ".cjs_milestone_template_submit_btn"
  And I wait for ajax to complete

  Then I should see "TEST MILESTONE"
  And I click ".cjs_show_on_collapse_milestone_template_handler"

  And I click ".add-action-opener"
  And I follow "Set up a Meeting"
  And I fill in "mentoring_model_task_template_title" with "TEST MEETING"
  Then I fill in CKEditor "cjs-mentoring-model-task-template-description-new" with "Test Meeting Description"
  And I select "Mentor" from "mentoring_model_task_template[role_id]"
  And I click ".cjs-task-template-submit-btn"
  And I wait for ajax to complete

  And I click ".add-action-opener"
  And I follow "Add a Survey"
  And I fill in "mentoring_model_task_template_title" with "TEST SURVEY"
  And I click ".cjs-task-template-submit-btn"
  And I wait for ajax to complete

  And I follow "Preview"
  Then I should see "Select role to preview as"
  # First Milestone should be open by default
  Then I should see "TEST MILESTONE"
  Then I should see "TEST MEETING"
  Then I should see "Edit Mentoring Connection Plan"

  #Closing and opening it again
  And I click ".cjs_milestone_description_handler"
  And I click ".cjs_milestone_description_handler"
  Then I should see "TEST MEETING"
  Then I should see "Set up a meeting"
  Then I should see "TEST SURVEY"
  And element with id ".cjs-unassigned-available-for-checkbox" should not be disabled

  And I click ".cjs-edit-content-header"
  Then I should see "TEST DESCRIPTION"
  Then I should see "Test Meeting Description"
  Then I should see "" within "div > textarea"
  Then I should not see "Add Milestone"
  
  And I click ".add-action-opener"
  Then I should see "This is just a preview and links/buttons won't behave as expected."
  And I press "OK"

  And I click ".cjs_milestone_description_handler"
  Then I should not see "TEST MEETING"
  Then I should not see "Set up a meeting"

  And I follow "Edit Mentoring Connection Plan"
  And I follow "CONFIGURE FEATURES"
  And I check "cjs_mentoring_model_users_manage_mm_milestones"
  And I press "Save and Continue Later"
  And I follow "Preview"
  And I click ".cjs_milestone_description_handler"
  Then I should see "Add Milestone"

  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "View"
  Then I should see "Preview Plan"