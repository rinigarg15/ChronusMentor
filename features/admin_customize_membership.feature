Feature: Admin customizes membership questions for subprogram

@javascript @cross_browser
  Scenario: Making a question admin only visible/editable should disable it in membership coustomize
    Given the current program is "primary":"albers"
    And I perform missed migrations
    And I have logged in as "ram@example.com"
    When I hover over "my_programs_container"
    Given the current program is "primary":""
    And I "enable" membership request customization for "primary"
    And there are questions "AlbersQ1,AlbersQ2" for "mentor" in "primary":"albers"
    And I make "AlbersQ1" question admin only editable for "mentor" in "primary":"albers"
    And I make "AlbersQ2 " question admin only visible for "mentor" in "primary":"albers"
    When I hover over "my_programs_container"
    And I select "Albers Mentor Program" from the program selector
    When I follow "Manage"
    When I click "i.manage-icon-customize-profile"  
    Then "Location" question in section "1" under "mentor" role should not be disabled in "primary":"albers"
    Then "AlbersQ1" question in section "1" under "mentor" role should be disabled in "primary":"albers"
    Then "AlbersQ2" question in section "1" under "mentor" role should be disabled in "primary":"albers"