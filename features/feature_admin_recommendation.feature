Feature: Admin Mentor Recommendation
  In order to view and act on admin mentor recommendations in self matching mode.
  As a student
  I want the following scenario satisfied after receiving the mentor recommendation

  Background: Set the program to albers
    Given the current program is "primary":"albers"

  @javascript
  Scenario: Student gets system recommendation
    Given "userrahim@example.com" user have no pending mentor requests in program "primary":"albers"
    Given "userrahim@example.com" user have no admin mentor recommendations in program "primary":"albers"
    Given "userrahim@example.com" user is not part of any active connection in program "primary":"albers"
    When I have logged in as "userrahim@example.com"
    Then I should see "Featured Mentor Recommendations" within ".cjs_quick_connect_items"
    And I should see "CONNECT" within ".cjs_quick_connect_items"
    #When I click ".custom-slick-next"
    Then I should see "mentor_a chronus" within ".cjs_quick_connect_items"
    Then I should see "Community"
    Then I should see "You may also"
    Then I should see "Search using filters"
    Then I should see "View more Mentors →"
    Then I follow "Search using filters"
    Then I should see "Mentors"
    Then I follow "Home"
    #When I click ".custom-slick-prev"
    And I follow "Connect" link for user with email "mentor_0@example.com" in program "primary":"albers"

    Then I should see "Request mentor_a chronus to be my mentor" within ".modal"
    And I fill in "mentor_request_message" with "Testing" within ".modal"
    And I press "Send request"
    Then I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_a chronus. You will be notified once the mentor accepts your request."

  @javascript @cross_browser
  Scenario: Student gets admin recommendation
    Given "userrahim@example.com" user have no pending mentor requests in program "primary":"albers"
    Given "userrahim@example.com" user is not part of any active connection in program "primary":"albers"
    And The "userrahim@example.com" user has no ignored preferences in program "primary":"albers"
    Given program "primary":"albers" has mentor recommendations feature enabled
    And The "userrahim@example.com" user has a published mentor recommendation in program "primary":"albers"
    When I have logged in as "userrahim@example.com"
    Then I should see "Recommendations from administrator"
    And I should see "CONNECT" within ".admin_recommendations"
    And I follow "CONNECT" within ".admin_recommendations"

    Then I should see "Request Kal Raman (Administrator) to be my mentor" within ".modal"
    And I fill in "mentor_request_message" with "Testing" within ".modal"
    And I press "Send request"
    Then I should see the flash "Your request for a mentoring connection has been successfully sent to Kal Raman (Administrator). You will be notified once the mentor accepts your request."
    Then I follow "Mentors"
    Then I should see "userram@example.com" user of "primary":"albers" program as recommended