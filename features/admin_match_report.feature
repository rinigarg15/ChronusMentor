
Feature: Match Report Landing Page

Background: Admin logs in and enabled required features
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  Then I create a few default configs
  Given the current program is "primary":"albers"
  And I enable "match_report" feature as a super user
  And I follow "Health Reports"
  And I follow "Match Report"

@javascript @cross_browser 
Scenario: Admin selects Admin Views for Mentor Distribution section
  And I click ".cjs_mentor_distribution_tile_setting" within "#match_report"
  Then I should see "Select two user segments to compare"
  Then I should see "Mentor user set" within "div.cjs_mentor_distribution_popup"
  Then I should see "Student user set" within "div.cjs_mentor_distribution_popup"
  Then I should see "Available Mentors" within "div.cjs_mentor_distribution_popup"
  Then I should see "Currently Unconnected Mentees" within "div.cjs_mentor_distribution_popup"
  Then I should see "User Count: 21 (18 unconnected, 0 drafted and 3 connected)" within "div.cjs_mentor_view_content"
  Then I should see "Filters Applied" within "div.cjs_mentor_view_content"
  Then I should see "Roles Mentor" within "div.cjs_mentor_view_content"
  Then I should see "User Count: 17 (16 unconnected, 1 drafted and 0 connected) " within "div.cjs_student_view_content"
  Then I should see "Filters Applied" within "div.cjs_student_view_content"
  Then I should see "Roles Student" within "div.cjs_student_view_content"
  Then I should see "User Status Active" within "div.cjs_student_view_content"
  Then I should not see "Edit View" within "div.cjs_student_view_content"
  Then I should not see "Edit View" within "div.cjs_mentor_view_content"
  Then I should see "View Users" within "div.cjs_student_view_content"
  Then I should see "View Users" within "div.cjs_mentor_view_content"
  When I click "#s2id_mentor_distribution_mentor_view_id > .select2-choice"
  And I click on select2 result "Never Connected Mentors"
  Then I should see "Roles Mentor" within "div.cjs_mentor_view_content"
  Then I should see "User Status Active" within "div.cjs_mentor_view_content"
  Then I should see "User's mentoring connection status Never connected" within "div.cjs_mentor_view_content"
  And I press "Save"
  Then I should not see "How are the mentors and students distributed?"
  And I click ".cjs_mentor_distribution_tile_setting" within "#match_report"
  Then I should see "Select two user segments to compare"
  Then I should see "Never Connected Mentors" within "div.cjs_mentor_distribution_popup"
   When I click "#s2id_mentor_distribution_mentor_view_id > .select2-choice"
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
  Then I should see "How are the students and mentors distributed?"
  Then I should not see "Never Connected Mentors" within "div.cjs_mentor_distribution_popup"
  Then I should see "Bulk Match Mentor View" within "div.cjs_mentor_distribution_popup"
  And I follow "Edit View" within "div.cjs_mentor_view_content"
  Then I should not see "Delete View"
  And I should see ".cjs_admin_view_step" hidden
  Then I should see "href" attribute for link "Back" matches with "/p/albers/match_reports/edit_section_settings?section=20"
  And I press "Update View"
  Then I should see "The View - Bulk Match Mentor View has been updated successfully"
  And I follow "View Users" within "div.cjs_mentor_view_content"
  Then I should see "href" attribute for link "Back" matches with "/p/albers/match_reports/edit_section_settings?section=20"
  And I follow the back link
  Then I should see "Select two user segments to compare"

  #mentee view
  When I click "#s2id_mentor_distribution_mentee_view_id > .select2-choice"
  And I click on select2 result "All Mentees"
  Then I should see "Roles Student" within "div.cjs_student_view_content"
  Then I should not see "User Status Active" within "div.cjs_student_view_content"
  Then I should not see "User's mentoring connection status Never connected" within "div.cjs_student_view_content"
  And I press "Save"
  Then I should not see "How are the mentors and students distributed?"
  And I click ".cjs_mentor_distribution_tile_setting" within "#match_report"
  Then I should see "Select two user segments to compare"
  Then I should see "All Mentees" within "div.cjs_mentor_distribution_popup"
  When I click "#s2id_mentor_distribution_mentor_view_id > .select2-choice"
  And I click ".cjs_create_admin_view_link"

  Then I should see "Create New View"
  And I fill in "admin_view_title" with "Bulk Match Mentee View"
  Then I follow "Next »"
  Then I click view
  Then I should not see "Draft" within ".well.white-bg"
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Student"
  And I check "admin_view_roles_and_status_state_pending"
  And I select "Currently connected" from "cjs-connection-status-filter-category-1"
  And I press "Create View"

  Then I should see "The View - Bulk Match Mentee View has been created successfully"
  Then I should see "Select two user segments to compare"
  Then I should not see "All Mentees" within "div.cjs_mentor_distribution_popup"
  Then I should see "Bulk Match Mentee View" within "div.cjs_mentor_distribution_popup"
  And I follow "Edit View" within "div.cjs_student_view_content"
  Then I should not see "Delete View"
  And I should see ".cjs_admin_view_step" hidden
  Then I should see "href" attribute for link "Back" matches with "/p/albers/match_reports/edit_section_settings?section=20"
  And I press "Update View"
  Then I should see "The View - Bulk Match Mentee View has been updated successfully"
  And I follow "View Users" within "div.cjs_student_view_content"
  Then I should see "href" attribute for link "Back" matches with "/p/albers/match_reports/edit_section_settings?section=20"
  And I follow the back link
  Then I should see "Select two user segments to compare"

