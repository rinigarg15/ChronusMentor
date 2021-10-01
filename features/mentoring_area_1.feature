@javascript
Feature: Mentoring Connections V2

Background: Enable Mentoring Connections V2 Feature
  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  Then I enable admin audit logs
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user
  And I logout
  And I stub chronus s3 utils

@javascript @cross-browser
Scenario: Creating a new Group With Feature Mentoring Connections V2 Enabled With Goals, Tasks and Milestones Feature Enabled at end-user level.
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  Then I follow "CONFIGURE FEATURES"
  And I check "cjs_mentoring_model_users_manage_mm_milestones"
  And I check "cjs_mentoring_model_users_manage_mm_goals"

  And I press "Save and proceed to Add Content »"
  And I should see "Add New Goal"

  When I click ".cjs_add_new_goal"

  And I should see "Add New Goal" within "#remoteModal"
  And I fill in "mentoring_model_goal_template_title" with "Hello Title Goal"
  And I press "Save" within ".modal.in"
  Then I wait for remote Modal to be hidden

  When I click ".add-action-opener"
  And I follow "New Task"

  And I fill in "mentoring_model_task_template_title" with "Hello Task Title"
  And I press "Save Task"
  Then I wait for remote Modal to be hidden
  Then I should see "Hello Task Title"
  And I should see "Customize Goals"
  And I should not see "Add Custom Milestone"
  And I follow "CONFIGURE FEATURES"
  And I check "cjs_mentoring_model_admin_manage_mm_milestones"
  Then I confirm popup
  And I press "Save and proceed to Add Content »"
  And I should see "Add New Goal"
  And I should see "Customize Goals"
  And I should see "Customize Milestones"
  And I create milestone template with title "Hello Milestone Title"
  Then I click by xpath "//div[contains(text(),'Hello Milestone Title')]"
  And I create milestone template with title "Milestone 4"
  And I create required task template with title "Milestone 4 Task" for "Milestone 4" milestone
  Then I click by xpath "//div[contains(text(),'Milestone 4')]"
  And I create task template with title "Milestone 4 Task 2" for "Milestone 4" milestone
  And I create milestone template with title "Milestone 3"
  And I create task template with title "Milestone 3 Task" for "Milestone 3" milestone
  And I create milestone template with title "Milestone 2"
  And I create required task template with title "Milestone 2 Task" for "Milestone 2" milestone
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
  Then I should see "View 1 completed milestone"
  Then I should not see "Default Milestone"
  Then I should see milestone "Milestone 2" not completed
  Then I should see milestone "Milestone 3" completed
  Then I should see milestone "Milestone 4" not completed
  Then I should see milestone "Hello Milestone Title" not completed
  Then I should see "Hello Title Goal"
  Then I click ".cjs_show_completed_milestones"
  Then I should see milestone "Default Milestone" completed
  Then I should see "Hello Task Title"
  And I follow "Hello Title Goal"
  Then I should not see "Add New Goal"
  And I logout as super user
  And I logout

  Given the current program is "primary":"albers"
  When I have logged in as "robert@example.com"
  Then I should see "name & example"
  And I follow "name & example"
  Then I should see "View 1 completed milestone"
  Then I should see "Hello Milestone Title"
  And I should see "Add Milestone"
  Then I click ".cjs_show_completed_milestones"
  Then I should see "Default Milestone"
  Then I should see "Hello Task Title"
  Then I should see milestone "Milestone 4" not completed
  Then I should see "Milestone 4 Task"
  Then I should see "Milestone 4 Task 2"
  Then I mark the task "Hello Task Title" complete
  Then I mark the task "Milestone 4 Task" complete
  Then I refresh the page
  Then I should see "View 1 completed milestone"
  Then I should see "Hello Milestone Title"
  Then I click ".cjs_show_completed_milestones"
  Then I should see "Default Milestone"
  Then I should not see "Hello Task Title"
  Then I should see milestone "Milestone 4" completed
  Then I should see "Milestone 4 Task"
  Then I should see "Milestone 4 Task 2"
  Then I mark the task "Milestone 4 Task 2" complete
  Then I refresh the page
  Then I should see milestone "Milestone 4" completed
  Then I should not see "Milestone 4 Task"
  Then I should not see "Milestone 4 Task 2"

  Then I should see "View Tasks:"
  When I click "#connection_filter"
  Then I should see "#tasks_by_milestone_filter" selected
  Then I choose "tasks_by_due_date_filter"
  Then I click ".cjs_filter_submit_btn"

  And I should see "Completed Tasks"
  And I should see no "completed" tasks hidden
  Then I follow "completed" tasks

  And I should see no "completed" tasks
  And I should see "Overdue Tasks"
  And I should see no "overdue" tasks
  Then I follow "overdue" tasks
  And I should see no "overdue" tasks hidden
  And I should see "Upcoming Tasks"
  And I should see no "upcoming" tasks
  Then I follow "upcoming" tasks
  And I should see no "upcoming" tasks hidden
  And I should see "Other Pending Tasks"
  And I should see "Hello Task Title"
  Then I follow "pending" tasks
  And I should see "Hello Task Title" hidden

  Then I follow "upcoming" tasks
  And I should see no "upcoming" tasks
  And I follow "Add New Task"

  And I fill in "mentoring_model_task_title" with "User Upcoming Task"
  And I press "Save Task"

  And I should see "User Upcoming Task"
  And I should see "Completed Tasks"
  And I should see no "completed" tasks hidden
  And I should see "Overdue Tasks"
  And I should see no "overdue" tasks
  And I should see "Upcoming Tasks"
  And I should see "User Upcoming Task"
  And I should see "Other Pending Tasks"
  And I should see "Hello Task Title" hidden

  Then I should see "View Tasks:"
  When I click "#connection_filter"

  Then I should see "#tasks_by_due_date_filter" selected
  Then I choose "tasks_by_milestone_filter"
  Then I click ".cjs_filter_submit_btn"
  Then I should see "Hello Milestone Title"
  Then I should see "Default Milestone"
  Then I should see "Hello Task Title"
  And I should see "User Upcoming Task"

  And I follow "Add New Task"

  And I fill in "mentoring_model_task_title" with "End User Task"
  And I press "Save Task"

  And I should see "End User Task"
  When I click ".cjs_add_new_custom_milestone"

  Then I should see "Add Custom Milestone" within "#remoteModal"
  And I fill in "cjs_mentoring_model_milestone_title_" with "Hello Milestone Title Again"
  And I press "Save" within ".modal.in"
  Then I wait for remote Modal to be hidden

  Then I should see "Hello Title Goal"
  And I follow "Hello Title Goal"
  Then I should see "Add New Goal"
  When I click ".cjs_add_new_goal"
  Then I should see "Add New Goal" within "#remoteModal"
  And I fill in "mentoring_model_goal_title_" with "Hello Title Goal Again"
  And I press "Save" within ".modal.in"
  Then I wait for remote Modal to be hidden
  Then I should see "Hello Title Goal Again"

  And I logout