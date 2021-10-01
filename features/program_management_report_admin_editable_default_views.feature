Feature: Admin should be able to be see filter for the default pages of All Users, All Mentees, All Mentors and All Members

Background: Admin logs in
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"

@javascript @cross-browser
Scenario: Admin tries to update the "Never Connected Users" page
    Then I follow "Manage"
    And I should see "User Views"
    Then I follow "User Views"
    Then I should see "All Users"
    And I click on the view "Never Connected Mentees"
    And I should see "Never Connected Mentees"
    And I should see "Update View"
    Then I follow "Update View"
    And I check if the filters are editable for mentee view
    Then I logout

@javascript
Scenario: Admin tries to update the "Registered Users with Unpublished Profiles" page
    Then I follow "Manage"
    And I should see "User Views"
    Then I follow "User Views"
    Then I should see "All Users"
    And I click on the view "Registered Mentors with Unpublished Profiles"
    And I should see "Registered Mentors with Unpublished Profiles"
    And I should see "Update View"
    Then I follow "Update View"
    And I check if the filters are editable
    Then I logout

@javascript
Scenario: Admin tries to update the "Currently Unconnected Users" page
    Then I follow "Manage"
    And I should see "User Views"
    Then I follow "User Views"
    Then I should see "All Users"
    And I click on the view "Currently Unconnected Mentees"
    And I should see "Currently Unconnected Mentees"
    And I should see "Update View"
    Then I follow "Update View"
    And I check if the filters are editable for mentee view
    Then I logout

@javascript
Scenario: Admin tries to update the "Application Accepted, Awaiting Signup" page
    Then I follow "Manage"
    And I should see "User Views"
    Then I follow "User Views"
    Then I should see "All Users"
    And I click on the view "Application Accepted, Awaiting Signup"
    And I should see "Application Accepted, Awaiting Signup"
    And I should see "Update View"
    Then I follow "Update View"
    And I check if the filters are editable
    Then I logout

@javascript @cross-browser
Scenario: Admin tries to update the "All Users" page
    Then I follow "Manage"
    And I should see "User Views"
    Then I follow "User Views"
    Then I should see "All Users"
    And I should see "Update View"
    Then I follow "Update View"
    And I check if the filters are uneditable
    Then I logout