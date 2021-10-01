# encoding: utf-8
@mentoring_connections_limit_reached
Feature: Mentees should be able to send mentoring requests to the mentors and interact with them through scraps.
  In order to send mentor request
  As a Mentee
  I want to be able to send mentor request when the limit is nill and not be able to send request when limit is 1

  # Mentee sends a mentoring request.
  Background:
    Given the current program is "primary":"albers"
    And there are no mentor requests
  @javascript @cross-browser
  Scenario: Mentee having a group sending a request
    When I have logged in as "mkr@example.com"
    And I visit the profile of "mentrostud@example.com"
    And I open Actions from profile
    And I follow "Request Mentoring Connection"
    Then I should see "Request Mentor Studenter to be my mentor"
    Then I fill in "mentor_request_message" with "I kindly request you to be my mentor."
    And I press "Send request"
    And I should see the flash "Your request for a mentoring connection has been successfully sent to Mentor Studenter. You will be notified once the mentor accepts your request."
    Then I follow "Home"
    And I click ".pending_requests_notification_icon"
    Then I should not see "Mentoring Requests 1" within "#pending_requests_dropdown"
    And I logout

  @javascript
  Scenario: Admin setting limit to 1 and mentee having a group not able to send request
    When I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Matching Settings"
    Then I select "1 mentor" from "program_max_connections_for_mentee"
    And I press "Save"
    Then I should see "Your changes have been saved"
    And I logout
    When I have logged in as "mkr@example.com"
    And I visit the profile of "mentrostud@example.com"
    And I open Actions from profile
    And I follow "Request Mentoring Connection"
    Then I should see "Mentor Studenter"
    Then I should not see "Request Ongoing Mentoring from Mentor Studenter"
    Then I should see the flash "You cannot send any more mentoring connection requests as you have reached the limit for the number of concurrent mentoring connections."