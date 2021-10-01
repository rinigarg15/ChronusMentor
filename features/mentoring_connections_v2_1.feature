@javascript
Feature: Mentoring Connections V2

Background: Enable Mentoring Connections V2 Feature
  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user
  And I logout
  And I stub chronus s3 utils

@javascript
Scenario: Confidentiality Log
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I enable admin audit logs
  And I follow "Manage"
  Then I should see "Admin Audit Log"
  Then I follow "Mentoring Connections"
  Then I follow "chronus & example"
  Then I should see "Enter a reason to view confidential area"
  Then I logout

@javascript
Scenario: Only Superuser should be able to either enable/disable Mentoring Connections V2 Feature.
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I disable the feature "mentoring_connections_v2" as a super user
  #And I logout as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Features"
  And I should not see "Mentoring Connections V2"
  And I logout

@javascript
Scenario: RA and other objects should be hidden if Mentoring Connections V2 Feature is enabled.
  Given the current program is "primary":"albers"
  When I have logged in as "robert@example.com"
  When I follow "name & madankumarrajan"
  And I logout
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector

@javascript @cross-browser
Scenario: Enabling Admin Level Goals should allow you to add new goals at template level.
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  Then I follow "CONFIGURE FEATURES"
  Then the disabled "cjs_mentoring_model_admin_manage_mm_tasks" checkbox_id should be checked
  And I press "Save and proceed to Add Content »"
  And I should see "Add a new action"
  And I follow "CONFIGURE FEATURES"
  And I check "cjs_mentoring_model_admin_manage_mm_goals"
  And I press "Save and proceed to Add Content »"
  And I should see "Add New Goal"
  And I should see "Customize Goals"
  And I should see "There are no goals yet"
  And I should not see "Hello Title"
  When I click ".cjs_add_new_goal"
  And I wait for ajax to complete
  And I should see "Cancel"
  And I fill in "mentoring_model_goal_template_title" with "Hello Title"
  And I fill in "mentoring_model_goal_template_description" with "Some description"
   
  And I press "Save" within "#cjs-mentoring-model-goal-template-form-new"
  Then I wait for remote Modal to be hidden
  And I wait for ajax to complete
   
  Then I should see "Hello Title"
  And I should see "There are no goals yet" hidden
  When I click ".cjs-goal-template-title"
    
  Then I should see "Some description"
  Then I click on dropdown toggle within ".cjs-goal-template-header"
  And I click ".cjs_edit_goal_template"
  And I wait for ajax to complete
  And I fill in "mentoring_model_goal_template_title" with "EDITED GOAL TITLE"
  And I fill in "mentoring_model_goal_template_description" with "Edited description"
  And I press "Save" within ".cjs_goal_template_edit"
  And I wait for ajax to complete
   
  Then I should not see "Hello Title"
  But I should see "EDITED GOAL TITLE"
  When I click ".cjs-goal-template-title"
  Then I should not see "Some description"
  But I should see "Edited description"
  When I click ".cjs-goal-template-title"
  Then I click on dropdown toggle within ".cjs-goal-template-header"
  And I follow "Delete"
  And I confirm popup
  Then I should see "EDITED GOAL TITLE" hidden
  But I should see "There are no goals yet"
  And I logout


@javascript @cross-browser
Scenario: Enabling Admin Level Task should allow you to add new tasks at template level.
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
  When I click ".cjs_add_new_goal"
  And I fill in "mentoring_model_goal_template_title" with "Hello Title"
  And I press "Save" within ".modal.in"
   
  When I click ".add-action-opener"
  And I follow "New Task"
   
  And I fill in "mentoring_model_task_template_title" with "` Hello Task Title '"
  Then I follow "Cancel"
  Then I should not see "` Hello Task Title '"
  
  When I click ".add-action-opener"
  And I follow "New Task"
   
  And I fill in "mentoring_model_task_template_title" with "` Hello Task Title '"
  And I should see ".cjs-required-checkbox-true" hidden
  When I check "mentoring_model_task_template_required"
  Then I select "Specific Date" from "mentoring_model_task_template_date_assigner"
  Then I click "#mentoring_model_task_template_specific_date"
  Then I click ".cjs_datepicker_clear_selection"
  When I click ".cjs-required-checkbox-true"
  Then I should see "Hello Title"
  And I press "Save Task"
  # The form does not submit as due date field is highlighted.
  Then I select "1" days after program creation as due date for "mentoring_model_task_template_specific_date"
  And I press "Save Task"
  Then I should see "` Hello Task Title '"
  When I delete the task
  And I confirm popup
  Then I should not see "` Hello Task Title '"
  And I logout

