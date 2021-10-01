Feature: Project Based Engagements

Background: Admin logs in
  Given the current program is "primary":"pbe"
  And pbe program has custom term
  And I have logged in as "ram@example.com"
  And I logout

@javascript
Scenario: Admin visits Connection Settings page
  And I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  When I follow "Project Settings"
  And I should not see "Maximum mentors for a student"
  And I should not see "Allow students to send mentoring requests"
  And I should not see "Allow students to withdraw mentor request"
  Then I should see "Allow members of a project to change the expiration date of the project"
  And I should see "Allow members of a project to leave it without project ending"
  And I should see "Recommended only for group project"
  And I should see "If 'No', members can send a request to the administrator to change the expiration date"
  When I follow "Project Settings"
  And I should not see "Project style"
  And I should not see "One-on-one"
  And I should not see "Group"

@javascript
Scenario: Admin visits Update Admin View Page
  And I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "User Views"
  And I follow "Update View"
  Then I should not see "Connection slots"

@javascript
Scenario: Mentor visits edit profile and account settings pages
  And I have logged in as "robert@example.com"
  And I click on profile picture and click "Edit Profile"
  And I click on the section with header "Work and Education"
  Then I should not see "Projects Limit"
  And I click on profile picture and click "Account Settings"
  Then I should not see "Projects Limit"

@javascript @cross-browser
Scenario: Admin creating project
  And I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  Then the "program_allow_circle_start_date" checkbox_id should be checked
  Then I should see "Allow proposer to set the start date of the project"
  Then I check "program_allow_circle_start_date"
  And I press "Save"
  And I follow "Manage"
  And I follow "Projects"
  When I follow "Create New Project"
  Then I should be on new group page in primary:pbe program
  And I should see "Project start date"
  And I fill in "Name" with "Todo App"
  And I fill in "Maximum number of students who can participate" with "3"
  And I select "January 25, 2020" for "#circle_start_date_form" from datepicker
  And I press "Save and proceed to Add Members »"
  Then I should see "Todo App"
  Then I select "mentor_a chronus,mentor_b chronus" as mentors and "student_a example,student_b example,student_c example,student_d example" as students
  And I press "Save and Make Project Available"
  And I should see "1 Project will be made available for mentors and students to join"
  And I fill in "Message" with "Please Join"
  And I press "Make Project Available"
  And I should see the flash "The project can't have more than 3 students"

  Then I select "mentor_a chronus,mentor_b chronus" as mentors and "student_a example,student_b example" as students

  And I press "Save and Make Project Available"
  And I should see "1 Project will be made available for mentors and students to join"
  And I fill in "Message" with "Please Join"
  And I press "Make Project Available"

  Then individual mails should go to "mentor_0@example.com,mentor_1@example.com,student_0@example.com,student_1@example.com" having "We will notify you when the project starts."

  Then I should be on groups page in primary:pbe program
  And I follow "Manage"
  And I follow "Projects"
  When I follow "Create New Project"
  Then I should be on new group page in primary:pbe program
  And I fill in "Name" with "<script>alert('Alert should not come!')</script> Test PBE Project"
  And I fill in "Maximum number of students who can participate" with "3"
  And I press "Save and proceed to Add Members »"
  Then I should see "<script>alert('Alert should not come!')</script> Test PBE Project"
  Then I select "mentor_a chronus" as mentors and "student_a example" as students
  And I press "Save and Make Project Available"
  And I fill in "Message" with "Please Join"
  And I press "Make Project Available"
  And I logout
  When I have logged in as "student_0@example.com"
  Then I should see "Please Reset Your Time Zone"

