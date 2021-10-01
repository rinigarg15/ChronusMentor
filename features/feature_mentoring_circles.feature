Feature: Mentoring Circles

Background: Admin logs in
  Given the current program is "primary":"pbe"
  And pbe program has custom term

@javascript @matching_scenario @cross_browser
Scenario: Mentee sends join request fom Home Page Widget
  When I have logged in as "student_0@example.com"
  Then I should see "project_b" within "#cjs_home_page_widget"
  Then I should see "project_c" within "#cjs_home_page_widget"
  Then I should see "project_d" within "#cjs_home_page_widget"
  Then I follow "Join"
  Then I should see "Request to join project_b"
  And I fill in "project_request_message" with "My Request to join project_b"
  Then I press "Send Request"
  Then I should see "Your request has been sent"
  Then I should not see "project_b" within "#cjs_home_page_widget"
  Then I should see "project_e" within "#cjs_home_page_widget"
  Then I logout

@javascript @matching_scenario
Scenario: Mentee should not see already joined project in the Widget
  When I have logged in as "ram@example.com"
  Then I follow "Manage" within "nav#sidebarLeft"
  Then I should see "Administration"
  Then I follow "Projects"
  Then I follow "Available"
  Then I follow "project_b"
  And I follow "Manage Members"
  Then I follow "Add Student"
  When I enter "student_a" in "add_member_student" autocomplete it with "student_a example"
  And I press "Add"
  Then I should see "student_a example"
  And I press "Save"
  And I follow "Manage Members"
  Then I should see "student_a example"
  Then I logout
  When I have logged in as "student_0@example.com"
  Then I should not see "project_b" within "#cjs_home_page_widget"
  Then I logout

@javascript @matching_scenario
Scenario: Mentee should not see already joined project in the Widget
  When I have logged in as "ram@example.com"
  Then I follow "Manage" within "nav#sidebarLeft"
  Then I should see "Administration"
  Then I follow "Projects"
  Then I follow "Available"
  Then I follow "project_b"
  And I follow "Edit Project Profile"
  And I fill in "student" field with prefix "max_" of "primary":"pbe" with "2"
  And I press "Save"
  Then I logout
  When I have logged in as "student_0@example.com"
  Then I should not see "project_b" within "#cjs_home_page_widget"
  Then I logout

@javascript @matching_scenario
Scenario: User who is both Mentor and Mentee sending join request from Home Page Widget
  When I have logged in as "ram@example.com"
  And I enable "send_project_request" for "mentor" in "primary":"pbe"
  Then I navigate to "student_0@example.com" profile in "pbe"
  Then I follow "Change Roles"
  Then I check "Mentor"
  Then I press "Submit"
  Then I logout
  When I have logged in as "student_0@example.com"
  Then I should see "project_b" within "#cjs_home_page_widget"
  Then I follow "Join"
  Then I should see "Request to join project_b"
  Then I should see "Mentor"
  Then I should see "Student"
  Then I choose "project_request_sender_role_id_Mentor"
  And I fill in "project_request_message" with "My Request to join project_b"
  Then I press "Send Request"
  Then I should see "Your request has been sent"
  Then I logout

@javascript @matching_scenario @cross_browser
Scenario: Project Limits with User who is both Mentor and Mentee sending join request
  When I have logged in as "ram@example.com"
  And I enable "send_project_request" for "mentor" in "primary":"pbe"
  Then I navigate to "student_0@example.com" profile in "pbe"
  Then I follow "Change Roles"
  Then I check "Mentor"
  Then I press "Submit"
  Then I follow "Manage" within "nav#sidebarLeft"
  Then I should see "Administration"
  Then I follow "Projects"
  Then I follow "Available"
  Then I follow "project_b"
  And I follow "Edit Project Profile"
  And I fill in "student" field with prefix "max_" of "primary":"pbe" with "2"
  And I press "Save"
  Then I logout
  When I have logged in as "student_0@example.com"
  Then I should see "project_b" within "#cjs_home_page_widget"
  Then I follow "Join"
  Then I should see "Request to join project_b"
  Then I should see "Mentor"
  Then I should see "Student"
  Then element with id "#project_request_sender_role_id_Student" should be disabled
  And I fill in "project_request_message" with "My Request to join project_b"
  Then I press "Send Request"
  Then I should see "Your request has been sent"
  Then I logout

