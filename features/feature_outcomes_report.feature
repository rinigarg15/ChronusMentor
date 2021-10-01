@javascript
Feature: Program outcomes report feature

Background: Admin logs in
  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I enable "program_outcomes_report" feature as a super user
  And I logout                         

@javascript
Scenario: Only Superuser should be able to either enable/disable Program Outcomes Report Feature. 
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  When I follow "Outcome Reports" within "nav#sidebarLeft"
  Then I should see "Program Outcomes Report"
  When I disable the feature "program_outcomes_report" as a super user
  When I follow "Outcome Reports" within "nav#sidebarLeft"
  Then I should not see "Program Outcomes Report"
  And I logout

@javascript @cross-browser
Scenario: Admin views the Program Outcomes Report
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  Then I change engagement type of program "primary":"albers" to "career based and ongoing"
  When I follow "Outcome Reports" within "nav#sidebarLeft"
  And I follow "Program Outcomes Report"
  
  # Testing back-link
  Then I should see "Outcomes Report"
  When I follow the back link
  Then I should see "Reports" within "#title_box"
  And I follow "Program Outcomes Report"

  
  Then I should see "Membership"
  Then I should see "Users Total"
  Then I should see "Matching"
  Then I should see "Mentoring Connections"
  Then I should see "Engagement - Completed Mentoring Connections"
  Then I should see "Positive Results Reported in Completed Mentoring Connections"

  And I should see the tooltip text "This is the number of users in active state at some point in your program during the selected time period." on hovering over the info icon for "users_total"
  And I should see the tooltip text "This is the number of users in at least one mentoring connection at some point during the selected time period." on hovering over the info icon for "users_connected"
  And I should see the tooltip text "This is the number of mentoring connections present at some point during the selected time period." on hovering over the info icon for "mentoring_connections_total"
  And I should see the tooltip text "This is the number of users who completed at least one mentoring connection at some point during the selected time period." on hovering over the info icon for "users_with_completed_mentoring_connections"
  And I should see the tooltip text "This is the number of mentoring connections that were completed at some point during the selected time period." on hovering over the info icon for "mentoring_connections_completed"
     
  Then I should see "Click here to configure the reported positive outcomes section "
  And I click ".cjs_positive_outcomes_popup"
  Then I should see "Configure Positive Outcomes Report"
  And I select "Where are you from?" as positive outcomes question
  And I select "Earth" as positive outcomes choice for question "Where are you from?"
  Then I press "Save"
  And I should see the tooltip text "This is the number of users who completed a mentoring connection and reported positive results in the mentoring connection survey(s) selected." on hovering over the info icon for "users_reporting_positive_results"
  And I should see the tooltip text "This is the number of mentoring connections with at least one member reporting positive results in the selected survey during the selected time period." on hovering over the info icon for "mentoring_connections_reporting_positive_results"
  And I click ".cjs_positive_outcomes_popup"
  Then I should see "Where are you from?"
  Then I should see "Earth"
  Then I should see "Select a survey question"
  Then I follow "Cancel"

  # Testing date range filters

  And I follow "report_date_range"
  And I select "Custom" from reports date range presets
  And I cannot select a date prior to program created date
  And I select "1" days and "3" days after program creation
  And I press "Go"
  Then I should see "1" days and "3" days after program creation as the selected date range
  And I logout

@javascript @not_run_on_tddium
Scenario: The Engagement related sections should not be present if the ongoing mentoring is disabled.
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  Then I change engagement type of program "primary":"albers" to "career based and ongoing"
  When I follow "Outcome Reports" within "nav#sidebarLeft"
  And I follow "Program Outcomes Report"
  Then I should see "Membership"
  Then I should see "Matching"
  Then I should see "Users Connected"
  Then I should see "Mentoring Connections Completed"
  Then I should see "Positive Results Reported in Completed Mentoring Connections"
  Then I change engagement type of program "primary":"albers" to "career based"
  When I follow "Outcome Reports" within "nav#sidebarLeft"
  And I follow "Program Outcomes Report"
  Then I should see "Membership"
  Then I should not see "Matching"
  Then I should not see "Users Connected"
  Then I should not see "Mentoring Connections Completed"
  Then I should not see "Positive Results Reported in Completed Mentoring Connections"
  And I logout

@javascript @not_run_on_tddium
Scenario: The Session related sections should not be present if the ongoing mentoring and one time mentoring are enabled.
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Then I change engagement type of program "primary":"albers" to "career based"
  When I follow "Outcome Reports" within "nav#sidebarLeft"
  And I follow "Program Outcomes Report"
  Then I should see "Membership"
  Then I should not see "Matching"
  Then I should not see "Users Connected"
  Then I should not see "Mentoring Connections Completed"
  Then I should not see "Positive Results Reported in Completed Mentoring Connections"
  And I should see "Engagement"
  And I should see "Users with Completed Meetings"
  And I should see "Meetings Completed"
  And I should see "Meetings Reporting Positive Results"
  Then I change engagement type of program "primary":"albers" to "career based and ongoing"
  When I follow "Outcome Reports" within "nav#sidebarLeft"
  And I follow "Program Outcomes Report"
  Then I should see "Membership"
  Then I should see "Matching"
  Then I should see "Users Connected"
  Then I should see "Mentoring Connections Completed"
  Then I should see "Positive Results Reported in Completed Mentoring Connections"
  And I logout