@javascript @cross-browser
Scenario: Admin creating project with slot config setting
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  Then I should see "Allow proposer to set the start date of the project"
  Then I uncheck "program_allow_circle_start_date"
  And I press "Save"
  Then the "program_allow_circle_start_date" checkbox_id should not be checked
  Then I should see "Project Slot Limit Options"
  And I should see slot config setting for student as optional
  Then I directly go to "/p/pbe/groups"
  When I follow "Create New Project"
  Then I should be on new group page in primary:pbe program
  And I should see "Maximum number of students who can participate"
  And I should see "Maximum number of mentors who can participate"
  And I should see "Maximum number of teachers who can participate"

  When I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I disable slot config for student role
  And the required checkbox for teacher role should be hidden
  And I disable slot config for teacher role
  Then the required checkbox for teacher role should be hidden
  When I enable slot config as required for teacher role
  Then the required checkbox for teacher role should not be hidden
  When I press "Save"
  Then I should see slot config setting for student as disabled
  And I should see slot config setting for mentor as optional
  And I should see slot config setting for teacher as required
  Then I directly go to "/p/pbe/groups"
  When I follow "Create New Project"
  Then I should be on new group page in primary:pbe program
  And I should not see "Maximum number of students who can participate"
  And I should see "Maximum number of mentors who can participate"
  And I should see "Maximum number of teachers who can participate *"
  And I should not see "Project start date"
  When I fill in "Name" with "Todo App"
  And I press "Save and proceed to Add Members »"
  Then I should see "Please fill all the required fields. Fields marked * are required"
  When I fill in "Maximum number of teachers who can participate" with "3"
  And I press "Save and proceed to Add Members »"
  Then I should see "Todo App"
  When I select "mentor_a chronus,mentor_b chronus" as mentors and "student_a example,student_b example,student_c example,student_d example" as students
  And I press "Save and Make Project Available"
  Then I should see "1 Project will be made available for mentors and students to join"
  When I fill in "Message" with "Please Join"
  Then I click on input by value "Make Project Available"
  Then I wait for "2" seconds
  Then I should be on groups page in primary:pbe program
  And I should see "Project Slots Availability"

  When I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I disable slot config for teacher role
  And I disable slot config for mentor role
  And I press "Save"
  And I go to groups page in primary:pbe program
  Then I should not see "Project Slots Availability"

@javascript @cross-browser
Scenario: Admin visits group profile page
  And I have logged in as "ram@example.com"
  When I visit drafted project profile
  Then I should see "Make Project Available,Edit Project Profile,Manage Members,Assign Project Plan Template, Discard Project" in admin actions pane
  And I should see "Drafted" label beside the project name

  When I visit pending project profile
  Then I should see "Publish Project,Edit Project Profile,Manage Members,Assign Project Plan Template" in admin actions pane
  And I should see "Available" label beside the project name

  When I visit published project profile
  Then I should see "Edit Project Profile,Manage Members,Close Project" in admin actions pane
  And I should see "Profile" label beside the project name

  When I visit closed project profile
  Then I should see "Reactivate Project" in admin actions pane
  And I should see "Profile" label beside the project name

@javascript @p2 @cross-browser
Scenario: Admin adds teachers to pending and ongoing projects. Teachers can view projects.
  When I have logged in as "ram@example.com"
  Then I enable admin audit logs
  And I follow "Manage"
  And I follow "Projects"
  And I follow "Available (5)"
  Then I should see "project_a"
  When I follow "project_a"
  And I follow "Manage Members"
  Then I follow "Add Teacher"
  When I enter "teacher_a chronus" in "add_member_teacher" autocomplete it with "teacher_a chronus"
  And I press "Add" within ".cjs_add_teacher"
  Then I should see "teacher_a chronus"
  Then I follow "Add Teacher"
  When I enter "teacher_b chronus" in "add_member_teacher" autocomplete it with "teacher_b chronus"
  And I press "Add" within ".cjs_add_teacher"
  Then I should see "teacher_b chronus"
  And I press "Save"
  When I follow "Manage Members"
  Then I should see "teacher_a chronus"
  And I should see "teacher_b chronus"
  Then I follow "Cancel"
  When I follow "Manage"
  And I follow "Projects"
  And I follow "Ongoing (1)"
  And I follow "project_group"
  And I fill in "confidentiality_audit_log_reason" with "Updating connection"
  And I press "Proceed »"
  When I follow "Manage Members"
  Then I follow "Add Teacher"
  When I enter "teacher_a chronus" in "add_member_teacher" autocomplete it with "teacher_a chronus"
  And I press "Add" within ".cjs_add_teacher"
  Then I should see "teacher_a chronus"
  Then I follow "Add Teacher"
  When I enter "teacher_b chronus" in "add_member_teacher" autocomplete it with "teacher_b chronus"
  And I press "Add" within ".cjs_add_teacher"
  Then I should see "teacher_b chronus"
  And I press "Save"
  When I follow "Manage Members"
  Then I should see "teacher_a chronus"
  And I should see "teacher_b chronus"
  And I logout
  #Teacher logs in and visits the pending and ongoing project
  When I have logged in as "teacher_0@example.com"
  Then I should see "PROJECTS"
  Then I should see "All projects" within "ul.metismenu"
  When I follow "project_a" within "ul.metismenu"
  Then I should see "My Project" label beside the project name
  And I follow "project_group"
  Then I should see "Plan"
  And I should see "Add New Task"
  And I logout

