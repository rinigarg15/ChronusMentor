@manage_connection
Feature: Admin should be able to manage connections
In order to modify the connections of a user
As an admin
I want to be able to add new connections, find a mentor, add new member

@javascript @download
Scenario: Admin exports the mentoring connections as CSV

  Given the current program is "primary":"albers"
  And I clear the downloads folder
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
  And I add the following "mentors" with names "mentor_a chronus,mentor_c chronus"
  And I add the following "mentees" with names "student_a example,student_b example"
  And I click "#create_and_publish"
  Then I should see "chronus, chronus, example, & example"
  And I check "cjs_groups_primary_checkbox"
  And I follow "Export Mentoring Connections as CSV" in the bulk actions
  Then I should see "mentoring connections will be included in the downloaded csv."
  And I press "Export"
  Then I wait for download to complete
  Then the csv must contain "chronus, chronus, example, & example" under "Mentoring Connection Name"
  Then the csv must contain "mentor_a chronus, mentor_c chronus" under "Mentors"
  Then the csv must contain "student_a example, student_b example" under "Students"

@javascript
Scenario: Mentor should not see Connections
  Given the current program is "primary":"albers"
  And I have logged in as "robert@example.com"
  And I follow "Students"
  And I should see "student example"
  And I follow "student example"
  And I should not see "student example's Mentoring Connections" within ".right_pane"
  And I follow "Mentors"
  And I should see "Good unique name"
  And I follow "Good unique name" within "#mentors_index"
  And I should not see "Good unique name's Mentoring Connections" within ".right_pane"
  Then I logout

@javascript
Scenario: Mentee should not see Connections
  Given the current program is "primary":"albers"
  And I have logged in as "rahim@example.com"
  And I follow "Students"
  And I should see "student example"
  And I follow "student example" within "#mentors_index"
  And I should not see "student example's Mentoring Connections" within ".right_pane"
  When I navigate to "robert@example.com" profile in "albers"
  And I should not see "Good unique name's Mentoring Connections" within ".right_pane"
  Then I logout

@javascript
Scenario: Back links for mentors and mentees
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I follow "Mentors"
  And I should see "Mentor Studenter"
  And I follow "Mentor Studenter"
  And I follow "Mentoring Connections (0)"
  And I follow "Create New Mentoring Connection"
  Then I close modal
  Then I follow back link
  And I should see "Mentor Studenter"
  And I should see "The user does not have any ongoing mentoring connections. Switch tabs to see mentoring connections in other states."
  And I follow "Students"
  And I should see "student example"
  And I follow "student example"
  And I follow "Mentoring Connections (0)"
  And I follow "Find a Mentor"
  Then I follow back link
  And I should see "student example"

@javascript
Scenario: Connection counts in member profile tabs
  Given the current program is "primary":"pbe"
  And I have logged in as "ram@example.com"
  And I follow "Mentors"
  And I should see "Good unique name"
  And I follow "Good unique name"
  And I follow "Mentoring Connections (1)"
  And I should see "Ongoing (1)" in user's group tabs
  And I should see "Closed (0)" in user's group tabs
  And I should see "Proposed (2)" in user's group tabs
  And I should see "Rejected (1)" in user's group tabs
  Then I follow "Closed (0)"
  And I should see "The user does not have any closed mentoring connections. Switch tabs to see mentoring connections in other states."
  Then I follow "Drafted (0)"
  And I should see "The user does not have any drafted mentoring connections. Switch tabs to see mentoring connections in other states."
  Then I follow "Available (0)"
  And I should see "The user does not have any available mentoring connections. Switch tabs to see mentoring connections in other states."
  Then I follow "Withdrawn (1)"
  And I should see "Good unique name" within "div#group_elements"

@javascript
Scenario: Admin Add/Update Notes for connections
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Connections"
  And I click on dropdown of the group "name & madankumarrajan"
  Then I should see "Add/Update Notes"
  And I follow "Add/Update Notes"
  Then I should see "Add Notes"
  And I fill in "group_notes" with "Test Notes"
  And I press "Add"
  Then I should see "Test Notes" in the group "name & madankumarrajan"
  When I follow "name & madankumarrajan"
  Then I should see "Test Notes" in connection admin notes section
  When I follow "Edit" in connection admin notes section
  And I fill in "group_notes" with "Updated Notes"
  And I press "Update"
  Then I should see "Updated Notes" in connection admin notes section
  And I should not see "Test Notes" in connection admin notes section
  When I follow "Edit" in connection admin notes section
  And I fill in "group_notes" with ""
  And I press "Update"
  Then I should not see "Updated Notes" in connection admin notes section
  And I should see "You can attach a personal note or description about this mentoring connection." in connection admin notes section
  When I follow "Add Notes" in connection admin notes section
  And I fill in "group_notes" with "Notes 2.0"
  And I press "Add"
  Then I should see "Notes 2.0" in connection admin notes section
  And I should not see "You can attach a personal note or description about this mentoring connection." in connection admin notes section
  And I logout

  When I have logged in as "robert@example.com"
  And I follow "name & madankumarrajan" subtab inside opened navigation header
  Then I should not see "Administrator Notes"
  And I should not see "Notes 2.0"
  And I logout

