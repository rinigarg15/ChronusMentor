@javascript
Feature: Multiple Templates for mentoring connections V2

Background: Enable Multiple Templates Feature
  Given the current program is "primary":""
  When I have logged in as "ram@example.com"
  Then I enable "mentoring_connections_v2" feature as a super user
  And I logout

@javascript @cross-browser
Scenario: First time admin comes in to the app, after the feature was enabled
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Albers Mentor Program" from the program selector
  Then I follow "Manage"
  Then I should not see "Set Up Mentoring Model"
  Then I should not see "Facilitate Mentoring Connections"
  And I should see "Mentoring Connection Plan Templates"
  Then I follow "Mentoring Connection Plan Templates"
  Then I follow "View"
  Then I should see "Albers Mentor Program Template (Default)"
  Then I should see "180 Days"
  Then I follow the back link
  Then I should see "Goal Plans (Administrators, Users)" within ".features_list"
  Then I should see "Tasks (Administrators, Users)" within ".features_list"
  Then I should see "Meetings (Users)" within ".features_list"
  Then I should see "Facilitation Messages (Administrators)" within ".features_list"
  Then I should not see "Create a New Template"
  Then I logout

@javascript @cross-browser
Scenario: Add Content to the default mentoring model - Wizard View
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Albers Mentor Program" from the program selector
  Then I follow "Manage"
  Then I should not see "Create a New Template"
  And I login as super user
  When I hover over "my_programs_container"
  And I select "Albers Mentor Program" from the program selector
  Then I follow "Manage"
  Then I follow "Mentoring Connection Plan Templates"
  Then I should see "Create a New Template"
  Then I follow "Create a New Template"
  Then I should see "New Mentoring Connection Plan Template" within "div#title_div"
  Then I should see "DESCRIBE PLAN"
  Then I should see "CONFIGURE FEATURES"
  Then I should see "ADD CONTENT"
  Then I fill in "cjs_title_field" with "albers mentor program template"
  Then I fill in "mentoring_model_description" with "House Of Cards"
  Then I press "Save and proceed to Configure Features »"
  Then I should see the flash "There is already a Mentoring Connection Plan Template with this title."
  Then I fill in "cjs_title_field" with "Homeland Template"
  Then I press "Save and proceed to Configure Features »"
  Then I should see "Homeland Template" within "div#title_div"
  And the "cjs_mentoring_model_admin_manage_mm_goals" checkbox_id should be checked
  And I should see "Task Based Progress"
  And I should see "Manual Progress"
  And the "cjs_mentoring_model_users_manage_mm_goals" checkbox_id should be checked
  And the disabled "cjs_mentoring_model_admin_manage_mm_tasks" checkbox_id should be checked
  And the disabled "cjs_mentoring_model_admin_manage_mm_messages" checkbox_id should be checked
  And the "cjs_mentoring_model_users_manage_mm_meetings" checkbox_id should be checked
  And I check "cjs_mentoring_model_admin_manage_mm_milestones"
  And I press "Save and proceed to Add Content »"
  Then I should see "Homeland Template" within "div#title_div"
  Then I should see "DESCRIBE PLAN"
  Then I should see "CONFIGURE FEATURES"
  Then I should see "ADD CONTENT"
  Then I should see "Duration:" within "h3"
  Then I should see "Customize Goals"
  Then I should not see "Timeline"
  Then I should see "Customize Milestones"
  Then I should see "Add New Goal"
  Then I should see "Add Custom Milestone"
  Then I fill in "ada_mentoring_period_value" with "14"
  Then I press "Save" within "#cjs_mentoring_model_duration_form"
  Then I should see the flash "The Duration of the Mentoring Connection Plan Template has been updated successfully."
  Then I follow the back link
  Then I should see "Mentoring Connection Plan Templates" within "div#title_div"
  Then I should see "Homeland Template"
  Then I should see "2 Weeks"
  Then I should see "Facilitation Messages (Administrators)"
  Then I logout

@javascript @cross-browser
Scenario: Perform Other Actions on the page
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Albers Mentor Program" from the program selector
  Then I follow "Manage"
  Then I follow "Mentoring Connection Plan Templates"
  Then I follow "View"
  Then I should see "Albers Mentor Program Template (Default)"
  Then I follow the back link
  Then I follow "Delete"
  Then I should see "This template cannot be deleted as it is marked as default. If you want to delete this template, please make some other template as default."
  Then I ok alert
  Then I confirm popup
  Then I follow "Edit"
  And I follow "DESCRIBE PLAN"
  Then I should see "Albers Mentor Program Template (Default)"
  Then I fill in "cjs_title_field" with "Homeland Template"
  Then I fill in "mentoring_model_description" with "Awesome Description - This should get us started"
  Then I press "Save and Continue Later"
  Then I should see "Mentoring Connection Plan Templates" within "div#title_div"
  Then I should not see "Albers Mentor Program Template (Default)"
  Then I follow "View"
  Then I should see "Homeland Template (Default)"
  Then I should see "Awesome Description - This should get us started"
  And I follow "Manage" within "div#title_div"
  Then I should see "Edit"
  Then I should see "Duplicate"
  Then I should see "Delete"
  Then I should see "180 Days"
  Then I should see "Goals"
  Then I should see "Timeline"
  Then I follow "Duplicate"
  Then I should see "Duplicate Homeland Template"
  Then I fill in "cjs_title_field" with "homeland template"
  Then I press "Continue"
  Then I should see the flash "There is already a Mentoring Connection Plan Template with this title."
  Then I fill in "cjs_title_field" with "House Of Cards"
  Then I press "Continue"
  Then I should see "House Of Cards" within "div#title_div"
  Then I fill in "mentoring_model_description" with "Frank - Claire Underwood"
  Then I press "Save and Continue Later"
  Then I should see "Mentoring Connection Plan Templates" within "div#title_div"
  Then I should see "House Of Cards"
  Then I should see "Frank - Claire Underwood"
  Then I logout

 
