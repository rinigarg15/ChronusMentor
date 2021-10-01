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

@javascript
Scenario: Creating a new Group With Feature Mentoring Connections V2 Enabled With Task and Goal Feature Enabled.
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  Then I follow "CONFIGURE FEATURES"
  And I check "cjs_mentoring_model_admin_manage_mm_goals"
  And I press "Save and proceed to Add Content »"
  And I should see "Add New Goal"
  And I should see "Customize Goals"
  And I follow "CONFIGURE FEATURES"
  Then the disabled "cjs_mentoring_model_admin_manage_mm_tasks" checkbox_id should be checked
  And I press "Save and proceed to Add Content »"
  And I should see "Add New Goal"
  And I should see "Customize Goals"
  And I should see "Add a new action"
  When I click ".add-action-opener"
  And I follow "New Task"
  Then I should see "Assign To" 
  And I fill in "mentoring_model_task_template_title" with "Hello Task Title" within "#cjs_new_mentoring_model_task_template_new"
  And I press "Save Task"
  And I wait for ajax to complete
  Then I should see "Hello Task Title"
  Then I reload the page
  When I click ".cjs_add_new_goal"
  Then I should see "Cancel"
  #And I wait for animation to complete
  
  And I fill in "mentoring_model_goal_template_title" with "Hello Title Goal"
  And I press "Save" within "#cjs-mentoring-model-goal-template-form-new"
  Then I wait for remote Modal to be hidden
  Then I should see "Hello Title Goal"
  
  And I follow "Manage"
  Then I follow "Mentoring Connections"
  And I follow "Create New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"
  
  And I click "#create_and_publish"
  
  Then I should see "name & example"
  And I follow "name & example"
  And I fill in "confidentiality_audit_log_reason" with "Checking Connection"
  And I press "Proceed"
  Then I should see "Hello Task Title"
  Then I should see "Hello Title Goal"
  And I logout

@javascript
Scenario: Creating a new Group With Feature Mentoring Connections V2 Enabled With Task and Milestones Feature Enabled.
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  Then I follow "CONFIGURE FEATURES"
  And I check "cjs_mentoring_model_admin_manage_mm_goals"
  And I press "Save and proceed to Add Content »"
  And I should see "Add New Goal"
  And I should see "Customize Goals"
  And I should not see "Add Custome Milestone"
  And I follow "CONFIGURE FEATURES"
  Then the disabled "cjs_mentoring_model_admin_manage_mm_tasks" checkbox_id should be checked
  And I check "cjs_mentoring_model_admin_manage_mm_milestones"
  And I press "Save and proceed to Add Content »"
  And I should see "Add New Goal"
  And I should see "Customize Goals"
  And I should see "Customize Milestones"

  When I click "#cjs_add_milestone_template"
  Then I should see "Cancel"
  And I fill in "cjs_milestone_template_form_title_" with "Hello Milestone Title" within "#new_mentoring_model_milestone_template"
  And I press "Save" within "#new_mentoring_model_milestone_template"
  Then I wait for remote Modal to be hidden
  
  Then I should see "Hello Milestone Title"
  And I should see "Add New Task" hidden

  And I follow "Manage"
  Then I follow "Mentoring Connections"
  And I follow "Create New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"
  
  And I click "#create_and_publish"
  
  Then I should see "name & example"
  And I follow "name & example"
  And I fill in "confidentiality_audit_log_reason" with "Checking Connection"
  And I press "Proceed"
  Then I should see "Hello Milestone Title"
  And I should see "No Goals Yet."
  And I should see "There are no tasks"
  And I logout

@javascript @cross_browser
Scenario: Creating a new Group With Feature Mentoring Connections V2 Enabled With Task, Goals and Milestones Feature Enabled.
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  Then I follow "CONFIGURE FEATURES"
  And I check "cjs_mentoring_model_admin_manage_mm_goals"
  And I press "Save and proceed to Add Content »"
  And I should see "Add New Goal"
  When I click ".add-action-opener"
  And I follow "New Task"
  Then I should see "Assign To"
  And I fill in "mentoring_model_task_template_title" with "Hello Task Title"
  And I press "Save Task"
  And I wait for ajax to complete
  Then I should see "Hello Task Title"
  And I should see "Customize Goals"
  And I should not see "Add Milestone"
  And I follow "CONFIGURE FEATURES"
  Then the disabled "cjs_mentoring_model_admin_manage_mm_tasks" checkbox_id should be checked
  Then the disabled "cjs_mentoring_model_admin_manage_mm_tasks" checkbox_id should be checked
  And I check "cjs_mentoring_model_admin_manage_mm_goals"
  And I check "cjs_mentoring_model_admin_manage_mm_milestones"
  And I press "OK"
  And I press "Save and proceed to Add Content »"
  And I should see "Add New Goal"
  And I should see "Customize Goals"
  And I should see "Customize Milestones"

  When I click "#cjs_add_milestone_template"
  Then I should see "Cancel"
  And I fill in "cjs_milestone_template_form_title_" with "Hello Milestone Title" within "#new_mentoring_model_milestone_template"
  And I press "Save" within "#new_mentoring_model_milestone_template"
  Then I wait for remote Modal to be hidden
  
  Then I should see "Hello Milestone Title"

  Then I reload the page
  When I click ".cjs_add_new_goal"
  Then I should see "Cancel"
  #And I wait for animation to complete
  
  And I fill in "mentoring_model_goal_template_title" with "Hello Title Goal"
  And I press "Save" within "#cjs-mentoring-model-goal-template-form-new"
  Then I wait for remote Modal to be hidden
  Then I should see "Hello Title Goal"

  And I follow "Manage"
  Then I follow "Mentoring Connections"
  And I follow "Create New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"
  
  And I click "#create_and_publish"
  
  And I should see "Goals Progress"
  And I should see "Milestones Progress"
  And I should not see "Tasks Progress"
  And I should see "Hello Title Goal"
  Then I should see "name & example"
  And I follow "name & example"
  And I fill in "confidentiality_audit_log_reason" with "Checking Connection"
  And I press "Proceed"
  Then I should see "Hello Milestone Title"
  Then I should see "Hello Title Goal"
  Then I click ".cjs_show_completed_milestones"
  Then I should see "Default Milestone"
  #Then I click ".cjs_milestone_description_handler"
  Then I should see "Hello Task Title"
  And I logout as super user
  And I logout

  Given the current program is "primary":"albers"
  When I have logged in as "robert@example.com"
  And I follow "name & example"
  Then I should see "Hello Milestone Title"
  Then I should see "Hello Title Goal"
  Then I click ".cjs_show_completed_milestones"
  Then I should see "Default Milestone"
  Then I should see "Hello Task Title"
  And I should not see "Add Milestone"
  And I logout