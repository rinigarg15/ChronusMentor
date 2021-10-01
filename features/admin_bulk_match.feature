
Feature: Bulk Match Landing Page

Background: Admin logs in and enabled required features
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  Then I have enabled "bulk_matching" feature
  Then I create a few default configs
  Given the current program is "primary":"albers"

@javascript @cross_browser 
Scenario: Admin selects Admin Views for Bulk Match
  And I logout
  Given the current program is "annauniv":""
  And I have logged in as "ceg_admin@example.com"
  And I enable "bulk_matching" feature as a super user
  Given the current program is "annauniv":"ceg"

  When I go to bulk match page in annauniv:ceg program
  Then I should see "Bulk Match Users"
  And I should see ".cjs_bulk_match_export" hidden
  When I press "Next »"
  And I should see "Please select a view for both the roles"
  When I click "#s2id_bulk_match_mentor_view_id > .select2-choice"
  And I click ".cjs_create_admin_view_link"

  Then I should see "Create New View"
  And I fill in "admin_view_title" with "Bulk Match Mentor View"
  Then I follow "Next »"
  Then I click view
  Then I should not see "Draft" within ".well.white-bg"
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Mentor"
  And I check "admin_view_roles_and_status_state_pending"
  And I select "Currently connected" from "cjs-connection-status-filter-category-1"
  And I press "Create View"

  Then I should see "The View - Bulk Match Mentor View has been created successfully"
  And I follow "Edit View"
  Then I should not see "Delete View"
  And I should see ".cjs_admin_view_step" hidden
  Then I should see "href" attribute for link "Back" matches with "/p/ceg/users/bulk_match"
  And I press "Update View"
  Then I should see "The View - Bulk Match Mentor View has been updated successfully"
  And I follow "View Users"
  Then I should see "href" attribute for link "Back" matches with "/p/ceg/users/bulk_match"
  And I follow the back link
  Then I should see "Select Users"
  When I click "#s2id_bulk_match_mentee_view_id > .select2-choice"
  And I click on select2 result "All Mentees"

  Then I should see "1" within ".cjs_student_view_content"
  Then I should see "Student" within ".cjs_student_view_content"
  When I click "#s2id_bulk_match_mentor_view_id > .select2-choice"

  And I click on select2 result "Bulk Match Mentor View"

  And I should see "0" within ".cjs_mentor_view_content"
  Then I should see "Mentor" within ".cjs_mentor_view_content"
  Then I should see "Unpublished" within ".cjs_mentor_view_content"
  Then I should see "Currently connected" within ".cjs_mentor_view_content"
  And I press "Next »"
  Then I should see "Both Mentor and Student View should have at least One User. Please select some other view."
  And I follow "select_users"
  Then I should see "Are you sure you want to navigate from this tab? Please make sure you Draft/Publish all required pairs. UnMatched/Selected pairs will not be preserved."
  And I confirm popup
  Then I should not see "View drafted pairs"
  And I have a connection associated with bulk match
  When I click "#s2id_bulk_match_mentor_view_id > .select2-choice"

  And I click on select2 result "All Mentors"

  Then I should see "3" within ".cjs_mentor_view_content"
  Then I press "Next »"
  Then I should see "Bulk Actions"
  Then I follow "View drafted pairs"
  Then I switch to latest window
  Then I should see "Drafted (0)"
  Then I close the new window and switch to main window
  And I logout