@javascript @cross-browser
Scenario: Perform Other Actions on the page
  Given the current program is "primary":""
  When I have logged in as "ram@example.com"
  Then I enable "mentoring_connections_v2" feature as a super user
  When I hover over "my_programs_container"
  And I select "Albers Mentor Program" from the program selector
  Then I follow "Manage"
  Then I follow "Mentoring Connection Plan Templates"
  Then I follow "Duplicate"
  Then I should see "Duplicate Albers Mentor Program Template"
  Then I fill in "cjs_title_field" with "House Of Cards" within "div#remoteModal"
  Then I press "Continue"
  Then I should see "House Of Cards" within "div#title_div"
  Then I fill in "mentoring_model_description" with "Frank - Claire Underwood"
  Then I press "Save and Continue Later"
  Then I follow "Manage"
  Then I follow "Mentoring Connections"
  And I follow "Create New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>" 
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>" 
  And I select "House Of Cards" from "new_assignable_mentoring_model"
  And I click "#save_as_draft"
  Then I should see "name & example"
  Then I should see "House Of Cards"
  And I click on dropdown of the group "name & example"
  Then I should see "Assign Mentoring Connection Plan Template"
  Then follow "Assign Mentoring Connection Plan Template"
  Then I should see "Please assign a template for name & example"
  And I select "Albers Mentor Program Template (Default)" from "assign_mentoring_model"
  Then I press "Assign"
  Then I should see "The template information for the Mentoring Connection has been applied successfully"
  Then I logout


@javascript @cross-browser
Scenario:  in template when a new task is open and we delete an existing task/meeting add new action should appear
  Given the current program is "primary":""
  When I have logged in as "ram@example.com"
  Then I enable "mentoring_connections_v2" feature as a super user
  When I hover over "my_programs_container"
  And I select "Albers Mentor Program" from the program selector
  Then I follow "Manage"
  Then I follow "Mentoring Connection Plan Templates"
  Then I follow "Edit"
  And I follow "DESCRIBE PLAN"
  And I press "Save and proceed to Add Content »"
  And I should see "Add a new action"
  When I click ".add-action-opener"
  And I follow "New Task"
   
  And I fill in "mentoring_model_task_template_title" with "` Hello Task Title '"
  And I press "Save Task"
  Then I should see "` Hello Task Title '"
  When I click ".add-action-opener"
  And I follow "New Task"
     
  When I delete the task
  And I confirm popup
  And I should see "Add a new action"

@javascript @cross-browser
Scenario: Hybrid templates - creation and workflow
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Mentoring Connection Settings"
  Then I should see "Advanced Options"
  And I follow "Advanced Options"
  Then I should see "Enable hybrid templates"
  And I choose "program_hybrid_templates_enabled_true"
  And I press "Save"
  Then I follow "Manage"
  Then I follow "Mentoring Connection Plan Templates"
  Then I should see "Create a New Template"
  And I click "a.dropdown-toggle.btn-large"
  Then I follow "Create a New Hybrid Template"
  Then I should see "Create a New Hybrid Mentoring Connection Plan Template" within "div#title_div"
  Then I should see "DESCRIBE PLAN"
  Then I should see "CONFIGURE TEMPLATE"
  Then I fill in "cjs_title_field" with "albers mentor program template"
  Then I fill in "mentoring_model_description" with "Test hybrid templates description goes here"
  Then I follow "Proceed »"
  Then I should see "There is already a Mentoring Connection Plan Template with this title."
  Then I fill in "cjs_title_field" with "Test hybrid template"
  Then I follow "Proceed »"
  And I click "a.cjs-template-add"
  Then I press "Create"
  Then I should see "Same template is selected more than once"
  And I click "a.cjs-template-remove"
  Then I press "Create"
  Then I should see "Test hybrid template"
  When I follow "Manage" within "div#title_div"
  And I follow "Edit"
  Then I should see "DESCRIBE PLAN"
  And I should see "CONFIGURE TEMPLATE"
  And I should not see "ADD CONTENT"
  Then I logout

@javascript @cross-browser
Scenario: Check the default template shown in Tasks Status filter in groups lisitng page upon changing the default template.
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  When I hover over "my_programs_container"
  And I select "Albers Mentor Program" from the program selector
  Then I follow "Manage"
  Then I follow "Mentoring Connection Plan Templates"
  Then I follow "Create a New Template"
  Then I fill in "cjs_title_field" with "Homeland Template"
  Then I fill in "mentoring_model_description" with "Test hybrid templates description goes here"
  And I press "Save and proceed to Configure Features »"
  And I press "Save and proceed to Add Content »"
  And I follow the back link
  Then I check "Make Default" for the template with title "Homeland Template"
  Then I should see "Homeland Template (Default)"
  Then I follow "Manage"
  Then I follow "Connections"
  And I click on "Task Status" header
  Then I click "#cjs_custom_task_status_filter_popup"
  Then I should see "Homeland Template (Default)"
  When I click ".select2-choice"
  Then I should see "No matches found"