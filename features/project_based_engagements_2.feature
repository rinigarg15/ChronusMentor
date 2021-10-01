Feature: Project Based Engagements

Background: Admin logs in
  Given the current program is "primary":"pbe"
  And pbe program has custom term
  And I have logged in as "ram@example.com"
  And I logout

@javascript @matching_scenario @cross-browser
Scenario: User leaving from project which is in available state
  And I have logged in as "student_0@example.com"
  Then I update allow users to leave connection setting for "Project Based Engagement" program to true
  And I follow "project_a"
  Then I should see "This project has not started yet. You will be notified once it starts."
  Then I should see "Leave Project"
  And I click "#leave_connection"
  Then I should see "Leave 'project_a'"
  And I fill in "group_termination_reason" with "I am already connected in other project"
  Then I press "Leave"
  Then I should see "You have left the Project"
  And I logout

@javascript @matching_scenario @cross-browser
Scenario: Member updating notification setting when project is in available state
  And I have logged in as "student_0@example.com"
  And I follow "project_a"
  Then I should see "This project has not started yet. You will be notified once it starts."
  Then I logout
  And I have logged in as "student_0@example.com"
  And I follow "Discover"
  And I follow "project_b"
  Then I should see "This project has not started yet. If you join, you will be notified once it starts."
  Then I should not see "Manage Notification Settings"
  Then I logout

@javascript @p2
Scenario: Admin creates a drafted project.
    When I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Projects"
    When I follow "Create New Project"
    Then I should be on new group page in primary:pbe program
    And I fill in "Name" with "TODO app in IOS"
    And I fill in "Maximum number of students who can participate" with "3"
    And I press "Save and proceed to Add Members »"
    Then I should see "TODO app in IOS"
    And I press "Save and Continue Later"
    Then I should be on groups page in primary:pbe program
    And I should see "Drafted (2)" within "li.ct_active"
    And I logout

@javascript @p2 
Scenario: Admin changes the state of drafted project to pending
  When I have logged in as "ram@example.com"
  And I visit drafted project profile
  Then I should see "Drafted" label beside the project name
  And I follow "Make Project Available"
  And I fill in "make_available_message" with "This is now available"
  And I press "Make Project Available"
  Then I should see "Available" label beside the project name
  And I logout

@javascript @p2 @matching_scenario @cross-browser
Scenario: Admin changes the state of pending project to published. Project with pending request will be redirected to project requests page.
  When I have logged in as "ram@example.com"
  And I visit pending project profile
  Then I should see "Available" label beside the project name
  Then I stub project requests path for "admin" for "project_a" group
  When I follow "Publish Project"
  And I press "Publish"
  Then I should see the flash "Congratulations on publishing project_a! There are outstanding request(s) to join your project. Please respond below."
  Then I should see "Project Requests"
  And I click on actions of "project_a" project
  And I click ".cjs_reject_request"
  And I should see "You have selected a project request."
  And I fill in "Reason for rejection" with "Not eligible"
  And I press "Reject Request"
  Then I should see the flash "The selected project request has been rejected"

@javascript @p2 @matching_scenario @cross-browser
Scenario: Publish circle widget, owner tries to publish the group from inside the widget.
  And I make member with email "student_0@example.com" as owner of project with name "project_a"
  When I have logged in as "student_0@example.com"
  Then I should not see "Kick start your project"
  And I change pending date of project with name "project_a" to "8" days ago
  And I follow "Home"
  Then I should see "Kick start your project (1)"
  Then I should see "project_a" within "div#cjs_publish_circles_widget"
  Then I should see available for info for project with name "project_a"
 # Then I should see "Available for 8 days" within "div#cjs_publish_circles_widget"
  Then I should see "Publish" within "div#cjs_publish_circles_widget"
  Then I should see "View project" within "div#cjs_publish_circles_widget"
  Then I should see "No slot limit"
  And I click ".cjs_remove_circle_from_widget" within "div#cjs_publish_circles_widget"
  Then I should not see "Kick start your project (1)"
  And I logout
  When I have logged in as "student_0@example.com"
  Then I should see "Kick start your project (1)"
  And I follow "View project" within "div#cjs_publish_circles_widget"
  Then I should see "Edit Project Profile"
  Then I should see "Requests to Join 1"
  And I follow "Home"
  Then I stub project requests path for "owner" for "project_a" group
  When I follow "Publish"
  And I press "Publish"
  Then I should see the flash "Congratulations on publishing project_a! There are outstanding request(s) to join your project. Please respond below."
  Then I should see "Project Requests"