@javascript @cross_browser 
Scenario: Admin selects orientation type and Admin Views for Mentor to Mentee Bulk Match
  And I logout
  Given the current program is "annauniv":"ceg"
  And I have logged in as "ceg_admin@example.com"
  And I enable "bulk_matching" feature as a super user
  And I enable "mentor_to_mentee_matching" feature as a super user
  When I go to bulk match page in annauniv:ceg program
  Then I should see "Bulk Match Users"
  And I should see "Students" within "#cjs_bulk_match_orientation_type"
  And I should see "Match every student with the best mentor available" within "#cjs_bulk_match_orientation_type"
  And I should see "Mentors" within "#cjs_bulk_match_orientation_type"
  And I should see "Match every mentor with the best student available"
  Then I should see the radio button "orientation_type_mentee_to_mentor" selected
  Then I choose "orientation_type_mentor_to_mentee"
  Then I should see the radio button "orientation_type_mentor_to_mentee" selected
  And I should see ".cjs_bulk_match_export" hidden
  When I press "Next »"
  And I should see "Please select a view for both the roles"
  When I click "#s2id_bulk_match_mentor_view_id > .select2-choice"
  And I click on select2 result "All Mentors"
  And I should see "3" within ".cjs_mentor_view_content"
  Then I should see "Mentor" within ".cjs_mentor_view_content"
  When I click "#s2id_bulk_match_mentee_view_id > .select2-choice"
  And I click on select2 result "All Mentees"
  Then I should see "1" within ".cjs_student_view_content"
  Then I should see "Student" within ".cjs_student_view_content"
  Then I press "Next »"
  Then I should see "Bulk Actions"
  When I go to bulk match page in annauniv:ceg program
  Then I should see "Bulk Match Users"
  And I should see the radio button "orientation_type_mentor_to_mentee" selected
  And I logout

@javascript @cross_browser 
Scenario: Bulk Match should prefill admin views according to action type(recommendation or matches)
  When I go to bulk match page in primary:albers program
  And I should see "Student" within ".cjs_student_view_content"
  And I should see "Mentor" within ".cjs_mentor_view_content"
  Then I should see "21 (16 unconnected, 1 drafted and 4 connected)" within ".cjs_student_view_content"
  Then I should see "23 (19 unconnected, 0 drafted and 4 connected)" within ".cjs_mentor_view_content"

@javascript @reindex @cross_browser 
Scenario: Admin tries to select mentor respecting mentor's mentoring mode preferences
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  When I login as super user
  And I follow "Manage"
  Then I follow "Program Settings"
  Then I follow "Matching Settings"
  Then I check "program_allow_mentoring_mode_change"
  And I press "Save"
  And I follow "Manage"
  And I follow "Bulk Match Users"
  Then I should see "Bulk Match Users"
  When I click "#s2id_bulk_match_mentee_view_id > .select2-choice"

  And I click on select2 result "All Mentees"
  When I click "#s2id_bulk_match_mentor_view_id > .select2-choice"
  And I click on select2 result "All Mentors"
  And I press "Next »"
  Then I wait for ajax to complete
  And I follow "Settings"
  And I choose "bulk_match_show_drafted_true"
  And I choose "bulk_match_show_published_true"
  And I press "Apply"
  And I should see "Available slots: 5" within "#student_records_12"
  Then I should see ".mentor_available_71" hidden
  And I change mentoring mode of mentor with email "pending_user@example.com" in program "primary":"albers" to "one time"
  And I follow "Manage"
  And I follow "Bulk Match Users"
  When I click "#s2id_bulk_match_mentee_view_id > .select2-choice"

  And I click on select2 result "All Mentees"
  When I click "#s2id_bulk_match_mentor_view_id > .select2-choice"
  And I click on select2 result "All Mentors"
  And I press "Next »"
  Then I should see ".cjs_slot_71" hidden
  Then I click "#cjs_quick_search_2"
  When I scroll the div "#search_text_results_2"
  And I should see "NA" within ".mentor_available_71"
  And I click "#mentor_search_item_2_71"
  Then I should see "Mentor has preferred to participate only in One time mentoring" within ".sweet-alert.showSweetAlert.visible"

