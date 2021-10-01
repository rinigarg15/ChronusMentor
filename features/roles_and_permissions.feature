Feature: Roles and Permissions
  In order to manage permissions to different roles
  As an admin
  I want to view and update various permissions

Background: The current program is albers
  # Login as Admin
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Permissions"

@javascript
Scenario: Students can publish Articles
  Then the "mentees_publish_articles" checkbox_id should not be checked
  Then I check "mentees_publish_articles"
  And I press "Save"
  Then the "mentees_publish_articles" checkbox_id should be checked
  Then I logout

@javascript
Scenario: Allow users to send message out side mentoring area
  And I should see the radio button "program_allow_user_to_send_message_outside_mentoring_area_true" selected
  Then I choose "program_allow_user_to_send_message_outside_mentoring_area_false"
  And I press "Save"
  Then I should see the radio button "program_allow_user_to_send_message_outside_mentoring_area_false" selected
  Then I logout

@javascript
Scenario: Allow only global admins to change permission for track admins to access all users
  And I should see "Allow program administrators to view profiles of, and add global users to this program"
  And I should see the radio button "program_allow_track_admins_to_access_all_users_false" selected
  Then I choose "program_allow_track_admins_to_access_all_users_true"
  And I press "Save"
  Then I should see the radio button "program_allow_track_admins_to_access_all_users_true" selected
  Then I logout
  And I have logged in as "userram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Permissions"
  And I should not see "Allow program administrators to view profiles of, and add global users to this program"
  Then I logout

@javascript
Scenario: Mentors and mentees can view all others mentors and mentees
  Then the view "mentors" permission should be enabled for "mentor" role
  And the view "students" permission should be enabled for "mentor" role
  And the view "mentors" permission should be enabled for "student" role
  And the view "students" permission should be enabled for "student" role
  And I logout
  Given the current program is "primary":"albers"
  And I have logged in as "robert@example.com"
  Then I should see "Mentors"
  And I should see "Students"
  And I logout
  Given the current program is "primary":"albers"
  And I have logged in as "rahim@example.com"
  Then I should see "Mentors"
  And I should see "Students"
  And I logout

@javascript
Scenario: Mentors Should not see students and students should not see other students and mentors
  Then the view "mentors" permission should be enabled for "mentor" role
  And the view "students" permission should be enabled for "mentor" role
  And the view "mentors" permission should be enabled for "student" role
  And the view "students" permission should be enabled for "student" role
  When I disable view "students" permission for "mentor" role
  And I disable view "mentors" permission for "student" role
  And I disable view "students" permission for "student" role
  And I press "Save"
  Then the view "mentors" permission should be enabled for "mentor" role
  And I logout
  Given the current program is "primary":"albers"
  And I have logged in as "robert@example.com"
  Then I should see "Mentors"
  Then I should not see "Students"
  Then I logout
  Given the current program is "primary":"albers"
  And I have logged in as "rahim@example.com"
  Then I should not see "Mentors"
  Then I should not see "Students"
  Then I logout