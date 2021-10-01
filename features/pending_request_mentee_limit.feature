@pending_mentoring_requests_limit_reached
@javascript
Feature: Mentees should be able to send mentoring requests to the mentors and interact with them through scraps.
  In order to send mentor request
  As a Mentee
  I have no pending requests, I want to be able to send mentoring request when the pending requests limit is nil and not be able to send request when limit is 1 once I sent the first request

  # Mentee sends a mentoring request.
  Background:
    Given the current program is "primary":"albers"
    And there are no mentor requests

  Scenario: Mentee having a group sending a request
    When I have logged in as "mkr@example.com"

    When I visit the profile of "mentrostud@example.com"
    And I follow "Actions"
    And I follow "Request Mentoring Connection"
    Then I should see "Request Mentor Studenter to be my mentor"
    Then I fill in "mentor_request_message" with "I kindly request you to be my mentor."
    And I press "Send request"
    And I should see the flash "Your request for a mentoring connection has been successfully sent to Mentor Studenter. You will be notified once the mentor accepts your request."
    And I logout
    When I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Matching Settings"
    Then I select "No limit" from "program_max_pending_requests_for_mentee"
    And I press "Save"
    Then I should see "Your changes have been saved"
    And "ram@example.com" is not a mentor in "primary":"albers"
    When I navigate to "ram@example.com" profile in "albers"
    And I follow "Change Roles"

    And I check "Mentor"
    And I press "Submit"
    And I logout
    When I have logged in as "mkr@example.com"

    When I visit the profile of "ram@example.com"
    And I follow "Actions"
    And I follow "Request Mentoring Connection"
    Then I fill in "mentor_request_message" with "I kindly request you to be my mentor."
    And I press "Send request"
    And I should see the flash "Your request for a mentoring connection has been successfully sent to Freakin Admin (Administrator). You will be notified once the mentor accepts your request."
    And I logout

  Scenario: Admin setting pending requests limit to 1 and mentee not able to send more than one request
    When I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Matching Settings"
    Then I select "1 request" from "program_max_pending_requests_for_mentee"
    And I follow "Advanced Options"
    And I choose "program_allow_mentee_withdraw_mentor_request_true"
    And I press "Save"
    Then I should see "Your changes have been saved"
    And "ram@example.com" is not a mentor in "primary":"albers"
    When I navigate to "ram@example.com" profile in "albers"
    And I follow "Change Roles"

    And I check "Mentor"
    And I press "Submit"
    And I logout
    When I have logged in as "mkr@example.com"

    When I visit the profile of "mentrostud@example.com"
    And I follow "Actions"
    And I follow "Request Mentoring Connection"
    Then I should see "Request Mentor Studenter to be my mentor"
    Then I fill in "mentor_request_message" with "I kindly request you to be my mentor."
    And I press "Send request"
    And I should see the flash "Your request for a mentoring connection has been successfully sent to Mentor Studenter. You will be notified once the mentor accepts your request."
    And I should not see "See more mentors"
    When I visit the profile of "ram@example.com"
    And I follow "Actions"
    And I follow "Request Mentoring Connection"
    Then I should not see "Request Ongoing Mentoring from Mentor Studenter"
    Then I should see "You cannot send any more mentoring connection requests as you have reached the limit for the number of concurrent pending requests. Click here to view your pending requests."
    Then I follow "Click here"
    Then I should see "Mentoring Requests"
    And I logout

Scenario: Admin check one time mentoring disable and sees warning popup
    When I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Matching Settings"
    And I check "program_enabled_features_"
    And I uncheck "program_enabled_features_"
    And I check "program_enabled_features_"
    Then I press "Save"
    And I uncheck "program_enabled_features_"
    Then I should see "All the past and scheduled meetings will be deleted permanently"
    Then I should see "All the mentors will be moved to 'Ongoing Mentoring'"
    Then I press "No"
    And I logout
