Feature: Progam admin must be able to perform actions on meetings

Background:
  Given valid and appropriate date time settings
  Given the current program is "primary":"albers"
  Given there are no meeting requests
  And I stub chronus s3 utils
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"

@javascript @download
Scenario: Admin must be able to export the meeting requests as csv

  Given the current program is "primary":"albers"
  Then I enable the settings for mentor to connect without availability slots
  And I clear the downloads folder
  And I have logged in as "mentor_0@example.com"
  And I set the message for connecting without availability slots and set the maximum slots
  Then I logout
  And I have logged in as "student_1@example.com"
  And I follow "Mentors"
  And I follow "mentor_a chronus"
  Then I send a non-calendar meeting request to mentor with name "mentor_a chronus"
  And I logout
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Meeting Requests"
  #assuming default is pending
  Then I should see "Received"
  Then I should see "1"
  Then I should see "Pending"
  Then I should see "1"
  Then I should see "Accepted"
  Then I should see "0"
  Then I should see "Others"
  Then I should see "0"
  Then I should see "Sender"
  Then I should see "student_b example"
  Then I should see "Sent"
  #Then I should see "less than a minute ago"
  Then I should see "Recipient"
  Then I should see "mentor_a chronus"
  Then I should see "Topic"
  Then I should see "Calendar Meeting"
  Then I should see "Description"
  Then I should see "Kindly help needed in ruby"
  Then I follow "Accepted"
  Then I should see "There are no meeting requests matching the chosen criteria "
  Then I follow "Pending"
  And I click "#cjs_reports_export"
  Then I wait for download to complete
  Then the csv header must have the fields "Request ID,Sender,Sender Email,Recipient,Recipient Email,Topic,Description,Proposed Time,Location,Sent"
  Then the csv must have the following row
  | Sender          | student_b example          |
  | Sender Email    | student_1@example.com |
  | Recipient       | mentor_a chronus           |
  | Recipient Email | mentor_0@example.com |
  | Description     | Kindly help needed in ruby |

@javascript @download @not_run_on_jenkins
Scenario: Admin goes to Mentoring Calendar Report
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I login as super user
  And I go to feature listing page in primary:albers program
  And I check "mentoring_connection_meeting"
  And I press "Save"
  And I logout as super user
  And I clear the downloads folder
  Then I follow "Health Reports" within "nav#sidebarLeft"
  Then I should see "Mentoring Calendar Report"
  Then I follow "Mentoring Calendar Report"
  And I click "#cjs-reports-export-dropdown"
  And I should see "Export as CSV"
  And I should see "Export as PDF"
  And I follow "Export as PDF"
  Then I wait for download to complete
  Then the pdf file should have been downloaded with name "meetings_and_availability"
  
@javascript
Scenario: Admin must be able to close meeting requests

  Given the current program is "primary":"albers"
  Then I enable the settings for mentor to connect without availability slots
  And I have logged in as "mentor_0@example.com"
  And I set the message for connecting without availability slots and set the maximum slots
  Then I logout
  And I have logged in as "student_1@example.com"
  And I follow "Mentors"
  And I follow "mentor_a chronus"
  Then I send a non-calendar meeting request to mentor with name "mentor_a chronus"
  And I logout
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Meeting Requests"
  #assuming default is pending
  And I close the meeting request by notifying the sender and recipient
  Then I should see "The selected meeting request has been closed"
  Then a mail should go to "mentor_0@example.com" having "The meeting requested by student_b example has been closed by an administrator"
  Then "student_1@example.com" should receive an email with subject "Your meeting request with mentor_a chronus is closed"
  And I logout
  And I have logged in as "student_1@example.com"
  And I click ".pending_requests_notification_icon"
  And I follow "Meeting Requests"
  And I choose "Closed"
  Then I should see "mentor_a chronus"
  Then I should see "Closed By"


@javascript @cross_browser
Scenario: Admin must be able to bulk close meeting requests

  Given the current program is "primary":"albers"
  Then I enable the settings for mentor to connect without availability slots
  And I have logged in as "mentor_0@example.com"
  And I set the message for connecting without availability slots and set the maximum slots
  Then I logout
  And I have logged in as "mentor_2@example.com"
  And I set the message for connecting without availability slots and set the maximum slots
  Then I logout
  And I have logged in as "student_1@example.com"
  And I follow "Mentors"
  And I follow "mentor_a chronus"
  Then I send a non-calendar meeting request to mentor with name "mentor_a chronus"
  And I follow "Mentors"
  And I follow "mentor_c chronus"
  Then I send a non-calendar meeting request to mentor with name "mentor_c chronus"
  And I logout
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Meeting Requests"
  #assuming default is pending
  And I bulk close the meeting requests
  Then I should see "The selected 2 meeting requests have been closed"
  Then I should see "There are no meeting requests matching the chosen criteria"
  Then a mail should go to "mentor_2@example.com" having "The meeting requested by student_b example has been closed by an administrator"
  Then "student_1@example.com" should receive an email with subject "Your meeting request with mentor_a chronus is closed"
  And I logout
  And I have logged in as "student_1@example.com"
  And I click ".pending_requests_notification_icon"
  And I follow "Meeting Requests"
  And I choose "Closed"
  Then I should see "mentor_a chronus"
  Then I should see "Closed By"
  Then I should see "mentor_c chronus"
  And I logout
  And I have logged in as "mentor_0@example.com"
  And I click ".pending_requests_notification_icon"
  And I follow "Meeting Requests"
  And I choose "Closed"
  Then I should see "student_b example"
  Then I should see "Closed By"

@javascript
Scenario: Meeting Request Report with no requests
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I have logged in as "ram@example.com"
  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Meeting Requests"
  And I should see "Meeting Requests"
  Then I should see "There are no meeting requests matching the chosen criteria"