Feature:  Users must be able to filter tasks in the mentoring area

@javascript @engagement_scenario @cross_browser
Scenario: When template without milestones is used, the user must not see filter tasks

  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  Then I enable "mentoring_connections_v2" feature as a super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Mentoring Connection Settings"
  And I choose "One-on-one"
  And I press "Save"
  And I follow "Manage"
  And I follow "Mentoring Connections"
  Then I should see "Ongoing"
  And I follow "Ongoing"
  And I follow "Create New Mentoring Connection"
  Then I should see "Create a New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>" within "#new_group"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>" within "#new_group"
  And I click "#create_and_publish"
  Then I should see "name & example"
  And I logout
  When I have logged in as "robert@example.com"
  Then I follow "name & example"
  Then I should not see "Show Tasks For"

  #Automatically expand members on One-on-one Mentoring
  And I should see "Members (2)" within "#SidebarRightContainer"
  And I should see "Mentor (1)" within "#SidebarRightContainer"
  And I should see "Good unique name"
  And I should see "Student (1)" within "#SidebarRightContainer"
  And I should see "student example"

  Then I follow "Plan"
  Then I follow "View Tasks: Assigned to all"
  Then I should see "Show Completed Tasks"

@javascript @engagement_scenario
Scenario: Filter tasks when there are less than two members in the connection must be showing all the tasks by default and preserve the tasks filter across sessions

  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user
  And I logout
  And I stub chronus s3 utils
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  Then I follow "CONFIGURE FEATURES"
  Then the disabled "cjs_mentoring_model_admin_manage_mm_tasks" checkbox_id should be checked
  And I check "cjs_mentoring_model_admin_manage_mm_milestones"
  And I check "cjs_mentoring_model_admin_manage_mm_goals"
  And I press "Save and proceed to Add Content »"
  And I should see "Add New Goal"
  When I click ".cjs_add_new_goal"
  And I should see "Cancel"
  And I fill in "mentoring_model_goal_template_title" with "Divergent" within "#cjs-mentoring-model-goal-template-form-new"
  And I press "Save" within "#cjs-mentoring-model-goal-template-form-new"
  Then I should see "Divergent"

  When I click "#cjs_add_milestone_template"
  And I should see "Cancel"
  And I fill in "cjs_milestone_template_form_title_" with "Level 1" within "#new_mentoring_model_milestone_template"
  And I press "Save" within "#new_mentoring_model_milestone_template"
  Then I should see "Level 1"

  Then I should see "Level 1"
  And I follow "Expand or Collapse" within ".cjs_milestone_template_entity"

  When I click ".add-action-opener"
  And I follow "New Task"
  Then I should see "Assign To"
  And I fill in "mentoring_model_task_template_title" with "Create simulation tests" within "#cjs_new_mentoring_model_task_template_new"
  And I fill in CKEditor "cjs-mentoring-model-task-template-description-new" with "<a href='/ck_attachments/1'>Attachment Link</a>"
  And I assign the task to "Mentor"
  And I check "mentoring_model_task_template_required"
  And I align the task to the goal "Divergent"
  And I press "Save Task"
  And I wait for ajax to complete
  Then I should see "Create simulation tests"
  Then I should see "Add a new action"
  And I follow "Add a new action"
  Then I should see "New Task"
  And I follow "New Task"
  Then I should see "Assign To"
  And I fill in "mentoring_model_task_template_title" with "Pass the simulation" within "#cjs_new_mentoring_model_task_template_new"
  And I assign the task to "Student"
  And I check "mentoring_model_task_template_required"
  Then I set a harcoded value for deadline
  And I align the task to the goal "Divergent"
  And I press "Save Task"
  Then I wait for ajax to complete
  Then I should see the harcoded date
  Then I should see "Create simulation tests"
  Then I should see "Pass the simulation"
  And I follow "Manage"
  And I follow "Mentoring Connection"
  And I follow "Create New Mentoring Connection"
  Then I should see "Create a New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>" within "#new_group"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>" within "#new_group"
  And I click "#create_and_publish"
  Then I should see "name & example"
  And I follow "name & example"
  Then I should see "View Tasks:"
  Then I should see "Create simulation tests"
  Then I click on text "Create simulation tests"
  And I should see "Attachment Link" within "a.cjs_android_download_ckeditor_files"
  Then I should see "Pass the simulation"
  And I logout
  And I have logged in as "robert@example.com"
  Then I should see "name & example"
  And I follow "name & example"
  Then I should see "View Tasks:"
  And I follow "View Tasks: By Milestones, Assigned to all"
  Then I should see "#tasks_by_milestone_filter" selected
  Then I choose "tasks_by_due_date_filter"
  And I follow "Apply"
  Then I should see "Create simulation tests"
  Then I should see "Pass the simulation"
  Then I filter tasks for "robert@example.com"
  Then I should see "Create simulation tests"
  Then I should see "Assigned to Good unique name"
  And I logout                                                                                                                                                                                          
  And I have logged in as "robert@example.com"
  Then I should see "name & example"
  And I follow "name & example"
  Then I should see "Assigned to Good unique name"
  When I click "#connection_filter"
  Then I should see "#tasks_by_due_date_filter" selected

