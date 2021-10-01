Feature: Project Based Engagements

Background: Admin logs in
  Given the current program is "primary":"pbe"
  And pbe program has custom term
  And I have logged in as "ram@example.com"
  And I logout

@javascript @matching_scenario @cross-browser
Scenario: After applying filters end user sends a project request, request converted to ajax so filters should not disappear
And I have logged in as "rahim@example.com"
  And I follow "Discover"
  Then I should be on find_new groups page in primary:pbe program
  And I should see "project_a"
  And I should see "project_b"
  And I should see "project_c"
  And I fill in "search_filters_quick_search" with "project_a"
  And I press "Search" within "#quick_search"

  And I should not see "project_b"
  And I should not see "project_c"
  And I click join project to join "project_a"
  And I should see "Request to join project_a"
  And I fill in "Request" with "sample request"
  And I press "Send Request"
  Then I should be on find_new groups page in primary:pbe program
  And I should see "Request pending approval"
  And I should see "Your request has been sent"
  And I should not see "project_b"
  And I should not see "project_c"

@javascript @matching_scenario @not_run_on_bs
Scenario: When I request for joining project from show page
  And I have logged in as "ram@example.com"
  And I click on profile picture and click "View Profile"
  And I follow "Change Roles"
  And I check "Student"
  And I press "Submit"
  Then I follow "Mentors"
  Then I should not see "Availability Status"
  And I follow "Discover" within "ul.metismenu"
  Then I should be on find_new groups page in primary:pbe program
  And I should see "project_a"
  And I should see "project_b"
  And I should see "project_c"
  And I follow "project_a"
  Then I should see "Requests to Join 1"
  And I follow "Join Project"
  And I should see "Request to join project_a"
  And I fill in "Request" with "sample request"
  And I press "Send Request"
  And I should see "Request pending approval"
  And I should see "Your request has been sent"
  Then I should see "Requests to Join 2"

@javascript @matching_scenario @cross-browser
Scenario: When I apply filters for find new project page
  And I have logged in as "rahim@example.com"
  And I follow "Discover"
  Then I should be on find_new groups page in primary:pbe program
  And I uncheck "available_to_join_filters"
  Then I should see "project_group" within "#find_new_projects_results_pane"
  When I check "available_to_join_filters"
  And I should see "project_group" within "#find_new_projects_results_pane"
  When I click on "Project Name" header
  And I fill in "Project" with "project_a"
  And I press "Go" inside "Project Name" content
  Then I should see "project_a" within "#find_new_projects_results_pane"
  Then I should not see "project_b" within "#find_new_projects_results_pane"
  And I click ".cjs_exec_fn_on_click"
  Then I should see "project_b" within "#find_new_projects_results_pane"
  When I click on "Mentor" header
  And I fill in "Mentor" with "mentor_a chronus"
  And I press "Go" inside "Mentor" content
  Then I should see "project_a" within "#find_new_projects_results_pane"
  Then I should not see "mentor_b" within "#find_new_projects_results_pane"
  And I click ".cjs_exec_fn_on_click"
  Then I should see "project_b" within "#find_new_projects_results_pane"
  When I click on "Student" header
  And I fill in "Student" with "student_a example"
  And I press "Go" inside "Student" content
  Then I should see "project_a" within "#find_new_projects_results_pane"
  Then I should not see "project_c" within "#find_new_projects_results_pane"
  And I click ".cjs_exec_fn_on_click"
  Then I should see "project_c" within "#find_new_projects_results_pane"

@javascript @matching_scenario @cross-browser
Scenario: Managing members in pending project
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  Then I follow "Program Settings"
  Then I follow "Terminology"
  When I fill the custom program terms in "primary":"pbe"
  And I follow "Manage"
  And I follow "Links"
  And I follow "Available (5)"
  Then I should see "project_a"
  When I follow "project_a"
  And I follow "Manage Members"
  Then I follow "Add Coach"
  Then I should see the placeholder text "Enter the Coach's name" in "#add_member_teacher"
  When I enter "teacher_a" in "add_member_teacher" autocomplete it with "teacher_a chronus"
  And I press "Add"
  Then I should see "teacher_a chronus"
  And I press "Save"
  And I follow "Manage Members"
  Then I should see "teacher_a chronus"
  Then I "Remove" member with email "mentor_0@example.com" in "pbe" as "mentor"
  Then I press "Remove member"
  Then I press "Save"
  And I follow "Manage Members"
  Then I should not see "mentor_a chronus"
  And I should see "student_a example"
  And I should see "student_f example"
  Then I "Replace" member with email "student_0@example.com" in "pbe" as "student"
  Then I fill in "student_b example" as replaced user
  Then I press "Replace member"
  And I press "Save"
  Then I follow "Manage Members"
  Then I should see "student_b example"
  Then I should see "teacher_a chronus"
  And I should see "student_f example"
  Then I follow "Cancel"
  Then I logout

