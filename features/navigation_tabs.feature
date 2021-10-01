Feature: Navigation Tabs
  In order to Navigate through the tabs, the tab list must show the corresponding tabs for each kind of user role
  As a mentor, mentee, admin
  I want to see corresponding links on the navigation bar
  
  @javascript
  Scenario: User logs in and all the features are disabled and he must see the links correctly
    Given the current program is "primary":"albers"
    And there are no features enabled
    # Mentee Logs in
    When I have logged in as "rahim@example.com"
    Then I should see the tabs "Home, Mentors, Students, Overview" in that order and "" is a subtab
    Then I logout
    #Mentor Logs in
    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    Then I should see the tabs "Home, MY MENTORING CONNECTIONS, Mentors, Students, Overview" in that order and "" is a subtab
    And I should see "name & madankumarrajan" within "ul.metismenu"
    Then I logout
    #Admin Logs in
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    Then I should see the tabs "Home, Students, Mentors, Manage" in that order and "" is a subtab
    Then I logout

  @javascript @cross-browser
  Scenario: User logs in and forums feature is enabled he must see the links correctly
    Given the current program is "primary":"albers"
    And only "forums" features are enabled
    # Mentee Logs in
    When I have logged in as "rahim@example.com"
    Then I should see the tabs "Home, Mentors, Students, Forums, Overview" in that order and "Forums" is a subtab
    Then I follow "Forums"
    And I should see the subtabs "Mentees Forum" under the tab "Forums"
    Then I logout
    # Mentor Logs in
    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    Then I should see the tabs "Home, My Mentoring Connections, Mentors, Students, Forums, Overview" in that order and "My Mentoring Connections, Forums" is a subtab
    Then I follow "Forums"
    And I should see the subtabs "Mentors Forum" under the tab "Forums"
    Then I logout
    # Admin Logs in
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    Then I should see the tabs "Home, Mentors, Students, Forums, Manage" in that order and "Forums" is a subtab
    Then I follow "Forums"
    And I should see the subtabs "Mentors Forum, Mentees Forum" under the tab "Forums"
    Then I logout

  @javascript  
  Scenario: User logs in and articles feature is enabled he must see the links correctly
    Given the current program is "primary":"albers"
    And only "articles" features are enabled
    # Mentee Logs in
    When I have logged in as "rahim@example.com"
    Then I should see the tabs "Home, Mentors, Students, Articles, Overview" in that order and "" is a subtab
    Then I logout
    # Mentor Logs in
    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    Then I should see the tabs "Home, My Mentoring Connections, Mentors, Students, Articles, Overview" in that order and "My Mentoring Connections" is a subtab
    Then I logout
    # Admin Logs in
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    Then I should see the tabs "Home, Mentors, Students, Articles, Manage" in that order and "" is a subtab
    Then I logout

  @javascript
  Scenario: User logs in and Questions and answers features are enabled he must see the links correctly
    Given the current program is "primary":"albers"
    And only "answers" features are enabled
    # Mentee Logs in
    When I have logged in as "rahim@example.com"
    Then I should see the tabs "Home, Mentors, Students, Question & Answers, Overview" in that order and "" is a subtab
    Then I logout
    # Mentor Logs in
    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    Then I should see the tabs "Home, My Mentoring Connections, Mentors, Students, Question & Answers, Overview" in that order and "My Mentoring Connections" is a subtab
    Then I logout
    # Admin Logs in
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    Then I should see the tabs "Home, Mentors, Students, Question & Answers, Manage" in that order and "" is a subtab
    Then I logout

  @javascript
  Scenario: User logs in and Calendar feature is enabled he must see the links correctly
    Given the current program is "primary":"albers"
    And only "calendar" features are enabled
    And I have logged in as "ram@example.com"
    And I allow mentors in the program to configure availability slots
    And I logout

    # Mentee Logs in
    When I have logged in as "rahim@example.com"
    Then I should see the tabs "Home, MEETINGS, Mentors, Students, Overview" in that order and "" is a subtab
    Then I should see "Requests" within "ul.metismenu"
    Then I should see "Upcoming" within "ul.metismenu"
    Then I should see "Past" within "ul.metismenu"
    Then I should see "Mentoring Calendar" within "ul.metismenu"
    Then I logout
    # Mentor Logs in
    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    Then I should see the tabs "Home, MEETINGS, MY MENTORING CONNECTIONS, Mentors, Students, Overview" in that order and "" is a subtab
    Then I logout
    # Admin Logs in
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    Then I should see the tabs "Home, Mentors, Students, Manage" in that order and "Mentor Schedule" is a subtab
    Then I logout

  @javascript
  Scenario: User logs in and Connection Profiles feature is enabled he must see the links correctly
    Given the current program is "primary":"albers"
    And only "connection_profile" features are enabled
    # Mentee Logs in
    When I have logged in as "rahim@example.com"
    Then I should see the tabs "Home, MEETINGS, MENTORING CONNECTIONS, Mentors, Students, Overview" in that order and "" is a subtab
    Then I logout
    # Mentor Logs in
    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    Then I should see the tabs "Home, MEETINGS, MENTORING CONNECTIONS, Mentors, Students, Overview" in that order and "" is a subtab
    Then I logout
    # Admin Logs in
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    Then I should see the tabs "Home, Students, Mentors, Manage" in that order and "" is a subtab
    Then I logout

  @javascript @cross-browser
  Scenario: User logs in and Articles and Questions and answers features is enabled he must see the links correctly
    Given the current program is "primary":"albers"
    And only "articles, answers" features are enabled
    # Mentee Logs in
    When I have logged in as "rahim@example.com"
    Then I should see the tabs "Home, Mentors, Students, Advice, Overview" in that order and "Advice" is a subtab
    Then I follow "Advice"
    And I should see the subtabs "Articles, Question & Answers" under the tab "Advice"
    Then I logout
    # Mentor Logs in
    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    Then I should see the tabs "Home, Mentors, Students, Advice, Overview" in that order and "My Mentoring Connections, Advice" is a subtab
    Then I follow "Advice"
    And I should see the subtabs "Articles, Question & Answers" under the tab "Advice"
    Then I logout
    # Admin Logs in
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    Then I should see the tabs "Home, Mentors, Students, Advice, Manage" in that order and "Advice" is a subtab
    Then I follow "Advice"
    And I should see the subtabs "Articles, Question & Answers" under the tab "Advice"
    Then I logout

  @javascript  
  Scenario: Admin should see Features tab only when he is a super user
    Given the current program is "primary":""
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Program Settings"
    And I should see "Features" within "div.inner_tabs"
    Then I follow "Home"
    When I follow "Albers Mentor Program"
    And I follow "Manage"
    And I follow "Program Settings"
    And I should not see "Features" within "div.inner_tabs"
    And I login as super user
    And I follow "Program Settings"
    And I should see "Features" within "div.inner_tabs"
    Then I hover over "my_programs_container"
    And I select "Primary Organization" from the program selector
    Then I follow "Manage"
    And I follow "Program Settings"
    And I should see "Features" within "div.inner_tabs"
    Then I logout
    Given the current program is "foster":"main"
    And I have logged in as "fosteradmin@example.com"
    Then I follow "Manage"
    Then I follow "Program Settings"
    And I should see "Features" within "div.inner_tabs"
    Then I logout

  @javascript @cross-browser
  Scenario: Mentor Should Not See MyMeetings if he is not available for one time mentoring
    Given the current program is "primary":"albers"
    And only "calendar" features are enabled
    And I have logged in as "ram@example.com"
    And I allow mentors in the program to configure availability slots
    And I logout

    # Mentee Logs in
    When I have logged in as "rahim@example.com"
    Then I should see the tabs "Home, MEETINGS, Mentors, Students, Overview" in that order and "" is a subtab
    Then I should see "Requests" within "ul.metismenu"
    Then I should see "Upcoming" within "ul.metismenu"
    Then I should see "Past" within "ul.metismenu"
    Then I should see "Mentoring Calendar" within "ul.metismenu"
    Then I logout
    # Mentor Logs in
    Given the current program is "primary":"albers"
    And I set mentoring mode of "mentor_1@example.com" to ongoing
    When I have logged in as "mentor_1@example.com"
    Then I should see the tabs "Home, MY MENTORING CONNECTIONS, Mentors, Students, Overview" in that order and "" is a subtab
    Then I should not see "MEETINGS" within "ul.metismenu" 
    Then I logout
    # Admin Logs in
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    Then I should see the tabs "Home, Mentors, Students, Manage" in that order and "Mentor Schedule" is a subtab
    Then I follow "Manage"
    And I follow "User Views"
    And I add "Admin" role to "mentor_1@example.com" from admin users page
    Then I follow "Manage"
    And I follow "User Views"
    And I follow "2"
    And I add "Admin" role to "rahim@example.com" from admin users page
    Then I logout
    # Mentor Logs in again but now he's a admin too..
    Given the current program is "primary":"albers"
    And I set mentoring mode of "mentor_1@example.com" to ongoing
    When I have logged in as "mentor_1@example.com"
    Then I should see the tabs "Home, MY MENTORING CONNECTIONS, Mentors, Students, Manage" in that order and "" is a subtab
    Then I should not see "MEETINGS" within "ul.metismenu"
    Then I logout
    # Mentee Logs in again but now he's a admin too..
    When I have logged in as "rahim@example.com"
    Then I should see the tabs "Home, MEETINGS, Mentors, Students, Manage" in that order and "" is a subtab
    Then I should see "Requests" within "ul.metismenu"
    Then I should see "Upcoming" within "ul.metismenu"
    Then I should see "Past" within "ul.metismenu"
    Then I should see "Mentoring Calendar" within "ul.metismenu"
    Then I logout

  @javascript
  Scenario: Admin logs in and he adds student role to Mentor
    Given the current program is "primary":"albers"
    And only "calendar" features are enabled
    When I have logged in as "ram@example.com"
    Then I follow "Manage"
    And I follow "User Views"
    And I add "Student" role to "mentor_1@example.com" from admin users page
    Then I logout
    Given the current program is "primary":"albers"
    And I set mentoring mode of "mentor_1@example.com" to ongoing
    When I have logged in as "mentor_1@example.com"
    Then I should see the tabs "Home, Meetings, My Mentoring Connections, Mentors, Students, Forums, Overview" in that order and "My Mentoring Connections, Forums" is a subtab
    Then I logout

  @javascript
  Scenario: Admin logs in and he adds Mentor role to student
    Given the current program is "primary":"albers"
    And only "calendar" features are enabled

    And I have logged in as "ram@example.com"
    And I allow mentors in the program to configure availability slots
    Then I follow "Manage"
    And I follow "User Views"
    And I follow "2"
    And I add "Mentor" role to "rahim@example.com" from admin users page
    And I set mentoring mode of "rahim@example.com" to ongoing
    Then I logout
    Given the current program is "primary":"albers"
    When I have logged in as "rahim@example.com"
    Then I should see the tabs "Home, Meetings, My Mentoring Connections, Mentors, Students, Forums, Overview" in that order and "My Mentoring Connections, Forums" is a subtab
    Then I logout

  @javascript
  Scenario: Change student to mentor and check if the tabs are being shown appropriately.
    Given the current program is "primary":"albers"
    Given I have logged in as "ram@example.com"
    Given There are no meeting requests for "rahim@example.com" in "primary":"albers"
    And only "calendar" features are enabled
    And "rahim@example.com" is a student in "primary":"albers"
    And "rahim@example.com" is not a mentor in "primary":"albers"
    When I navigate to "rahim@example.com" profile in "albers"
    And I follow "Change Roles"
    Then I check "role_names_mentor"
    Then I uncheck "role_names_student"
    And I fill in "role_change_reason_text" with "Roles updated as you requested"
    And I press "Submit"
    Then I should see "The roles have been successfully updated"
    Then "rahim@example.com" is not a student in "primary":"albers"
    And check "rahim@example.com" is a mentor in "primary":"albers"
    And I set mentoring mode of "rahim@example.com" to ongoing
    Then I logout
    Given the current program is "primary":"albers"
    And I set mentoring mode of "rahim@example.com" to ongoing
    When I have logged in as "rahim@example.com"
    Then I should see the tabs "Home, My Mentoring Connections, Mentors, Students, Forums, Overview" in that order and "My Mentoring Connections, Forums" is a subtab
    Then I should not see the tab "Meetings" 
    Then I logout

  @javascript
  Scenario: Mentor changes from Ongoing to One-time Mentoring mode but is present in active groups.
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Connections"
    And I click "#list_view"
    And I follow "Closed"
    And I should see "Closed" selected under group tabs
    And I follow "Create New Mentoring Connection"
    And I fill in "mentor" field of "primary":"albers" with "Good unique name <mentor_1@example.com>" 
    And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"
    And I click "#create_and_publish"    
    And I should see "Ongoing" within "li.ct_active"
    Then I should see "chronus & example"
    Then I should not see "Visit Mentoring Area"
    Then I should see "Mentoring Connection Name" within "#cjs_group_record"
    Then I logout
    #Mentor logs in..
    Given the current program is "primary":"albers"
    And only "calendar" features are enabled
    And I set mentoring mode of "mentor_1@example.com" to one time
    Given the current program is "primary":"albers"
    When I have logged in as "mentor_1@example.com"
    Then I should see the tabs "Home, Meetings, My Mentoring Connections, Mentors, Students, Forums, Overview" in that order and "My Mentoring Connections, Forums" is a subtab
    Then I logout