@javascript @cross_browser 
Scenario: Admin find matches for the students
  And I follow "Manage"
  And I suspend "na@chronus.com"
  And I follow "Bulk Match Users"
  Then I should see "Bulk Match Users"
  Then I should see ".cjs_bulk_match_export" hidden
  When I click "#s2id_bulk_match_mentee_view_id > .select2-choice"

  And I click on select2 result "All Mentees"
  When I click "#s2id_bulk_match_mentor_view_id > .select2-choice"
  And I click on select2 result "All Mentors"
  And I press "Next »"
  Then I wait for ajax to complete
  Then I should see "Bulk Actions"

  And I follow "Settings"
  And I fill in "bulk_match_max_pickable_slots" with "5"
  And I choose "bulk_match_show_drafted_true"
  And I choose "bulk_match_show_published_true"
  And I press "Apply"
  And I follow "Reset"

  Then I should see ".cjs_bulk_match_export" not hidden
  And I should see "Match Performance"
  And I follow "Bulk Actions"
  And I follow "Publish Drafted Mentoring Connections"
  Then I should see "Please select at least one drafted record"
  And I confirm popup
  And I should see "mentor_o chronus" within "#student_records_2 .selected_mentor_box"
  And I should see "Available slots: 5" within "#student_records_2 .selected_mentor_box"

  And I should see "Show Details" within "#student_records_2"
  And I follow "Show Details" within "#student_records_2"

  Then I should see match config details
  Then I should see "Location" within "#student_records_comparision_2"
  Then I close modal

  And I follow "Draft" within "#student_records_2"
  Then I should see "Add notes & Draft"
  And I fill in "cjs_notes_2" with "Testing Notes Feature"
  And I check "cjs_request_notes"
  And I press "Add notes & Draft"
  Then I should see "Drafted" within "#student_records_2"
  And I should see "Drafted to" within "#student_records_2"
  And I should see "mentor_o chronus" within "#student_records_2 .selected_mentor_box"
  And I should see "Available slots: 4" within "#student_records_2"
  And I should see "mentor_o chronus" within "#student_records_5 .selected_mentor_box"
  And I should not see "mentor_o chronus" within "#student_records_11 .selected_mentor_box"

  And I follow "Settings"
  And I fill in "bulk_match_max_pickable_slots" with "1"
  Then I should see match performance metrics calculated
  And I press "Apply"
  And I should not see "mentor_o chronus" within "#student_records_5 .selected_mentor_box"
  And I click "#cjs_quick_search_5"
  When I scroll the div "#search_text_results_5"
  And I click "#mentor_search_item_5_39"
  Then I should see "mentor_o chronus has already been matched with 1 student" within "#bulk_match_alter_pickable_slots"
  And I should see "To assign mentor_o chronus" within "#bulk_match_alter_pickable_slots"
  And I should see "student example" within "#bulk_match_alter_pickable_slots"
  And follow "Remove Draft Mentoring Connection"

  Then I should see "mentor_o chronus" within "#student_records_5 .selected_mentor_box"
  And I should see "#student_records_2 .selected_mentor_box" hidden

  And I follow "Settings"
  And I fill in "bulk_match_max_pickable_slots" with "0"
  And I press "Apply"
  And I wait for ajax to complete
  And I should not see "mentor_o chronus" within "#student_records_5"
  And I should see match performance metrics as NA
  And I follow "Settings"
  And I fill in "bulk_match_max_pickable_slots" with "3"
  And I press "Apply"
  And I should not see "mentor_o chronus" within "#student_records_5"

  And I follow "Reset"
  Then I should see match performance metrics calculated
  And I follow "Draft" within "#student_records_2"

  Then I should see "Drafted" within "#student_records_2"
  And I should see "Drafted to" within "#student_records_2"

  And I follow "Draft" within "#student_records_5"
  Then I should not see "Add notes & Draft"
  Then I should see "Drafted" within "#student_records_2"
  And I should see "Drafted to" within "#student_records_2"
  And I should see "Available slots: 3" within "#student_records_2"
  And I should not see "pending user" within "#student_records_7 .selected_mentor_box"

  And I check "master_checkbox"
  Then the "cjs_bulk_match_record_2" checkbox_id should be checked
  And the "cjs_bulk_match_record_5" checkbox_id should be checked
  And the "cjs_bulk_match_record_7" checkbox_id should be checked
  And I uncheck "cjs_bulk_match_record_2"
  Then I set the focus to the main window
  And I follow "Bulk Actions"
  And I follow "Publish Drafted Mentoring Connections"
  And I fill in "cjs_bulk_message" with "Test message"
  And I press "Publish"
  Then I should see "An email will be sent to the users if you complete this action."
  And I press "OK"
  Then I should see "Mentoring Connections published successfully"
  And I confirm popup
  And the "master_checkbox" checkbox_id should be checked
  Then I wait for the "Published" label display
  Then I should see "Published" within "#student_records_5"
  And I should see "Connected to" within "#student_records_5"

  And I follow "Settings"
  Then I should see the radio button "bulk_match_show_drafted_true" selected
  And I should see the radio button "bulk_match_show_published_true" selected
  And I should see the radio button "bulk_match_request_notes_false" selected

  Then I choose "bulk_match_show_drafted_false"
  And I choose "bulk_match_show_published_false"
  And I choose "bulk_match_request_notes_true"
  And I press "Apply"
  Then I should see "#student_records_2" hidden
  And I should see "#student_records_5" hidden

  And I follow "Settings"
  And I choose "bulk_match_show_drafted_true"
  And I choose "bulk_match_show_published_true"
  And I press "Apply"
  Then I should see "#student_records_2" not hidden
  And I should see "#student_records_5" not hidden

  And I follow "Settings"
  And I fill in "bulk_match_max_pickable_slots" with "1"
  And I press "Apply"
  And I should not see "Requestable mentor" within "#student_records_9 .selected_mentor_box"
  And I click "#cjs_quick_search_9"
  When I scroll the find users dropdown "#search_text_results_9" to see "#mentor_search_item_9_43"
  And I click "#mentor_search_item_9_43"
  Then I should see "Requestable mentor has already been matched with 1 student" within "#bulk_match_alter_pickable_slots"
  And I should see "To assign Requestable mentor" within "#bulk_match_alter_pickable_slots"
  And I should see "madankumarrajan" within "#bulk_match_alter_pickable_slots"
  And follow "Remove Match"
  Then I should see "Requestable mentor" within "#student_records_9 .selected_mentor_box"
  And I should see "#student_records_7 .selected_mentor_box" hidden

  And I check "master_checkbox"
  Then the "cjs_bulk_match_record_2" checkbox_id should be checked
  And the "cjs_bulk_match_record_5" checkbox_id should not be checked
  And I follow "Bulk Actions"
  And I follow "Discard Drafted Mentoring Connections"
  Then I wait for ajax to complete
  Then I should see "Connections discarded successfully"
  And I confirm popup
  And I should see "Available slots: 6" within "#student_records_2"
  And the "master_checkbox" checkbox_id should be checked

  And I follow "Draft" within "#student_records_2"
  Then I should see "Add notes & Draft"
  And I follow "Cancel"

  And I check "cjs_bulk_match_record_2"
  Then I set the focus to the main window
  And I follow "Bulk Actions"
  And I follow "Create Drafted Mentoring Connections"
  Then I wait for ajax to complete
  #Then I should see "Mentoring Connections drafted successfully"
  And I confirm popup
  Then I wait for the "Drafted" label display
  Then I should see "Drafted" within "#student_records_2"
  And I should see "Available slots: 5" within "#student_records_2"
  And the "cjs_bulk_match_record_2" checkbox_id should be checked