@javascript @matching_scenario @cross-browser
Scenario: Student joins the project via find new project page
  And I have logged in as "rahim@example.com"
  Then I should see "PROJECTS" within "ul.metismenu"
  Then I should see "Discover" within "ul.metismenu"
  And I follow "Discover" within "ul.metismenu"
  Then I should be on find_new groups page in primary:pbe program
  And I click join project to join "project_a"
  And I should see "Request to join project_a"
  And I press "Send Request"
  Then I should see "Please fill all the required fields. Fields marked * are mandatory"
  And I fill in "Request" with "sample request"
  And I press "Send Request"
  Then I should be on find_new groups page in primary:pbe program
  Then I logout

@javascript @matching_scenario @cross-browser
Scenario: Student joins the project from project profile page
  And I have logged in as "rahim@example.com"
  When I visit pending project profile
  Then I should see "Join Project"
  And I click ".cjs_create_project_request"
  And I should see "Request to join"
  And I fill in "Request" with "sample request"
  And I press "Send Request"
  Then I should see "Request pending approval"
  And I should not see "Join Project"

@javascript @cross-browser
Scenario: Mentor visits project listing page
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  When I follow "Matching Settings"
  Then I uncheck "mentor" role can apply to join project in the program "Project Based Engagement"
  And I press "Save"
  Then I logout
  And I have logged in as "robert@example.com"
  Then I should see "All projects" within "ul.metismenu"
  And I follow "All projects" within "ul.metismenu"
  # he should see only published project
  And I should see "project_group"
  And I should not see "project_a"

@javascript @matching_scenario @cross-browser
Scenario: Admin visits project request listing page
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  Then I should see "Project Requests"
  And I follow "Project Requests"
  # Accepting a request
  And I should see "project_a"
  And I click on actions of "project_a" project
  Then I should see "Accept"
  And I should see "Reject"
  And I follow "Accept"
  Then I wait for ajax to complete
  Then I should see "An email will be sent to the user if you complete this action."
  And I press "Accept Request"
  And mail should go to "student_2@example.com" having "We have accepted your request to join project_a."
  And I should not see "project_a"

  # Rejecting a request
  And I click on actions of "project_b" project
  Then I should see "Accept"
  And I should see "Reject"
  And I click ".cjs_reject_request"
  And I should see "You have selected a project request."
  And I should see "An email will be sent to the selected user, with the reason for rejecting the project request if you complete this action."
  And I fill in "Reason for rejection" with "You are stupid"
  And I press "Reject Request"
  And mail should go to "student_3@example.com" having "Unfortunately, we have to reject your request to join the project"
  And I should not see "project_b"