@javascript @cross-browser
Scenario: Enabling Admin Level Milestones Templates should allow Admin to configure milestones
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
  And I should not see "Add Custom Milestone"
  And I follow "CONFIGURE FEATURES"
  Then the disabled "cjs_mentoring_model_admin_manage_mm_tasks" checkbox_id should be checked
  And I check "cjs_mentoring_model_admin_manage_mm_milestones"
  And I press "Save and proceed to Add Content »"
  And I should see "Add New Goal"
  And I should see "Customize Goals"
  And I should see "Customize Milestones"

  When I click "#cjs_add_milestone_template"
  And I should see "Cancel"
  Then I should see "Description"
  And I fill in "cjs_milestone_template_form_title_" with "Hello Milestone Title"
  And I press "Save" within "#new_mentoring_model_milestone_template"
  Then I wait for remote Modal to be hidden
  And I wait for ajax to complete
  Then I should see "Hello Milestone Title"
  And I should see "Add New Task" hidden
  And I logout

@javascript @p2
Scenario: Admin should be able to set up and proceed to customize models
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  And I follow "CONFIGURE FEATURES"
  And I check "cjs_mentoring_model_admin_manage_mm_milestones"
  Then the disabled "cjs_mentoring_model_admin_manage_mm_tasks" checkbox_id should be checked
  And I press "Save and proceed to Add Content »"
  Then I should see "Customize Milestones"
  And I should see "Add Custom Milestone"
  And I logout

@javascript @p2
Scenario: Admin should be able to create new milestones in position
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  And I follow "CONFIGURE FEATURES"
  And I check "cjs_mentoring_model_admin_manage_mm_milestones"
  Then the disabled "cjs_mentoring_model_admin_manage_mm_tasks" checkbox_id should be checked
  And I press "Save and proceed to Add Content »"
  Then I should see "Customize Milestones"
  And I should see "Add Custom Milestone"
  And I click "#cjs_add_milestone_template"
  And I fill in "cjs_milestone_template_form_description_" with "This is description of milestone 1."
  And I fill in "cjs_milestone_template_form_title_" with "Milestone 1"
  And I click ".cjs_milestone_template_submit_btn"
  Then I wait for remote Modal to be hidden
  Then I wait for ajax to complete
  Then I should see "Milestone 1" within "div#cjs_milestone_templates"
  And I click "#cjs_add_milestone_template"
  And I fill in "cjs_milestone_template_form_description_" with "This is description of milestone 2."
  And I fill in "cjs_milestone_template_form_title_" with "Milestone 2"
  And I choose "milestone_position_1"
  And I click ".cjs_milestone_template_submit_btn"
  Then I wait for remote Modal to be hidden
  Then I wait for ajax to complete
  Then I should see "Milestone 2" within "div#cjs_milestone_templates"
  And I click "#cjs_add_milestone_template"
  And I fill in "cjs_milestone_template_form_description_" with "This is description of milestone 3."
  And I fill in "cjs_milestone_template_form_title_" with "Milestone 3"
  And I choose "milestone_position_2"
  And I select "Milestone 2" from "cui_insert_milestone_after_dropdown"
  And I click ".cjs_milestone_template_submit_btn"
  Then I wait for remote Modal to be hidden
  Then I wait for ajax to complete
  Then I should see "Milestone 3" within "div#cjs_milestone_templates"
  And I logout


