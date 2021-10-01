Feature: Mentors listing page

@javascript
Scenario: Default Sort order Match Score, and Turn into relevance when searched for a string, and back to match score when search removed with relevance as current sort.
    Given the current program is "primary":"albers"
    And I have logged in as "mentrostud@example.com"
    And I follow "Mentors"
    Then I should see "Match Score (High to Low)"
    Then I should see "Quick Find"
    Then I fill in "Quick Find" with "chronus"
    Then I click "#quick_search .btn-primary"
    Then I should see "Relevance"
    Then I follow "Reset all"
    Then I should see "Match Score (High to Low)"    
    Then I logout

@javascript
Scenario: User is both a mentor and a mentee and the "Request Mentoring Connection" should not be shown for the user.
    Given the current program is "primary":"albers"
    And I have logged in as "mentrostud@example.com"
    And I follow "Mentors"
    When I navigate to "mentrostud@example.com" profile in "albers"
    Then I should not see "Request Mentoring Connection"
    Then I logout

@javascript
Scenario: Mentor availability pane should be shown when calendar feature activated.
    Given the current program is "primary":"albers"
    And I have enabled "Calendar" feature
    And I have logged in as "mentrostud@example.com"
    And I follow "Mentors"
    Then I should see "Availability Status"

@javascript
Scenario: Guru Availability pane should be shown when calendar feature activated and Mentor term changed to Guru.
    Given the current program is "primary":"albers"
    And I have enabled "Calendar" feature
    And "mentor" Role Term changed to "Guru"
    And I have logged in as "mentrostud@example.com"
    And I follow "Gurus"
    Then I should see "Availability Status"

@javascript @cross-browser
Scenario: Mentor available status calendar filters should be shown and checked by default and default should be false after calendar availability range uncheck.
    Given the current program is "primary":"albers"
    And I have enabled "Calendar" feature
    And I have logged in as "mentrostud@example.com"
    And I follow "Mentors"
    Then the "filter_long_term_availability" checkbox_id should be checked
    When I check "filter_available_for_a_meeting"
    Then the "filter_available_for_a_meeting" checkbox_id should be checked
    
@javascript @cross-browser
Scenario: Mentor available status calendar filters should be shown and checked by default and default should be false after long term availability uncheck.
    Given the current program is "primary":"albers"
    And I have enabled "Calendar" feature
    And I have logged in as "mentrostud@example.com"
    And I follow "Mentors"
    Then I should see "Availability Status"
    Then the "filter_long_term_availability" checkbox_id should be checked
    When I uncheck "filter_long_term_availability"
    Then the calendar availability default field should be false
    Then I should see "Availability Status"

@javascript @cross-browser
Scenario: Mentor availablility filters should disappear when unchecked both.
    Given the current program is "primary":"albers"
    And I have enabled "Calendar" feature
    And I have logged in as "mentrostud@example.com"
    And I follow "Mentors"
    Then I should see "Availability Status"
    Then the "filter_long_term_availability" checkbox_id should be checked
    When I uncheck "filter_long_term_availability"
    Then the calendar availability default field should be false
    When I uncheck "filter_available_for_a_meeting"

@javascript @cross-browser
Scenario: Mentee sees request ongoing mentoring and request meeting disabled in mentors listing
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    Then I follow "Manage"
    Then I follow "Program Settings"
    Then I follow "Matching Settings"
    Then I check "program_allow_mentoring_mode_change"
    And I press "Save"
    Then I logout
    When I have logged in as "rahim@example.com"
    And I follow "Mentors"
    And I follow "Connect"
    Then I should see "Request Mentoring Connection"
    Then I should see "Request Meeting"
    Then I should see "Send Message"
    And I change mentoring mode of mentor with email "mentrostud@example.com" in program "primary":"albers" to "one time"
    And I follow "Mentors"
    Then I filter a mentor with name "Mentor Studenter" using quick find
    And I follow "Connect"
    And I should see disabled "Request Mentoring Connection"
    Then I hover over link with text "Request Mentoring Connection"
    And I should see "Mentor is not available for ongoing mentoring."
    And I should see "Request Meeting"
    Then I should see "Send Message"
    And I change mentoring mode of mentor with email "mentrostud@example.com" in program "primary":"albers" to "ongoing"
    And I follow "Mentors"
    Then I filter a mentor with name "Mentor Studenter" using quick find
    And I follow "Connect"
    Then I should see "Request Mentoring Connection"
    And I should see disabled "Request Meeting"
    Then I hover over link with text "Request Meeting"
    And I should see "Mentor is not available for meetings."
    Then I should see "Send Message"

