@javascript
Feature: Mentor Requests page filters

Background:
  Given the current program is "primary":"albers"
  Given withdraw mentor request feature enabled for "albers"

Scenario: Mentor logs in
  When I have logged in as "robert@example.com"
  And I click ".pending_requests_notification_icon"
  And  I follow "Mentoring Requests"
  Then I should see "Pending"
  And I should see "Accepted"
  And I should see "Declined"
  And I should see "Closed"
  And I should not see "Withdrawn"
  And I should not see "Sender"
  And I should not see "Receiver"
  And I should not see "Sent Between"

Scenario: Mentee logs in
  When I have logged in as "rahim@example.com"
  And I click ".pending_requests_notification_icon"
  And  I follow "Mentoring Requests"
  Then I should see "Pending"
  And I should see "Accepted"
  And I should see "Declined"
  And I should see "Withdrawn"
  And I should see "Closed"
  And I should not see "Sender"
  And I should not see "Receiver"
  And I should not see "Sent Between"

@javascript @cross-browser
Scenario: Admin logs in
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Mentoring Requests"
  And I should not see "Export as CSV"
  And I should not see "Export as PDF"
  Then I should see "Pending"
  And I should see "Accepted"
  And I should see "Rejected"
  And I should see "Withdrawn"
  And I should see "Closed"
  Then I follow "filter_report"
  And I should see "Sender"
  And I should see "Recipient"
  Then I close modal
  Then I follow "Close"
  And I follow "report_date_range"
  And I should see "Sent Between"

@javascript @cross-browser
Scenario: Mentor student logs in
  When I have logged in as "mentrostud@example.com"
  And I click ".pending_requests_notification_icon"
  And  I follow "Mentoring Requests"
  Then I choose "filter_by_me"
  Then I should see "Requests initiated"
  Then I should see "Pending"
  And I should see "Accepted"
  And I should see "Declined"
  And I should see "Closed"
  And I should see "Withdrawn"
  Then I choose "filter_me"
  Then I should see "Pending"
  And I should see "Accepted"
  And I should see "Declined"
  And I should not see "Withdrawn"
  And I should see "Closed"
  And I should not see "Sender"
  And I should not see "Receiver"
  And I should not see "Sent Between"

@javascript @cross-browser
Scenario: Admin logs in and searches for records
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Mentoring Requests"
  Then I should see "student_k example"
  Then I select "Sort by oldest" from "sort_by"
  Then I should not see "student_k example"
  Then I follow "filter_report"
  And I filter mentor requests on sender
  Then I should see "There are no mentoring requests that match the chosen criteria"
  Then I follow "filter_report"
  And I filter mentor requests on receiver
  Then I should not see "Sort by oldest"
  Then I should not see "Sort by most recent"
  Then I follow "filter_report"
  Then I follow "Reset"
  Then I should not see "student_k example"
  Then I should see "Sort by oldest"
  Then I select "Sort by most recent" from "sort_by"
  Then I should see "student_k example"
  And I logout