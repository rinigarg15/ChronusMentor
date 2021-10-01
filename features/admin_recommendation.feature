@reindex
Feature: Bulk Recommendations Page

Background: Admin logs in and enables required features
  Given the current program is "primary":""
  #Given I reindex model "user"
  And I have logged in as "ram@example.com"
  Then I have enabled "mentor_recommendation" feature
  Then I create a few default configs
  Given the current program is "primary":"albers"

@javascript
Scenario: Admin should go to bulk recommendations page from Manage
  When I follow "Manage"
  And I follow "Recommend Mentors"
  And I press "Next"
  Then I should see "Recommend Mentors"
  And I should see the tab "Manage" selected

@javascript @cross_browser 
Scenario: Admin chooses recommend mentors should have empty admin views if no bulk recommendation
  And I logout
  Given the current program is "annauniv":""
  And I have logged in as "ceg_admin@example.com"
  And I enable "mentor_recommendation" feature as a super user
  Given the current program is "annauniv":"ceg"

  When I go to bulk recommendation page in annauniv:ceg program
  Then I should see "Recommend Mentors"
  And I should see "Select View" within "#s2id_bulk_match_mentee_view_id > .select2-choice"
  And I should see "Select View" within "#s2id_bulk_match_mentor_view_id > .select2-choice"
  When I click "#s2id_bulk_match_mentee_view_id > .select2-choice"
  And I click on select2 result "All Mentees"

  And I should not see "Select View" within "#s2id_bulk_match_mentee_view_id > .select2-choice"
  And I should see "Select View" within "#s2id_bulk_match_mentor_view_id > .select2-choice"
  And I should see "1" within ".cjs_student_view_content"
  And I should see "Student" within ".cjs_student_view_content"

@javascript @cross_browser 
Scenario: Bulk Match should prefill admin views for bulk recommendation page
  When I go to bulk recommendation page in primary:albers program
  And I should see "Student" within ".cjs_student_view_content"
  And I should see "Mentor" within ".cjs_mentor_view_content"
  Then I should see "16 (15 unconnected, 1 drafted and 0 connected)" within ".cjs_student_view_content"
  Then I should see "23 (19 unconnected, 0 drafted and 4 connected)" within ".cjs_mentor_view_content"

@javascript @cross_browser
Scenario: Admin sends recommendations to mentees
  When I go to bulk recommendation page in primary:albers program
  And I press "Next »"
  And I wait for ajax to complete
  When I follow "Settings"
  And I choose "bulk_recommendation_show_published_true" within "#bulk_match_settings_content"
  And I choose "bulk_recommendation_show_drafted_true" within "#bulk_match_settings_content"
  And I press "Apply" within "#bulk_match_settings_content"

  # Should see more users on scrolling down
  Then I should see "#student_records_40" hidden
  And I scroll to bottom of page
  Then I should see "#student_records_40" not hidden

  # Algorithm for recommending should work correctly
  Then I should see "Not Accepted" within "#student_records_2"
  And I should see "mentor_o chronus" within "#student_records_2"
  And I should see "Good unique name" 0 times
  And I should see "Recommendations Sent" within "#student_records_7 .cui-td-group-status"

  And I should see 2 "mentors" in "#student_records_2"
  And I should see 2 "trash_icons" in "#student_records_2"
  And I should see 2 "mentors" in "#student_records_7"
  But I should see 0 "trash_icons" in "#student_records_7"

  # Remove recommended mentors and check recommended count
  And I should see recommended count 2 in the row 2 of record "#student_records_16"
  And I should see "mentor_f chronus"
  And I should see recommended count 2 in the row 1 of record "#student_records_40"
  And I should see recommended count 2 in the row 2 of record "#student_records_40"
  When I remove mentor 1 in "#student_records_24"
  Then I should see 1 "mentors" in "#student_records_24"
  And I should see 1 "trash_icons" in "#student_records_24"
  And I should see recommended count 1 in the row 1 of record "#student_records_40"
  And I should see recommended count 2 in the row 2 of record "#student_records_40"

  # Update recommended mentors
  When I click "#cjs_quick_search_24"
  Then I should see "#mentor_search_item_24_3" hidden
  When I scroll the find users dropdown "#search_text_results_24" to see "#mentor_search_item_24_3"
  And I click "#mentor_search_item_24_3"
  Then I should see recommended count 1 in the row 2 of record "#student_records_24"
  And I should see "Good unique name" within "#student_records_24"

  When I click "#cjs_quick_search_24"
  And I click "#mentor_search_item_24_25"
  Then I should see "Student has maximum recommendations. Please change the settings or remove a recommended mentor"
  And I press "OK"
  When I remove mentor 2 in "#student_records_24"
  And I click "#cjs_quick_search_24"
  And I click "#mentor_search_item_24_25"
  Then should see "mentor_a chronus" within "#student_records_24"
  And I should see recommended count 2 in the row 2 of record "#student_records_16"