@javascript @cross-browser
Scenario: Mentee sees request ongoing mentoring and request meeting disabled in mentors profile
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    Then I follow "Manage"
    Then I follow "Program Settings"
    Then I follow "Matching Settings"
    Then I check "program_allow_mentoring_mode_change"
    And I press "Save"
    Then I logout
    When I have logged in as "rahim@example.com"
    And I follow "Mentors"
    Then I filter a mentor with name "Mentor Studenter" using quick find
    And I follow "Mentor Studenter"
    And I follow "Actions"
    Then I should see "Request Mentoring Connection"
    Then I should see "Request Meeting"
    Then I should see "Send Message"
    And I change mentoring mode of mentor with email "mentrostud@example.com" in program "primary":"albers" to "one time"
    And I follow "Mentors"
    Then I filter a mentor with name "Mentor Studenter" using quick find
    And I follow "Mentor Studenter"
    When I follow "Actions"
    Then I should see disabled "Request Mentoring Connection"
    When I hover over link with text "Request Mentoring Connection"
    Then I should see "Mentor is not available for ongoing mentoring."
    And I should see "Request Meeting"
    Then I should see "Send Message"
    And I change mentoring mode of mentor with email "mentrostud@example.com" in program "primary":"albers" to "ongoing"
    And I follow "Mentors"
    Then I filter a mentor with name "Mentor Studenter" using quick find
    And I follow "Mentor Studenter"
    When I follow "Actions"
    And I should see "Request Mentoring Connection"
    And I should see disabled "Request Meeting"
    When I hover over link with text "Request Meeting"
    Then I should see "Mentor is not available for meetings."
    And I should see "Send Message"

@javascript
Scenario: Mentee sees add to preferred mentors disabled in mentors listing
    Given the current program is "primary":"modprog"
    When I have logged in as "moderated_admin@example.com"
    And I enable "calendar" feature that was removed from UI as super user of "primary":"modprog"
    Then I follow "Manage"
    Then I follow "Program Settings"
    Then I follow "Matching Settings"
    Then I check "program_allow_mentoring_mode_change"
    And I press "Save"
    Then I logout
    When I have logged in as "moderated_student@example.com"
    And I follow "Mentors"
    Then I should see "Add to preferred mentors" "not disabled" for "modprog" mentor with email "moderated_mentor@example.com"
    When I change mentoring mode of mentor with email "moderated_mentor@example.com" in program "primary":"modprog" to "one time"
    And I follow "Mentors"
    Then I should see "Add to preferred mentors" "disabled" for "modprog" mentor with email "moderated_mentor@example.com"
    When I hover over link with text "Add to preferred mentors"
    Then I should see "Mentor is not available for ongoing mentoring."

@javascript @cross-browser
Scenario: Mentee sees request ongoing mentoring disabled in mentors listing and profile for unavailable mentor
    Given the current program is "primary":"albers"
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    When I have logged in as "rahim@example.com"
    And I follow "Mentors"
    Then I filter a mentor with name "Mentor Studenter" using quick find
    And I follow "Connect"
    Then I should see "Request Mentoring Connection"
    When I follow "Mentor Studenter"
    And I follow "Actions"
    Then I should see "Request Mentoring Connection"
    And I change maximum connections limit of mentor with email "mentrostud@example.com" in program "primary":"albers" to "0"
    And I follow "Mentors"
    And I remove the status filter
    Then I filter a mentor with name "Mentor Studenter" using quick find
    And I follow "Connect" within "div#mentor_5"
    And I should see disabled "Request Mentoring Connection"
    Then I hover over link with text "Request Mentoring Connection"
    And I should see "Mentor has already reached the mentoring connection limit and currently not available for Ongoing mentoring."
    When I follow "Mentor Studenter"
    And I follow "Actions"
    Then I should see disabled "Request Mentoring Connection"
    When I hover over link with text "Request Mentoring Connection"
    Then I should see "Mentor has already reached the mentoring connection limit and currently not available for Ongoing mentoring."