@javascript @engagement_scenario @cross_browser
Scenario: Filter tasks when there are greater than two members but less than 25 members in the connection. Each member must see their respective tasks

  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user
  And I logout
  And I stub chronus s3 utils
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Mentoring Connection Settings"
  And I choose "Group"
  And I press "Save"
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  Then I follow "CONFIGURE FEATURES"
  Then the disabled "cjs_mentoring_model_admin_manage_mm_tasks" checkbox_id should be checked
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
  Then I should see "Level 1"

  When I click ".add-action-opener"
  And I follow "New Task"
  Then I should see "Assign To"
  And I fill in "mentoring_model_task_template_title" with "Create simulation tests" within "#cjs_new_mentoring_model_task_template_new"
  And I assign the task to "Mentor"
  And I check "mentoring_model_task_template_required"
  And I align the task to the goal "Divergent"
  And I press "Save Task"
  And I wait for ajax to complete
  Then I should see "Create simulation tests"
  Then I should see "Add a new action"
  And I follow "Add a new action"
  Then I should see "New Task"
  And I follow "New Task"
  Then I should see "Assign To"
  And I fill in "mentoring_model_task_template_title" with "Pass the simulation" within "#cjs_new_mentoring_model_task_template_new"
  And I assign the task to "Student"
  And I check "mentoring_model_task_template_required"
  And I align the task to the goal "Divergent"
  And I press "Save Task"
  Then I should see "Create simulation tests"
  Then I should see "Pass the simulation"
  And I follow "Manage"
  And I follow "Mentoring Connection"
  And I follow "Create New Mentoring Connection"
  Then I should see "Create a New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>" within "#new_group"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>" within "#new_group"
  And I click "#create_and_publish" within "#new_group"
  Then I should see "name & example"
  And I "Manage Members" for the connection "name & example"
  And I follow "Add Mentor"
  When I enter "mentor_a" in "add_member_mentor" autocomplete it with "mentor_a chronus <mentor_0@example.com"
  And I choose "Do not add any tasks" for "mentor" role in "primary":"albers"
  And I press "Add"
  Then I wait for ajax to complete
  And I press "Save"
  Then I wait for ajax to complete
  And I follow "name & example"
  Then I should see "View Tasks:"
  Then I should see "Create simulation tests"
  Then I should see "Pass the simulation"
  And I logout
  And I have logged in as "robert@example.com"
  Then I should see "name & example"
  And I follow "name & example"

  Then I should see "View Tasks:"
  Then I should see "Create simulation tests"
  Then I should not see "Pass the simulation"
  Then I filter tasks for "all"
  Then I should see "Create simulation tests"
  Then I should see "Pass the simulation"
  And I logout
