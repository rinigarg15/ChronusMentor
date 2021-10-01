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
  Then I should see "Cancel"
  #And I wait for animation to complete

  And I fill in "mentoring_model_goal_template_title" with "Divergent"
  And I press "Save" within "#cjs-mentoring-model-goal-template-form-new"
  #Then I wait for remote Modal to be hidden
  Then I should see "Divergent"

  When I click "#cjs_add_milestone_template"
  Then I should see "Cancel"
  And I fill in "cjs_milestone_template_form_title_" with "Level 1" within "#new_mentoring_model_milestone_template"
  And I press "Save" within "#new_mentoring_model_milestone_template"
  Then I should see "Level 1"
  #Then I wait for remote Modal to be hidden

  Then I should see "Level 1"
  And I click ".cjs_show_on_collapse_milestone_template_handler"

  When I click ".add-action-opener"
  And I follow "New Task"
  Then I should see "Assign To"
  And I fill in "mentoring_model_task_template_title" with "Pass the simulation" within "#cjs_new_mentoring_model_task_template_new"
  And I assign the task to "Mentor"
  And I check "mentoring_model_task_template_required"
  And I align the task to the goal "Divergent"
  And I press "Save Task"
  And I wait for ajax to complete
  Then I should see "Pass the simulation"
  And I logout

@javascript @engagement_scenario @cross_browser

Scenario: Admin can replace a member in a one-one mentoring connection but cannot add or remove members

  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
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
  And I fill in "mentor" field of "primary":"albers" with "Mentor Studenter <mentrostud@example.com>"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"
  And I click "#create_and_publish"
  Then I should see "Studenter & example"
  And I "Manage Members" for the connection "Studenter & example"
  Then I should see "Mentors(1)"
  Then I should see "Students(1)"
  Then I should see "example"
  Then I click on replace member "student example"
  And I fill in "replace_member" with "Mentor Studenter <mentrostud@example.com>"
  Then I press "Replace member"
  And I press "Save"
  Then I should see "The user Mentor Studenter is already part of the mentoring connection as 'Mentor' and cannot be assigned 'Student' role unless removed from the mentoring connection first."
  Then I click on replace member "Mentor Studenter"
  Then I fill in "mentor_a chronus" as replaced user
  Then I press "Replace member"
  And I press "Save"
  And I logout
  And I have logged in as "mentor_0@example.com"
  Then I follow "Studenter & example"
  Then I filter tasks for "mentor_0@example.com"
  Then I should see "Pass the simulation"


@javascript @engagement_scenario
Scenario: Manage members must not be seen for closed connections

  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Mentoring Connections"
  And I follow "Closed"
  Then I should see "mentor & example"
  And I should not see "Manage Members" in the drop down action for "mentor & example"
  And I follow "Visit Mentoring Connection"
  Then I should not see "Manage Members"

@javascript @engagement_scenario
Scenario: Admin can add members to an ongoing group connection with no tasks assigned

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
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"

  And I click "#create_and_publish"

  Then I should see "name & example"
  And I follow "name & example"
  And I fill in "confidentiality_audit_log_reason" with "Checking Connection"
  And I press "Proceed"

  And I follow "Manage Members"
  Then I should see "Mentors(1)"
  Then I should see "Students(1)"
  Then I should see "Add Mentor"
  And I follow "Add Mentor"
  When I enter "mentor_a chronus" in "add_member_mentor" autocomplete it with "mentor_a chronus"
  And I choose "Do not add any tasks" for "mentor" role in "primary":"albers"
  And I press "Add"
  And I press "Save"
  And I logout
  When I have logged in as "mentor_0@example.com"
  Then I follow "name & example"
  And I follow "Plan"
  Then I filter tasks for "mentor_0@example.com"
  Then I should not see "Pass the simulation"
  Then I filter tasks for "robert@example.com"
  Then I should see "Pass the simulation"

@javascript @engagement_scenario @cross_browser
Scenario: Admin can add members to an ongoing group connection with default tasks assigned

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
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"

  And I click "#create_and_publish"

  Then I should see "name & example"
  And I follow "name & example"
  And I fill in "confidentiality_audit_log_reason" with "Checking Connection"
  And I press "Proceed"

  And I follow "Manage Members"
  Then I should see "Mentors(1)"
  Then I should see "Students(1)"
  Then I should see "Add Mentor"
  And I follow "Add Mentor"
  When I enter "mentor_a chronus" in "add_member_mentor" autocomplete it with "mentor_a chronus"
  And I choose Add "mentor"-assigned tasks
  And I press "Add"
  And I press "Save"
  And I logout
  When I have logged in as "mentor_0@example.com"
  Then I follow "name & example"
  Then I filter tasks for "mentor_0@example.com"
  Then I should see "Pass the simulation"