@javascript @matching_scenario
Scenario: Sending Join Request from Hovercard
  When I have logged in as "ram@example.com"
  Then I follow "Manage" within "nav#sidebarLeft"
  Then I should see "Administration"
  Then I follow "Projects"
  Then I follow "Available"
  Then I follow "project_b"
  And I follow "Manage Members"
  Then I follow "Add Mentor"
  When I enter "mentor_a chronus" in "add_member_mentor" autocomplete it with "mentor_a chronus"
  And I press "Add"
  Then I should see "mentor_a chronus"
  And I press "Save"
  And I follow "Manage Members"
  Then I should see "mentor_a chronus"
  Then I logout
  When I have logged in as "student_0@example.com"
  Then I should not see "MY PROJECTS" within "ul.metismenu"
  When I follow "project_a"
  And I expand the "mentor" listing of mentoring area members pane
  When I hover over link with text "mentor_a chronus"

  Then I should see "mentor_a chronus" within "div.cjs-hovercard-container"
  Then I should see "mentor_0@example.com" within "div.cjs-hovercard-container"
  Then I should see "project_b"
  Then I follow "Join Project"
  Then I should see "Request to join project_b"
  And I fill in "project_request_message" with "My Request to join project_b"
  Then I press "Send Request"
  Then I should see "Your request has been sent"
  And I expand the "mentor" listing of mentoring area members pane
  When I hover over link with text "mentor_a chronus"

  Then I should see "mentor_a chronus" within "div.cjs-hovercard-container"
  Then I should see "mentor_0@example.com" within "div.cjs-hovercard-container"
  Then I should see "project_b"
  Then I should not see "Join Project"
  Then I logout