@javascript @cross-browser
Scenario: Checking content on user hovercard as an admin
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Projects"
  And I follow "Available (5)"
  Then I should see "project_a"
  When I follow "project_a"
  And I expand the "mentor" listing of mentoring area members pane
  When I hover over link with text "mentor_a chronus"

  Then I should see "mentor_a chronus" within "div.cjs-hovercard-container"
  Then I should see "mentor_0@example.com" within "div.cjs-hovercard-container"
  Then I should see "Message" within "div.cjs-hovercard-container"
  Then I should see "Work on Behalf" within "div.cjs-hovercard-container"
  Then I should see "project_a" within "div.cjs-hovercard-container"
  Then I should not see "Location" within "div.cjs-hovercard-container"
  Then I should not see "Education" within "div.cjs-hovercard-container"
  Then I should see "Work" within "div.cjs-hovercard-container"
  And I follow "mentor_a chronus"
  And I follow "Edit mentor_a chronus's profile"
  And I fill in "Location" with "Chennai, Tamil Nadu, India"
  And I press "submit_general"
  And I follow "Manage"
  And I follow "Projects"
  And I follow "Available (5)"
  When I follow "project_a"
  And I expand the "mentor" listing of mentoring area members pane
  When I hover over link with text "mentor_a chronus"

  Then I should see "Location" within "div.cjs-hovercard-container"
  Then I should not see "Education" within "div.cjs-hovercard-container"

@javascript
Scenario: Checking content on user hovercard
  When I have logged in as "student_0@example.com"
  When I follow "project_a"
  And I expand the "mentor" listing of mentoring area members pane
  When I hover over link with text "mentor_a chronus"

  Then I should see "mentor_a chronus" within "div.cjs-hovercard-container"
  Then I should see "mentor_0@example.com" within "div.cjs-hovercard-container"
  Then I should see "Message" within "div.cjs-hovercard-container"
  Then I should see "Mentor" within "div.cjs-hovercard-container"
  Then I should see "project_a" within "div.cjs-hovercard-container"
  Then I should not see "Location" within "div.cjs-hovercard-container"
  Then I should not see "Education" within "div.cjs-hovercard-container"
  Then I should not see "Work" within "div.cjs-hovercard-container"

@javascript @cross-browser
Scenario: Owner must be able to manage members in a connection

  Then I stub project requests path for "owner" for the program "pbe"
  And I have logged in as "ram@example.com"
  Then I add "view_teachers" permissions for "pbe"
  And pbe program has custom term
  Then I follow "Manage"
  And I follow "Projects"
  Then I follow "Available"
  Then I follow "project_a"
  Then I should see "Add/Remove Owners"
  And I follow "Add/Remove Owners"
  Then I fill owners for group "project_a" with "student_a example" in "primary":"pbe"
  Then I press "Update"
  Then I wait for "2" seconds
  Then I logout
  When I have logged in as "student_0@example.com"
  And I follow "project_a" within "ul.metismenu"
  Then I should see "Manage Members"
  And I follow "Requests to Join"
  And I should see "project_a"
  And I click on actions of "project_a" project
  Then I should see "Accept"
  And I should see "Reject"
  And I follow "Accept"
  And I press "Accept Request"
  And mail should go to "student_2@example.com" having "We have accepted your request to join project_a."
  Then I should see "The selected project request has been accepted."
  Then I close the flash
  And I follow "project_a" within "ul.metismenu"
  Then I should see "Manage Members"
  And I follow "Manage Members"
  Then I should see "Mentors(1)"
  Then I should see "Students(3)"
  Then I should see "mentor_a chronus"
  Then I follow "Add Teacher"
  When I enter "teacher_a" in "add_member_teacher" autocomplete it with "teacher_a chronus"
  And I press "Add"
  Then I should see "teacher_a chronus"
  And I press "Save"
  And I follow "Manage Members"
  Then I should see "teacher_a chronus"
  Then I "Remove" member with email "mentor_0@example.com" in "pbe" as "mentor"
  Then I press "Remove member"
  Then I press "Save"
  And I follow "Manage Members"
  Then I should not see "mentor_a chronus"
  And I should see "student_a example"
  And I should see "student_f example"
  Then I "Replace" member with email "student_0@example.com" in "pbe" as "student"
  Then I fill in "student_b example" as replaced user
  Then I press "Replace member"
  And I press "Save"
  Then I logout

