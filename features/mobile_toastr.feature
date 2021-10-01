@javascript
Feature: Two toastrs should coexist in the app

  Scenario: User should see two toastr in a page
    Given the current program is "primary":""
    And I have logged in as "ram@example.com"
    And I create a normal toastr with text "Normal 1"
    And I create a notification toastr with text "Notification 1"
    And I should see "Normal 1"
    And I should see "Notification 1"
    And I clear normal toastr
    And I should not see "Normal 1"
    And I should see "Notification 1"
    And I clear notification toastr
    And I should not see "Normal 1"
    And I should not see "Notification 1"
    And I create a notification toastr with text "Notification 1"
    And I create a normal toastr with text "Normal 1"
    And I create a normal toastr with text "Normal 2"
    And I create a notification toastr with text "Notification 2"
    And I should see "Normal 1"
    And I should see "Notification 1"
    And I should see "Normal 2"
    And I should see "Notification 2"
    And I clear notification toastr
    And I should see "Normal 1"
    And I should see "Normal 2"
    And I should not see "Notification 1"
    And I should not see "Notification 2"