@javascript @cross_browser 
Scenario: Admin find matches for the mentors
  And I enable "mentor_to_mentee_matching" feature as a super user
  And I follow "Manage"
  And I follow "Bulk Match Users"
  Then I should see "Bulk Match Users"
  Then I choose "orientation_type_mentor_to_mentee"
  Then I should see the radio button "orientation_type_mentor_to_mentee" selected
  When I press "Next »"
  And I wait for ajax to complete
  Then I should see "Bulk Actions"
  When I fill in "mentor-name-search" with "Good unique"
  And I should not see "Good unique name" within "#cjs_bulk_match_result"
  And I follow "Reset"
  When I follow "Settings"
  Then I should see the radio button "bulk_match_show_drafted_false" selected
  And I should see the radio button "bulk_match_show_published_false" selected
  When I choose "bulk_match_show_drafted_true"
  And I choose "bulk_match_show_published_true"
  And I press "Apply"
  Then I should see "Kal Raman" within "#cjs_bulk_match_result"
  When I fill in "mentor-name-search" with "Good unique"
  Then I should see "Good unique name" within "#mentor_records_3"
  And I follow "Reset"
  And I should see "Connected to" within "#mentor_records_3"
  And I should see "1" within "#mentor_records_3 .available_slots"
  And I should see "student_g example" within "#mentor_records_3 .selected_student_box"
  And I click "#cjs_quick_search_3"
  When I scroll the find users dropdown "#search_text_results_3" to see "#mentee_search_item_3_9"
  And I click "#mentee_search_item_3_9"
  Then I should see "mkr_student madankumarrajan has already been matched with 2 mentors. To assign mkr_student madankumarrajan to Good unique name, please remove one of the matches below"
  And I should see "mentor_i chronus" within "#bulk_match_alter_pickable_slots"
  And I should see "mentor_j chronus" within "#bulk_match_alter_pickable_slots"
  And follow "Remove Match"
  Then I should see "mkr_student madankumarrajan" within "#mentor_records_3 .selected_student_box"
  And I should not see "student_g example" within "#mentor_records_3 .selected_student_box"
  When I fill in "mentor-name-search" with "Good unique"
  Then I should see "Good unique name" within "#cjs_bulk_match_result"
  And I should not see "Kal Raman" within "#cjs_bulk_match_result"
  When I fill in "mentor-name-search" with "Good unique"
  And I fill in "mentee-name-search" with "example"
  Then I should not see "Good unique name" within "#cjs_bulk_match_result"
  When I fill in "mentee-name-search" with "madan"
  Then I should see "Good unique name" within "#cjs_bulk_match_result"
  And I should see "mkr_student madankumarrajan" within "#mentor_records_3 .selected_student_box"
  And I should see "Match Performance"
  And I should see match performance metrics calculated
  And I should see "90 %" within "#mentor_records_3 .match_score"
  When I follow "Reset"
  And I wait for ajax to complete
  Then I should not see "mkr_student madankumarrajan" within "#mentor_records_3 .selected_student_box"
  And I should see "student_g example" within "#mentor_records_3 .selected_student_box"