@javascript @cross_browser
Scenario: Alter pickable slots
  When I go to bulk recommendation page in primary:albers program
  And I press "Next »"
  And I wait for ajax to complete
  When I follow "Settings"
  And I choose "bulk_recommendation_show_published_true" within "#bulk_match_settings_content"
  And I choose "bulk_recommendation_show_drafted_true" within "#bulk_match_settings_content"
  And I press "Apply" within "#bulk_match_settings_content"
  And I scroll to bottom of page
  Then I should see "mentor_e chronus" within "#student_records_22"
  And I should see "mentor_e chronus" within "#student_records_23"
  And I follow "Send Recommendations" within "#student_records_23"
  And I press "OK"
  And I remove mentor 2 in "#student_records_2"
  And I click "#cjs_quick_search_2"
  When I scroll the find users dropdown "#search_text_results_2" to see "#mentor_search_item_2_29"
  And I click "#mentor_search_item_2_29"
  Then I should see "mentor_e chronus has already been recommended to 2 students" within "#bulk_match_alter_pickable_slots"
  And I should see "student_n example" within "#bulk_match_alter_pickable_slots"
  And I should see "student_m example" within "#bulk_match_alter_pickable_slots"
  When I follow "Remove recommendation"
  And I should see "mentor_e chronus" within "#student_records_2"

  When I follow "Draft" within "#student_records_19"
  Then I should see "Drafted" within "#student_records_19"
  When I remove mentor 2 in "#student_records_2"
  And I click "#cjs_quick_search_2"

  And I click "#mentor_search_item_2_37"
  Then I should see "mentor_m chronus has already been recommended to 2 students" within "#bulk_match_alter_pickable_slots"
  When I follow "Remove recommendation"
  When I follow "Discard Draft"
  When I remove mentor 2 in "#student_records_2"
  And I click "#cjs_quick_search_2"
  When I scroll the div "#search_text_results_2"
  And I click "#mentor_search_item_2_38"
  Then I should see "mentor_n chronus has already been recommended to 2 students" within "#bulk_match_alter_pickable_slots"