@javascript @p2
Scenario: Admin should get warning on adding tasks outside chronlogical order
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  And I follow "CONFIGURE FEATURES"
  And I check "cjs_mentoring_model_admin_manage_mm_milestones"
  Then the disabled "cjs_mentoring_model_admin_manage_mm_tasks" checkbox_id should be checked
  And I press "Save and proceed to Add Content »"
  Then I should see "Customize Milestones"
  And I should see "Add Custom Milestone"
  And I click "#cjs_add_milestone_template"
  And I fill in "cjs_milestone_template_form_description_" with "This is description of milestone 1."
  And I fill in "cjs_milestone_template_form_title_" with "Milestone 1"
  And I click ".cjs_milestone_template_submit_btn"
  Then I wait for remote Modal to be hidden
  Then I wait for ajax to complete
  Then I should see "Milestone 1" within "div#cjs_milestone_templates"
  And I click ".cjs_milestone_template_entity"

  And I follow "Expand or Collapse" within ".cjs_milestone_template_entity"
  When I click ".collapse-link"
  Then I click ".add-action-opener"
  And I follow "Add New Task"
  Then I should see "Assign To"
  And I fill in "mentoring_model_task_template_title" with "Task 1" within "#cjs_new_mentoring_model_task_template_new"
  And I assign the task to "Mentor"
  And I check "mentoring_model_task_template_required"
  Then I select "Specific Date" from "mentoring_model_task_template_date_assigner"
  Then I select "4" days after program creation as due date for "mentoring_model_task_template_specific_date"
  And I press "Save Task"
  Then I should not see "This action will place tasks out of chronological order. Do you still wish to proceed?"

  And I click "#cjs_add_milestone_template"
  And I fill in "cjs_milestone_template_form_description_" with "This is description of milestone 2."
  And I fill in "cjs_milestone_template_form_title_" with "Milestone 2"
  And I choose "milestone_position_1"
  And I click ".cjs_milestone_template_submit_btn"
  Then I wait for remote Modal to be hidden
  Then I wait for ajax to complete
  Then I should see "Milestone 2" within "div#cjs_milestone_templates"

  And I follow "Expand or Collapse" within ".cjs_milestone_template_entity"
  When I click ".add-action-opener"
  And I follow "Add New Task"
  Then I should see "Assign To"
  And I fill in "mentoring_model_task_template_title" with "Task 2" within "#cjs_new_mentoring_model_task_template_new"
  And I assign the task to "Mentor"
  And I check "mentoring_model_task_template_required"
  Then I select "Specific Date" from "mentoring_model_task_template_date_assigner"
  Then I select "10" days after program creation as due date for "mentoring_model_task_template_specific_date"
  And I press "Save Task"
  Then I should see "This action will place tasks out of chronological order. Do you still wish to proceed?"
  Then I press "OK"
  And I logout


  @javascript @cross_browser
  Scenario: Mentor reactivates a group
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I prepone expiry time for closed group "mentor & example" in "primary":"albers"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Mentoring Connection Settings"
  And I should see "Allow members of a closed mentoring connection to reactivate the mentoring connection"
  And I check "program_role_permissions_17_reactivate_groups"
  Then I press "Save"
  And I logout

  And I have logged in as "request@example.com"
  And I follow "Closed"
  And I click on "reactivate_link_4" for the group "group_4"
  And I should see "Cancel"
  Then I follow "Cancel"
  And I follow "mentor & example"
  And I should see "The mentoring connection mentor & example has ended. Click here to reactivate"
  Then I follow "here"
  And I fill in "group_reactivation_reason_4" with "A reason"
  And I should see "Reactivate"
  And I select "January 25, 2020" for "#set_new_expiry_date_4" from datepicker
  And I press "Reactivate"
  Then I should see "The mentoring connection was recently reactivated. This mentoring connection ends in over 1 year"