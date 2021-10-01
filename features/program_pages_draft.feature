@javascript
Feature: Pages visibility
In order to manage pages status (draft, published)
As an user or admin
I want to view and update program pages status and change pages visibility

Background: Setup program
  Given the current program is "primary":"albers"

@javascript
Scenario: Program published should be available in page form
  When I have logged in as "ram@example.com"
  And I accesed new page form
  Then I should see submit button "Publish"
  Then I should see submit button "Save as draft"

@javascript @cross-browser
Scenario: Program marked as draft should be visible for admins only
  When I have logged in as "ram@example.com"
  Then I should see "Dashboard"
  Then I follow "x"
  And I accesed new page form
  And I fill in "page_title" with "New fine page"
  And I fill in CKEditor "program_overview_content" with "<h1>Beautiful header</h1><p>Generic content</p>"
  And I press "Save as draft"
  Then I should see "New fine pagedraft"
  When I follow "New fine pagedraft"
  Then I should see "Publish"
  When I logout
  And the current program is "primary":"albers"
  Then I should not see "New fine page"
  When I have logged in as "rahim@example.com"
  Then I should not see "New fine page"

#  @javascript
#  Scenario: User should be able to see mobile app prompt when looged in from mobile browser
#    Given the current browser is a mobile browser
#    When I have logged in as "ram@example.com"
#    Then I should see "Get the Mobile App"
#    And I should see "Already Have it"
#    And I should see "Open the App"
#    And I should see "continue to the mobile site"
#    When I follow "continue to the mobile site"
#    Then I should see "My Dashboard"