@javascript @cross_browser 
Scenario: Admin should see mentee to mentor ratio
  Then I should see "How are the students and mentors distributed?" within "div#mentor_distribution_container"
  Then I should see "Student to Mentor ratio" within "div#mentor_distribution_info"
  Then I should see "21 Available Mentors" within "div#mentor_distribution_info"
  Then I should see "17 Currently Unconnected Mentees" within "div#mentor_distribution_info"
  And I click ".cjs_mentor_distribution_tile_setting" within "div#mentor_distribution_container"
  When I click "#s2id_mentor_distribution_mentor_view_id > .select2-choice"
  And I click on select2 result "Never Connected Mentors"
  And I press "Save"
  Then I should see "How are the students and mentors distributed?" within "div#mentor_distribution_container"
  Then I should see "Student to Mentor ratio" within "div#mentor_distribution_info"
  Then I should see "17 Never Connected Mentors" within "div#mentor_distribution_info"
  Then I should see "17 Currently Unconnected Mentees" within "div#mentor_distribution_info"

@javascript @cross_browser 
Scenario: Admin should see Mentor Offers vs Mentee Needs
  And I login as super user
  Then I navigate to match_configs_path page
  Then I follow "New Config"
  Then I select "About Me" from "match_config_mentor_question_id" within "#edit_match_config"
  Then I select "About Me" from "match_config_student_question_id" within "#edit_match_config"
  And I press "Set Configuration"
  Then I follow "Recompute Match Scores"
  Then I navigate to match_configs_path page
  Then I follow "New Config"
  Then I select "Gender" from "match_config_mentor_question_id" within "#edit_match_config"
  Then I select "Gender" from "match_config_student_question_id" within "#edit_match_config"
  Then I choose "match_config_show_match_label_false" within "#edit_match_config"
  Then I choose "Set Matching"
  Then I follow "Add new set"
  And I enter "Male" in "mentor_choice_box_0_0" autocomplete it with "Male"
  And I enter "Female" in "mentor_choice_box_1_0" autocomplete it with "Female"
  And I fill in "match_config_threshold" with "1"
  And I press "Set Configuration"
  Then I should see "Gender" within "#match_configs"
  Then I follow "Recompute Match Scores"
  And I follow "Health Reports"
  And I follow "Match Report"
  Then I should see "Student Needs vs Mentor Offers" within "div.cjs_mentor_offers_mentee_needs"
  Then I should not see "Location »" within "div.cjs_mentor_offers_mentee_needs"
  Then I should not see "About Me »" within "div.cjs_mentor_offers_mentee_needs"
  Then I should see "Gender »" within "div.cjs_mentor_offers_mentee_needs"

@javascript
Scenario: Admin should be able to change admin view for Mentee Actions Section
  Then I should see "What are the student actions when trying to connect with mentor?"
  And I click ".cjs_mentee_actions_tile_setting" within "#match_report"
  Then I should see "Select the student segment to check what they are looking for"
  Then I should see "Student user set" within "div.cjs_mentee_actions_popup"
  Then I should see "All Mentees" within "div.cjs_mentee_actions_popup"
  Then I should see "User Count: 21 (16 unconnected, 1 drafted and 4 connected)" within "div.cjs_student_view_content"
  Then I should see "Filters Applied" within "div.cjs_student_view_content"
  Then I should see "Roles Student" within "div.cjs_student_view_content"
  Then I should not see "Edit View" within "div.cjs_student_view_content"
  Then I should see "View Users" within "div.cjs_student_view_content"
  When I click "#s2id_mentee_action_mentee_view_id > .select2-choice"
  And I click on select2 result "Never Connected Mentees"
  Then I should see "Never Connected Mentees" within "div.cjs_mentee_actions_popup"
  Then I should see "User Count: 16 (15 unconnected, 1 drafted and 0 connected)" within "div.cjs_student_view_content"
  And I press "Save"