@javascript 
Scenario: Admin view filters should hide based on roles
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  When I follow "Manage"
  Then I follow "User Views"
  And I click "#clicked-title-admin-view"
  And I should see "Create a new view"
  Then I follow "Create a new view"
  Then I should see "Create New View"
  Then I fill in "Title" with "Test Admin View"
  Then I follow "Next »"
  Then I click view
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Student"
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Mentor"
  And I should see "Matching & Engagement status"
  And I click on the section with header "Matching & Engagement status"
  And I should see "Students who have"
  And I should see "Mentors who have"
  And I should see "Users who are"
  And I should see "Ongoing mentoring"
  And I should see "One-time mentoring"
  And I unselect "Student" from "cjs_new_view_filter_roles_1"
  And I should not see "Students who have"
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Student"
  And I should see "Students who have"
  And I unselect "Mentor" from "cjs_new_view_filter_roles_1"
  And I should not see "Mentors who have"
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Admin"
  And I unselect "Mentor" from "cjs_new_view_filter_roles_1"
  And I unselect "Student" from "cjs_new_view_filter_roles_1"
  And I should not see "Matching & Engagement status"
  And I should not see "Students who have"
  And I should not see "Mentors who have"

@javascript @cross_browser 
Scenario: Admin should be able to select advanced options for request filters
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  When I follow "Manage"
  Then I follow "User Views"
  And I click "#clicked-title-admin-view"
  And I should see "Create a new view"
  Then I follow "Create a new view"
  Then I should see "Create New View"
  Then I fill in "Title" with "Test Admin View"
  Then I follow "Next »"
  Then I click view
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Student"
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Mentor"
  And I should see "Matching & Engagement status"
  And I click on the section with header "Matching & Engagement status"
  And I should not see "(Advanced options)"
  Then I click view
  And I select "Sent meeting requests" from "new_view_filter_mentees_meeting_requests"
  And I should see "(Advanced options)"
  And I follow "(Advanced options)"
  Then I should see "In last" within "div.modal-dialog"
  Then I should see "After" within "div.modal-dialog"
  Then I should see "Before" within "div.modal-dialog"
  Then I should see "Ever (Since the beginning of the program)" within "div.modal-dialog"
  Then I choose "In last"
  And I fill in "cjs_input_in_last_mentees_meeting_requests" with "10"
  Then I trigger change event on "cjs_input_in_last_mentees_meeting_requests"
  Then I follow "Save"
  Then I should see "In last 10 days"
  Then I should see "(Change)"
  And I should not see "(Advanced options)"
  And I select "Sent mentoring requests" from "new_view_filter_mentees_mentoring_requests"
  And I should see "(Advanced options)"
  And I follow "(Advanced options)"
  Then I choose "In last"
  And I fill in "cjs_input_in_last_mentees_mentoring_requests" with "100"
  Then I trigger change event on "cjs_input_in_last_mentees_mentoring_requests"
  Then I follow "Save"
  Then I should see "In last 100 days"
  And I should not see "(Advanced options)"
  And I follow "(Change)"
  Then I choose "Ever (Since the beginning of the program)"
  Then I follow "Save"
  Then I should not see "In last 10 days"
  Then I should see "(Advanced options)"