@javascript
Scenario: Admin manages members to pending and ongoing projects.
  Given the current program is "annauniv":"psg"
  When I have logged in as "psg@example.com"
  And I navigate to "Connections" from manage page

  # Add a member with default option
  And I click on dropdown of the group "mentora, mentorb, mentorc, psg, psg, & psg"
  And I follow "Manage Members"
  Then I follow "Add Mentor"
  And I press "Add" within ".cjs_add_mentor"
  Then I should see "Please enter a valid user"
  When I enter "mental mentor" in "add_member_mentor" autocomplete it with "mental mentor"
  And I press "Add" within ".cjs_add_mentor"
  Then I should see "mental mentor"
  And I press "Save"
  Then I wait for ajax to complete

  And I click on dropdown of the group "mentora, mentorb, mentorc, psg, psg, & psg"
  When I follow "Manage Members"
  Then I should see "PSG mentora"
  Then I should see "PSG mentorb"
  Then I should see "PSG mentorc"
  And I should see "mental mentor"
  Then I follow "Cancel"
  Then I wait for ajax to complete

  # Remove a Member with default option
  And I click on dropdown of the group "mentora, mentorb, mentorc, psg, psg, & psg"
  And I follow "Manage Members"
  Then I hover over class "cjs_display_member_handler"
  Then I should see "Remove"
  Then I follow "Remove"
  And I press "Remove member"
  Then I should see "PSG mentora" hidden
  And I press "Save"
  Then I wait for ajax to complete
  And I click on dropdown of the group "mentora, mentorb, mentorc, psg, psg, & psg"
  When I follow "Manage Members"
  Then I should see "PSG mentorb"
  Then I should see "PSG mentorc"
  And I should see "mental mentor"
  Then I follow "Cancel"
  Then I wait for ajax to complete

  # Add a member with second option
  And I click on dropdown of the group "mentora, mentorb, mentorc, psg, psg, & psg"
  And I follow "Manage Members"
  Then I follow "Add Mentor"
  And I choose "Do not add any tasks" for "mentor" role in "annauniv":"psg"
  When I enter "PSG mentora" in "add_member_mentor" autocomplete it with "PSG mentora"
  And I press "Add" within ".cjs_add_mentor"
  Then I should see "PSG mentora"
  And I press "Save"
  Then I wait for ajax to complete

  And I click on dropdown of the group "mentora, mentorb, mentorc, psg, psg, & psg"
  When I follow "Manage Members"
  Then I should see "PSG mentora"
  Then I should see "PSG mentorb"
  Then I should see "PSG mentorc"
  And I should see "mental mentor"
  Then I follow "Cancel"
  Then I wait for ajax to complete

  # Remove a Member with second option
  And I click on dropdown of the group "mentora, mentorb, mentorc, psg, psg, & psg"
  And I follow "Manage Members"
  Then I hover over class "cjs_display_member_handler"
  Then I should see "Remove"
  Then I follow "Remove"
  Then I choose "group_remove_member_option_1_54"
  And I press "Remove member"
  Then I should see "PSG mentora" hidden
  And I press "Save"
  Then I wait for ajax to complete

  And I click on dropdown of the group "mentora, mentorb, mentorc, psg, psg, & psg"
  When I follow "Manage Members"
  Then I should see "PSG mentora"
  Then I should see "PSG mentorc"
  And I should see "mental mentor"
  Then I follow "Cancel"
  Then I wait for ajax to complete

  # Replace a Member
  And I click on dropdown of the group "mentora, mentorb, mentorc, psg, psg, & psg"
  And I follow "Manage Members"
  Then I should see "Replace"
  Then I follow "Replace"
  And I press "Replace member"
  Then I should see "Please enter a valid user"
  When I enter "PSG mentorb" in "replace_member" autocomplete it with "PSG mentorb"
  And I press "Replace member"
  Then I should see "PSG mentorb"
  And I press "Save"
  Then I wait for ajax to complete

  And I click on dropdown of the group "mentora, mentorb, mentorc, psg, psg, & psg"
  When I follow "Manage Members"
  Then I should see "PSG mentora"
  Then I should see "PSG mentorb"
  And I should see "mental mentor"
  Then I follow "Cancel"
  Then I wait for ajax to complete

  # Connection should have at least one mentor
  And I click on dropdown of the group "mentora, mentorb, mentorc, psg, psg, & psg"
  Then I follow "Visit Mentoring Connection"
  And I follow "Manage Members"
  Then I "Remove" member with email "mentor2@psg.com" in "psg" as "mentor"
  And I press "Remove member"
  Then I "Remove" member with email "mentor1@psg.com" in "psg" as "mentor"
  And I press "Remove member"
  Then I "Remove" member with email "mentor@psg.com" in "psg" as "mentor"
  And I press "Remove member"
  And I press "Save"
  Then I should see "A mentoring connection needs at least one mentor. Try closing the mentoring connection instead of removing the mentor."
  And I logout

