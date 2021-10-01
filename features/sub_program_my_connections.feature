@sub_programs
Feature: Accessing mentoring connections at program level
  Users should be able to view all their mentors and mentees at the program level
  
  @javascript
  Scenario: Viewing 'My Mentees' and 'My Mentors' in albers
    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    And I follow "name & madankumarrajan"
	Then I should see "mkr_student madankumarrajan"
    And I should see "Good unique name"
  
  @javascript
  Scenario: Viewing 'My Mentors' in nwen
    Given the current program is "primary":"nwen"
    And I have logged in as "robert@example.com"
    And I follow "example & name"
    Then I should see "Good unique name"
    And I should see "student example"
  
  @javascript
  Scenario: Mentee viewing 'My Mentees' in nwen
    Given the current program is "primary":"nwen"
    And I have logged in as "rahim@example.com"
    And I follow "example & name"
    Then I should see "Good unique name"

  @javascript
  Scenario: Only onetime mentor should not see my connections
    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    And I change mentoring mode of mentor with email "robert@example.com" in program "primary":"albers" to "one time"
    Then I should see "MENTORING CONNECTIONS" within "ul.metismenu"
    Then admin terminate connection with name "name & madankumarrajan" of member with email "robert@example.com" in program "primary":"albers"
    And I follow "Home"
    Then I should see "MENTORING CONNECTIONS" within "ul.metismenu"
    Then I should see "Closed" within "ul.metismenu"