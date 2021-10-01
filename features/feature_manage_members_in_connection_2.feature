@javascript
Feature: Admin must be able to manage members in a connection

Background: creation of tasks for a mentoring connection template
  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  Then I enable admin audit logs
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
  Then the disabled "cjs_mentoring_model_users_manage_mm_tasks" checkbox_id should be checked
  And I check "cjs_mentoring_model_admin_manage_mm_milestones"
  And I check "cjs_mentoring_model_admin_manage_mm_goals"
  And I press "Save and proceed to Add Content »"
  And I should see "Add New Goal"
  When I click ".cjs_add_new_goal"
  Then I wait for remote Modal to be hidden
  And I should see "Add New Goal" within "div#remoteModal"
  And I fill in "mentoring_model_goal_template_title" with "Divergent"
  And I press "Save" within ".modal.in"
  Then I wait for remote Modal to be hidden
  Then I reload the page
  When I click "#cjs_add_milestone_template"
  And I should see "Add Custom Milestone" within "div#remoteModal"
  And I fill in "cjs_milestone_template_form_title_" with "Level 1"
  And I press "Save" within ".modal.in"
  Then I wait for remote Modal to be hidden

  Then I should see "Level 1"
  And I click ".cjs_show_on_collapse_milestone_template_handler"

  When I click ".add-action-opener"
  And I follow "New Task"

  And I fill in "mentoring_model_task_template_title" with "Pass the simulation"
  And I assign the task to "Mentor"
  And I check "mentoring_model_task_template_required"
  And I align the task to the goal "Divergent"
  And I press "Save Task"
  Then I should see "Pass the simulation"
  And I logout

@javascript @engagement_scenario
Scenario: Manage members must not be seen for PBE rejected connections

  Given the current program is "primary":"pbe"
  And pbe program has custom term
  When I have logged in as "ram@example.com"
  Then I enable admin audit logs
  And I follow "Manage"
  And I follow "Projects"
  And I follow "Rejected"
  Then I should see " Incorporate family values by watching Breaking Bad"
  And I follow "Incorporate family values by watching Breaking Bad"
  And I should not see "Manage Members"

@javascript @engagement_scenario @cross_browser
Scenario: Admin can replace members in an ongoing group connection when the previous mentor has not completed the task

  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Mentoring Connection Settings"
  And I choose "Group"
  And I press "Save"
  And I follow "Manage"
  And I follow "Mentoring Connections"
  And I follow "Create New Mentoring Connection"
  And I should see "Create a New Mentoring Connection" within "div#group_new"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"

  And I click "#create_and_publish"

  Then I should see "name & example"
  And I follow "name & example"
  And I fill in "confidentiality_audit_log_reason" with "Checking Connection"
  And I press "Proceed"

  And I follow "Manage Members"
  And I should see "Manage Members" within "div#remoteModal"
  Then I should see "Mentors(1)"
  Then I should see "Students(1)"
  Then I should see "Add Mentor"
  And I follow "Add Mentor"
  When I enter "mentor_a chronus" in "add_member_mentor" autocomplete it with "mentor_a chronus"
  And I choose Add "mentor"-assigned tasks
  And I press "Add"
  And I press "Save"
  And I follow "Manage Members"
  And I should see "Manage Members" within "div#remoteModal"
  Then I should see "Mentors(2)"
  Then I should see "Students(1)"
  Then I should see "name"
  Then I click on replace member "Good unique name"
  Then I fill in "mentor_b chronus" as replaced user
  Then I press "Replace member"
  And I press "Save"
  And I logout

  And I have logged in as "mentor_1@example.com"
  Then I follow "name & example"
  Then I filter tasks for "mentor_1@example.com"
  Then I should see "Pass the simulation"
  And I logout

  And I have logged in as "robert@example.com"
  Then I should not see "name & example"

@javascript @engagement_scenario
Scenario: Admin can remove members in an ongoing group connection - removing the tasks

  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Mentoring Connection Settings"
  And I choose "Group"
  And I press "Save"
  And I follow "Manage"
  And I follow "Mentoring Connections"
  And I follow "Create New Mentoring Connection"
  And I should see "Create a New Mentoring Connection" within "div#group_new"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"

  And I click "#create_and_publish"

  Then I should see "name & example"
  And I follow "name & example"
  And I fill in "confidentiality_audit_log_reason" with "Checking Connection"
  And I press "Proceed"

  And I follow "Manage Members"
  And I should see "Manage Members" within "div#remoteModal"
  Then I should see "Mentors(1)"
  Then I should see "Students(1)"
  Then I should see "Add Mentor"
  And I follow "Add Mentor"
  When I enter "mentor_a chronus" in "add_member_mentor" autocomplete it with "mentor_a chronus"
  And I choose Add "mentor"-assigned tasks
  And I press "Add"
  And I press "Save"
  And I follow "Manage Members"
  And I should see "Manage Members" within "div#remoteModal"
  Then I should see "Mentors(2)"
  Then I should see "Students(1)"
  Then I should see "name"
  Then I click on remove member "Good unique name"
  And I choose "group_remove_member_option_0_3"
  Then I press "Remove member"
  And I press "Save"
  And I follow "Manage Members"
  And I should see "Manage Members" within "div#remoteModal"
  Then I should see "Mentors(1)"
  Then I should see "Students(1)"
  And I press "Save"
  And I logout

  And I have logged in as "mentor_0@example.com"
  Then I follow "name & example"
  Then I filter tasks for "Unassigned"
  Then I should not see "Pass the simulation"
  And I logout

  And I have logged in as "robert@example.com"
  Then I should not see "name & example"