@javascript
Scenario: Owner manage members should respect project join options
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  When I follow "Matching Settings"
  Then I should see the "mentor" role can be added by owners in the program "Project Based Engagement"
  Then I should see the "student" role can be added by owners in the program "Project Based Engagement"
  Then I uncheck "mentor" role can be added by owners in the program "Project Based Engagement"
  Then I uncheck "student" role can be added by owners in the program "Project Based Engagement"
  Then I uncheck "teacher" role can be added by owners in the program "Project Based Engagement"
  And I press "Save"
  And I follow "Manage"
  And I follow "Projects"
  Then I follow "Available"
  And I follow "project_a"
  And I follow "Add/Remove Owners"
  Then I wait for ajax to complete
  Then I fill owners for group "project_a" with "student_a example" in "primary":"pbe"
  Then I press "Update"
  Then I wait for ajax to complete
  Then I should see "Owners are updated successfully in this project."
  Then I logout
  When I have logged in as "student_0@example.com"
  And I follow "project_a"
  Then I should not see "Manage Members"
  Then I logout
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  When I follow "Matching Settings"
  Then I check "mentor" role can be added by owners in the program "Project Based Engagement"
  And I press "Save"
  Then I should see the "mentor" role can be added by owners in the program "Project Based Engagement"
  Then I logout
  When I have logged in as "student_0@example.com"
  And I follow "project_a"
  Then I should see "Manage Members"
  And I follow "Manage Members"
  Then I wait for ajax to complete
  Then I should see "Mentors"
  Then I should see "Add Mentor"
  Then I should not see "Add Student"
  Then I press "Save"
  Then I logout
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  When I follow "Matching Settings"
  Then I check "student" role can be added by owners in the program "Project Based Engagement"
  And I press "Save"
  Then I should see the "mentor" role can be added by owners in the program "Project Based Engagement"
  Then I should see the "student" role can be added by owners in the program "Project Based Engagement"
  Then I logout
  When I have logged in as "student_0@example.com"
  And I follow "project_a"
  Then I should see "Manage Members"
  And I follow "Manage Members"
  Then I wait for ajax to complete
  Then I should see "Mentors"
  Then I should see "Students"
  Then I should see "Add Mentor"
  Then I should see "Add Student"
  Then I press "Save"
  Then I logout

@javascript @matching_scenario
Scenario: Apply to join cannot be disabled when there are already pending requests
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  When I follow "Matching Settings"
  Then I should see "To disable this option, please take action on all pending requests first"
  Then apply to join for "student" should be disabled
  Then I follow "pending requests"
  Then I should see "Project Requests"
  Then I click "#cjs_primary_checkbox"
  Then I follow "Actions"
  Then I should see "Reject"
  Then I follow "Reject"
  Then I press "Reject Requests"
  Then I should see "The selected project requests have been rejected"
  And I follow "Manage"
  And I follow "Program Settings"
  When I follow "Matching Settings"
  Then I should not see "To disable this option, please take action on all pending requests first"
  Then I logout