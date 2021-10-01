@javascript
Feature: Mentoring Connections V2

Background: Enable Mentoring Connections V2 Feature
  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  Then I enable admin audit logs
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user
  And I logout
  And I stub chronus s3 utils

@javascript @cross_browser
Scenario: Creating a new Group With Feature Mentoring Connections V2 Enabled With Tasks and Milestones Feature Enabled at end-user level. User should be able to comment for the task.
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  Then I follow "CONFIGURE FEATURES"
  And element with id "#cjs_mentoring_model_admin_manage_mm_tasks" should be disabled
  And element with id "#cjs_mentoring_model_admin_manage_mm_messages" should be disabled
  And I uncheck "cjs_mentoring_model_admin_manage_mm_milestones"
  And I uncheck "cjs_mentoring_model_admin_manage_mm_goals"

  Then the disabled "cjs_mentoring_model_users_manage_mm_tasks" checkbox_id should be checked
  And I check "cjs_mentoring_model_users_manage_mm_milestones"
  And I uncheck "cjs_mentoring_model_users_manage_mm_goals"

  And I press "Save and proceed to Add Content »"
  And I should not see "Add New Goal"
  When I click ".add-action-opener"
  And I follow "New Task"
  Then I should see "Assign To" 
  And I fill in "mentoring_model_task_template_title" with "Hello Task Title"
  And I press "Save Task"
  Then I wait for ajax to complete
  Then I should see "Hello Task Title"
  And I should not see "Customize Goals"
  And I should not see "Add Custom Milestone"
  And I follow "CONFIGURE FEATURES"
  And I check "cjs_mentoring_model_admin_manage_mm_milestones"
  Then I confirm popup
  And I press "Save and proceed to Add Content »"
  And I should not see "New Goal"
  And I should not see "Customize Goals"
  And I should see "Customize Milestones"

  When I click "#cjs_add_milestone_template"
  Then I should see "Cancel"
  And I fill in "cjs_milestone_template_form_title_" with "Hello Milestone Title" within "#new_mentoring_model_milestone_template"
  And I press "Save" within "#new_mentoring_model_milestone_template"  
  Then I should see "Hello Milestone Title"

  And I follow "Manage"
  Then I follow "Mentoring Connections"
  And I follow "Create New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>" within "#new_group"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>" within "#new_group"  
  And I click "#create_and_publish"
  
  And I should not see "Goals Progress"
  And I should see "Milestones Progress"
  And I should not see "Tasks Progress"
  Then I should see "name & example"

  And I follow "name & example"
  And I fill in "confidentiality_audit_log_reason" with "Checking Connection"
  And I press "Proceed"
  Then I should see "Hello Milestone Title"
  Then I click ".cjs_show_completed_milestones"
  Then I should see "Default Milestone"
  Then I should see "Hello Task Title"
  And I logout as super user
  And I logout

  Given the current program is "primary":"albers"
  When I have logged in as "robert@example.com"
  
  Then I should see "name & example"
  And I follow "name & example"
  Then I should see "Hello Milestone Title"
  Then I click ".cjs_show_completed_milestones"
  Then I should see "Default Milestone"
  Then I should see "Hello Task Title"
  And I should see "Add Milestone"

  When I click ".add-action-opener"
  And I follow "Add New Task"
  Then I should see "Assign To"
  And I fill in "mentoring_model_task_title" with "End User Task"

  And I should see ".cjs-required-checkbox-true" hidden
  When I check "mentoring_model_task_required"
  Then I click ".cjs_mentoring_model_task_due_date"
  Then I click ".cjs_datepicker_clear_selection"
  And I press "Save Task" 
  # The form does not submit as due date field is highlighted.
  
  Then I click ".cjs_mentoring_model_task_due_date"
  Then I click ".k-nav-today"
  And I press "Save Task" 
  And I should see "End User Task"
  
  Then I click task title
  And I should see "Notify others in the mentoring connection" hidden
  Then I click ".cjs_add_task_comment_sidepane"
  Then I wait for "2" seconds
  And I should see "Notify others in the mentoring connection"
  Then the "mentoring_model_task_comment_notify" checkbox should be checked
  Then I add a new comment "This is a task comment"
  Then I click ".cjs_comment_button"
  And I should see "Notify others in the mentoring connection" hidden
  Then I should see "This is a task comment" within ".cjs-task-comments-container"
  Then I should see "Me" within ".cjs-task-comments-container"
  Then I should see "less than a minute ago" within ".cjs-task-comments-container"

  Then I click on add new comment
  And I should see "Notify others in the mentoring connection" hidden

  Then I click on add new comment
  Then I should see "The comment has been added succesfully" hidden
  Then I hover on last comment
  Then I click ".delete-task"
  And I confirm popup
  
  Then I click task title
  Then I click ".cjs_add_task_comment_sidepane"
  Then I wait for "2" seconds
  Then I add a new comment "This is a new task comment"
  Then I click ".cjs_comment_button"

  When I click ".cjs_add_new_custom_milestone"
  
  And I fill in "cjs_mentoring_model_milestone_title_" with "Hello Milestone Title Again"
  And I press "Save" within ".modal.in"
  Then I wait for remote Modal to be hidden
  
  And I logout

  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  Then I follow "User Views"
  Then I follow "Good unique"
  And I follow "name & example"
  Then I should not see task dropdown
  Then I click task title
  And I should see "This is a new task comment" within ".cjs-task-comments-container"
  Then I hover on last comment

  @javascript
  Scenario: Creating a new Group With Feature Mentoring Connections V2 Enabled With Tasks and Milestones Feature Enabled at end-user level. User should not see notify others in the mentoring connection when audit message is enabled.
  Given the current program is "primary":"albers"
  And audit message is enabled for the program "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  Then I follow "CONFIGURE FEATURES"
  And element with id "#cjs_mentoring_model_admin_manage_mm_tasks" should be disabled
  And element with id "#cjs_mentoring_model_admin_manage_mm_messages" should be disabled
  And I uncheck "cjs_mentoring_model_admin_manage_mm_milestones"
  And I uncheck "cjs_mentoring_model_admin_manage_mm_goals"

  Then the disabled "cjs_mentoring_model_users_manage_mm_tasks" checkbox_id should be checked
  And I check "cjs_mentoring_model_users_manage_mm_milestones"
  And I uncheck "cjs_mentoring_model_users_manage_mm_goals"

  And I press "Save and proceed to Add Content »"
  And I should not see "Add New Goal"
  When I click ".add-action-opener"
  And I follow "New Task"
  Then I should see "Assign To"
  And I fill in "mentoring_model_task_template_title" with "Hello Task Title" within "#cjs_new_mentoring_model_task_template_new"
  And I press "Save Task"
  And I wait for ajax to complete
  Then I should see "Hello Task Title"
  And I should not see "Customize Goals"
  And I should not see "Add Custom Milestone"
  And I follow "CONFIGURE FEATURES"
  And I check "cjs_mentoring_model_admin_manage_mm_milestones"
  And I press "OK"
  And I press "Save and proceed to Add Content »"
  And I should not see "New Goal"
  And I should not see "Customize Goals"
  And I should see "Customize Milestones"

  When I click "#cjs_add_milestone_template"
  Then I should see "Cancel"
  And I fill in "cjs_milestone_template_form_title_" with "Hello Milestone Title" within "#new_mentoring_model_milestone_template"
  And I press "Save" within "#new_mentoring_model_milestone_template"  
  Then I should see "Hello Milestone Title"

  And I follow "Manage"
  Then I follow "Mentoring Connections"
  And I follow "Create New Mentoring Connection"
  Then I should see "Create a New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>" within "#new_group"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>" within "#new_group"  
  And I click "#create_and_publish"  
  
  Then I should not see "Goals Progress"
  And I should see "Milestones Progress"
  And I should not see "Tasks Progress"
  Then I should see "name & example"
  
  And I follow "name & example"
  And I fill in "confidentiality_audit_log_reason" with "Checking Connection"
  And I press "Proceed"
  Then I should see "Hello Milestone Title"
  Then I click ".cjs_show_completed_milestones"
  Then I should see "Default Milestone"
  Then I should see "Hello Task Title"
  And I logout as super user
  And I logout
  
  Given the current program is "primary":"albers"
  When I have logged in as "robert@example.com"
  
  Then I should see "name & example"
  And I follow "name & example"
  Then I click ".cjs_show_completed_milestones"
  Then I should see "Default Milestone"
  Then I should see "Hello Milestone Title"
  Then I should see "Hello Task Title"
  And I should see "Add Milestone"

  When I click ".add-action-opener"
  And I follow "Add New Task"
  Then I should see "Assign To"  
  And I fill in "mentoring_model_task_title" with "End User Task"
  And I press "Save Task"  
  Then I should see "End User Task"
  
  Then I click task title
  And I should not see "Notify others in the mentoring connection"
  Then I click ".cjs_add_task_comment_sidepane"
  And I should not see "Notify others in the mentoring connection"
  Then I add a new comment "This is a task comment"
  Then I wait for "2" seconds
  Then I click ".cjs_comment_button"
  Then I should see "This is a task comment" within ".cjs-task-comments-container"
  And I logout