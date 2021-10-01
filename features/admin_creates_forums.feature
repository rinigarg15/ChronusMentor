@admin_creates_forum
Feature: Admin creates forums for mentees and mentors
  In order to create, edit and destory forums
  As an admin
  I want to login and enter the appropriate as required

  Background: Admin logs in
   Given the current program is "primary":"albers"
   And I have logged in as "ram@example.com"

  @javascript
  Scenario: Admin should not see forums when it is disabled
    When I follow "Manage"
    Then I should see "Forums" within "#manage"
    Then I disable the feature "forums" as a super user
    When I follow "Manage"
    Then I should not see "Forums" within "#manage"

  @javascript @cross_browser
  Scenario: Admin creates a forum for mentor and mentee
    When I follow "Manage"
    And I follow "Forums" within "#manage"
    Then I should see "Mentors Forum" in "page_canvas"
    And I should see "Mentees Forum" in "page_canvas"
    And I should see "Common forum" in "page_canvas"
    And I choose "filter_student"
    Then I should see "Mentees Forum" in "page_canvas"
    And I should not see "Mentors Forum" in "page_canvas"

    And I follow "New Forum"
    And I fill in "Name" with "Mutual Collaboration"
    And I fill in "Description" with "This will be used by both mentors and mentees as weel"
    And I check mentors and students
    And I press "Create"
    Then I should see "The new forum has been successfully created"
    And I should see "Mutual Collaboration" in "page_canvas"
    And I should see "Common forum" in "page_canvas"
    And I should not see "Mentors forum" in "page_canvas"
    And I follow "Home"
    Then I hover on tab "Forums"
    And I follow "Mutual Collaboration"
    Then I should see "Start a Conversation"

 @javascript @cross_browser
  Scenario: Admin edits and removes a forum for mentor and mentee, and views all forums
    And I follow "Manage"
    And I follow "Forums" within "#manage"
    And I should see "Common forum"
    And I click "span.caret" within "div.list-group"
    Then I follow "Edit"
    #And I edit the forum "Common forum"
    And I fill in "Name" with "Common forum1"
    And I press "Save"
    Then I should see "The changes have been saved"
    And I should see "Common forum1" in "page_canvas"
    And I click "span.caret" within "div.list-group"
    Then I follow "Delete"
    And I confirm popup
    Then I should see "The forum has been successfully removed"
    And I should not see "Common forum1" in "page_canvas"