@javascript
Feature: Mentoring Connections V2

Background: Enable Mentoring Connections V2 Feature
  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user
  And I logout
  And I stub chronus s3 utils

@javascript @p2 @wip @cross-browser
Scenario: Editing user tasks, goals and milestones. Tasks can be marked complete.
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  And I follow "CONFIGURE FEATURES"
  Then the disabled "cjs_mentoring_model_users_manage_mm_tasks" checkbox_id should be checked
  And I check "cjs_mentoring_model_users_manage_mm_milestones"
  And I check "cjs_mentoring_model_users_manage_mm_goals"
  And I press "Save and Continue Later"

  And I follow "Manage"
  Then I follow "Mentoring Connections"
  And I follow "Create New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"
  
  And I click "#create_and_publish"
  
  Then I should see "name & example"
  And I logout

  Given the current program is "primary":"albers"
  When I have logged in as "rahim@example.com"
  Then I follow "My Mentoring Connections"
  Then I should see "name & example"
  And I follow "name & example"
  And I follow "Goals"
  And I should see "Add New Goal"
  When I click ".cjs_add_new_goal"
  
  And I fill in "mentoring_model_goal_title_" with "USER GOAL TITLE"
  And I press "Save" within ".modal.in"
  Then I wait for remote Modal to be hidden
  Then I should see "USER GOAL TITLE"
  When I click ".edit_goal"
  And I edit the user goal
  And I press "Save" within ".modal.in"
  Then I wait for remote Modal to be hidden
  Then I should see "EDITED GOAL TITLE"
  And I should not see "USER GOAL TITLE"
  When I click ".edit_goal"
  When I click ".delete_goal"
  And I confirm popup
  Then I should see "EDITED GOAL TITLE" hidden
  When I click ".cjs_add_new_goal"
  
  And I fill in "mentoring_model_goal_title_" with "USER GOAL TITLE"
  And I press "Save" within ".modal.in"
  Then I wait for remote Modal to be hidden
  Then  follow the back link
  Then I should see "Add Milestone"

  When I click ".cjs_add_new_custom_milestone"
  
  And I fill in "cjs_mentoring_model_milestone_title_" with "USER MILESTONE TITLE"
  And I press "Save" within ".modal.in"
  Then I wait for remote Modal to be hidden
 
  Then I should see "USER MILESTONE TITLE"
  When I click ".cjs_milestone_description_handler"
  When I click ".cjs_edit_milestone"
  And I edit the user milestone
  And I press "Save" within ".modal.in"
  Then I wait for remote Modal to be hidden
  Then I wait for ajax to complete
  Then I should see "EDITED MILESTONE TITLE"
  And I should not see "USER MILESTONE TITLE"
  When I click ".cjs_milestone_remove_link"
  And I confirm popup
  Then I wait for ajax to complete
  
  
  Then I should see "EDITED MILESTONE TITLE" hidden
  When I click ".cjs_add_new_custom_milestone"
  
  And I fill in "cjs_mentoring_model_milestone_title_" with "USER MILESTONE TITLE"
  
  And I press "Save" within ".modal.in"
  Then I wait for remote Modal to be hidden
  
  Then I should see "USER MILESTONE TITLE"
  Then I open the last created milestone
  When I click ".add-action-opener"
  And I follow "Add New Task"
  
  And I fill in "mentoring_model_task_title" with "USER TASK TITLE"
  And I should see ".cjs-task-required-checkbox-true" hidden
  When I check "mentoring_model_task_required"
  Then I should see "Apply to Goal"
  And I press "Save"
  Then I should see "USER TASK TITLE"
  And I click ".cjs-task-title"
  Then I click on dropdown toggle within ".cjs-edit-content-header"
  Then I follow "Edit" within ".cjs-edit-content-header"
  And I fill in "mentoring_model_task_title" with "EDITED TASK TITLE"
  And I press "Save Task"
  Then I should see "EDITED TASK TITLE"
  And I should not see "USER TASK TITLE"
  When I click ".cjs-task-title"
  Then I click on dropdown toggle within ".cjs-edit-content-header"
  Then I follow "Delete" within ".cjs-edit-content-header"
  And I confirm popup
  Then I should not see "EDITED TASK TITLE"
  When I follow "See all »" within ".cjs_side_pane_mentoring_model_goals"
  Then I should see "USER GOAL TITLE"
  And I should see "Add New Task"
  When I follow "Add New Task"
  
  And I fill in "mentoring_model_task_title" with "USER TASK"
  And the disabled "mentoring_model_task_required" checkbox_id should be checked
  And I should see "Apply to Milestone"
  And I should see "USER MILESTONE TITLE"
  And I press "Save Task"
  Then I follow the back link
  Then I should see "USER MILESTONE TITLE"
  And I should see "USER TASK"
  #And I mark the task complete
  And I logout

@javascript @cross-browser
  Scenario: Draft Engagement Surveys
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  Then I follow "Mentoring Connections"
  And I should see "Survey Responses"
  And I follow "mentor_b chronus"
  And I follow "Mentoring Connections (2)"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  And I follow "ADD CONTENT"
  When I click ".add-action-opener"
  And I follow "Add a Survey"
  And I fill in "mentoring_model_task_template_title" with "SURVEY TASK TITLE"
  And I assign the task to "Mentor"
  And I choose the survey "Partnership Effectiveness"
  And I press "Save Task"
  And I logout as super user
  And I follow "Manage"
  Then I follow "Mentoring Connections"
  And I follow "Create New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"
  
  And I click "#create_and_publish"
  
  And I should see "Survey Responses"
  And I should see "Survey Responses"
  And I should see "No response yet"
  Then I follow "More"
  
  And I follow "Good unique name"
  And I follow "Mentoring Connections (2)"
  And I should see "Survey Responses"
  And I should see "No response yet"
  And I follow "Work on Behalf"

  And I hover on tab "My Mentoring Connections"
  And I follow "name & example"
  And I follow "Partnership Effectiveness"
  Then I fill the answers "'Good', 'trial 1', 'trial 2'" of "Partnership Effectiveness"
  Then I follow "Save as draft"
  And I should see "Draft"
  Then I follow "Home"
  And I should see "Complete Surveys"
  Then I should see "Partnership Effectiveness"

  Then I follow "Complete Survey"
  Then I should see the answer "trial 1" for the question "What is going well in your mentoring partnership?"
  Then I press "Submit"
  Then I should see "Thanks for completing Partnership Effectiveness"