@javascript
Feature: Pages visibility
  In order to manage pages visibility
  As an admin
  I want to view and update programs visibility and see pages under different visibility

  Background: Setup program
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I login as super user

  Scenario: Program visibility should be available for super-admin only
    And I follow "Manage"
    And I follow "Program Settings"
    Then I should not see "Allow logged in pages"

  Scenario: Visibility should be disabled by default
    And the feature "logged_in_pages" should be "disabled" for "primary"
    When I accesed new page form
    Then I should not see "Visibility"
    Then I should not see "Make this page available on the navigation"

  Scenario: Super-admin can enable visibility
    Given the feature "logged_in_pages" is enabled for "primary"
    When I accesed new page form
    Then I should see "Visibility"
    Then I should see "Make this page available on the navigation"

  Scenario: Logged in users only page visibility with program visibility enables
    Given the feature "logged_in_pages" is enabled for "primary"
    # Create new page
    When I accesed new page form
    And I fill in "page_title" with "New fine page 1"
    And I fill in CKEditor "program_overview_content" with "<h1>Beautiful header</h1><p>Generic content</p>"
    And I select "Logged in users only" from "page_visibility"
    And I choose "page_use_in_sub_programs_true"
    And I press "Save"
    # See updated info
    Then I should see the tab "Manage" selected
    And I should see "New fine page"
    And I should see "Visibility: Logged in users only"
    Then I follow "Publish"
    # Menu for admin
    When I follow "Home"
    Then I should not see "New fine page"
    # Menu for not logged in user
    And I logout
    Then I should not see "New fine page"
    # For student
    When I have logged in as "rahim@example.com"

    Then I should see "New fine page"
    When I follow "New fine page"
    Then I should see "Beautiful header"
    And I should see "Generic content"

  Scenario: Non-elevated to subprograms page should be visible in Overview only
    Given the feature "logged_in_pages" is enabled for "primary"
    # Create new page
    When I accesed new page form
    And I fill in "page_title" with "New fine page"
    And I fill in CKEditor "program_overview_content" with "<h1>Beautiful header</h1><p>Generic content</p>"
    And I select "Logged in users only" from "page_visibility"
    And I choose "page_use_in_sub_programs_false"
    And I press "Save"
    # See updated info
    Then I should see the tab "Manage" selected
    And I should see "New fine page"
    And I should see "Visibility: Logged in users only"
    Then I follow "Publish"
    # Menu for not logged in user
    And I logout
    Then I should not see "New fine page"
    # For student
    When I have logged in as "rahim@example.com"

    Then I should not see "New fine page"
    When I follow "Overview"
    Then I should see "New fine page"

  Scenario: Both users page visibility
    Given the feature "logged_in_pages" is enabled for "primary"
    When I accesed new page form
    And I fill in "page_title" with "New fine page"
    And I fill in CKEditor "program_overview_content" with "<h1>Beautiful header</h1><p>Generic content</p>"
    And I select "Both logged in users and non logged in users" from "page_visibility"
    And I choose "page_use_in_sub_programs_true"
    And I press "Save"
    And I should see "New fine page"
    And I should see "Visibility: Both logged in users and non logged in users"
    Then I follow "Publish"
    # Menu for admin
    When I follow "Home"
    Then I should not see "New fine page"
    # Menu for not logged in user
    And I logout
    Then I should see "New fine page"
    When I follow "New fine page"
    Then I should see "Beautiful header"
    And I should see "Generic content"
    # For student
    When I have logged in as "rahim@example.com"

    Then I should see "New fine page"
    When I follow "New fine page"
    Then I should see "Beautiful header"
    And I should see "Generic content"

  Scenario: Both users page visibility with disabled :logged_in_pages
    Given the feature "logged_in_pages" is enabled for "primary"
    When I accesed new page form
    And I fill in "page_title" with "New fine page"
    And I fill in CKEditor "program_overview_content" with "<h1>Beautiful header</h1><p>Generic content</p>"
    And I select "Both logged in users and non logged in users" from "page_visibility"
    And I press "Save"
    And I should see "New fine page"
    And I should see "Visibility: Both logged in users and non logged in users"
    Then I follow "Publish"
    # Disable :logged_in_pages
    Given the feature "logged_in_pages" is disabled for "primary"
    # Menu for admin
    When I follow "Home"
    Then I should not see "New fine page"
    # Menu for not logged in user
    And I logout
    Then I should see "New fine page"
    When I follow "New fine page"
    Then I should see "Beautiful header"
    And I should see "Generic content"
    # For student
    When I have logged in as "rahim@example.com"

    Then I should not see "New fine page"
