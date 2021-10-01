# encoding: utf-8
@mentoring_interaction
Feature: Mentees should be able to send mentoring requests to the mentors and interact with them through scraps.
  In order to establish a mentoring connection
  As a Mentor
  I want to be able to accept mentoring requests and interact with students or reject them if I wish to do so.

  # Mentee sends a mentoring request.
  Background:
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    When I hover over "my_programs_container"
    And I select "Primary Organization" from the program selector
    Then I enable "mentoring_connections_v2" feature as a super user
    And I logout
    Given the current program is "primary":"albers"
    And there are no mentor requests
    When I have logged in as "rahim@example.com"
    When I visit the profile of "mentrostud@example.com"
    And I follow "Actions" within "#mentor_profile"
    And I follow "Request Mentoring Connection"
    Then I fill in "mentor_request_message" with "I kindly request you to be my mentor."
    And I press "Send request"
    And I should see the flash "Your request for a mentoring connection has been successfully sent to Mentor Studenter. You will be notified once the mentor accepts your request."
    And I logout
    Given the current program is "primary":"albers"
    And I have logged in as "mentrostud@example.com"
    And I click ".pending_requests_notification_icon"
    And I follow "Mentoring Requests"
    Then I choose "filter_me"

@javascript
  Scenario: Mentor accepts mentoring request
    And I follow "Actions" within "#results_pane"
    When I follow "Accept"
    Then I should see "Mentoring Connection"

@javascript
  Scenario: Mentor rejects mentoring request
    Given I follow "Decline" for the group "results_pane"
    Then I fill the last mentor request request text with "Sorry. Too busy."
    Then I choose the value "1" for "mentor_request[rejection_type]"
    And I press "Submit"
    And I should see "Thank you for your response. student example has been notified"

@javascript @cross-browser
  Scenario: Mentor and mentee interact through scraps
    Given I follow "Accept" for the group "results_pane"
    Then I should see "Mentoring Connection"
    Then I close modal
    # Post a scrap
    Then I follow "Messages" within "#mentoring_area_tabs"
    Then I follow "New Message"
    Then I wait for animation to complete
    Then I should see "Attach a file"
    Then I fill in "scrap[subject]" with "Water-fall model"
    And I fill in "scrap[content]" with "Please prepare a write-up on Water-fall model"
    And I press "Send Message"
    Then I wait for ajax to complete
    Then a mail should go to "rahim@example.com" having "Water-fall model"
    Then I click ".cjs-scrap-header"
    And I should see "Please prepare a write-up on Water-fall model"
    And I should not see "requesting a reply"
    And I logout

    # Mentee logs in to see the scrap
    Given the current program is "primary":"albers"
    Then I have logged in as "rahim@example.com"
    And I follow "Studenter & example"
    Then I follow "Messages" within "div#mentoring_area_tabs"
    And I should see "Water-fall model"
    Then I click ".cjs-scrap-header"
    Then I click ".scrap-actions"
    Then I click ".cjs_reply_link"
    And I reply "Sure. Will do" to the scrap with subject "Water-fall model"
    And I press "Reply"
    And a mail should go to "mentrostud@example.com" having "Sure. Will do"

@javascript
  Scenario: Mentor should not see any mentoring tips as mentoring tips are disabled by default
    And I follow "Actions" within "#results_pane"
    When I follow "Accept"
    Then I should see "Mentoring Connection"
    And I should not see "Refresh Your Mentoring Skills"