@javascript @engagement_scenario @cross_browser @enable_caching
Scenario: Admin can remove members in an ongoing group connection while leaving tasks unassigned

  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"

  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I should see "Enable third role"
  Then I should see the radio button "program_third_role_enabled_false" selected
  Then I click "#program_third_role_enabled_true"
  And I press "Save"

  And I follow "Manage"
  And I follow "User Views"
  And I add "Teacher" role to "arun@albers.com" from admin users page
  Then I reindex model "User"
  Then I follow "Manage"
  And I follow "Program Settings"
  And I follow "Mentoring Connection Settings"
  And I choose "Group"
  And I press "Save"
  And I follow "Manage"
  And I follow "Mentoring Connections"
  And I follow "Create New Mentoring Connection"
  And I should see "Create a New Mentoring Connection" within "div#group_new"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"

  And I click "#create_and_publish"

  Then I should see "name & example"
  And I follow "name & example"
  And I fill in "confidentiality_audit_log_reason" with "Checking Connection"
  And I press "Proceed"

  And I follow "Manage Members"
  And I should see "Manage Members" within "div#remoteModal"
  Then I should see "Mentors(1)"
  Then I should see "Students(1)"
  Then I should see "Teachers(0)"
  Then I should see "Add Mentor"
  And I follow "Add Mentor"
  When I enter "mentor_a chronus" in "add_member_mentor" autocomplete it with "mentor_a chronus"
  And I choose Add "mentor"-assigned tasks
  And I press "Add"
  And I press "Save"
  And I follow "Manage Members"
  And I should see "Manage Members" within "div#remoteModal"
  Then I should see "Mentors(2)"
  Then I should see "Students(1)"
  Then I should see "Teachers(0)"
  Then I should see "name"
  Then I click on remove member "Good unique name"
  And I choose "group_remove_member_option_1_3"
  Then I press "Remove member"
  And I follow "Add Student"
  When I enter "student_b example" in "add_member_student" autocomplete it with "student_b example"
  And I press "Add"
  And I press "Save"
  Then I should see "Mentor (1)" within "#group_info"
  Then I should see "Students (2)" within "#group_info"
  Then I should see "Teachers (0)" within "#group_info"

  And I follow "Manage Members"
  And I should see "Manage Members" within "div#remoteModal"
  Then I should see "Mentors(1)"
  Then I should see "Students(2)"
  Then I should see "Teachers(0)"
  Then I click on remove member "student example"
  Then I press "Remove member"
  And I follow "Add Teacher"
  When I enter "arun albers" in "add_member_teacher" autocomplete it with "arun albers"
  And I press "Add"
  And I press "Save"
  Then I should see "Mentor (1)" within "#group_info"
  Then I should see "Student (1)" within "#group_info"
  Then I should see "Teacher (1)" within "#group_info"
  And I logout

  And I have logged in as "mentor_0@example.com"
  Then I follow "name & example"
  Then I filter tasks for "Unassigned"
  Then I should see "Pass the simulation"
  And I logout

@javascript @engagement_scenario
Scenario: Admin can add teachers in one to one mentoring
  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"

  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I should see "Enable third role"
  Then I should see the radio button "program_third_role_enabled_false" selected
  Then I click "#program_third_role_enabled_true"
  And I press "Save"

  And I follow "Mentoring Connection Settings"
  And I choose "program_allow_one_to_many_mentoring_false"
  And I press "Save"
  And I follow "Manage"
  And I follow "User Views"
  And I add "Teacher" role to "arun@albers.com" from admin users page
  Then I reindex model "User"

  And I follow "Manage"
  And I follow "Mentoring Connections"
  And I follow "chronus & example"
  And I fill in "confidentiality_audit_log_reason" with "Checking Connection"
  And I press "Proceed"

  And I follow "Manage Members"
  Then I should not see "Add Mentor"
  Then I should not see "Add Student"
  Then I should see "Teachers(0)"
  Then I follow "Add Teacher"
  When I enter "arun albers" in "add_member_teacher" autocomplete it with "arun albers"
  And I press "Add"
  Then I follow "Remove"
  Then I press "Remove member"
  Then I follow "Add Teacher"
  When I enter "arun albers" in "add_member_teacher" autocomplete it with "arun albers"
  And I press "Add"
  And I press "Save"
  Then I should not see "Add Teacher"