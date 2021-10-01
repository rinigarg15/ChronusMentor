Feature: Admin Mentor Recommendation
  In order to view and act on admin mentor recommendations in preferred matching mode.
  As a student
  I want the following scenario satisfied after receiving the mentor recommendation

  Background:
    Given the current program is "annauniv":"psg"

  @javascript
  Scenario: Student gets system recommendation preferred matching
    Given "stud1@psg.com" user have no pending mentor requests in program "annauniv":"psg"
    Given "stud1@psg.com" user have no admin mentor recommendations in program "annauniv":"psg"
    Given "stud1@psg.com" user is not part of any active connection in program "annauniv":"psg"
    And I have logged in as "stud1@psg.com"
    And I follow "Home"

    Then I should see "Featured Mentor Recommendations" within ".cjs_quick_connect_items"
    And I should see "Request Mentoring Connection"
    And I follow "Request Mentoring Connection"
    Then I should see "Request Mentoring Connection "
    Then I should see "mental mentor" within ".mentor_preference"

  @javascript @cross-browser
  Scenario: Student gets admin recommendation
    Given "stud1@psg.com" user is not part of any active connection in program "annauniv":"psg"
    Given "stud1@psg.com" user does not have any mentors in program "annauniv":"psg"
    Given "stud1@psg.com" user does not have any meetings in program "annauniv":"psg"
    Given program "annauniv":"psg" has mentor recommendations feature enabled
    Given Admin assigns a published mentor recommendation of "mentor1@psg.com" and "mentor2@psg.com" mentors to "stud1@psg.com" user in program "annauniv":"psg"
    Given minimum preferred mentors count is "1" in program "annauniv":"psg"
    And I have logged in as "stud1@psg.com"
    And I follow "Mentors"
    And I add "mentor3@psg.com" to preferred mentors list
    And I follow "Home"
    Then I should see "Recommendations from administrator"
    Then I should not see ".cjs_quick_connect_items"
    And I should not see "CONNECT" within ".admin_recommendations"
    And I should see "Request Mentoring Connection"
    And I follow "Request Mentoring Connection" within ".admin_recommendations"

    And I should see "mentor1@psg.com" of "annauniv":"psg" program as preference
    And I should see "mentor2@psg.com" of "annauniv":"psg" program as preference
    And the mentor preference order must be correct
    And I click ".cjs_name_text_box input"
    And I should see "Recommended Mentors"
    And I should see "PSG mentorc"
    Then I select user with email "mentor3@psg.com" from dropdown in "annauniv":"psg" program

    And I should see "mentor3@psg.com" of "annauniv":"psg" program as preference
    And the mentor preference order must be correct
    And I remove "mentor1@psg.com" of "annauniv":"psg" program as preference
    And I should not see "mentor1@psg.com" of "annauniv":"psg" program as preference
    And I remove "mentor2@psg.com" of "annauniv":"psg" program as preference
    And I should not see "mentor2@psg.com" of "annauniv":"psg" program as preference
    And I remove "mentor3@psg.com" of "annauniv":"psg" program as preference
    And I should not see "mentor3@psg.com" of "annauniv":"psg" program as preference
    And I press "Send request"
    Then I should see "Please select at least 1 mentors"
    And I click ".cjs_name_text_box input"
    And I should see "Recommended Mentors"
    And I should see "PSG mentora"
    And I should see "PSG mentorb"
    And I should see "PSG mentorc"
    Then I select user with email "mentor1@psg.com" from dropdown in "annauniv":"psg" program
    And I should see "mentor1@psg.com" of "annauniv":"psg" program as preference
    And I press "Send request"
    And I should see "Please fill all the required fields. Fields marked * are mandatory"
    Then I fill in "mentor_request_message" with "labablab"
    And I press "Send request"
    Then I should see "Your request has been sent to administrator and you will be notified once a mentor is assigned"
    Then I follow "Mentors"
    Then I should see "mentor1@psg.com" user of "annauniv":"psg" program as recommended

  @javascript
  Scenario: Student gets admin recommendation
    Given "stud1@psg.com" user is not part of any active connection in program "annauniv":"psg"
    Given "stud1@psg.com" user does not have any mentors in program "annauniv":"psg"
    Given "stud1@psg.com" user does not have any meetings in program "annauniv":"psg"
    Given program "annauniv":"psg" has mentor recommendations feature enabled
    Given Admin assigns a published mentor recommendation of "mentor1@psg.com" and "mentor2@psg.com" mentors to "stud1@psg.com" user in program "annauniv":"psg"
    Given "stud1@psg.com" user of program "annauniv":"psg" has no permission to view mentors
    And I have logged in as "stud1@psg.com"
    And I follow "Home"
    Then I should see "Recommendations from administrator"
    Then I should not see ".cjs_quick_connect_items"
    And I follow "PSG mentora"
    Then I should see "PSG mentora"
    And I should see "Basic Information"
    And I should see "Work and Education"