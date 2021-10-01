@javascript
Feature: AP 2294 - not matched mentors

Background:
  Given valid and appropriate date time settings
  Given the current program is "primary":"albers"
  And allow_non_match_connection set to false for program "albers"
  And zero_match_score_message set to "non match message" for program "albers"
  And mentor_request_style set to MENTEE_TO_MENTOR for program "albers"
  And Mentor "robert@example.com" did not match student "rahim@example.com" in program "albers"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I have logged in as "ram@example.com"
  And I allow mentors in the program to configure availability slots
  And I logout
  And I have logged in as "rahim@example.com"
  And I hover over "my_programs_container"
  And I select "Albers Mentor Program" from the program selector
  And I create a mentoring slot from "13:00:00" to "14:00:00" for "robert@example.com"
  Then I maximize the window

@cross_browser
Scenario: Mentee visits the mentors listing, non matched mentor profile. Mentee cannot invite mentor if mentor doesn't not a match this mentee
  # Not checking the disabled link from mentoring calendar page, because of the #difficult to handle qtip
  Then I wait for "User" Elastic Search Reindex
  And I follow "Mentors"
  Then I remove the status filter
  And I filter a mentor with name "Good unique" using quick find
  Then I wait for ajax to complete
  And I follow "More filters"
  Then I scroll to and open section "Match Score" in sidepane filter
  Then I wait for ajax to complete
  And I check "filter_show_no_match"
  Then I wait for ajax to complete
  And The match score should show 'Not a match' for the not matched mentor
  Then I click ".cjs_ignore_feature"
  Then I hover over the match score and should see "non match message"
  And Connect menu should include 'Send message' only for the not matched mentor
  And "Available Next" is not a link for the given non matched mentor
  Then I click ".img-circle" within "#results_pane"
  And I follow "Actions"
  And I should see disabled "Request Mentoring Connection"
  Then I hover over the disabled link and should see "non match message"
  Then I hover over the match score and should see "non match message"
  Then I follow "Mentoring Calendar" within "ul.metismenu"
 
  Then I click on the event with text "Good unique name available"
 
  And I should see disabled "Request Meeting"
  And The match score should show 'Not a match' for the not matched mentor
  And I hover over the match score and should see "non match message"