@javascript @p2 @matching_scenario
Scenario: Once the maximum mentee limit is reached, admin cannot accept any other project request cannot be accepted.
  Then I stub project requests path for "admin" for the program "pbe"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  Then I should see "Allow proposer to set the start date of the project"
  Then I uncheck "program_allow_circle_start_date"
  And I press "Save"
  And I follow "Manage"
  And I follow "Projects"
  And I follow "Available (5)"
  When I follow "project_a"
  And I follow "Edit Project Profile"
  And I should not see "Project start date"
  And I fill in "student" field with prefix "max_" of "primary":"pbe" with "2"
  And I press "Save"
  When I follow "Requests to Join"
  And I click on actions of "project_a" project
  And I follow "Accept"
  Then I should see "An email will be sent to the user if you complete this action."
  And I press "Accept Request"
  Then I should see the flash "Request not accepted because project_a exceeded maximum limit"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  Then I should see "Allow proposer to set the start date of the project"
  Then I check "program_allow_circle_start_date"
  And I press "Save"
  And I follow "Manage"
  And I follow "Projects"
  And I follow "Available (5)"
  When I follow "project_a"
  And I follow "Edit Project Profile"
  And I should see "Project start date"
  And I fill in "student" field with prefix "max_" of "primary":"pbe" with "3"
  And I select "January 25, 2020" for "#circle_start_date_form" from datepicker
  And I press "Save"
  When I follow "Requests to Join"
  And I click on actions of "project_a" project
  And I follow "Accept"
  Then I should see "An email will be sent to the user if you complete this action."
  And I press "Accept Request"
  Then I should see the flash "The selected project request has been accepted"
  And I logout

@javascript @cross-browser
Scenario: Title and subtitles for different groups pages
  When I have logged in as "ram@example.com"

  And I follow "Manage"
  And I follow "Projects"
  And I follow "Proposed (4)"
  When I follow "Strategy to finish Game of Thrones in a weekend :)"
  Then I should see "Strategy to finish Game of Thrones in a weekend :)" within "#page_heading"

  Then I follow the back link
  And I follow "Available (5)"
  When I follow "project_a"
  Then I should see "project_a" within "#page_heading"
  Then I should see "Available" within "#page_heading"

  Then I follow the back link
  Then I enable admin audit logs
  And I follow "Manage"
  And I follow "Projects"

  And I follow "Ongoing (1)"
  When I follow "project_group"
  And I fill in "confidentiality_audit_log_reason" with "Updating connection"
  And I press "Proceed »"
  Then I should see "project_group" within "#page_heading"
  And I should see "Goals"
  And I should see "Meetings"
  Then I follow "Manage"
  And I follow "Projects"
  And I follow "Rejected (2)"
  When I follow "Incorporate family values by watching Breaking Bad"
  Then I should see "Incorporate family values by watching Breaking Bad" within "#page_heading"

  And I logout

