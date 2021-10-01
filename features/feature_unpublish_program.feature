Feature: Nonloggedin user should not be able to see unpublished programs

@javascript
Scenario: NonLogged in Student sees the programs listing page
    Given the current program is "primary":"albers"
    And I should see "Primary Organization"
    And I follow "Primary Organization"
    And I should see "Albers Mentor Program"
    #Admin logs in and hides the "Albers Mentor Program"
    When I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Program Settings"
    And I should see the radio button "program_published_true" selected
    Then I choose "program_published_false"
    Then I press "Save"
    And I logout
    And I follow "Primary Organization"
    And I should not see "Albers Mentor Program" within "#program_list"
    #Admin again logs in and publishes the "Albers Mentor Program"
    When I have logged in as "ram@example.com"
    And I follow "Albers Mentor Program"
    And I follow "Manage"
    And I follow "Program Settings"
    And I should see the radio button "program_published_false" selected
    Then I choose "program_published_true"
    Then I press "Save"
    And I logout