@javascript @cross_browser 
Scenario: Admin should be able to publish/draft connections in bulk match
  And I enable "mentor_to_mentee_matching" feature as a super user
  And I follow "Manage"
  And I follow "Bulk Match Users"
  Then I choose "orientation_type_mentor_to_mentee"
  When I press "Next »"
  And I wait for ajax to complete
  When I follow "Settings"
  When I choose "bulk_match_show_drafted_true"
  And I choose "bulk_match_show_published_true"
  And I press "Apply"
  Then I should see "Kal Raman" within "#cjs_bulk_match_result"
  Then I should see "Good unique name" within "#cjs_bulk_match_result"
  And I click "#cjs_quick_search_3"
  When I scroll the find users dropdown "#search_text_results_3" to see "#mentee_search_item_3_2"
  And I click "#mentee_search_item_3_2"
  Then I should see "student example has already been matched with 2 mentors. To assign student example to Good unique name, please remove one of the matches below"
  And follow "Remove Match"
  Then I should see "student example" within "#mentor_records_3 .selected_student_box"
  And I follow "Draft" within "#mentor_records_3"
  Then I should see "Add notes & Draft"
  And I fill in "cjs_notes_2" with "Testing Notes Feature"
  And I check "cjs_request_notes"
  And I press "Add notes & Draft"
  Then I should see "Drafted" within "#mentor_records_3"
  Then I should see "Publish" within "#mentor_records_3"
  Then I should see "Discard Draft" within "#mentor_records_3"
  Then I should see "0" within "tbody#mentor_records_3 td.available_slots"
  Then I click ".fa-file-text-o" within "#mentor_records_3"
  Then I should see "Testing Notes Feature"
  Then I close modal
  Then I follow "Discard Draft" within "#mentor_records_3"
  Then I should see "1" within "tbody#mentor_records_3 td.available_slots"
  Then I should not see "Discard Draft" within "#mentor_records_3"
  Then I should not see ".fa-file-text-o" within "#mentor_records_3"
  And I follow "Draft" within "#mentor_records_3"
  Then I follow "Publish" within "#mentor_records_3"
  Then I wait for "2" seconds
  Then I fill in "group_name" with "Good unique name group"
  Then I should see "An email will be sent to the users (mentors and students) if you complete this action."
  And I press "Publish"
  Then I should see "Published" within "#mentor_records_3"
  Then I should see "0" within "tbody#mentor_records_3 td.available_slots"
  Then I should not see "Discard Draft" within "#mentor_records_3"
  Then I click ".fa-file-text-o" within "#mentor_records_3"
  Then I should see "Testing Notes Feature"

