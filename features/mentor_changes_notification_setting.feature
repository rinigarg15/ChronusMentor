 Feature: Mentors should be able to change notification settings (apart from other things)
  In order to achieve benefits of mentoring
  As a mentor
  I want to be able to change notification setting

  Background:
    Given the current program is "primary":"albers"

  @javascript @cross-browser
  Scenario: Mentor should be able to change the notification settings from Aggregate to All
    Given the notifications setting of "robert@example.com" is "aggregate"
    And "robert@example.com" has a few pending notifications
    And I have logged in as "robert@example.com"
    And I click on profile picture and click "Edit Profile"
    Then I follow "Notifications" within "div#mentor_profile"   
    And I change the notification setting to "all"
