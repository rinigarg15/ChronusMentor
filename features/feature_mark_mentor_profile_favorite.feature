@javascript
Feature: Skip and Bookmark mentor profiles

Background:
  Given the current program is "primary":"albers"

Scenario: Check if Skip and Bookmark mentor profiles enabled for mentee to mentor style
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Features"
  Then I should see "Skip and Favorite profiles"
  And I logout

  Given the current program is "primary":""
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Features"
  Then I should see "Skip and Favorite profiles"

Scenario: Skip and Bookmark mentor profiles disabled for mentee to admin style
  Given the current program is "annauniv":"psg"
  And I have logged in as "psg@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Features"
  Then I should see "Skip and Favorite profiles"
  And I should see "Ability for the students to favorite and skip mentor profiles from recommendations"

Scenario: Mentee marks a mentor profile favorite
  When I have logged in as "ram@example.com"
  And I enable "skip_and_favorite_profiles" feature as a super user
  And I logout
  When I have logged in as "rahim@example.com"
  Then I follow "Mentors"
  Then I should see the image with src "/assets/star-off.png"
  Then I filter a mentor with name "mentor_j chronus" using quick find
  Then I follow "mentor_j chronus"
  Then I click on the image with src "/assets/star-off.png"
  Then I should see the image with src "/assets/star.png"

Scenario: Mentee marks a mentor profile favorite from recommendations
  When I have logged in as "ram@example.com"
  And I enable "skip_and_favorite_profiles" feature as a super user
  And I logout
  Given "userrahim@example.com" user have no pending mentor requests in program "primary":"albers"
  Given "userrahim@example.com" user is not part of any active connection in program "primary":"albers"
  When I have logged in as "userrahim@example.com"
  And I follow "Home"
  Then I should see "Featured Mentor Recommendations" within ".cjs_quick_connect_items"
  Then I should see the image with src "/assets/star-off.png"
  Then I click on the image with src "/assets/star-off.png"
  Then I should see the image with src "/assets/star.png"

Scenario: Mentee marks a mentor profile favorite from recommendations when match score is disabled
  When I have logged in as "ram@example.com"
  And I enable "skip_and_favorite_profiles" feature as a super user
  When I login as super user
  And I follow "Manage"
  Then I follow "Program Settings"
  Then I follow "Matching Settings"
  Then I uncheck "program_allow_end_users_to_see_match_scores"
  And I press "Save"
  And I logout
  Given "userrahim@example.com" user have no pending mentor requests in program "primary":"albers"
  Given "userrahim@example.com" user is not part of any active connection in program "primary":"albers"
  When I have logged in as "userrahim@example.com"
  And I follow "Home"
  Then I should see "Featured Mentor Recommendations" within ".cjs_quick_connect_items"
  Then I should see the image with src "/assets/star-off.png"
  Then I click on the image with src "/assets/star-off.png"
  Then I should see the image with src "/assets/star.png"

Scenario: Mentee should see favorite link in the header when feature is enabled
  Then I enable "Telugu" language for the organization "Primary Organization"
  When I have logged in as "rahim@example.com"
  Then I should see "Favorites" within "#chronus_header_wrapper"
  Then I should see "2" within "#favorite_in_header span.label-warning"
  Then "#side-menu li a i.fa-language" should not be visible
  Then I should see "English" within "#header_actions"

  Then I change to mobile view
  Then I should not see "Favorites"
  Then I should not see "English" within "#header_actions"
  Then I click by xpath "//*[@id='page-wrapper']/nav[2]/div/div/div[1]/div[3]"
  And I wait for "1" seconds
  Then I should see "Favorites"
  And I should see "2" within "#favorite_in_footer"
  Then I close modal
  Then I click by xpath "//*[@id='page-wrapper']/nav[2]/div/div/div[2]/div/a/div"  
  And I wait for "1" seconds
  Then "#side-menu li a i.fa-language" should be visible
  Then I follow "Mentors"

  Then I change to desktop view
  Then I click on the image with src "/assets/star-off.png"
  Then I should see "3" within "#favorite_in_header span.label-warning"
  Then I change to mobile view
  Then I click by xpath "//*[@id='page-wrapper']/nav[2]/div/div/div[1]/div[3]"
  And I wait for "1" seconds
  Then I should see "Favorites"
  And I should see "3" within "#favorite_in_footer"
  Then I close modal
  Then I change to desktop view

  Then I click on the image with src "/assets/star.png"
  Then I should see "2" within "#favorite_in_header span.label-warning"
  Then I change to mobile view
  Then I click by xpath "//*[@id='page-wrapper']/nav[2]/div/div/div[1]/div[3]"
  And I wait for "1" seconds
  Then I should see "Favorites"
  And I should see "2" within "#favorite_in_footer"
  Then I change to desktop view
  Then I close modal
  And I logout