@javascript
Scenario: Withdraw circle Scenario
  When I have logged in as "ram@example.com"

  Then I follow "Manage"
  And I follow "Projects"
  And I follow "Withdrawn (1)"
  Then I should see "Learn to survive from Claire"
  And I follow "(View reason)"
  And I should see "Reason for withdrawal"
  And I should see "Admin is on leave !!"

  And I follow "Manage"
  And I follow "Projects"
  And I follow "Available (5)"
  Then I should see "project_a"
  And I follow "project_a"
  Then I should see "Withdraw Project"
  Then I follow "Withdraw Project"
  Then I wait for ajax to complete
  And I fill in "withdraw_message" with "Admin is not interested!!"
  Then I press "Withdraw Project"
  When I follow the back link

  #Not reindexing here, only checking the count
  Then I should see "Withdrawn (2)"
  And I should see "Available (4)"

@javascript @cross-browser
Scenario: Allow users to send requests checkbox in published groups
  When I have logged in as "ram@example.com"
  And I clear project prequests of "project_a"
  And I clear project prequests of "project_b"

  And I follow "Manage"
  And I follow "Projects"
  And I follow "Available (5)"
  And I follow publish for group "project_a"
  Then I should see "Allow new users to send requests to join this project for the available slots."
  And I should see "An email will be sent to the user if you complete this action."
  Then I confirm modal
  Then I should see "The project has been published"
  And users with roles "mentor,student" should be allowed to send requests to "project_a"

  And I follow "Manage"
  And I follow "Projects"
  And I should see "Available (4)"
  And I follow "Available (4)"
  And I follow publish for group "project_b"
  Then I should see "Allow new users to send requests to join this project for the available slots."
  And I uncheck "group[membership_settings][allow_join]"
  Then I confirm modal
  Then I should see "The project has been published"
  And users with roles "mentor,student" should not be allowed to send requests to "project_b"

  Then I follow "Ongoing (3)"
  And I follow "project_group"
  Then I should see "Allow/Stop User requesting to join"
  And I follow "Allow/Stop User requesting to join"
  Then I should see "Users Requesting to Join Project"
  Then I remove join requests permission for "student"
  Then I confirm modal
  Then I should see "The project join settings have been updated."
  And users with roles "mentor" should be allowed to send requests to "project_group"
  And users with roles "student" should not be allowed to send requests to "project_group"

  Then I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  Then I uncheck "mentor" role can apply to join project in the program "Project Based Engagement"
  And I press "Save"
  Then users with roles "mentor" should not be allowed to send requests to "project_group"
  Then I logout

@javascript @cross-browser
Scenario: Set and Change Start date for groups
  When I have logged in as "ram@example.com"

  And I follow "Manage"
  And I follow "Projects"
  And I follow "Proposed (4)"
  
  Then I should see "Not set(Set date)" for start date of project "Strategy to finish Game of Thrones in a weekend :)"
  Then I click "Set date" for project "Strategy to finish Game of Thrones in a weekend :)"
  And I select "January 25, 2020" for "#circle_start_date_form" from datepicker
  And I press "Set Start Date"
  And I should see "A start date has been set for the project."
  Then I should see "January 25, 2020" for start date of project "Strategy to finish Game of Thrones in a weekend :)"
  Then I click "Change date" for project "Strategy to finish Game of Thrones in a weekend :)"
  And I select "January 28, 2020" for "#circle_start_date_form" from datepicker
  And I press "Set Start Date"
  And I should see "Start date has been updated successfully for the project."
  Then I should see "January 28, 2020" for start date of project "Strategy to finish Game of Thrones in a weekend :)"

  Then I should see "Not set(Set date)" for start date of project "Study the principles of Frank Underwood and share the learnings"
  Then I click "Set date" for project "Study the principles of Frank Underwood and share the learnings"
  And I select "January 25, 2020" for "#circle_start_date_form" from datepicker
  And I press "Set Start Date"
  And I should see "A start date has been set for the project."
  Then I should see "January 25, 2020" for start date of project "Study the principles of Frank Underwood and share the learnings"
  Then I click "Change date" for project "Study the principles of Frank Underwood and share the learnings"
  And I select "January 28, 2020" for "#circle_start_date_form" from datepicker
  And I press "Set Start Date"
  And I should see "Start date has been updated successfully for the project."
  Then I should see "January 28, 2020" for start date of project "Study the principles of Frank Underwood and share the learnings"

  And I follow "Available (5)"
  Then I should see "Not set(Set date)" for start date of project "project_a"
  Then I click "Set date" for project "project_a"
  And I select "January 25, 2020" for "#circle_start_date_form" from datepicker
  And I press "Set Start Date"
  And I should see "A start date has been set for the project."
  Then I should see "January 25, 2020" for start date of project "project_a"
  Then I click "Change date" for project "project_a"
  And I select "January 28, 2020" for "#circle_start_date_form" from datepicker
  And I press "Set Start Date"
  And I should see "Start date has been updated successfully for the project."
  Then I should see "January 28, 2020" for start date of project "project_a"
  And I logout