@javascript @cross_browser
Scenario: Admin changes settings
  # Decrease max_suggestion_count
  When I go to bulk recommendation page in primary:albers program
  And I press "Next »"
  And I wait for ajax to complete
  And I follow "Settings"
  Then I should see "Limit number of times a mentor can be recommended to"
  Then I should not see "Ask for notes while creating Mentoring Connections?"
  When I fill in "bulk_recommendation_max_suggestion_count" with "1" within "#bulk_match_settings_content"
  And I choose "bulk_recommendation_show_published_true" within "#bulk_match_settings_content"
  And I choose "bulk_recommendation_show_drafted_true" within "#bulk_match_settings_content"
  And I press "Apply" within "#bulk_match_settings_content"
  Then I should see "Not Accepted" within "#student_records_2"
  And I should not see "mentor_g chronus" within "#student_records_2"
  And I should see 1 "mentors" in "#student_records_2"
  And I should see 1 "trash_icons" in "#student_records_2"
  But I should see 2 "mentors" in "#student_records_7"
  And I should see 0 "trash_icons" in "#student_records_7"

  # Increase max_suggestion_count
  When I follow "Settings"
  Then I should see "Limit number of times a mentor can be recommended to"
  And I fill in "bulk_recommendation_max_suggestion_count" with "3" within "#bulk_match_settings_content"
  And I press "Apply" within "#bulk_match_settings_content"
  Then I should see "mentor_n chronus" within "#student_records_2"
  And I should see 3 "mentors" in "#student_records_2"
  But I should see 2 "mentors" in "#student_records_7"

  # Increase max_pickable_slots
  When I follow "Settings"
  Then I should see "Limit number of times a mentor can be recommended to"
  And I fill in "bulk_recommendation_max_suggestion_count" with "2" within "#bulk_match_settings_content"
  And I fill in "bulk_recommendation_max_pickable_slots" with "5" within "#bulk_match_settings_content"
  And I press "Apply" within "#bulk_match_settings_content"
  Then I should see "Not Accepted" within "#student_records_2"
  And I should see "mentor_g chronus" 0 times

  # Decrease max_pickable_slots
  When I follow "Settings"
  Then I should see "Limit number of times a mentor can be recommended to"
  And I fill in "bulk_recommendation_max_pickable_slots" with "0" within "#bulk_match_settings_content"
  And I press "Apply" within "#bulk_match_settings_content"
  Then I should see 2 "mentors" in "#cjs_bulk_match_result"
  And I should see 2 "mentors" in "#student_records_7"
  And I should see 0 "trash_icons" in "#cjs_bulk_match_result"
  Then I reload the page
  And I press "Next »"
  And I wait for ajax to complete

  # Change show drafted/published setting
  When I follow "Settings"
  Then I should see "Limit number of times a mentor can be recommended to"
  And I fill in "bulk_recommendation_max_pickable_slots" with "2" within "#bulk_match_settings_content"
  And I press "Apply" within "#bulk_match_settings_content"
  And I follow "Reset"
  Then I should see 1 recommendations in "Recommendations Sent" state
  When I follow "Settings"
  Then I should see "Limit number of times a mentor can be recommended to"
  And I choose "bulk_recommendation_show_drafted_false" within "#bulk_match_settings_content"
  And I press "Apply" within "#bulk_match_settings_content"
  And I follow "Draft" within "#student_records_2"
  Then I should see "Mentor recommendations drafted successfully. Please change settings to view drafted mentor recommendations"
  And I press "OK"
  Then I should see 0 recommendations in "Drafted" state
  When I follow "Settings"
  Then I should see "Limit number of times a mentor can be recommended to"
  And I choose "bulk_recommendation_show_published_false" within "#bulk_match_settings_content"
  And I choose "bulk_recommendation_show_drafted_true" within "#bulk_match_settings_content"
  And I press "Apply" within "#bulk_match_settings_content"
  Then I should see 0 recommendations in "Recommendations Sent" state
  And I should see 1 recommendations in "Drafted" state

  When I follow "Send Recommendations" within "#student_records_2"
  Then I should see "An email will be sent to the users if you complete this action."
  And I press "OK"
  Then I should see "Mentor recommendations published successfully. Please change settings to view published mentor recommendations"
  And I press "OK"
  And I should see 0 recommendations in "Recommendations Sent" state

  When I follow "Settings"
  Then I should see "Limit number of times a mentor can be recommended to"
  And I choose "bulk_recommendation_show_published_true" within "#bulk_match_settings_content"
  And I press "Apply" within "#bulk_match_settings_content"
  Then I should see 2 recommendations in "Recommendations Sent" state

