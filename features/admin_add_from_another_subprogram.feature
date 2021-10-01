Feature: Admin adds users from other subprograms

Background:
  Given the current program is "primary":"albers"
  And I give permission to admins in program "primary":"albers"
  And "student" role "term" is called as "Box" in "primary":"albers"
  And "mentor" role "term" is called as "Car" in "primary":"albers"
  And "mentor" role "pluralized_term" is called as "Cars" in "primary":"albers"
  And "student" role "pluralized_term" is called as "Boxes" in "primary":"albers"
  And "Program" "term_downcase" is called as "community" in "primary"
  And "Program" "term" is called as "Community" in "primary"
  And "Program" "pluralized_term_downcase" is called as "communities" in "primary"

@javascript
Scenario: Admin needs to select users for bulk action
  When I have logged in as "ram@example.com"
  Then I list all the programs
  And I select "Albers Mentor Program" from the program selector
  And I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from Primary Organization"
  Then I should not see "Good unique"
  But I should see "moderated_student@example.com"
  Then I should see "Actions"
  Then I follow "Add to Community" in the bulk actions
  Then I should see "Please select at least one user"
  Then I logout

@javascript
Scenario: Admin adds mentor from another sub program
  When I have logged in as "ram@example.com"
  Then I list all the programs
  And I select "Albers Mentor Program" from the program selector
  And I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from Primary Organization"
  Then I should not see "Good unique"
  But I should see "moderated_student@example.com"
  Then I should see "Actions"

  When I select "moderated_student@example.com" from the sub-program user import selector
  Then I follow "Add to Community" in the bulk actions
  And I check "Car"
  And I press "Submit"
  Then I should see "The selected user (in Active state) has been imported to this community as Car"

  When I logout
  And I have logged in as "moderated_student@example.com"
  Then I list all the programs
  Then I should see program selector containing "Moderated Program" under "Primary Organization"
  And I should see program selector containing "Albers Mentor Program" under "Primary Organization"
  Then I list all the programs

  When I select "Primary Organization" from the program selector
  Then I click ".profile_header_image"
  And I follow "View Profile"
  Then I should see the role "Car" in "Albers Mentor Program"
  And I should see the role "Student" in "Moderated Program"

@javascript
Scenario: Admin adds mentee from another sub program
  When I have logged in as "ram@example.com"
  Then I list all the programs
  And I select "Albers Mentor Program" from the program selector
  And I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from Primary Organization"
  Then I should not see "Good unique"
  But I should see "moderated_student@example.com"
  Then I should see "Actions"

  When I select "moderated_student@example.com" from the sub-program user import selector
  Then I follow "Add to Community" in the bulk actions
  And I check "Box"
  And I press "Submit"
  Then I should see "The selected user (in Active state) has been imported to this community as Box"

  When I logout
  And I have logged in as "moderated_student@example.com"
  Then I list all the programs
  Then I should see program selector containing "Moderated Program" under "Primary Organization"
  And I should see program selector containing "Albers Mentor Program" under "Primary Organization"
  Then I hover over "my_programs_container"

  Then I list all the programs
  When I select "Primary Organization" from the program selector
  Then I click ".profile_header_image"
  And I follow "View Profile"
  Then I should see the role "Box" in "Albers Mentor Program"
  And I should see the role "Student" in "Moderated Program"

@javascript @cross_browser
Scenario: Admin adds mentor and mentee from another sub program
  When I have logged in as "ram@example.com"
  Then I list all the programs
  And I select "Albers Mentor Program" from the program selector
  And I follow "Manage"
  Then I should see "Community Settings"
  And I follow "Community Settings"
  Then I should see "Membership"
  Then I follow "Membership"
  Then I should see "Allow user to apply or join for more than one role"
  And I choose "program_show_multiple_role_option_true"
  And I press "Save"
  And I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from Primary Organization"
  Then I should not see "Good unique"
  But I should see "moderated_student@example.com"
  Then I should see "Actions"

  When I select "moderated_student@example.com" from the sub-program user import selector
  Then I follow "Add to Community" in the bulk actions
  And I check "Box"
  And I check "Car"
  And I press "Submit"
  Then I should see "The selected user (in Active state) has been imported to this community as Car and Box"

  When I logout
  And I have logged in as "moderated_student@example.com"
  Then I list all the programs
  Then I should see program selector containing "Moderated Program" under "Primary Organization"
  And I should see program selector containing "Albers Mentor Program" under "Primary Organization"
  Then I list all the programs

  When I select "Primary Organization" from the program selector
  Then I click ".profile_header_image"
  And I follow "View Profile"
  Then I should see the role "CarBox" in "Albers Mentor Program"
  And I should see the role "Student" in "Moderated Program"