@javascript @cross_browser
Scenario: Task Template in Pending Groups
  Given the current program is "primary":"pbe"
  And I have logged in as "ram@example.com"
  And pbe program has custom term
  Then I enable "mentoring_connections_v2" feature as a super user
  And I login as super user
  And I follow "Manage" within "nav#sidebarLeft"
  Then I should see "Administration"
  And I follow "Project Plan Templates"
  And I follow "Create a New Template"
  And I fill in "cjs_title_field" with "New Mentoring Template with Milestones"
  And I press "Save and proceed to Configure Features »"
  Then the disabled "cjs_mentoring_model_admin_manage_mm_tasks" checkbox_id should be checked
  And I check "cjs_mentoring_model_admin_manage_mm_milestones"
  Then I check "mentoring_model_check_box_allow_messaging"
  Then I uncheck "mentoring_model_check_box_allow_forum"
  And I press "Save and proceed to Add Content »"
  And I should see "Customize Milestones"
  When I click "#cjs_add_milestone_template"
  And I should see "Add Custom Milestone" within "div#remoteModal"
  And I fill in "cjs_milestone_template_form_title_" with "Hello Milestone Title"
  And I fill in "cjs_milestone_template_form_description_" with "Hello Milestone Description"
  And I press "Save" within ".modal.in"
  Then I wait for remote Modal to be hidden

  Then I should see "Hello Milestone Title"
  Then I click on the section with header "Hello Milestone Title"
  When I click ".add-action-opener"
  And I follow "New Task"

  And I fill in "mentoring_model_task_template_title" with "Mentor Task"
  And I assign the task to "Mentor"
  And I press "Save Task"
  Then I wait for ajax to complete
  When I click ".add-action-opener"
  And I follow "New Task"

  And I fill in "mentoring_model_task_template_title" with "Mentee Task"
  And I assign the task to "Student"
  And I press "Save Task"
  Then I wait for ajax to complete
  When I click ".add-action-opener"
  And I follow "New Task"

  And I fill in "mentoring_model_task_template_title" with "Unassigned Task"
  And I press "Save Task"
  Then I wait for ajax to complete
  And I follow "Manage" within "nav#sidebarLeft"
  Then I should see "Administration"
  And I follow "Projects"
  And I should see "Available (5)"
  And I follow "Available (5)"
  Then I should see "project_a"
  When I follow "project_a"
  Then I should see "Assign Project Plan Template"
  Then follow "Assign Project Plan Template"
  Then I should see "Please assign a template for project_a"
  When I select "New Mentoring Template with Milestones" from "assign_mentoring_model"
  And I press "Assign"
  Then I should see "Project Plan"
  And I should see "Hello Milestone Title"
  And I click ".cjs_milestone_description_handler"
  And I should see "Hello Milestone Description"
  And I should see "Mentor Task"
  And I should see "Mentee Task"
  And I should see "Unassigned Task"
  And I check for appropriate assignees on hover
  Then I follow back link
  And I follow "project_b"
  And follow "Assign Project Plan Template"
  And I select "New Mentoring Template with Milestones" from "assign_mentoring_model"
  And I press "Assign"
  Then I create scrap in "project_a, project_b" groups of "pbe" program
  Then I create topic in "project_c, project_e" groups of "pbe" program
  And I follow "Manage" within "nav#sidebarLeft"
  Then I should see "Administration"
  And I follow "Projects"
  And I should see "Available (5)"
  And I follow "Available (5)"
  Then I should see "project_d"
  And I click "#cjs_groups_primary_checkbox"
  Then I follow "Assign Project Plan Template" in the bulk actions
  And I select "Project Based Engagement Template (Default)" from "assign_mentoring_model"
  Then I press "Assign"
  Then I should see "Some of the selected projects have been configured to have Messages based on their existing template." within ".cjs_groups_alert_container"
  Then I should see "Changing the template to 'Project Based Engagement Template' will disable Messages and will result in loss of messages for users in the following projects." within ".cjs_groups_alert_container"
  Then I should see "project_a" within ".cjs_groups_alert_container"
  Then I should see "project_b" within ".cjs_groups_alert_container"
  When I follow "No, Go Back"
  Then I should see "Some of the selected projects have been configured to have Messages based on their existing template." within ".cjs_groups_alert_container"
  Then I press "Assign"
  Then I follow "Yes"
  Then I should see "The template information for the Projects has been applied successfully"
  Then I should see "Project Based Engagement Template" in the group "project_a"
  Then I create topic in "project_a" groups of "pbe" program
  And I click on dropdown of the group "project_a"
  Then I follow "Assign Project Plan Template"
  And I select "New Mentoring Template with Milestones" from "assign_mentoring_model"
  Then I press "Assign"
  Then I should see "The updated template does not have Discussion Boards enabled. If you go ahead with this change, the users of the project will no longer be able to see the discussions."
  And I click ".modal-header .close"
  And I follow "project_a"
  And I follow "Assign Project Plan Template"
  And I select "New Mentoring Template with Milestones" from "assign_mentoring_model"
  And I press "Assign"
  Then I should see "The updated template does not have Discussion Boards enabled. If you go ahead with this change, the users of the project will no longer be able to see the discussions."
  And I click ".modal-header .close"

  Then I follow back link
  And I click "#cjs_groups_primary_checkbox"
  Then I follow "Assign Project Plan Template" in the bulk actions
  And I select "New Mentoring Template with Milestones" from "assign_mentoring_model"
  Then I press "Assign"
  Then I should see "Some of the selected projects have been configured to have Discussion Boards based on their existing template." within ".cjs_groups_alert_container"
  Then I should see "Changing the template to 'New Mentoring Template with Milestones' will disable Discussion Boards and will result in loss of discussions for users in the following projects." within ".cjs_groups_alert_container"
  Then I should see "project_c" within ".cjs_groups_alert_container"
  Then I should see "project_e" within ".cjs_groups_alert_container"
  Then I follow "Yes"
  Then I should see "The template information for the Projects has been applied successfully"
  Then I should see "New Mentoring Template with Milestones" in the group "project_c"
  Then I create scrap in "project_c" groups of "pbe" program
  And I click on dropdown of the group "project_c"
  Then I follow "Assign Project Plan Template"
  And I select "Project Based Engagement Template" from "assign_mentoring_model"
  Then I press "Assign"
  Then I should see "The updated template does not have Messages enabled. If you go ahead with this change, the users of the project will no longer be able to see the messages."
  And I click ".modal-header .close"
  And I follow "project_c"
  And follow "Assign Project Plan Template"
  And I select "Project Based Engagement Template" from "assign_mentoring_model"
  And I press "Assign"
  Then I should see "The updated template does not have Messages enabled. If you go ahead with this change, the users of the project will no longer be able to see the messages."
  And I click ".modal-header .close"
