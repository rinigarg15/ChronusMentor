@javascript @cross-browser
Feature: Mentee request new mentor without any mentor preference and admin assigns a mentor

Background: Program is moderated program
  Given the current program is "primary":"modprog"
  Then I maximize the window

Scenario: Admin logs in and changes the settings such that the user won't be asked to give preferred mentors for requesting a mentor
  When I have logged in as "moderated_admin@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I follow "Advanced Options"
  And I should see "Allow students to give mentor preferences in requests for mentoring"
  And I should see the radio button "program_allow_preference_mentor_request_true" selected
  Then I choose "program_allow_preference_mentor_request_false"
  Then I press "Save"
  And I follow "Advanced Options"
  And I should see the radio button "program_allow_preference_mentor_request_false" selected
  Then I logout
  #Mentee visits the mentors listing and adds preferred mentor
  When I have logged in as "moderated_student@example.com"
  And I follow "Mentors"
  And I should not see "Add to preferred mentors"
  And I follow "Request Mentoring Connection"
  And I should see "Request Mentoring Connection"
  And I should not see "Preferred Mentors"
  And I should not see "Add your mentor preferences along with optional comments describing the preferences."
  And I fill in "mentor_request_message" with "Need more exposure to the international markets."
  And I press "Send request"
  And I should see the flash "Your request has been sent to administrator and you will be notified once a mentor is assigned"
  Then I logout
  #Admin logs in and accepts the request
  When I have logged in as "moderated_admin@example.com"
  And I follow "Manage"
  And I follow "Mentoring Requests"
  And I should not see "Preferred Mentors"
  And I should see "Need more exposure to the international markets."
  And I click "#cjs-reports-export-dropdown"
  And I should see "Export as CSV"
  And I should see "Export as PDF"
  And I follow "Export as PDF"
  And I should see "Requests for mentoring are being exported to PDF. You will receive an email soon with the PDF report"
  And I click "#cjs-reports-export-dropdown"
  And I follow "Export as CSV"
  And I should see "Requests for mentoring are being exported to CSV. You will receive an email soon with the CSV report"
  Then I assign the mentee to a mentor
  Then I logout