@javascript
Scenario: Admin bulk adds mentors and mentees from another sub program
  When I have logged in as "ram@example.com"
  Then I list all the programs
  And I select "Albers Mentor Program" from the program selector
  And I follow "Manage"
  Then I should see "Community Settings"
  And I follow "Community Settings"
  Then I should see "Membership"
  Then I follow "Membership"
  Then I should see "Allow user to apply or join for more than one role"
  And I choose "program_show_multiple_role_option_true"
  And I press "Save"
  And I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from Primary Organization"
  Then I should not see "Good unique"
  But I should see "moderated_student@example.com"
  Then I should see "Actions"

  And I check "cjs_user_primary_checkbox"
  Then I follow "Add to Community" in the bulk actions
  And I check "Box"
  And I check "Car"
  And I press "Submit"
  Then I should see "The selected 13 users (in Active state) have been imported to this community as Cars and Boxes"

@javascript @cross_browser
Scenario: Admin bulk adds admins, mentors and mentees from another sub program
  When I have logged in as "ram@example.com"
  Then I list all the programs
  And I select "Albers Mentor Program" from the program selector
  And I follow "Manage"
  Then I should see "Community Settings"
  And I follow "Community Settings"
  Then I should see "Membership"
  Then I follow "Membership"
  Then I should see "Allow user to apply or join for more than one role"
  And I choose "program_show_multiple_role_option_true"
  And I press "Save"
  And I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from Primary Organization"
  Then I should not see "Good unique"
  But I should see "moderated_student@example.com"
  Then I should see "Actions"

  And I check "cjs_user_primary_checkbox"
  Then I follow "Add to Community" in the bulk actions
  And I check "Box"
  And I check "Car"
  And I should see "Administrator"
  And I check "Admin"
  And I should see "User(s) will be added as Administrator"
  And I press "Submit"
  Then I should see "The selected 13 users (in Active state) have been imported to this community as Administrators, Cars and Boxes"

@javascript
Scenario: Admin should not be able to add user if role not selected
  When I have logged in as "ram@example.com"
  Then I list all the programs
  And I select "Albers Mentor Program" from the program selector
  And I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from Primary Organization"
  Then I should not see "Good unique name"
  But I should see "moderated_student@example.com"

  When I select "moderated_student@example.com" from the sub-program user import selector
  Then I follow "Add to Community" in the bulk actions
  And I press "Submit"
  Then I should not see "The selected user (in Active state) has been imported to this community as Box"
  Then I should not see "The selected user (in Active state) has been imported to this community as Car"

@javascript @cross_browser
Scenario: Admin applies filters and sorts results
  Given the current program is "primary":"nwen"
  And I give permission to admins in program "primary":"nwen"
  And Ram is an admin for nwen and moderated program
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from Primary Organization"
  Then I should see "Dormant users"

  When I set filter by program "primary":"modprog"
  And I should see "Community/Role" within "#your_filters span"
  Then I should see the users from program "moderated" and filter "all"

  When I reset filter by program "primary":"modprog"
  And I set filter by role "mentor" of "primary":"modprog"
  Then I should see the users from program "moderated" and filter "mentor"

  When I reset filter by role "mentor" of "primary":"modprog"
  And I set filter by role "student" of "primary":"modprog"
  Then I should see the users from program "moderated" and filter "student"

  Then I remove filter with id "filter_item_program_role"
  Then I should see "mentor_8@example.com"
  Then I should see "moderated_admin@example.com"

  And I should see "First name" within "tr.cui_table_sort th.sort_asc"
  And I click to sort items by first name
  And I should see "First name" within "tr.cui_table_sort th.sort_desc"