@javascript @cross-browser
Scenario: Admin moving circle from proposed to available with past start date
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Projects"
  And I follow "Proposed (4)"
  Then I follow "Accept & Make Available"
  Then I should not see "Start date of the project is already past. Please set a new start date before you make it available."
  And I follow "Cancel"
  And I make start date of project "Strategy to finish Game of Thrones in a weekend :)" in past
  Then I follow "Accept & Make Available"
  Then I should see "Start date of the project is already past. Please set a new start date before you make it available."
  And I select "January 28, 2020" for "#circle_start_date_form" from datepicker
  Then I select "Project Based Engagement Template (Default)" from "assign_mentoring_model"
  And I press "Accept & Make Available"
  Then I should see "The Project has been accepted and made available successfully"
  And I follow "Proposed (3)"
  Then I should see "January 28, 2020" for start date of project "Strategy to finish Game of Thrones in a weekend :)"

@javascript @cross-browser
Scenario: Admin moving circle from drafted to available with past start date
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Projects"
  And I follow "Drafted (1)"
  Then I follow "Make Project Available"
  Then I should not see "Start date of the project is already past. Please set a new start date before you make it available."
  And I follow "Cancel"
  And I make start date of project "Drafted PBE group" in past
  And I follow "Drafted (1)"
  Then I follow "Make Project Available"
  Then I should see "Start date of the project is already past. Please set a new start date before you make it available."
  And I select "January 28, 2020" for "#circle_start_date_form" from datepicker
  And I press "Make Project Available"
  Then I should see "The Project have been made available successfully"
  And I follow "Drafted (0)"
  Then I should see "January 28, 2020" for start date of project "Drafted PBE group"

@javascript @cross-browser
Scenario: Admin moving circles from proposed to available with one circle having start date in past
  When I have logged in as "ram@example.com"
  And I make start date of project "Strategy to finish Game of Thrones in a weekend :)" in past
  And I follow "Manage"
  And I follow "Projects"
  And I follow "Proposed (4)"
  And I check "cjs_groups_primary_checkbox"
  And I follow "Actions"
  And I follow "Accept & Make Available" within "ul.dropdown-menu"
  Then I select "Project Based Engagement Template (Default)" from "assign_mentoring_model"
  And I press "Accept & Make Available"
  Then I should see "Couldn't complete the action as the start date of project(s) Strategy to finish Game of Thrones in a weekend :) are already past. Please set a new start for mentioned project to complete the action in bulk."

@javascript @cross-browser
Scenario: Admin moving circles from drafted to available with one circle having start date in past
  When I have logged in as "ram@example.com"
  And I make start date of project "Drafted PBE group" in past
  And I follow "Manage"
  And I follow "Projects"
  And I follow "Drafted (1)"
  And I check "cjs_groups_primary_checkbox"
  And I follow "Actions"
  And I follow "Make Projects Available" within "ul.dropdown-menu"
  And I press "Make Project Available"
  Then I should see "Couldn't complete the action as the start date of project(s) Drafted PBE group are already past. Please set a new start for mentioned project to complete the action in bulk."


