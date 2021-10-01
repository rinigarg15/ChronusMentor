@javascript @cross-browser
Feature: Mentoring Connections V2

Background: Enable Mentoring Connections V2 Feature
  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  #And I select "Primary Organization" from the program selector
  Given the current program is "primary":""
  Then I enable "mentoring_connections_v2" feature as a super user
  And I logout
  And I stub chronus s3 utils

@javascript
Scenario: Enabling meetings allows admins to add meeting action item and end-users can set up meeting.
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  Then I enable admin audit logs
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  And I follow "CONFIGURE FEATURES"
  And I check "cjs_mentoring_model_users_manage_mm_meetings"
  And I press "Save and proceed to Add Content »"
  Then I should see "Add a new action"
  When I click ".add-action-opener"
  Then I should see "Set up a Meeting"
  And I follow "Set up a Meeting"
  And I press "Save Task"
  Then I should see "Set Up Meeting"
  Then I hover over class "cjs-task-template-title"
  Then I click on dropdown toggle within ".cjs-task-template-header"
  Then I follow "Edit"
  Then the "mentoring_model_task_template_title" field should contain "Set Up Meeting"
  And I fill in "mentoring_model_task_template_title" with "EDITED MEETING TITLE"
 
  And I press "Save Task"
  Then I should see "EDITED MEETING TITLE"
  And I should not see "Set Up Meeting"
  When I delete the task
  And I confirm popup
  Then I should not see "EDITED TASK"
  When I click ".add-action-opener"
  And I follow "Set up a Meeting"
  And I fill in "mentoring_model_task_template_title" with "MEETING TASK TITLE"
  And I press "Save Task"
  Then I wait for ajax to complete
  Then I should see "MEETING TASK TITLE"
  And I should see "Schedule a Meeting"

  When I follow "Manage"
  Then I follow "Mentoring Connections"
  And I follow "Create New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"
  
  And I click "#create_and_publish"
  
  And I should see "Tasks Progress"
  And I follow "name & example"
  And I fill in "confidentiality_audit_log_reason" with "Checking Connection"
  And I press "Proceed"
  Then I should see "MEETING TASK TITLE"
  And I logout

  Given the current program is "primary":"albers"
  When I have logged in as "robert@example.com"
  Then I should see "name & example"
  And I follow "name & example"
  Then I should see "MEETING TASK TITLE"
  Then the checkbox for task "MEETING TASK TITLE" should not be checked
  And I should see "Set up a meeting"
  When I follow "Set up a meeting"
  And I fill in "new_meeting_title" with "INTRODUCTION MEETING"
  And I check "meeting_recurrent"
  And I should see "month" within ".cjs-repeat-every-help"
  And I select "Daily" from "meeting_schedule_rule"
  And I should see "day" within ".cjs-repeat-every-help"
  And I select "Weekly" from "meeting_schedule_rule"
  And I should see "week" within ".cjs-repeat-every-help"
  And I select "Monthly" from "meeting_schedule_rule"
  And I should see "month" within ".cjs-repeat-every-help"
  And I fill in "meeting_date" with a date 20 days from now
  Then I trigger change event on "meeting_date" without browserstack
  Then I wait for ajax to complete
  And I press "Create"
  Then I wait for ajax to complete
  Then I should see "INTRODUCTION MEETING"
  Then I follow "Plan"
  Then the checkbox for task "MEETING TASK TITLE" should be checked
  
  And I logout

  # The non owner member should see the RSVP
  Given the current program is "primary":"albers"
  When I have logged in as "rahim@example.com"
  Then I should see "name & example"
  And I follow "name & example"
  And I follow "Plan"
  Then I should see "MEETING TASK TITLE"
  And I should see "Set up a meeting"
  And I logout

@javascript @p2
Scenario: Enabling user goals should allow admins to add goal plan action item and end-users can create goal plan
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  Then I enable admin audit logs
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  And I follow "CONFIGURE FEATURES"
  And I check "cjs_mentoring_model_users_manage_mm_goals"
  Then the disabled "cjs_mentoring_model_users_manage_mm_tasks" checkbox_id should be checked
  And I press "Save and proceed to Add Content"
  When I click ".add-action-opener"
  Then I should see "Create Goal Plan"
  And I follow "Create Goal Plan"
  
  And I fill in "mentoring_model_task_template_title" with "TASK WITH GOAL PLAN"
  And I press "Save Task"
  Then I should see "TASK WITH GOAL PLAN"
  And I should see "Create Goal Plan"

  When I follow "Manage"
  Then I follow "Mentoring Connections"
  And I follow "Create New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"
  
  And I click "#create_and_publish"
  
  And I should see "Goals Progress"
  And I should see "Tasks Progress"
  And I follow "name & example"
  And I fill in "confidentiality_audit_log_reason" with "Checking Connection"
  And I press "Proceed"
  Then I should see "TASK WITH GOAL PLAN"
  And I logout

  Given the current program is "primary":"albers"
  When I have logged in as "robert@example.com"
  Then I should see "name & example"
  And I follow "name & example"
  Then I should see "TASK WITH GOAL PLAN"
  And I should see "Create Goal Plan"
  When I follow "Create Goal Plan"
  And I should see "Add New Goal"
  When I follow "Add New Goal"
 
  And I fill in "mentoring_model_goal_title_" with "User goal plan"
  And I press "Save" within ".modal.in"
  Then I wait for remote Modal to be hidden
  Then I wait for ajax to complete
  Then I should see "User goal plan"
  And I logout

@javascript
Scenario: Engagement Surveys
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  Then I follow "Mentoring Connections"
  And I should see "Survey Responses"
  And I follow "mentor_b chronus"
  And I follow "Ongoing mentoring connections"
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
  And I should see "Tasks Completed"
  And I should see "0/1"
  And I should see "No response yet"
  Then I follow "More"
  
  And I follow "Good unique name"
  And I follow "Ongoing mentoring connections"
  And I should see "Survey Responses"
  And I should see "No response yet"
  And I follow "Work on Behalf"

  And I hover on tab "My Mentoring Connections"
  And I follow "name & example"
  And I follow "Partnership Effectiveness"
  Then I submit the answers "'Good', 'trial 1', 'trial 2'" of "Partnership Effectiveness"
  And I follow "Switch back to Freakin Admin"
  And I follow "Mentors" tab
  And I follow "Good unique name"
  And I follow "Ongoing mentoring connections"
  And I should see "Survey Responses"
  And I should not see "No response yet"
  And I see survey details "Partnership Effectivenesson" today
  And I follow "Partnership Effectiveness"
  
  And I see survey details "Partnership Effectiveness" today
  And I should see "Partnership Effectiveness"
  And I should see "How effective is your partnership in helping to reach your goals"
  And I should see "Good"
  And I should see "What is going well in your mentoring partnership?"
  And I should see "trial 1"
  And I should see "What could be better in your mentoring partnership?"
  And I should see "trial 2"