@javascript @reindex @cross_browser
Scenario: Admin Bulk Actions for connections
  Given the current program is "primary":"albers"
  #Then I reindex model "group"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Connections"
  Then I should see "Actions"
  Then I follow "Send Message" in the bulk actions
  Then I should see the flash "Please select at least one mentoring connection"
  And I click "#cjs_groups_primary_checkbox"
  Then I follow "Send Message" in the bulk actions
  And I fill in "admin_message_subject" with "Test Subject"
  And I fill in CKEditor "admin_message_content" with "Test Detail"
  And I press "Send"
  Then I should see the flash "Your message has been sent"

  Then I follow "Set Expiration Date" in the bulk actions
  And I fill in "bulk_actions_mentoring_period" with a date "February 28, 2030"
  And I fill in "bulk_actions_reason" with "Test Reason"
  And I press "Set Expiration Date"
  Then I should see the flash "Expiration date updated successfully"
  And I should see "February 28, 2030" within "#groups"

  And I click "#cjs_groups_primary_checkbox"
  Then I follow "Close Mentoring Connection" in the bulk actions
  And I fill in "bulk_actions_termination_reason" with "Test Reason"
  And I press "Close"
  Then I should see "Mentoring Connections closed successfully"
  And I should see "0" within "#cjs_ongoing_count"
  And I should see "7" within "#cjs_closed_count"

  And I click "#closed_tab a"
  Then I follow "Reactivate Mentoring Connection" in the bulk actions
  Then I should see the flash "Please select at least one mentoring connection"
  And I click "#cjs_groups_primary_checkbox"
  Then I follow "Reactivate Mentoring Connection" in the bulk actions
  Then I should see "1 mentoring connection will be reactivated."
  And I fill in "bulk_actions_mentoring_period" with a date "March 15, 2035"
  And I fill in "bulk_actions_reason" with "Test Reason"
  And I press "Reactivate"
  Then I should see the flash "Mentoring Connections reactivated successfully"
  Then I logout

@javascript
Scenario: Admin sees non-published users creating connection
  Given the current program is "foster":"main"
  And I have logged in as "fosteradmin@example.com"
  And I navigate to "Connections" from manage page
  And I follow "Create New Mentoring Connection"
  And I click the "mentor" field with enclosure id as "ul.select2-choices" of "foster":"main"
  Then I should see "Miller Adams <millad1@foster.com>"
  Then I close select2 dropdown
  And I click the "student" field with enclosure id as "ul.select2-choices" of "foster":"main"
  Then I should see "Lao Zi <studnt1@foster.com>"
  Then I close select2 dropdown

@javascript
Scenario: Admin sees errror flash when publishing connection exceeding limit
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And I select "Albers Mentor Program" from the program selector
  And I follow "Mentors"
  And I follow "mentor_b chronus"
  And I follow "Edit mentor_b chronus's profile"
  And I follow "Settings"
  And I click on the section with header "Ongoing Mentoring"
  And I fill in "Connections Limit" with "2"
  Then I press "Save" within "#settings_section_ongoing"
  And I follow "Manage"
  And I navigate to "Mentoring Connections" from manage page
  And I follow "Drafted"
  And I should see "Drafted" within "li.ct_active"
  And I should see "chronus & example"
  And I follow "Publish Mentoring Connection" within "#group_11"
  And I fill in "group_message" with "Test Message"
  And I press "Publish"
  Then I should see "mentor_b chronus preferred not to have more than 2 students"
  And I should see "drafted_group_1"
  And I click "#cjs_groups_primary_checkbox"
  Then I follow "Publish Mentoring Connection" in the bulk actions
  And I press "Publish"
  Then I should see "mentor_b chronus preferred not to have more than 2 students"
  And I should not see "drafted_group_1"