@javascript
Scenario: Admin should see top applied filters in Mentee Actions Section
  And I logout
  Then I wait for "User" Elastic Search Reindex
  Then I perform missed migrations
  And there are some available for advance search configuration and ordered option question for "mentor" in "primary":"albers"
  And I have logged in as "mkr@example.com"
  When I follow "Mentors" tab
  Then I follow "More filters"
  Then I apply text based filters
  And I apply ordered option filter in combination with text based filter
  And I follow "Reset all"
  Then I wait for ajax to complete
  Then I apply location filter
  And I apply choice based filter in combination with location filter
  And I logout
  And I have logged in as "mkr@example.com"
  When I follow "Mentors" tab
  Then I follow "More filters"
  Then I apply text based filters
  And I apply ordered option filter in combination with text based filter
  And I follow "Reset all"
  Then I wait for ajax to complete
  Then I apply location filter
  And I apply choice based filter in combination with location filter
  And I logout
  When I have logged in as "ram@example.com"
  And I follow "Health Reports"
  And I follow "Match Report"
  Then I should see "What are the student actions when trying to connect with mentor?"
  And I should see "Top applied filters by student" within "#applied_filters_data"
  And I should see "Location" within "#applied_filters_data"
  And I should see "Current Education" within "#applied_filters_data"
  And I should see "Entire Education" within "#applied_filters_data"
  And I should see "Automation Preference" within "#applied_filters_data"
  And I should see "What is your name" within "#applied_filters_data"
  And I should see a count of "2" for profile question with text "Location" in filter section in the program "Albers Mentor Program"
  And I should see a count of "2" for profile question with text "Current Education" in filter section in the program "Albers Mentor Program"
  And I should see a count of "2" for profile question with text "Entire Education" in filter section in the program "Albers Mentor Program"
  And I should see a count of "2" for profile question with text "Automation Preference" in filter section in the program "Albers Mentor Program"
  And I should not see "+ 2 more" within "#applied_filters_data"
  Then I change the top filters limit to "5"
  And I follow "Home"
  And I follow "Health Reports"
  And I follow "Match Report"
  Then I should see "What are the student actions when trying to connect with mentor?"
  And I should see "Top applied filters by student" within "#applied_filters_data"
  And I should see "Location" within "#applied_filters_data"
  And I should see "Current Education" within "#applied_filters_data"
  And I should see "Entire Education" within "#applied_filters_data"
  And I should see "Automation Preference" within "#applied_filters_data"
  And I should see "What is your name" within "#applied_filters_data"
  And I should see a count of "2" for profile question with text "Location" in filter section in the program "Albers Mentor Program"
  And I should see a count of "2" for profile question with text "Current Education" in filter section in the program "Albers Mentor Program"
  And I should see a count of "2" for profile question with text "Entire Education" in filter section in the program "Albers Mentor Program"
  And I should see a count of "2" for profile question with text "Automation Preference" in filter section in the program "Albers Mentor Program"
  And I should see "+ 2 more"
  When I follow "+ 2 more"
  Then I should see "Applied Filters" within "#cjs_applied_filters_modal"
  And I should see "Count" within "#cjs_applied_filters_modal"
  And I should see "What is your name" within "#cjs_applied_filters_modal"
  And I should see "What is your hobby" within "#cjs_applied_filters_modal"
  And I should see "1" within "#cjs_applied_filters_modal"
  And I logout

@javascript
Scenario: Admin should see top search keywords in Mentee Actions Section
  Then I should see "What are the student actions when trying to connect with mentor?"
  And I should see "Top search keywords" within "#search_keywords_data"
  And I should see "sample answer text" within "#search_keywords_chart svg"
  And I should see "sample search text" within "#search_keywords_chart svg"
  And I should see "sample choice text" within "#search_keywords_chart svg"
  When I hover over the bubble with the text "sample answer text"
  Then I should see "sample answer text: 1"