@javascript @matching_scenario @cross-browser
Scenario: Owner accepting project request
  Then I stub project requests path for "owner" for the program "pbe"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Projects"
  Then I follow "Available"
  Then I follow "project_a"
  Then I should see "Add/Remove Owners"
  And I follow "Add/Remove Owners"
  Then I fill owners for group "project_a" with "student_a example" in "primary":"pbe"
  Then I press "Update"
  And I wait for "2" seconds
  Then I logout
  When I have logged in as "student_0@example.com"
  And I follow "project_a"
  Then I should see "Manage Members"
  And I follow "Requests to Join"
  And I should see "project_a"
  And I click on actions of "project_a" project
  Then I should see "Accept"
  And I should see "Reject"
  And I follow "Accept"
  Then I wait for ajax to complete
  Then I should not see "An email will be sent to the user if you complete this action."
  And I press "Accept Request"
  And mail should go to "student_2@example.com" having "We have accepted your request to join project_a."
  Then I should see "The selected project request has been accepted."

@javascript @matching_scenario @cross-browser
Scenario: Owner rejecting project request
  Then I stub project requests path for "owner" for the program "pbe"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Projects"
  Then I follow "Available"
  Then I follow "project_a"
  Then I should see "Add/Remove Owners"
  And I follow "Add/Remove Owners"
  Then I fill owners for group "project_a" with "student_a example" in "primary":"pbe"
  Then I press "Update"
  Then I logout
  When I have logged in as "student_0@example.com"
  And I follow "project_a"
  Then I should see "Manage Members"
  And I follow "Requests to Join"
  And I should see "project_a"
  And I click on actions of "project_a" project
  Then I should see "Accept"
  And I should see "Reject"
  And I follow "Reject"
  And I should see "You have selected a project request."
  And I should not see "An email will be sent to the selected user, with the reason for rejecting the connection request if you complete this action."
  And I fill in "Reason for rejection" with "You are stupid"
  And I press "Reject Request"
  And mail should go to "student_2@example.com" having "Unfortunately, we have to reject your request to join the project"
  Then I should see "The selected project request has been rejected."

@javascript @cross-browser
Scenario: Add default tasks option on accepting project requests of ongoing groups
  And I have logged in as "ram@example.com"
  Then I publish group "project_a"

  Then I follow "Manage"
  And I follow "Project Requests"
  Then I should see "project_a"
  And I click on actions of "project_a" project
  Then I should see "Accept"
  And I should see "Reject"
  And I follow "Accept"
  Then I wait for ajax to complete
  Then I should see "An email will be sent to the user if you complete this action."
  And I should see "There is 1 user who has requested to join a project which has already started."
  And I should see "Add all tasks to the new users being accepted into the projects which have already started"
  And I should see "Don't add any tasks for the new users being accepted into the projects which have already started"
  Then the "Add all tasks to the new users being accepted into the projects which have already started" checkbox should be checked
  Then default tasks must be copied to the new user
  And I press "Accept Request"
  Then I should see "The selected project request has been accepted."
  And mail should go to "student_2@example.com" having "We have accepted your request to join project_a."
  And I should not see "project_a"

  Then I publish group "project_b"
  And I click on actions of "project_b" project
  And I follow "Accept"
  Then I wait for ajax to complete
  And I should see "There is 1 user who has requested to join a project which has already started."
  And I should see "Add all tasks to the new users being accepted into the projects which have already started"
  And I should see "Don't add any tasks for the new users being accepted into the projects which have already started"
  Then I choose radio button with label "Don't add any tasks for the new users being accepted into the projects which have already started"
  Then default tasks must not be copied to the new user
  And I press "Accept Request"
  Then I should see "The selected project request has been accepted."
  And mail should go to "student_3@example.com" having "We have accepted your request to join project_b."
  And I should not see "project_b"
  Then I logout

@javascript
Scenario: Publish popup for critical mass reached groups project requests
  And I have logged in as "ram@example.com"
  And I make the group "project_a" critical mass
  Then I follow "Manage"
  And I follow "Project Requests"
  Then I should see "project_a"
  And I click on actions of "project_a" project
  Then I should see "Accept"
  And I follow "Accept"
  Then I wait for ajax to complete
  Then I should see "An email will be sent to the user if you complete this action."
  And I press "Accept Request"
  Then I should see "The selected project request has been accepted."
  Then I should see "Would you also like to publish this project?"
  And I should see "Allow new users to send requests to join this project for the available slots"
  Then I confirm modal
  And I should see "Close Project"
  Then I logout