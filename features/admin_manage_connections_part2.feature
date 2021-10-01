@manage_connection
Feature: Admin should be able to manage connections
In order to modify the connections of a user
As an admin
I want to be able to add new connections, find a mentor, add new member


@javascript @cross_browser
Scenario: Admin updates columns for list view
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Connections"
  And I click "#list_view"
  And I should see "Mentoring Connection Name" within "#groups"
  And I should not see "Mentor - Location" within "#groups"
  And I should see "Edit Columns"
  And I click "#group_view_columns_update_link"
  Then I maximize the window
  And I should see "Select Fields to Display"
  Then I remove all fields to display
  Then I should not see "The columns to be shown have been updated"
  But I should see "You need to select at least one field"
  And I select all mentor columns
  Then I should see "The columns to be shown have been updated"
  And I should not see "Mentoring Connection Name" within "#groups"
  And I should see "Mentor - Location" within "#groups"
  And I should see "Mentor - Email" within "#groups"
  And I should see "Student - Email" within "#groups"

@javascript
Scenario: On creating a new connection, the view must be retained
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Connections"
  And I click "#list_view"
  And I follow "Closed"
  And I should see "Closed" selected under group tabs
  And I follow "Create New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>" 
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"
  And I click "#create_and_publish"
  And I should see "Ongoing" within "li.ct_active"
  Then I should see "name & example"
  Then I should not see "Visit Mentoring Area"
  Then I should see "Mentoring Connection Name" within "#cjs_group_record"

@javascript @not_run_on_bs
Scenario: Admin check login instances
# Remote Driver issue with dual login
  Given the current program is "annauniv":"psg"
  And I have logged in as "mentor1@psg.com"
  And I logout
  And I have logged in as "psg@example.com"
  And I follow "Manage"
  And I follow "Connections"
  And I should see "1" within ".login_count"
  And I logout
  And I have logged in as "stud1@psg.com"
  And I logout
  And I have logged in as "psg@example.com"
  And I follow "Manage"
  And I follow "Connections"
  And I should see "2" within ".login_count"
  Then I follow "More"
  And I should see "1" 
  And I should see "PSG mentora"

@javascript @cross_browser
Scenario: Applying filter and sort siultaneously
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I enable "mentoring_connections_v2" feature as a super user
  And I follow "Manage"
  And I follow "Connections"
  And I should see "Ongoing" selected under group tabs
  And I should see "chronus & example" within "#group_elements"
  And I should see "mentor & example" within "#group_elements"
  And I select "Expiration time" from "sort_by"
  And I wait for ajax to complete
  And I should see "Expiration time" selected from "#sort_by"
  Then I filter for "sub_filter_active" connections
  And I should see "Status" within "#your_filters"
  And I should see "Expiration time" selected from "#sort_by"
  # On view change, filters are retained, but sort is reverted to default
  Then I click "#list_view"
  Then I should not see "#sort_by"
  And I should see "Mentoring Connection Name" within "tr.cui_table_sort th.sort_asc"
  And I should see "Status" within "#your_filters"
  And I click to sort connections by name
  And I should see "Mentoring Connection Name" within "tr.cui_table_sort th.sort_desc"
  And I click "#detailed_view"
  Then I should see "Recently connected" selected from "#sort_by"
  And I should see "Status" within "#your_filters"
  And I select "Recently active" from "sort_by"
  Then I should see "Recently active" selected from "#sort_by"
  # Creation of new connection should revert all the filter/sort options
  Then I follow "Create New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"
  And I click "#create_and_publish"
  Then I should see "name & example"
  Then I should see "#reset_all" hidden

@javascript
Scenario: Survey Response filter
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Connections"
  Then I should not see "Survey Response" within "#filter_pane"
  Then I enable "mentoring_connections_v2" feature as a super user
  And I follow "Manage"
  And I follow "Connections"
  Then I should see "Survey Response" within "#filter_pane"

@javascript
Scenario: Creating one to one connection
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Connections"
  And I follow "Create New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>" 
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"
  And I click "#create_and_publish"
  Then I should see "name & example"

@javascript
Scenario: Creating one to one connection with one time mentoring mode
  Given the current program is "primary":"albers"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I have logged in as "ram@example.com"
  When I login as super user
  And I follow "Manage"
  Then I follow "Program Settings"
  Then I follow "Matching Settings"
  Then I check "program_allow_mentoring_mode_change"
  And I press "Save"
  And I follow "Manage"
  And I follow "Connections"
  And I follow "Create New Mentoring Connection"
  And I change mentoring mode of mentor with email "robert@example.com" in program "primary":"albers" to "one time"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"
  And I click "#create_and_publish"
  Then I should see "Good unique name has preferred to participate only in One time mentoring"

@javascript @cross_browser
Scenario: Trying to update group by adding mentor with one time mentoring mode
  Given the current program is "annauniv":"psg"
  And I enable "calendar" feature that was removed from UI as super user of "annauniv":"psg"
  When I have logged in as "psg@example.com"
  When I login as super user
  And I follow "Manage"
  Then I follow "Program Settings"
  Then I follow "Matching Settings"
  Then I check "program_allow_mentoring_mode_change"
  And I press "Save"
  And I navigate to "Connections" from manage page
  And I change mentoring mode of mentor with email "mentor@psg.com" in program "annauniv":"psg" to "one time"
  And I click on dropdown of the group "mentora, mentorb, mentorc, psg, psg, & psg"
  And I follow "Manage Members"
  Then I follow "Add Mentor"
  When I fill in "add_member_mentor" with "mental mentor <mentor@psg.com>"
  And I press "Add"   
  Then I should see "mental mentor"
  And I press "Save"
  Then I should see "mental mentor has preferred to participate only in One time mentoring"

@javascript
Scenario: Super user should be able to download the solution pack
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  Then I should see "Export Solution Pack" hidden
  When I login as super user
  Then I follow "Manage"
  Then I should see "Export Solution Pack"
  Then I follow "Export Solution Pack"
  Then I should see "Created by"
  And I fill in "Created by :" with "test user"
  And I fill in "Description :" with "testing solution pack"
  And I press "Submit"
  Then I should see "Successfully Exported!"
  Then I logout

@javascript @cross_browser
Scenario: Admin creates a group mentoring connection

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
  And I wait for animation to complete
  And I add the following "mentors" with names "mentor_a chronus,mentor_c chronus"
  And I add the following "mentees" with names "student_a example,student_b example"
  And I click "#create_and_publish"
  Then I should see "chronus, chronus, example, & example"

  @javascript
  Scenario: Admin duplicates a closed group mentoring connection
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Mentoring Connections"
    And I should see "6" within "#cjs_ongoing_count"
    And I follow "Closed"
    And I click on "clone_link_4" for the group "group_4"
    Then I should see "Create Duplicate Mentoring Connection"
    Then I should see "mentor & example" in group attribute "#group_name"
    Then I should see "Requestable mentor <request@example.com>" as "mentor" of the closed group "mentor & example"
    Then I should see "student_e example <student_4@example.com>" as "mentee" of the closed group "mentor & example"
    Then I press "Duplicate"
    And I should see "7" within "#cjs_ongoing_count"