@javascript
Feature: Detailed outcomes report feature

Background: Admin logs in
  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I enable "program_outcomes_report" feature as a super user
  And I logout


@cross_browser
Scenario: Admin views the Detailed User Outcomes Report
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  Then I follow "Outcome Reports" within "nav#sidebarLeft"
  And I follow "Program Outcomes Report"
  And I follow "report_date_range"
  And I select "Custom" from reports date range presets
  And I click on start date selector
  Then I click by xpath "//tr[1]/descendant::td[@role='gridcell' and not(a)][1]"
  Then I should see "Custom"
  Then I click by xpath "//div[@class='k-animation-container']"
  Then I should see "Custom"
  And I follow "Membership"
  Then I should see "Membership Outcomes Report"
  # Testing back-link

  When I follow the back link
  Then I should see "Outcomes Report" within "#title_box"
  And I follow "Membership"

  And I wait for ajax to complete
  And I should see "Users Total"
  And I should see "Mentors"
  And I should see "Students"
  And I should see "First Name"
  #FIXME should be "Last Name"
  And I should see "last Name"
  And I should see "Role"
  And I should see "Registered on"
  And I should see "Email"
  And I should see "Membership Trends"
  And I should see "new"
  And I should see "deactivated"
  Then I hover over "info-circle" icon
  And I should see "This is the number of users in active state at some point in your program during the selected time period."
  # Testing date range filters
  And I should see "Program start to date"
  And I should see "Custom"
  Then I choose "Program start to date" from date selector in ".cui-outcomes-report-daterange"
  And I press "Go"
  Then I choose "Custom" from date selector in ".cui-outcomes-report-daterange"
  And I select "3" days after program creation as "#date_range_content .cjs_daterange_picker_start"
  And I select "5" days after program creation as "#date_range_content .cjs_daterange_picker_end"
  And I press "Go"

  #testing profile filter
  Then I should see "Gender"
  Then I should see "Location"
  Then I should see "Education"
  Then I should see "Work"
  Then I should see "Industry"
  Then I click on "Gender" header
  Then I should see "Male"
  Then I should see "Female"
  Then I check "Male"
  And I logout

@cross_browser
Scenario: Admin views the Detailed Connections Outcomes Report Users tab
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  Then I follow "Outcome Reports" within "nav#sidebarLeft"
  And I follow "Program Outcomes Report"
  
  Then I should see "Users Connected"
  Then I should see "Mentoring Connections"
  And I follow "Matching"
  And I wait for ajax to complete
  And I should see "Mentoring Connection Summary"
  And I should see "#cui-group-table-header" hidden
  And I should see "First Name"
  And I should see "last Name"
  And I should see "Role"
  And I should see "Email"
  And I should see "Registered on"
  And I should see the tab "Users" selected in "tab-box"

  # Admin changes tab
  Then I click "#cui-groups-tab-link"
  And I should see "#cui-user-table-header" hidden
  And I should see "Mentoring Connection Name"
  And I should see "Mentors"
  And I should see "Students"
  And I should see "Status"
  And I should see "Template"
  And I should see "Started On"

  # Testing date range filters
  And I should see "Program start to date"
  And I should see "Custom"
  Then I choose "Program start to date" from date selector in ".cui-outcomes-report-daterange"
  And I press "Go"
  Then I choose "Custom" from date selector in ".cui-outcomes-report-daterange"
  And I select "2" days after program creation as "#date_range_content .cjs_daterange_picker_start"
  And I select "5" days after program creation as "#date_range_content .cjs_daterange_picker_end"
  And I press "Go"

  #testing profile filter
  Then I should see "Gender"
  Then I should see "Location"
  Then I should see "Education"

@cross_browser
Scenario: Admin views the Detailed Connections Outcomes Report Connections tab
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  Then I follow "Outcome Reports" within "nav#sidebarLeft"
  And I follow "Program Outcomes Report"
  
  Then I should see "Users Connected"
  Then I should see "Mentoring Connections"
  And I follow "Matching"
  And I follow "Mentoring Connections"
  And I wait for ajax to complete
  And I should see "Mentoring Connections (in selected time range)"
  And I should see "First Name" hidden
  And I should see "last Name" hidden
  And I should see the tab "Connections" selected in "tab-box"
  And I should see "Mentoring Connection Name"
  And I should see "Mentors"
  And I should see "Students"
  And I should see "Status"
  And I should see "Template"
  And I should see "Started On"

@cross_browser
Scenario: Admin views the Detailed Connection Outcomes Report through Section 2 title
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  Then I follow "Outcome Reports" within "nav#sidebarLeft"
  And I follow "Program Outcomes Report"
  And I follow "Matching"
  Then I should see "Mentoring Connection Summary Report"
  # Testing back-link

  When I follow the back link
  Then I should see "Outcomes Report" within "#title_box"