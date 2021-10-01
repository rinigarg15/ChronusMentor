@group_termination
Feature: Group Termination
  In order disable a group
  As an admin
  I want to be able to terminate a group

  @javascript @cross_browser
  Scenario: Admin terminates a group
    # First log in as admin
    Given the current program is "primary":"albers"
    Given I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Mentoring Connections"
    # admin terminates the group
    And I click on "terminate_link_1" for the group "group_1"
    And I fill in "group_termination_reason" with "<h1>Hello</h1> A reason"
    And I press "Close"
    Then individual mails should go to "mkr@example.com,robert@example.com" having "<h1>Hello</h1> A reason"
    Then I should see "has been closed"
    And I logout
    # Now log in as mentor of the closed group
    Given I have logged in as "request@example.com"
    And I follow "View Profile"
    Then I follow "Past mentoring connections"
    Then I should not see "Test reason"
    And I follow "Closed"
    Then I should see "Accomplished goals of connection"
    And I follow "Visit Mentoring Connection"
    # Forms should not be shown
    Then I should not see "message_text_box"
    Then I should not see "to add your notes"
    Then I should not see "callout_content"
    Then I should not see "Add a goal"
    Then I should not see "task_title"
    And I logout
    Given I have logged in as "ram@example.com"
    And I follow "Mentors"
    Then I filter a mentor with name "Requestable mentor" using quick find
    And I follow "Requestable mentor"
    Then I follow "Past mentoring connections"
    And I follow "clone_link_4" for the group "group_4"
    Then I should see "Create Duplicate Mentoring Connection"
    Then I should see "mentor & example" in group attribute "#group_name"
    Then I should see "Requestable mentor <request@example.com>" as "mentor" of the closed group "mentor & example"
    Then I should see "student_e example <student_4@example.com>" as "mentee" of the closed group "mentor & example"
    And I logout
    # admin reactivates the closed group
    Given the current program is "primary":"albers"
    Given I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Mentoring Connections"
    And I follow "Closed"
    # admin terminates the group
    And I click on "reactivate_link_4" for the group "group_4"
    Then I should see "Cancel"
    And I fill in "group_reactivation_reason_4" with "A reason"
    Then I should see "Reactivate"
    And I press "Reactivate"
    Then I should see "has been reactivated"
    And I logout
    # Now again log in as mentor of the reactivated group
    Given I have logged in as "request@example.com"
    And I follow "View Profile"
    Then I follow "Ongoing mentoring connections"
    And I follow "Closed"
    Then I follow "mentor & example"
    Then I should see "mentoring connection was recently reactivated"
    And I click "#group_notice_message_hide_id"
    Then I reload the page
    Then I should not see "mentoring connection was recently reactivated"
    And I logout
    # The flash notice will reappear when session is cleared
    Given I have logged in as "request@example.com"
    And I follow "View Profile"
    Then I follow "Ongoing mentoring connections"
    And I follow "Closed"
    Then I follow "mentor & example"
    Then I should see "mentoring connection was recently reactivated"
    And I logout

  @javascript @cross_browser
  Scenario: Super admin deletes a closed group
    Given the current program is "primary":"albers"
    Given I have logged in as "ram@example.com"
    And I login as super user
    And I follow "Manage"
    And I follow "Mentoring Connections"
    And I follow "Closed"
    And I click ".dropdown-toggle" within ".cjs_group_actions_4"
    And I follow "Delete Mentoring Connection"
    Then I should see "Are you sure you want to delete this mentoring connection? All information related to this mentoring connection will be deleted."
    And I press "Delete"
    Then I should see "The mentoring connection has been deleted"
    And I logout
