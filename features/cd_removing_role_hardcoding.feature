@reindex @manage_career_development

Feature: Removing all the role hardcoding
  In order to support new roles other then mentor and mentee
  I want to login into a portal as Admin and check if the behaviour is same.

  Background:
    Given the current program is "nch":"portal"
    And I have logged in as "nch_admin@example.com"
    
  @javascript
  Scenario: Admin should see employee profile questions while creating
  	Then I follow "Manage"
  	Then I follow "User Views"
    And I click "#clicked-title-admin-view"
    And I should see "Create a new view"
    Then I follow "Create a new view"
    Then I should see "Create New View"
    Then I fill in "Title" with "Test Admin View"
    Then I follow "Next »"
    Then I should see "Profile Question"
    Then I should see "How old are you?"
    And I should see "What is your interest?"
    Then I click view
    Then I select "How old are you?" from "admin_view_profile_questions_questions_1_question"
    Then I follow "Next »"
    Then I wait for ajax to complete
    Then I click view
    Then I press "Create View"


    Then I follow "Update View"
    Then I should see "Profile Question"
    Then I should see "How old are you?"
    And I should see "What is your interest?"

  @javascript
  Scenario: Program Event show page should show user information for employee role
    Then I follow "Manage"
    And I follow "Events"
    And I follow "Birthday Party"
    Then I should see "See all (4)" within "#SidebarRightContainer"
    Then I follow "See all (4)" within "#SidebarRightContainer"
    Then I see "American boys school" as user info for "nch_employee@example.com"
  
  @javascript
  Scenario: portal should have employee description in Article
    Given the current program is "nch":"portal"
    Then I hover on tab "Advice"
    When I follow "Articles"
    And I follow "Write New Article"
    And I should see "Make a list of websites and books that you found useful in the past that could be helpful to the members of the program."
    And I scroll and click the element "div#a_list" below my visibility
    And I should see "Share books/website that will help members of the program"

    Given the current program is "nch":"main"
    Then I hover on tab "Advice"
    When I follow "Articles"
    And I follow "Write New Article"
    And I should see "Make a list of websites and books that you found useful in the past that could be helpful to the members of the program"
    And I scroll and click the element "div#a_list" below my visibility
    And I should see "Share books/website that will help members of the program"