Scenario: Mentee should not see favorite link in the header when feature is not enabled
  When I have logged in as "rahim@example.com"
  Then I disable the feature "skip_and_favorite_profiles" as a super user
  And I follow "Home"
  Then I should not see "Favorites" within "#chronus_header_wrapper"
  And I enable "skip_and_favorite_profiles" feature as a super user
  And I follow "Home"
  Then I should see "Favorites" within "#chronus_header_wrapper"
  And I logout

Scenario: Mentors should not see the favorite link the header
  When I have logged in as "robert@example.com"
  Then I disable the feature "skip_and_favorite_profiles" as a super user
  And I follow "Home"
  Then I should not see "Favorites" within "#chronus_header_wrapper"
  And I enable "skip_and_favorite_profiles" feature as a super user
  And I follow "Home"
  Then I should not see "Favorites" within "#chronus_header_wrapper"
  And I logout

Scenario: Mentee should see blank favorite listing page
  When I have logged in as "userrahim@example.com"
  Then I should see "Favorites" within "#chronus_header_wrapper"
  Then I follow "Favorites"
  Then I should see "Kal Raman" within "#cjs_favorite_listing"

  Then I should see "Review Recommendations" within "#SidebarRightContainer"
  Then I should see "Learn more about potential mentors by reviewing their profiles for compatibility with your preferences. Check out detailed profiles for as many mentors as you can to understand the options available to you. Around 10 to 15 is a good start." within "#SidebarRightContainer"
  Then I should see "Connect with your Mentors" within "#SidebarRightContainer"
  Then I should see "Reach out to mentors you like by sending a request with a personalized greeting and a description of your needs and how they might be able to help." within "#SidebarRightContainer"
  Then I should see "Build your Favorite Mentors List" within "#SidebarRightContainer"
  Then I should see "Add a few mentors to your favorites list in case your first choice of mentors cannot accept your requests. Only you can see this list and mentors are not notified when you add them." within "#SidebarRightContainer"
  Then I should see "Find a mentor"
  Then I follow "Find a mentor"
  Then I should see "Mentors" within ".cjs_title_text"
  Then I follow "Favorites"

  Then I click on the image with src "/assets/star.png"
  Then I wait for ajax to complete
  And I should not see "Kal Raman"
  Then I should see "You don't have any favorite users" within "#no_favorite_users"
  And I should see "Browse Profiles" within "#no_favorite_users"
  Then I follow "Browse Profiles"
  Then I should see "Mentors" within ".cjs_title_text"
  And admin update role permission "view_mentors" for "student" to "false" for program with name "Albers Mentor Program"
  Then I follow "Home"
  Then I should not see "Favorites" within "#chronus_header_wrapper"
  Then I change to mobile view
  Then I click by xpath "//*[@id='page-wrapper']/nav[2]/div/div/div[1]/div[3]"
  And I wait for "1" seconds
  Then I should not see "Favorites"
  And I logout

Scenario: Mentee sends a meeting request and sees bookmarked recommendations
  And I enable "skip_and_favorite_profiles" feature as a super user
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I logout
  When I have logged in as "rahim@example.com"
  Then I follow "Mentors"
  Then I filter a mentor with name "mentor_k chronus" using quick find
  Then I follow "mentor_d chronus"
  Then I click on the image with src "/assets/star-off.png"
  Then I follow "Mentors"
  Then I filter a mentor with name "Kal Raman" using quick find
  Then I follow "Kal Raman"
  Then I click on the image with src "/assets/star-off.png"
  Then I follow "Mentors"
  Then I filter a mentor with name "mentor_j chronus" using quick find
  Then I follow "mentor_j chronus"
  Then I click on the image with src "/assets/star-off.png"
  And I follow "Connect"
  Then I should see "Request Mentoring Connection"
  Then I follow "Request Mentoring Connection"
  Then I fill in "mentor_request_message" with "I kindly request you to be my mentor."
  And I press "Send request"
  And I should see "Your request for a mentoring connection has been successfully sent to mentor_j chronus"
  And I should see "Your settings allow you to connect with more mentors. Consider connecting with your favorite mentors"
  And I should see "mentor_d chronus"
  Then I follow "Send Request" for user with email "mentor_3@example.com" in program "primary":"albers"
  Then I fill in "mentor_request_message" with "I kindly request you to be my mentor."
  And I press "Send request"
  And I should not see "Request successfully sent!"
  