@javascript @cross_browser
Scenario: Perform actions on recommendation
  # Draft recommendation
  When I go to bulk recommendation page in primary:albers program
  And I press "Next »"
  And I wait for ajax to complete
  And I follow "Settings"
  And I choose "bulk_recommendation_show_drafted_true"
  And I choose "bulk_recommendation_show_published_true"
  And I press "Apply"
  And I scroll to bottom of page
  Then I should see 0 recommendations in "Drafted" state
  And I should see 1 recommendations in "Recommendations Sent" state
  And I should see 15 recommendations in "Selected" state

  And I should see "Draft" within "#student_records_2"
  And I should see ".cjs_quick_search_2" not hidden
  Then I should see "Send Recommendations" within "#student_records_2"

  When I follow "Draft" within "#student_records_2"
  Then I should see "Drafted" within "#student_records_2"
  And I should see "Send Recommendations" within "#student_records_2"
  And I should see 14 recommendations in "Selected" state
  And I should see 1 recommendations in "Drafted" state
  And I confirm 1 recommendations in "Drafted" state
  And I should see ".cjs_quick_search_2" hidden
  But I should see "checkbox" for "#student_records_2"
  And I should see 2 "mentors" in "#student_records_2"
  But I should see 0 "trash_icons" in "#student_records_2"
  And I should see "Send Recommendations" within "#student_records_2"
  Then I should see "Discard" within "#student_records_2"

  # Publish recommendation
  When I follow "Send Recommendations" within "#student_records_2"
  Then I should see "An email will be sent to the users if you complete this action."
  And I press "OK"
  Then I should see "Recommendations Sent" within "#student_records_2"
  And I should see "Discard" within "#student_records_2"
  And I should see 2 recommendations in "Recommendations Sent" state
  And I confirm 2 recommendations in "Recommendations Sent" state
  And I should see ".cjs_quick_search_2" hidden
  And I should not see "checkbox" for "#student_records_2"
  And I should see 2 "mentors" in "#student_records_2"
  But I should see 0 "trash_icons" in "#student_records_2"

  # Discard recommendation
  When I follow "Reset"
  And I follow "Discard" within "#student_records_2"
  And I should see "Draft" within "#student_records_2"
  And I should see ".cjs_quick_search_2" not hidden
  And I should see "checkbox" for "#student_records_2"
  And I should see 2 "mentors" in "#student_records_2"
  And I should see 2 "trash_icons" in "#student_records_2"

  And I follow "Send Recommendations" within "#student_records_2"
  Then I should see "An email will be sent to the users if you complete this action."
  And I press "OK"
  Then I should see "Recommendations Sent" within "#student_records_2"
  And I should see "Discard" within "#student_records_2"

  # Draft multiple recommendations
  When I check "master_checkbox"
  Then the "cjs_bulk_match_record_5" checkbox_id should be checked
  And the "cjs_bulk_match_record_10" checkbox_id should be checked
  When I follow "Bulk Actions"
  And I follow "Publish Drafted Recommendations" within ".cjs_bulk_actions .dropdown-menu"
  Then I should see "Please select at least one drafted record"
  And I press "OK"
  Then I set the focus to the main window
  When I follow "Bulk Actions"
  And I follow "Draft Recommendations" within ".cjs_bulk_actions .dropdown-menu"
  Then I wait for ajax to complete
  #Then I should see "Mentor recommendations drafted successfully"
  And I press "OK"
  When I scroll to bottom of page
  And I should see 14 recommendations in "Drafted" state
  And I confirm 14 recommendations in "Drafted" state
  And I should see 2 recommendations in "Recommendations Sent" state
  And I confirm 2 recommendations in "Recommendations Sent" state
  And I should see ".cjs_quick_search_5" hidden
  And I should see ".cjs_quick_search_10" hidden

  # Discard multiple recommendations
  When I uncheck "master_checkbox"
  And I follow "Bulk Actions"
  And I follow "Discard Drafted Recommendations" within ".cjs_bulk_actions .dropdown-menu"
  Then I should see "Please select at least one drafted record"
  And I press "OK"

  When I check "master_checkbox"
  And I follow "Bulk Actions"
  And I follow "Discard Drafted Recommendations" within ".cjs_bulk_actions .dropdown-menu"
 # Then I should see "Mentor recommendations discarded successfully"
  And I press "OK"
  Then I should see 0 recommendations in "Drafted" state
  And I confirm 0 recommendations in "Drafted" state

  # Publish multiple recommendations
  When I follow "Bulk Actions"
  And I follow "Draft Recommendations" within ".cjs_bulk_actions .dropdown-menu"
  #Then I should see "Mentor recommendations drafted successfully"
  And I press "OK"
  When I follow "Bulk Actions"
  And I follow "Publish Drafted Recommendations" within ".cjs_bulk_actions .dropdown-menu"
  Then I should see "An email will be sent to the users if you complete this action."
  And I press "OK"
  #Then I should see "Mentor recommendations published successfully"
  And I press "OK"
  Then I should see 0 recommendations in "Drafted" state
  And I confirm 0 recommendations in "Drafted" state
  And I should see 16 recommendations in "Recommendations Sent" state
  And I confirm 16 recommendations in "Recommendations Sent" state
  And I should not see "checkbox" for "#cjs_bulk_match_result .tbody"