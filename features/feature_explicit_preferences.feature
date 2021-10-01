Feature: Mentee can set explicit user preferences and should see recommended mentors based on preferences set.
  In order to perform the above steps
  As an admin
  I want to login and enter the appropriate as required

Background: The current program is albers
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I enable "explicit_user_preferences" feature as a super user
  Then I enable "popular_categories" feature as a super user
  And I log out

@javascript @cross_browser
Scenario: Mentee should be able to create and update explicit preferences
  When I have logged in as "rahim@example.com"
  Then I follow "Mentors"
  Then I follow "Personalize Recommendations"
  Then I should not see "Important"
  Then I should see "Select Profile Field"
  Then I should not see "Select Preferences"
  Then I click on select2 with selector ".cjs_explicit_preference_question_selector" inside ".cjs-explicit-preference-rows-creation-container"
  Then I should see "Industry"
  And I click on select2 result "Gender"
  And I press "Add"
  Then I should not see "Select Profile Field"
  Then I click on select2 with selector ".cjs_explicit_preference_option_selector" inside ".cjs-explicit-preference-rows-creation-container"
  Then I should see "Female"
  And I click on select2 result "Male"
  And I press "Add"
  Then I should see "Gender"
  Then I should see "Male"
  Then I should see "Important"
  Then I should see "Start Over"
  Then I should see "Show Recommendations"
  Then I should see "Select Profile Field"
  Then I should not see "Select Preferences"
  Then I change weight slider inside ".cjs_explicit_preference_weight_container" to "1"
  Then I should see "Nice to have"
  Then I change weight slider inside ".cjs_explicit_preference_weight_container" to "5"
  Then I should see "Very Important"
  Then I click on select2 with selector ".cjs_explicit_preference_question_selector" inside ".cjs-explicit-preference-rows-creation-container"
  And I click on select2 result "Language"
  Then I click on select2 with selector ".cjs_explicit_preference_option_selector" inside ".cjs-explicit-preference-rows-creation-container"
  Then I should see "English"
  And I click on select2 result "Hindi"
  And I press "Add"
  Then I should see "Select Profile Field"
  Then I click ".cjs_open_update_explicit_preference" of last preference
  Then I should not see "Select Profile Field"
  Then I should see "Language" inside last preference edit container
  Then I should see "Hindi" inside last preference edit container
  Then I should see "Cancel" inside last preference edit container
  Then I click ".cjs_close_update_explicit_preference" of last preference
  Then I should see "Select Profile Field"
  Then I click ".cjs_open_update_explicit_preference" of last preference
  Then I unselect all options of last preference
  And I press "Save"
  Then I should see "Language"
  Then I should see "Cancel" inside last preference edit container
  Then I click on option selector of last preference
  Then I should see "English"
  Then I change weight of last preference to "2"
  And I click on select2 result "English"
  And I press "Save"
  Then I should see "English"
  Then I should see "Slightly Important"
  Then I should see "Select Profile Field"
  Then I click ".fa-trash" of last preference
  Then I should see "Are you sure you want to delete this preference?"
  And I press "Cancel"
  Then I should see "Language"
  Then I click ".fa-trash" of last preference
  Then I should see "Are you sure you want to delete this preference?"
  And I press "OK"
  Then I should not see "Language"
  Then I click ".cjs_close_preference_popup"
  And I visit home page with popular categories experiment enabled
  Then I should see "Popular Categories"
  And I should not see "Male" within ".cjs_preference_based_mentor_lists_container"
  And I should not see "Gender" within ".cjs_preference_based_mentor_lists_container"
  When I stub to get valid mentor lists
  And I visit home page with popular categories experiment enabled
  Then I should see "Popular Categories"
  And I should see "Male" within ".cjs_preference_based_mentor_lists_container"
  And I should see "Gender" within ".cjs_preference_based_mentor_lists_container"
  Then I follow "VIEW ALL MENTORS"
  Then I follow "Personalize Recommendations"
  Then I should see "Select Profile Field"
  Then I should see "Gender"
  Then I should see "Male"
  Then I follow "Start Over"
  Then I should see "This will remove all the existing preferences and begin with an empty template. This cannot be rolled back. Continue?"
  And I press "OK"
  Then I click ".cjs_close_preference_popup"
  And I visit home page with popular categories experiment enabled
  Then I should not see "Gender" within ".cjs_preference_based_mentor_lists_container"
  Then I should not see "Male" within ".cjs_preference_based_mentor_lists_container"