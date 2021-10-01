Feature: Subscription Feature

 Background:

@javascript @cross-browser
Scenario: Standalone with various subscription types
    Given the current program is "foster":"main"
    And I have logged in as "fosteradmin@example.com"

    Given the program subscription type is "0" for "foster"
    When I follow "Manage"
    Then I should see "Membership Requests"
    And I follow "Program Settings" manage icon
    And I should not see "Terms & Conditions" within "#program_form"
    Then I should not see "Permissions"
    And I should not see "Features"
    And I should see "Connection Settings"
    And I should see "Membership"
    And I should see "Matching Settings"
    And I follow "Matching Settings"
    #And element with id "#program_enabled_features_" should be disabled
    Then the "program_enabled_features_" checkbox_id should not be checked
    Then the feature "profile_completion_alert" should be "enabled" for "foster"
    Then the feature "subprogram_creation" should be "disabled" for "foster"
    Then the feature "organization_profiles" should be "disabled" for "foster"
    Then the feature "answers" should be "disabled" for "foster"
    Then the feature "articles" should be "disabled" for "foster"
    Then the feature "bulk_matching" should be "enabled" for "foster"
    Then the feature "resources" should be "enabled" for "foster"
    Then the feature "flagging" should be "disabled" for "foster"
    Then the feature "sticky_topic" should be "disabled" for "foster"
    Then the feature "organization_profiles" should be "disabled" for "foster"
    Then the feature "skype_interation" should be "disabled" for "foster"
    Then the feature "program_events" should be "disabled" for "foster"
    Then the feature "work_on_behalf" should be "enabled" for "foster"
    When I follow "Manage"
    Then I should see "Mentoring Connections"
    When I follow "Mentoring Connections"
    Then I click the mentoring connections dropdown
    Then I should see "Find a Mentor"

    Given the program subscription type is "1" for "foster"
    When I follow "Manage"
    Then I should see "Membership Requests"
    And I follow "Program Settings" manage icon
    And I should see "Terms & Conditions" within "#program_form"
    Then I should see "Permissions"
    And I should see "Features"
    And I should see "Connection Settings"
    And I should see "Membership"
    Then the feature "answers" should be "enabled" for "foster"
    Then the feature "articles" should be "enabled" for "foster"
    Then the feature "bulk_matching" should be "disabled" for "foster"
    Then the feature "profile_completion_alert" should be "enabled" for "foster"
    Then the feature "resources" should be "enabled" for "foster"
    Then the feature "flagging" should be "enabled" for "foster"
    Then the feature "sticky_topic" should be "enabled" for "foster"
    Then the feature "organization_profiles" should be "enabled" for "foster"
    Then the feature "skype_interation" should be "enabled" for "foster"
    Then the feature "program_events" should be "enabled" for "foster"
    When I follow "Manage"
    Then I should see "Mentoring Connections"
    When I follow "Mentoring Connections"
    Then I click the mentoring connections dropdown
    Then I should see "Find a Mentor"

    Given the program subscription type is "2" for "foster"
    When I follow "Manage"
    Then I should see "Membership Requests"
    And I follow "Program Settings" manage icon
    And I should see "Terms & Conditions" within "#program_form"
    Then I should see "Permissions"
    And I should see "Features"
    And I should see "Connection Settings"
    And I should see "Membership"
    Then the feature "answers" should be "enabled" for "foster"
    Then the feature "articles" should be "enabled" for "foster"
    Then the feature "bulk_matching" should be "disabled" for "foster"
    Then the feature "profile_completion_alert" should be "enabled" for "foster"
    Then the feature "resources" should be "enabled" for "foster"
    Then the feature "flagging" should be "enabled" for "foster"
    Then the feature "sticky_topic" should be "enabled" for "foster"
    Then the feature "organization_profiles" should be "enabled" for "foster"
    Then the feature "skype_interation" should be "enabled" for "foster"
    Then the feature "program_events" should be "enabled" for "foster"
    Then the feature "work_on_behalf" should be "enabled" for "foster"
    When I follow "Manage"
    Then I should see "Mentoring Connections"
    When I follow "Mentoring Connections"
    Then I click the mentoring connections dropdown
    Then I should see "Find a Mentor"

@javascript @cross-browser
Scenario: Non Standalone with various subscription types
    # All Sub Program level checks
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"

    #Basic Type cannot have subprograms

    Given the program subscription type is "1" for "primary"
    When I follow "Manage"
    Then I should see "Membership Requests"
    And I follow "Program Settings" manage icon
    Then I should see "Permissions"
    And I should see "Connection Settings"
    And I should see "Membership"

    Given the program subscription type is "2" for "primary"
    When I follow "Manage"
    Then I should see "Membership Requests"
    And I follow "Program Settings" manage icon
    Then I should see "Permissions"
    And I should see "Connection Settings"
    And I should see "Membership"
    And I logout

    # All Organization level checks
    And I have logged in as "ram@example.com"

    Given the program subscription type is "1" for "primary"
    When I follow "Manage"
    And I follow "Program Settings" manage icon
    And I should not see "Terms & Conditions" within "#program_form"
    Then the feature "answers" should be "enabled" for "primary"
    Then the feature "articles" should be "enabled" for "primary"