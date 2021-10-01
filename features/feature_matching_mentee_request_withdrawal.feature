Feature: Matching negative scenarios for mentee request mentor

Background: Admin enables one-one mentoring

  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Mentoring Connection Settings"
  And I choose "One-on-one"
  And I press "Save"
  And I follow "Matching Settings"
  And I check "Mentors offer mentoring to students" in ongoing mentoring settings
  And I press "Save"
  Then the disabled "program_mentor_request_style_0" checkbox_id should be checked
  Then the "cjs_offer_mentor_check" checkbox_id should be checked
  And I logout

@javascript @matching_scenario @cross_browser
Scenario: Mentee request mentor with mentee withdrawal enabled and maximum pending requests allowable from a mentee

  #admin sets the maximum pending requests allowable from a mentee to 1
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  Then I should see "Mentoring Request Settings"
  And I select "1" from "program_max_pending_requests_for_mentee"
  And I follow "Advanced Options"
  And I choose "program_allow_mentee_withdraw_mentor_request_true"
  And I press "Save"
  And I logout

  #login as mentee and send request to mentor
  Then I have logged in as "mentrostud@example.com"
  And I follow "Mentors"
  Then I should see "mentor_a chronus"
  Then I follow "Connect" text for user with email "mentor_0@example.com" in program "primary":"albers"
  Then I follow "Request Mentoring Connection" text for user with email "mentor_0@example.com" in program "primary":"albers"
  And I fill in "mentor_request_message" with "Request mentoring connection"
  And I press "Send request"
  And I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_a chronus. You will be notified once the mentor accepts your request."
  And I follow "Mentors"
  Then I should see "mentor_f chronus"
  Then I follow "Connect" text for user with email "mentor_5@example.com" in program "primary":"albers"
  Then I follow "Request Mentoring Connection" text for user with email "mentor_5@example.com" in program "primary":"albers"
  Then I should see "You cannot send any more mentoring connection requests as you have reached the limit for the number of concurrent pending requests. Click here to view your pending requests."
  And I follow "Click here"
  And I choose "Requests initiated"
  Then I should see "Sent Mentoring Requests"
  Then I should see "mentor_a chronus"

  #withdraw request and resend
  And I "Withdraw Request" the request for "mentor_a chronus"
  Then I should see "Withdraw Request"
  And I fill in "mentor_request[response_text]" with "withdrawal message. Sorry about that"
  And I press "Submit"
  And I follow "Mentors"
  Then I follow "Connect" text for user with email "mentor_5@example.com" in program "primary":"albers"
  Then I follow "Request Mentoring Connection" text for user with email "mentor_5@example.com" in program "primary":"albers"
  Then I should not see "You cannot send any more mentoring connection requests as you have reached the limit for the number of concurrent pending requests. Click here to view your pending requests."

@javascript @matching_scenario
Scenario: Auto withdrawal of other mentoring requests when mentee reaches the maximum concurrent mentors limit

  #admin sets the maximum concurrent mentors for mentee
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I check "One-time Mentoring"
  Then I should see "Mentoring Connection Limits"
  And I select "1" from "program_max_connections_for_mentee"
  And I follow "Advanced Options"
  And I choose "program_allow_mentee_withdraw_mentor_request_true"
  And I press "Save"
  And I logout

  #login as mentee and send request to three mentors
  Then I have logged in as "mentrostud@example.com"
  And I follow "Mentors"
  Then I should see "mentor_a chronus"
  Then I follow "Connect" text for user with email "mentor_0@example.com" in program "primary":"albers"
  Then I follow "Request Mentoring Connection" text for user with email "mentor_0@example.com" in program "primary":"albers"
  And I fill in "mentor_request_message" with "Request mentoring connection"
  And I press "Send request"
  And I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_a chronus. You will be notified once the mentor accepts your request."
  And I follow "Mentors"
  Then I should see "mentor_e chronus"
  Then I follow "Connect" text for user with email "mentor_4@example.com" in program "primary":"albers"
  Then I follow "Request Mentoring Connection" text for user with email "mentor_4@example.com" in program "primary":"albers"
  And I fill in "mentor_request_message" with "Request mentoring connection"
  And I press "Send request"
  And I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_e chronus. You will be notified once the mentor accepts your request."
  And I follow "Mentors"
  Then I should see "mentor_d chronus"
  Then I follow "Connect" text for user with email "mentor_3@example.com" in program "primary":"albers"
  Then I follow "Request Mentoring Connection" text for user with email "mentor_3@example.com" in program "primary":"albers"
  And I fill in "mentor_request_message" with "Request mentoring connection"
  And I press "Send request"
  And I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_d chronus. You will be notified once the mentor accepts your request."
  Then I open Actions from profile
  And I follow "View your pending request"
  Then I should see "mentor_a chronus"
  Then I should see "mentor_e chronus"
  Then I should see "mentor_d chronus"
  And I logout

  #login as mentor and accept the request
  And I open new mail
  Then I should see "You received a new mentoring request from Mentor Studenter" in the email subject
  Then I should see "has requested that you be their mentor" in the email body
  And I have logged in as "mentor_0@example.com"
  And I follow "View Request" in the email
  Then I should see "Received Mentoring Requests"
  And I "Accept request" the request from "Mentor Studenter"
  Then I should see "chronus & Studenter"
  Then I should see "Members"
  Then I should see "Messages"
  And I logout

  #verify withdrawal of other requests
  Then I have logged in as "mentrostud@example.com"
  And I click ".pending_requests_notification_icon"
  And I follow "Mentoring Requests"
  And I choose "Requests initiated"
  Then I should see "Sent Mentoring Requests"
  And I choose "Withdrawn"
  Then I should see "mentor_e chronus"
  Then I should see "mentor_d chronus"
  And I click ".pending_requests_notification_icon"
  And I follow "Meeting Requests"
  And I choose "Requests initiated"
  And I choose "Withdrawn"
  And I choose "Requests received"
  Then I should see "Received Meeting Requests"