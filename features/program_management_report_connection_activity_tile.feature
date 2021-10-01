Feature: New dashboard for program administrators

Background: Admin logs in
  Given the current program is "primary":"albers"
  Then I maximize the window
  And I have logged in as "ram@example.com"
  Then I enable "mentoring_connections_v2" feature as a super user
  And I stub chronus s3 utils

@javascript @cross-browser
Scenario: Admin sees connections activity tile
  Then I should see "How active are your mentoring connections?"
  And I verify the presence of charts
  Then I should see "Mentoring Connections with activity(Last 30 days)"
  Then I should see "Mentoring Connection activity summary(Last 30 days)"
  Then I should see "3 Mentoring Connections with activity"
  Then I should see "4 Mentoring Connections without any activity"
  Then I should see "7 Mentoring Connections"
  Then I enable "mentoring_connections_v2" feature as a super user
  And I enable "mentoring_connection_meeting" feature as a super user
  Then I reload the page
  Then I should see "3 Mentoring Connections with activity"
  Then I should see "4 Mentoring Connections without any activity"
  #Then I should see "17 Total activities"
  Then I should not see "Posts 0"
  Then I should see "Messages exchanged 9"
  #Then I should see "Meetings scheduled 8"
  Then I should see "Tasks completed 0"
  Then I should see "Survey responses 0"
  Then I follow "View Activity Report »"
  Then I should see "Mentoring Connection Activity Report"
  Then I should see "Activity Trends"

@javascript @cross-browser
Scenario: Admin applies date filter inside connections activity tile
  Then I enable "mentoring_connections_v2" feature as a super user
  And I enable "mentoring_connection_meeting" feature as a super user
  Then I reload the page
  And I click ".cjs_management_report_date_range_preset" within "#connections_activity_info"
  And I select "Custom" from reports date range presets
  And I select "3" days after program creation as "#connections_activity_info .cjs_management_report_time_filter_form .cjs_daterange_picker_start"
  And I select "500" days after program creation as "#connections_activity_info .cjs_management_report_time_filter_form .cjs_daterange_picker_end"
  And I press "Go"
  And I should see "Custom" within ".cjs_management_report_date_range_preset" within "#connections_activity_info"
  And I verify the presence of charts
  Then I should see "Mentoring Connections with activity(selected time)"
  Then I should see "Mentoring Connection activity summary(selected time)"
  Then I should see "3 Mentoring Connections with activity"
  Then I should see "4 Mentoring Connections without any activity"
  Then I should see "7 Mentoring Connections"
  #Then I should see "17 Total activities"
  Then I should not see "Posts 0"
  Then I should see "Messages exchanged 9"
  #Then I should see "Meetings scheduled 8"
  Then I should see "Tasks completed 0"
  Then I should see "Survey responses 0"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  And I follow "CONFIGURE FEATURES"

  Then I uncheck "mentoring_model_check_box_allow_messaging"
  Then I check "mentoring_model_check_box_allow_forum"
  And I press "Save and proceed to Add Content »"
  Then I follow "Home"
  And I click ".cjs_management_report_date_range_preset" within "#connections_activity_info"
  And I select "Custom" from reports date range presets
  And I select "3" days after program creation as "#connections_activity_info .cjs_management_report_time_filter_form .cjs_daterange_picker_start"
  And I select "500" days after program creation as "#connections_activity_info .cjs_management_report_time_filter_form .cjs_daterange_picker_end"
  And I press "Go"
  And I should see "Custom" within ".cjs_management_report_date_range_preset" within "#connections_activity_info"
  Then I should see "Posts 0"
  Then I should not see "Messages exchanged"
  
@javascript @cross-browser
Scenario: Admin manipulates connections activity tile settings
  Then I enable "mentoring_connections_v2" feature as a super user
  And I enable "mentoring_connection_meeting" feature as a super user
  Then I reload the page
  And I click ".cjs-dashboard-settings" within "#connections_activity_info_container"
  Then I should see "Metrics to be displayed"
  Then I follow "Add new metric"
  Then I select a new metric "All Administrators"
  Then I follow "Add new metric"
  Then I select a new metric "Connections with no Activity"
  Then I follow "Add new metric"
  Then I select a new metric "Connections with no Recent Activity"
  Then I follow "Add new metric"
  Then I select a new metric "Connections with Overdue Tasks"
  Then I press "Save"
  Then I should see "6 Connections with no Activity"
  Then I should see "0 Connections with no Recent Activity"
  Then I should see "0 Connections with Overdue Tasks"
  Then I should see "2 All Administrators"
  Then I follow "Connections with no Activity"
  Then I should see "Connections with no Activity"
  Then I should see "Drafted (3)"
  Then I should see "Ongoing (6)"
  Then I should see "Closed (1)"