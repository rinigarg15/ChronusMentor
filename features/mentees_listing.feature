@javascript
Feature: Filters in Students listing page
In order to see which students are connected and who are not
As an admin
I want to login and enter the appropriate as required

Background:
    Given the current program is "primary":"albers"

@javascript
Scenario: Default Sort order Name Ascending, and Turn into relevance when searched for a string, and back to Name Ascending when search removed with relevance as current sort.
    Given the current program is "primary":"albers"
    And I have logged in as "mentrostud@example.com"
    And I follow "Students"
    Then I should see "Name (A-Z)"
    Then I should see "Quick Find"
    Then I fill in "Quick Find" with "Arun"
    Then I click "#quick_search .btn-primary"
    Then I should see "Relevance"
    Then I follow "Reset all"
    Then I should see "Name (A-Z)"    
    Then I logout

Scenario: Mentor should not see the filters
    And I have logged in as "robert@example.com"
    And I follow "Students"
    Then I should not see "Status"
    And I should not see "Last Login"
    Then I should not see "10 mentors per page"
    And I should see "student example"
    And I should see "student_b example"
    And I should see "mkr_student madankumarrajan"

Scenario: Mentee should not see the filters
    And I have logged in as "rahim@example.com"
    And I follow "Students"
    Then I should not see "Status"
    And I should not see "10 students per page"
    And I should not see "Last Login"
    And I should see "student example"
    And I should see "student_b example"
    And I should see "mkr_student madankumarrajan"

@javascript @cross-browser
Scenario: Items per page should be seen by admin
    And I have logged in as "ram@example.com"
    And I follow "Students"
    And I should see "student example"
    And I should see "student_b example"
    And I should see "mkr_student madankumarrajan"
    And I should see "Last Login"
    And I should see "Showing 1 - 10 of 21"
    And I select "40" from "items_per_page_selector"
    Then I should see "Showing 1 - 21 of 21"
    And I should see "Connection Status"

    When I check "filter_connected_mentees"
    Then I should not see "student_k example"
    And I should not see "student_l example"
    # Expired connection
    And I should not see "student_e example"
    And I should see "student_c example"
    And I should see "student_d example"
    And I should see "mkr_student madankumarrajan"

    When I remove filter with id "filter_item_connection_status"
    And I check "filter_unconnected_mentees"
    And I select "20" from "items_per_page_selector"
    Then I should see "student_k example"
    And I should see "student_l example"
    And I should see "student_e example"
    And I should not see "student_c example"
    And I should not see "student_d example"
    And I should not see "mkr_student madankumarrajan"

    When I remove filter with id "filter_item_connection_status"
    And I check "filter_never_connected_mentees"
    And I select "20" from "items_per_page_selector"
    Then I should see "student_k example"
    And I should see "student_l example"
    # Expired connection
    And I should not see "student_e example"
    # Unconnected
    And I should not see "student_c example"
    And I should not see "student_d example"
    And I should not see "mkr_student madankumarrajan"

    When I remove filter with id "filter_item_connection_status"
    And I should see "student example"
    And I should see "student_b example"
    And I should see "mkr_student madankumarrajan"

@javascript
Scenario: Find a mentor should not be visible in ongoing mentoring disabled program in mentees listing
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I follow "Students"
    And I follow "Actions" in the users listing
    Then I should see "Find a Mentor"
    When I change engagement type of program "primary":"albers" to "career based"
    And I follow "Students"
    And I follow "Actions" in the users listing
    Then I should not see "Find a Mentor"
    Then I should see "Send Message"

@javascript
Scenario: Connection Status should not be visible in ongoing mentoring disabled program
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I follow "Students"
    And I should see "Connection Status" within "#filter_pane"
    And I change engagement type of program "primary":"albers" to "career based"
    And I follow "Students"
    And I should not see "Connection Status" within "#filter_pane"

@javascript
Scenario: Find a mentor should not be visible in ongoing mentoring disabled program in mentee profile
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I follow "Students"
    And I follow "arun albers"
    Then I should see "Find a Mentor" within "div#profile_side_bar"
    And I change engagement type of program "primary":"albers" to "career based"
    And I follow "Students"
    And I follow "arun albers"
    Then I should not see "Find a Mentor" within "div#profile_side_bar"

@javascript
Scenario: Connection related quick links should not be present in mentee profile for ongoing mentoring disabled program 
    Given the current program is "primary":"albers"
    When I have logged in as "mkr@example.com"
    Then I should see "MENTORING CONNECTIONS" within "nav#sidebarLeft"
    And I click ".pending_requests_notification_icon"
    Then I should see "Mentoring Requests" within "ul#header_actions"
    Then I logout
    And I change engagement type of program "primary":"albers" to "career based"
    When I have logged in as "mkr@example.com"
    Then I should not see "Mentoring Connections" within "nav#sidebarLeft"
    Then I should not see "Mentoring Requests" within "ul#header_actions"