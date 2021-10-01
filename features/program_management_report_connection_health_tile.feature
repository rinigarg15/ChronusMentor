Feature: New dashboard for program administrators

Background: Admin logs in
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I enable "mentoring_connections_v2" feature as a super user
  And I stub chronus s3 utils

@javascript @cross-browser
Scenario: Admin sees connections tile
  Then I should see "How healthy are your mentoring connections in the selected time period?"
  And I verify the presence of charts
  Then I should see "Mentoring Connections health"
  Then I should see "Survey responses (0)"
  Then I should see "No survey responses in the selected time period"
  Then I should see "0 Mentoring Connections with positive survey responses"
  Then I should see "0 Mentoring Connections with neutral or negative survey responses"
  Then I should see "0 Mentoring Connections without survey responses"
  Then I follow "View Survey Responses »"
  Then I should see "Mentoring Connections Surveys"
  Then I should see "Program Surveys"

@javascript @cross-browser
Scenario: Admin sees connections tile survey responses
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  And I follow "ADD CONTENT"
  When I click ".add-action-opener"
  And I follow "Add a Survey"
  And I fill in "mentoring_model_task_template_title" with "SURVEY TASK TITLE"
  And I assign the task to "Mentor"
  And I choose the survey "Partnership Effectiveness"
  And I press "Save Task"
  And I follow "Manage"
  Then I follow "Mentoring Connections"
  And I follow "Create New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"
  And I click "#create_and_publish"
  And I follow "Good unique name"
  And I follow "Ongoing mentoring connections"
  And I follow "Work on Behalf"

  And I hover on tab "My Mentoring Connections"
  And I follow "name & example"
  And I follow "Partnership Effectiveness"
  Then I submit the answers "'Good', 'trial 1', 'trial 2'" of "Partnership Effectiveness"
  And I follow "Switch back to Freakin Admin"
  Then I should see "How healthy are your mentoring connections in the selected time period?"
  Then I should see "Mentoring Connections health"
  Then I should see "Survey responses (1)"
  Then I should not see "No survey responses in the selected time period"
  Then I should see "0 Mentoring Connections with positive survey responses"
  Then I should see "0 Mentoring Connections with neutral or negative survey responses"
  Then I should see "0 Mentoring Connections without survey responses"
  And I click ".cjs_management_report_date_range_preset" within "#engagements_info"
  And I select "Custom" from reports date range presets
  And I select "3" days after program creation as "#engagements_info .cjs_management_report_time_filter_form .cjs_daterange_picker_start"
  And I select "500" days after program creation as "#engagements_info .cjs_management_report_time_filter_form .cjs_daterange_picker_end"
  And I press "Go"
  And I should see "Custom" within ".cjs_management_report_date_range_preset"
  And I verify the presence of charts
  Then I should see "Survey responses (1)"
  Then I should not see "No survey responses in the selected time period"
  Then I should see "0 Mentoring Connections with positive survey responses"
  Then I should see "0 Mentoring Connections with neutral or negative survey responses"
  Then I should see "0 Mentoring Connections without survey responses"
  And I follow "Partnership Effectiveness"
  And I see survey details "Partnership Effectiveness" today
  And I should see "Partnership Effectiveness"
  And I should see "How effective is your partnership in helping to reach your goals"
  And I should see "Good"
  And I should see "What is going well in your mentoring partnership?"
  And I should see "trial 1"
  And I should see "What could be better in your mentoring partnership?"
  And I should see "trial 2"
  Then I close modal

  And I click ".cjs-dashboard-settings" within "#engagements_info_container"
  When I click ".select2-chosen"
  And I select "How effective is your partnership in helping to reach your goals" as positive outcomes question
  And I select "Good" as positive outcomes choice for question "How effective is your partnership in helping to reach your goals"
  Then I close the select2 dropdown
  And I press "Save"
  And I verify the presence of charts
  Then I should see "Survey responses (1)"
  Then I should not see "No survey responses in the selected time period"
  Then I should see "1 Mentoring Connections with positive survey responses"
  Then I should see "0 Mentoring Connections with neutral or negative survey responses"
  Then I should see "0 Mentoring Connections without survey responses"
  Then I follow "Mentoring Connections with neutral or negative survey responses"
  Then I should see "0 mentoring connections (0 ongoing, 0 closed) with neutral or negative survey responses in the selected time"

@javascript @cross-browser
Scenario: Admin manipulates connections tile settings
  And I click ".cjs-dashboard-settings" within "#engagements_info_container"
  Then I should see "Health of mentoring connections"
  Then I should see "Select reports to show"
  Then I should see "Mentoring Connections health based on survey responses"
  Then I should see "Individual survey responses for the selected time period"
  Then I uncheck "dashboard_reports_0"
  Then I should see "Configure health based on survey responses"
  Then I should see "Consider the mentoring connections healthy if the survey responses are any of"
  And I press "Save"
  Then I should see "How healthy are your mentoring connections in the selected time period?"
  Then I should not see "Mentoring Connections health"
  Then I should see "Survey responses (0)"
  Then I should see "No survey responses in the selected time period"
  Then I should not see "0 Mentoring Connections with positive survey responses"
  Then I should not see "0 Mentoring Connections with neutral or negative survey responses"
  Then I should not see "7 Mentoring Connections without survey responses"
  And I click ".cjs-dashboard-settings" within "#engagements_info_container"
  Then I uncheck "dashboard_reports_1"
  And I press "Save"
  Then I should see "How healthy are your mentoring connections in the selected time period?"
  Then I should not see "Survey responses (0)"
  Then I should not see "Mentoring Connections health"