@javascript
Scenario: Request ongoing mentoring should not be visible in ongoing mentoring disabled program in mentor listing
    Given the current program is "primary":"albers"
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    When I have logged in as "rahim@example.com"
    And I follow "Mentors"
    And I follow "Connect"
    Then I should see "Request Mentoring Connection"
    Then I change engagement type of program "primary":"albers" to "career based"
    And I follow "Mentors"
    And I follow "Connect"
    And I should not see "Request Mentoring Connection"

@javascript
Scenario: Add as favorite should not be visible in ongoing mentoring disabled program
    Given the current program is "primary":"modprog"
    When I have logged in as "moderated_student@example.com"
    Then I change engagement type of program "primary":"modprog" to "career based and ongoing"
    And I follow "Mentors"
    Then I click on dropdown toggle within "#results_pane"
    Then I should see "Add to preferred mentors"
    Then I change engagement type of program "primary":"modprog" to "career based"
    And I follow "Mentors"
    And I should not see "Add to preferred mentors"

@javascript
Scenario: Availability Status should not be visible in ongoing mentoring disabled program
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    Then I logout
    When I have logged in as "rahim@example.com"
    And I follow "Mentors"
    And I should see "Availability Status" within "#filter_pane"
    And I should see "Available for a long term mentoring connection"
    And I should see "Available for a meeting"
    Then I change engagement type of program "primary":"albers" to "career based"
    And I follow "Mentors"
    And I should see "Availability Status" within "#filter_pane"
    And I should not see "Available for a long term mentoring connection"
    And I should see "Available for a meeting"

@javascript
Scenario: Request ongoing mentoring should not be visible in ongoing mentoring disabled program in mentor profile
    Given the current program is "primary":"albers"
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    When I have logged in as "rahim@example.com"
    And I follow "Mentors"
    And I remove the status filter
    Then I filter a mentor with name "Mentor Studenter" using quick find
    And I follow "Mentor Studenter"
    And I follow "Actions"
    Then I should see "Request Mentoring Connection"
    Then I change engagement type of program "primary":"albers" to "career based"
    And I follow "Mentors"
    Then I filter a mentor with name "Mentor Studenter" using quick find
    And I follow "Mentor Studenter"
    And I follow "Actions"
    And I should not see "Request Mentoring Connection"

@javascript
Scenario: Connections listing should not be visible in ongoing mentoring disabled program in mentor profile
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I follow "Mentors"
    Then I filter a mentor with name "Mentor Studenter" using quick find
    Then I should scroll by "500"
    And I follow "Mentor Studenter"
    Then I should see "Mentoring Connections (0)" within "div#profile_side_bar"
    Then I change engagement type of program "primary":"albers" to "career based"
    And I follow "Mentors"
    Then I filter a mentor with name "Mentor Studenter" using quick find
    Then I should scroll by "500"
    And I follow "Mentor Studenter"
    Then I should not see "Mentoring Connections (0)" within "div#profile_side_bar"

@javascript @cross-browser
Scenario: Connection related Activity overview should not be visible in ongoing mentoring disabled program in mentor profile
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I follow "Mentors"
    Then I filter a mentor with name "Mentor Studenter" using quick find
    Then I should scroll by "500"
    And I follow "Mentor Studenter"
    Then I should see "Ongoing mentoring connections" within "#program_role_info"
    Then I should see "Past mentoring connections" within "#program_role_info"
    Then I change engagement type of program "primary":"albers" to "career based"
    And I follow "Mentors"
    Then I filter a mentor with name "Mentor Studenter" using quick find
    Then I should scroll by "500"
    And I follow "Mentor Studenter"
    Then I should not see "Ongoing mentoring connections" within "#program_role_info"
    Then I should not see "Past mentoring connections" within "#program_role_info"