@filter @javascript
Scenario: Admin trying to use the filter in  manage connections page
  Given the current program is "primary":""
  When I have logged in as "ram@example.com"
  And I select "Albers Mentor Program" from the program selector
  Then I follow "Manage"
  And I follow "Mentoring Connections"
  And I follow "Closed"
  Then I should see "Closed on" within "#filter_pane"
  And I should see "Started on" within "#filter_pane"
  And I follow "Ongoing"
  Then I should see "Closes on" within "#filter_pane"
  And I should see "Started on" within "#filter_pane"

  # Testing with different timezones
  And I set current timezone to yesterday
  Then I click on "Started on" header
  And I choose "Last 7 days" from date selector
  Then the date range should be a "week" for "Started on"
  And I choose "Last 30 days" from date selector
  Then the date range should be a "month" for "Started on"

  And I should not see "Closed on" within "#filter_pane"
  And I follow "Drafted"
  Then I should not see "Closes on" within "#filter_pane"
  And I should not see "Started on" within "#filter_pane"
  And I should not see "Closed on" within "#filter_pane"
  And I logout
  Then I have logged in as "mkr@example.com"
  And I follow "View Profile"
  And I follow "Ongoing mentoring connections"
  Then I should not see "Closes on" within "#filter_pane"
  And I should not see "Started on" within "#filter_pane"
  And I should not see "Closed on" within "#filter_pane"
  And I logout

@javascript
Scenario: Admin sees should able to change connection limit to all mentors/new mentors
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And I select "Albers Mentor Program" from the program selector
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I fill in "Maximum concurrent students for a mentor" with "20"
  And I press "Save"
  And I click "#cjs_all_mentors"
  And I fill in "Maximum concurrent students for a mentor" with "25"
  And I press "Save"
  And I click "#cjs_only_new_mentors"
  Then I logout
  And I have logged in as "robert@example.com"
  And I select "Albers Mentor Program" from the program selector
  And I click on profile picture and click "Edit Profile"
  Then I follow "Settings"
  Then I click on the section with header "Ongoing Mentoring"
  And value of "#user_max_connections_limit" should be "20"

@javascript @cross_browser
Scenario: Admin toggles between list view and detailed view. Filters, tabs, must be retained
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I enable "mentoring_connections_v2" feature as a super user
  And I follow "Manage"
  And I follow "Connections"
  And I should see "Ongoing" under group tabs
  And I should see "Closed" under group tabs
  And I should see "Ongoing" selected under group tabs
  And I should see "group_view_columns_update_link" hidden
  And I click "#list_view"
  And I should see "Ongoing" selected under group tabs
  And I should see "group_view_columns_update_link" not hidden
  And I should see "mentor & example" within "#group_elements"
  Then I filter for "sub_filter_active" connections
  And I should see "Status" within "#your_filters"
  And I should see "mentor & example" within "#group_elements"
  And I should see "chronus & example" within "#group_elements"
  And I click "#detailed_view"
  And I should see "Status" within "#your_filters"
  And I should see "mentor & example" within "#groups"
  And I should see "chronus & example" within "#groups"
  Then I follow "Reset all"
  And I follow "Closed"
  And I should see "Closed" selected under group tabs
  And I click "#list_view"
  And I should see "Closed" selected under group tabs

@javascript @cross_browser
Scenario: Admin applies filters and sorts results
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I enable "mentoring_connections_v2" feature as a super user
  And I follow "Manage"
  And I follow "Connections"
  And I click "#list_view"
  And I should see "Ongoing" selected under group tabs
  And I should see "chronus & example" within "#group_elements"
  And I should see "mentor & example" within "#group_elements"
  Then I filter for "sub_filter_active" connections
  And I should see "Status" within "#your_filters"
  And I should see "mentor & example" within "#group_elements"
  And I should see "chronus & example" within "#group_elements"
  And I remove filter with id "filter_item_status"
  And I should see "mentor & example" within "#group_elements"
  And I should see "chronus & example" within "#group_elements"
  When I filter on "Mentor" with name "mentor"
  Then I should see "mentor & example" within "#group_elements"
  And I should not see "chronus & example" within "#group_elements"
  And I should see "Mentor" within "#your_filters"
  And I should see "Mentoring Connection Name" within "tr.cui_table_sort th.sort_asc"
  And I click to sort connections by name
  And I should see "Mentoring Connection Name" within "tr.cui_table_sort th.sort_desc"
  Then I follow "Reset all"

