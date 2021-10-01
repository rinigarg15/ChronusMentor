Feature: Preference based mentor lists for a mentee

Background: The current program is albers
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I enable "popular_categories" feature as a super user
  And I log out

@javascript @cross_browser
Scenario: Mentee should see popular categories
When I have logged in as "rahim@example.com"
Then I should not see "Popular Categories"
And I visit home page with popular categories experiment enabled
Then I should see "Popular Categories"
And I should see "Looks like there are no profile categories available." within ".cjs_preference_based_mentor_lists_container"
Then I stub to get some mentor lists
And I visit home page with popular categories experiment enabled
Then I should see "Popular Categories"
Then I should see "Chennai" within ".cjs_preference_based_mentor_lists_container"
And I should see "Location" within ".cjs_preference_based_mentor_lists_container"
Then I should see "Male" within ".cjs_preference_based_mentor_lists_container"
And I should see "Gender" within ".cjs_preference_based_mentor_lists_container"
Then I follow "VIEW ALL MENTORS" within ".cui-preference-based-mentor-list-item:first-child"
Then I should see "Location" within "#your_filters"
And I should see "Chennai,Tamil Nadu,India" in Location filter
And I visit home page with popular categories experiment enabled
And I follow "VIEW ALL MENTORS" within ".cui-preference-based-mentor-list-item:last-child"
Then I should see "Gender" within "#your_filters"
And I verify gender filter
And I visit home page with popular categories experiment enabled
Then I click ".cui-preference-based-mentor-list-item:first-child .cui_quick_connect_no_border_link"
Then I follow "Don't show this category again"
Then I should see "Male" within ".cjs_preference_based_mentor_lists_container"
And I should see "Gender" within ".cjs_preference_based_mentor_lists_container"
And I should not see "Location" within ".cjs_preference_based_mentor_lists_container"
Then I should not see "Chennai" within ".cjs_preference_based_mentor_lists_container"
Then I click ".cui-preference-based-mentor-list-item:first-child .cui_quick_connect_no_border_link"
Then I follow "Don't show this category again"
Then I should not see "Male"
And I should not see "Gender"
And I should not see "Popular Categories"