@javascript @cross-browser
Scenario: Connection related quick links should not be present in mentor profile for ongoing mentoring disabled program 
    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    Then I should see "name & madankumarrajan" within "ul#cjs_mentoring_connection_header"
    And I click ".pending_requests_notification_icon"
    Then I should see "Mentoring Requests"
    Then I logout
    Then I change engagement type of program "primary":"albers" to "career based"
    When I have logged in as "robert@example.com"
    Then I should not see "name & madankumarrajan" within "ul#side-menu"
    Then I should not see "Requests"

@javascript @cross-browser
Scenario: Student count should not be visible if mentor is not opting for ongoing mentoring
    Given the current program is "primary":"albers"
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    When I have logged in as "ram@example.com"
    When I login as super user
    And I follow "Manage"
    Then I follow "Program Settings"
    Then I follow "Matching Settings"
    Then I check "program_allow_mentoring_mode_change"
    And I press "Save"
    Then I logout as super user
    Then I logout
    When I have logged in as "rahim@example.com"
    And I follow "Mentors"
    Then I filter a mentor with name "Mentor Studenter" using quick find
    And I should see "0 students" within "div#mentor_5" 
    #And I follow "Mentor Studenter"
    #Then I should see "0 students" within "div.ct_name_title"
    And I change mentoring mode of mentor with email "mentrostud@example.com" in program "primary":"albers" to "one time"
    And I follow "Mentors"
    Then I filter a mentor with name "Mentor Studenter" using quick find
    And I should not see "0 students" within "div#mentor_5"
    #And I follow "Mentor Studenter"
    #Then I should not see "0 students" within "div.ct_name_title"

@javascript @cross-browser
Scenario: Student count should not be visible if ongoing mentoring is disabled
    Given the current program is "primary":"albers"
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    When I have logged in as "ram@example.com"
    When I login as super user
    And I follow "Manage"
    Then I follow "Program Settings"
    Then I follow "Matching Settings"
    Then I check "program_allow_mentoring_mode_change"
    And I press "Save"
    Then I logout as super user
    Then I logout
    When I have logged in as "rahim@example.com"
    And I follow "Mentors"
    Then I filter a mentor with name "Mentor Studenter" using quick find
    And I should see "0 students" within "div#mentor_5"
    And I follow "Mentor Studenter"
    Then I should not see "0 students" within "div.ct_name_title"
    Then I change engagement type of program "primary":"albers" to "career based"
    And I follow "Mentors"
    Then I filter a mentor with name "Mentor Studenter" using quick find
    And I should not see "0 students" within "div#mentor_5"
    And I follow "Mentor Studenter"
    Then I should not see "0 students" within "div.ct_name_title"

@javascript @cross-browser
Scenario: Filtering on choice based questions
  Given the current program is "primary":"albers"
  When I have logged in as "robert@example.com"
  And I follow "Mentors" within "nav#sidebarLeft"
   
  Then I should see "Good unique name" within "#results_pane"
  Then I follow "More filters"
  Then I should scroll by "500"
  And I filter by question "Industry" with choice "Insurance"
  Then I should not see "Good unique name" within "#results_pane"
  When I click on profile picture and click "Edit Profile"
  And I click on the section with header "Mentoring Profile"
  And I select "Insurance" for the profile question "Industry"
  And I press "Save" within "#custom_fields_3"
  Then I follow "Mentors" within "nav#sidebarLeft"
   
  And I should see "Good unique name" within "#results_pane"
  Then I follow "More filters"
  Then I should scroll by "500"
  And I filter by question "Industry" with choice "Insurance"
  Then I should see "Good unique name" within "#results_pane"