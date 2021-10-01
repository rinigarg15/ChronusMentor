Feature: mentoring Tips

Background: Set Program Level
    Given the current program is "primary":"albers"

@javascript @p2 @cross-browser
Scenario: Admin create new tip + Edit a tip + Delete Tip
	And I have logged in as "ram@example.com"
    And I follow "Manage"
    Then I should see "Mentoring Insights"
    And I follow "Mentoring Insights"
    #Add new tip
    And I follow "Actions"
    Then I follow "Add new mentoring insight"
    And I fill in "Mentoring Insight" with "Be a good listener to be a good mentor"
    Then I press "Save"
    Then I should see "Be a good listener to be a good mentor"

    #Edit a tip
    Then I follow "Student"
    And I follow "Actions"
    Then I follow "Add new mentoring insight"
    And I fill in "Mentoring Insight" with "Ask for constructive critisim from your mentor"
    Then I press "Save"
    
    And I follow "Edit"
    Then I fill in "Mentoring Insight" with "Ask for constructive criticisim from your mentor"
    And I press "Save"
    Then I logout

    #Create new connection
    Given the current program is "primary":"albers"
    And there are no mentor requests
    When I have logged in as "rahim@example.com"
    And I visit the profile of "mentrostud@example.com"
    And I follow "Actions"
    And I follow "Request Mentoring Connection"
    Then I fill in "mentor_request_message" with "I kindly request you to be my mentor."
    And I press "Send request"
    And I should see the flash "Your request for a mentoring connection has been successfully sent to Mentor Studenter. You will be notified once the mentor accepts your request."
    And I logout
    Given the current program is "primary":"albers"
    And I have logged in as "mentrostud@example.com"
    And I click ".pending_requests_notification_icon"
    And I follow "Mentoring Requests"
    Then I choose "filter_me"
    And I follow "Actions"
    When I follow "Accept"
    Then I should see "Studenter & example"
    Then I close modal
    #See the tip as mentor
    Then I should see "Be a good listener to be a good mentor"
    #Hide tip
    Then I hide the mentoring tip
    And I hover over "My Mentoring connections"
    Then I follow "Studenter & example"
    And I should not see "Be a good listener to be a good mentor"
    Then I logout
    
    And I have logged in as "rahim@example.com"
    And I hover over "My mentoring connections"
    Then I follow "Studenter & example"
    #See tip as mentee
    Then I should see "Ask for constructive criticisim from your mentor"
    Then I logout

    #Delete tip
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    Then I should see "Mentoring Insights"
    And I follow "Mentoring Insights"
    Then I follow "Delete"
    And I should see "Are you sure you want to delete this mentoring insight?"
    And I confirm popup
    Then I should not see "Be a good listener to be a good mentor"

    #Enable All
    And I follow "Actions"
    And I follow "Enable all"
    Then I follow "Student"
    And I follow "Actions"
    And I follow "Disable all"
    Then I logout

    Given the current program is "primary":"albers"
    And I have logged in as "mentrostud@example.com"
 	And I hover over "My mentoring connections"
    Then I follow "Studenter & example"
    Then I follow "Plan"
    Then I should see "Refresh Your Mentoring Skills" 
    Then I logout

    #Disable All
    And I have logged in as "rahim@example.com"
    And I hover over "My mentoring connections"
    Then I follow "Studenter & example"
    Then I should not see "Ask for constructive criticisim from your mentor" 

@javascript @cross-browser
Scenario: Admin disable mentoring tips
    When I have logged in as "ram@example.com"
    And I follow "Manage"
    Then I should see "Mentoring Insights"
    And I follow "Mentoring Insights"
    And I follow "Actions"
    Then I follow "Add new mentoring insight"
    And I fill in "Mentoring Insight" with "Mentor Tip"
    Then I press "Save"
    Then I should see "Mentor Tip"
    Then I follow "Student"
    And I follow "Actions"
    Then I follow "Add new mentoring insight"
    And I fill in "Mentoring Insight" with "Student Tip"
    Then I press "Save"
    Then I logout

    Given the current program is "primary":"albers"
    And there are no mentor requests
    When I have logged in as "rahim@example.com"
    And I visit the profile of "mentrostud@example.com"
    And I follow "Actions"
    And I follow "Request Mentoring Connection"
    Then I fill in "mentor_request_message" with "I kindly request you to be my mentor."
    And I press "Send request"
    And I should see the flash "Your request for a mentoring connection has been successfully sent to Mentor Studenter. You will be notified once the mentor accepts your request."
    And I logout
    Given the current program is "primary":"albers"
    And I have logged in as "mentrostud@example.com"
    And I click ".pending_requests_notification_icon"
    And I follow "Mentoring Requests"
    Then I choose "filter_me"
    And I follow "Actions"
    When I follow "Accept"
    Then I should see "Studenter & example"
    #See the tip as mentor
    Then I should see "Mentor Tip"
    And I logout
    And I have logged in as "rahim@example.com"
    And I hover over "My mentoring connections"
    Then I follow "Studenter & example"
    Then I should see "Student Tip"
    And I logout

    And I have logged in as "ram@example.com"
    And I login as super user
    And I follow "Manage"    
    And I follow "Program Settings"
    And I follow "Features"
    Then I should see "Mentoring Insights"
    And I uncheck "Mentoring Insights"
    And I press "Save"
    And I follow "Manage"
    Then I should not see "Mentoring Insights"
    Then I logout

    And I have logged in as "rahim@example.com"
    And I hover over "My mentoring connections"
    Then I follow "Studenter & example"
    Then I should not see "Student Tip"
    And I logout

    And I have logged in as "mentrostud@example.com"
    And I hover over "My mentoring connections"
    Then I follow "Studenter & example"
    Then I should not see "Mentor Tip"
    And I logout