@javascript @cross_browser 
Scenario: Admin should be able to bulk publish/draft connections
  And I enable "mentor_to_mentee_matching" feature as a super user
  And I follow "Manage"
  And I follow "Bulk Match Users"
  Then I choose "orientation_type_mentor_to_mentee"
  When I press "Next »"
  And I wait for ajax to complete
  When I follow "Settings"
  When I choose "bulk_match_show_drafted_true"
  And I choose "bulk_match_show_published_true"
  And I press "Apply"
  Then I should see "Kal Raman" within "#cjs_bulk_match_result"
  Then I should see "Good unique name" within "#cjs_bulk_match_result"
  And I check "master_checkbox"
  And I follow "Bulk Actions"
  And I follow "Create Drafted Mentoring Connections"
  Then I wait for ajax to complete
  Then I should see "Mentoring Connections drafted successfully"
  And I confirm popup
  Then I should see "Drafted" within "#mentor_records_3"
  Then I should not see "Published" within "#mentor_records_3"
  Then I should see "0" within "tbody#mentor_records_3 td.available_slots"
  Then I should see "Kal Raman" within "#cjs_bulk_match_result"
  Then I should see "Good unique name" within "#cjs_bulk_match_result"
  And I follow "Bulk Actions"
  And I follow "Discard Drafted Mentoring Connections"
  Then I wait for ajax to complete
  Then I should see "Mentoring Connections discarded successfully"
  And I confirm popup
  Then I should see "1" within "tbody#mentor_records_3 td.available_slots"
  And I follow "Bulk Actions"
  And I follow "Create Drafted Mentoring Connections"
  Then I wait for ajax to complete
  Then I should see "Mentoring Connections drafted successfully"
  And I confirm popup
  And I follow "Bulk Actions"
  And I follow "Publish Drafted Mentoring Connections"
  And I fill in "cjs_bulk_message" with "Test message"
  And I press "Publish"
  Then I should see "An email will be sent to the users if you complete this action."
  And I press "OK"
  Then I should see "Mentoring Connections published successfully"
  And I confirm popup
  Then I should not see "Drafted" within "tbody#mentor_records_3 td.cui-td-group-status"
  Then I should see "Published" within "tbody#mentor_records_3 td.cui-td-group-status"
  Then I should see "0" within "tbody#mentor_records_3 td.available_slots"
  Then I click ".fa-file-text-o" within "#mentor_records_3"
  Then I close modal
  And I should see "Show Details" within "#mentor_records_3"
  And I follow "Show Details" within "#mentor_records_3"
  Then I should see match config details
  Then I should see "Location" within ".cui_match_config_summary"
  Then I select "Skype ID" from "supplementary_matching_pair[mentor_role_question_id]"
  Then I select "Skype ID" from "supplementary_matching_pair[student_role_question_id]"
  Then I follow "Add"
  Then I should see "Skype ID" within ".cui_match_config_summary"
  Then I close modal