@javascript @reindex @cross_browser
Scenario: Admin Bulk Actions for list view
  Given the current program is "primary":"albers"
  #Then I reindex model "group"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Connections"
  And I click "#list_view"
  Then I should see "Actions"
  Then I follow "Send Message" in the bulk actions
  Then I should see "Please select at least one mentoring connection"
  And I click "#cjs_groups_primary_checkbox"
  Then I follow "Send Message" in the bulk actions
  Then I should see "Add an attachment"
  And I fill in "admin_message_subject" with "Test Subject"
  And I fill in CKEditor "admin_message_content" with "Test Detail"
  And I press "Send"
  Then I should see "Your message has been sent"

  Then I follow "Set Expiration Date" in the bulk actions
  And I fill in "bulk_actions_mentoring_period" with a date "February 28, 2030"
  And I fill in "bulk_actions_reason" with "Test Reason"
  And I press "Set Expiration Date"
  Then I should see "Expiration date updated successfully"

  And I click "#cjs_groups_primary_checkbox"
  Then I follow "Close Mentoring Connection" in the bulk actions
  And I fill in "bulk_actions_termination_reason" with "Test Reason"
  And I press "Close"
  Then I should see "Mentoring Connections closed successfully"
  And I should see "0" within "#cjs_ongoing_count"
  And I should see "7" within "#cjs_closed_count"

  And I click "#closed_tab a"
  Then I follow "Reactivate Mentoring Connection" in the bulk actions
  Then I should see "Please select at least one mentoring connection"
  And I click "#cjs_groups_primary_checkbox"
  Then I follow "Reactivate Mentoring Connection" in the bulk actions
  Then I should see "1 mentoring connection will be reactivated."
  And I fill in "bulk_actions_mentoring_period" with a date "March 15, 2035"
  And I fill in "bulk_actions_reason" with "Test Reason"
  And I press "Reactivate"
  Then I should see "Mentoring Connections reactivated successfully"
  
  And I click "#closed_tab a"
  And I click "#cjs_groups_primary_checkbox"
  Then I stub "mentoring_connections_v2_enabled?" for "Program" as "boolean" value "true"
  Then I follow "Duplicate Mentoring Connections" in the bulk actions
  Then I should see the radio button "bulk_actions_assign_new_template_true" selected
  Then I click ".cjs_assign_existing_template"
  And element with the id "#cjs_assign_mentoring_model" should be disabled
  Then I click ".cjs_assign_new_template"
  And element with the id "#cjs_assign_mentoring_model" should not be disabled
  Then I logout

@javascript @reindex
Scenario: Member should see overdue engagement survey popup in engagement area
  Given the current program is "primary":"albers"
  And I create overdue survey task
  And I have logged in as "robert@example.com"
  And I follow "name & madankumarrajan" subtab inside opened navigation header
  Then I should see "task title - Mentoring Relationship Health"
  Then I should see "The Mentoring Relationship Health is overdue. Please fill in the survey below."
  Then I press "Submit"
  Then I should see "task title - Mentoring Relationship Health"
  Then I should see "Please fill all the required fields. Fields marked * are required"
  Then I follow "Cancel"
  And I follow "Students"
  And I follow "name & madankumarrajan" subtab inside opened navigation header
  Then I should not see "task title - Mentoring Relationship Health"
  Then I should not see "The Mentoring Relationship Health is overdue. Please fill in the survey below."
  Then I logout
  And I have logged in as "robert@example.com"
  And I follow "name & madankumarrajan" subtab inside opened navigation header
  Then I should see "task title - Mentoring Relationship Health"
  Then I should see "The Mentoring Relationship Health is overdue. Please fill in the survey below."
  And I fill the answers "'Good', 'Yes', 'Good', '', ''" of "Mentoring Relationship Health"
  Then I follow "Save as draft"
  Then I should see "Your draft for the survey 'Mentoring Relationship Health' has been saved successfully."
  Then I logout
  And I have logged in as "robert@example.com"
  And I follow "name & madankumarrajan" subtab inside opened navigation header
  Then I should see "task title - Mentoring Relationship Health"
  Then I should see "The Mentoring Relationship Health is overdue. Please fill in the survey below."
  Then I press "Submit"
  Then I should see "Thanks for completing Mentoring Relationship Health"

@javascript
Scenario: A user can be part of a group in only one role

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
  And I add the following "mentors" with names "Mentor Studenter"
  Then I find no matches for the "mentees" with names "Mentor Studenter"
  Then I remove "Mentor Studenter" from the selected list
  And I add the following "mentees" with names "Mentor Studenter"
  Then I find no matches for the "mentors" with names "Mentor Studenter"
  And I add the following "mentors" with names "mentor_a chronus,mentor_c chronus"
  And I click "#create_and_publish"
  Then I should see "chronus, chronus, & Studenter"