Scenario: Mentee sends a meeting request and sees bookmarked recommendations
  And I enable "skip_and_favorite_profiles" feature as a super user
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I logout
  When I have logged in as "mkr@example.com"
  Then I follow "Mentors"
  Then I filter a mentor with name "mentor_k chronus" using quick find
  Then I follow "mentor_d chronus"
  Then I click on the image with src "/assets/star-off.png"
  Then I follow "Mentors"
  Then I filter a mentor with name "Kal Raman" using quick find
  Then I follow "Kal Raman"
  Then I click on the image with src "/assets/star-off.png"
  Then I follow "Mentors"
  Then I filter a mentor with name "mentor_j chronus" using quick find
  Then I follow "mentor_j chronus"
  Then I click on the image with src "/assets/star-off.png"
  And I follow "Connect"
  Then I should see "Request Meeting"
  Then I follow "Request Meeting"
  And I fill in "new_meeting_title" with "Calendar Meeting"
  And I fill in "new_meeting_description" with "Let us meet and have a general meeting"
  Then I follow "Proceed to Propose Times"
  And I fill in "mentee_general_availability_message" with "mentee general availability message"
  Then I follow "Request Meeting"
  And I should see "Your request for a meeting with mentor_j chronus has been successfully sent" within ".toast-message"
  And I should see "Your settings allow you to connect with more mentors. Consider connecting with your favorite mentors"
  And I should see "mentor_d chronus"
  And I should see "90% match"

Scenario: Mentee bookmarks a mentor from show compatibility popup
  Given I unstub matching functions
  Given the current program is "primary":"albers"
  And I have logged in as "student_1@example.com"
  And I follow "Edit Profile"
  And I click on the section with header "Mentoring Profile"
  And I select the option "Female" for the question "Gender"
  And I save the section "Mentoring Profile"
  Then I logout
  And I have logged in as "mentor_2@example.com"
  And I follow "Edit Profile"
  And I click on the section with header "Mentoring Profile"
  And I select the option "Female" for the question "Gender"
  And I save the section "Mentoring Profile"
  Then I logout

  And I have logged in as "ram@example.com"
  And I login as super user
  Given the current program is "primary":"albers"
  Then I navigate to match_configs_path page
  Then I follow "New Config"
  Then I select "Gender" from "match_config_mentor_question_id" within "#edit_match_config"
  Then I select "Gender" from "match_config_student_question_id" within "#edit_match_config"
  Then I choose "Set Matching"
  Then I follow "Add new set"
  And I enter "Male" in "mentor_choice_box_0_0" autocomplete it with "Male"
  And I enter "Female" in "mentor_choice_box_1_0" autocomplete it with "Female"
  And I fill in "match_config_threshold" with "1"
  Then I choose "match_config_show_match_label_true" within "#edit_match_config"
  And I fill in "match_config_prefix" with "Gender Preferences - Male/Male and Female/Female" within "#edit_match_config"
  And I press "Set Configuration"
  Then I follow "Recompute Match Scores"
  Then I follow "Edit" within "#match_configs"
  Then I logout
  And I have logged in as "student_1@example.com"
  When I navigate to "mentor_2@example.com" profile in "albers"
  
  Then I should see "Show compatibility"
  And I follow "Show compatibility"
  Then I should see the image with src "/assets/star-off.png"
  Then I click on the image with src "/assets/star-off.png" within "#remoteModal"
  Then I should see the image with src "/assets/star.png"
  Then I click on the image with src "/assets/star.png" within "#remoteModal"
  Then I should see the image with src "/assets/star-off.png"