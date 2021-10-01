@reindex @manage_career_development

Feature: Removing all the role hardcoding
  In order to support new roles other then mentor and mentee
  I want to login into a portal as Admin and check if the behaviour is same.

  Background:
    And I perform missed migrations
    Given the current program is "nch":"portal"
    And I have logged in as "nch_admin@example.com"

  @javascript @enable_caching
  Scenario: Admin should see employee profile questions while creating
    Then I follow "Manage"
    Then I follow "User Views"
    And I click "#clicked-title-admin-view"
    And I should see "Create a new view"
    Then I follow "Create a new view"
    Then I should see "Create New View"
    Then I fill in "Title" with "Test Admin View"
    Then I follow "Next »"
    Then I click view
    Then I should see "Profile Questions"
    Then I should see "How old are you?"
    And I should see "What is your interest?"
    Then I select "How old are you?" from "admin_view_profile_questions_questions_1_question"
    Then I follow "Next »"
    Then I click view
    Then I press "Create View"
    Then I follow "Update View"
    Then I click view
    Then I should see "Profile Questions"
    Then I should see "How old are you?"
    And I should see "What is your interest?"

  @javascript @enable_caching
  Scenario: User filter profile questions cache should expire on creating a new question
    Then I follow "Employee"
    Then I follow "More filters"
    Then I should see "How old are you?" within "#filter_pane"
    And I should see "What is your interest?" within "#filter_pane"
    Then I follow "Manage"
    Then I follow "Customize"
    And I open section with header "More Information"
    And I click on profile question with question text "How old are you?"
    And I follow "Roles"
    Then I uncheck "Employee"
    Then I should see "Are you sure you want to remove this question for this program?"
    Then I click on text "Yes"
    Then I wait for ajax to complete
    Then I follow "Employee"
    Then I follow "More filters"
    Then I should not see "How old are you?" within "#filter_pane"
    And I should see "What is your interest?" within "#filter_pane"

  @javascript @enable_caching
  Scenario: Employee User must see updated profile Summary of User
    Given "employee" role have permission to "view_employees" in "Primary Career Portal"
    Then I logout
    When I have logged in as "nch_employee@example.com"
    Then I should see "Employees"
    When I follow "Employees"
    Then I should see "nch_employee@example.com" answered "How old are you?" as "I forgot"
    When I follow "Nch Portal Employee"
    And I follow "Actions"
    And I follow "Edit your Profile"
    And I click on the section with header "More Information"
    And I fill in "How old are you?" with "Just Kidding"
    And I save section with header "More Information"
    And I wait for ajax to complete
    Then I should see "Nch Portal Employee"

    When I follow "Employees"
    Then I should see "nch_employee@example.com" answered "How old are you?" as "Just Kidding"

  @javascript
  Scenario: Employee user should see flash message with correct term
    Given the "Primary Career Portal" admin has added required questions for "employee"
    And I give permission to admins in program "nch":"portal"
    When admin add "nch_mentor@example.com" as "Employee"
    And I logout

    When I have logged in as "nch_mentor@example.com"
    Then I should see "Your employee profile is incomplete. Please fill all the required fields and publish your profile."

  @javascript
  Scenario: Program Event show page should show user information for employee role
    Then I follow "Manage"
    And I follow "Events"
    And I follow "Birthday Party"
    Then I should see "See all (4)" within "#SidebarRightContainer"
    Then I follow "See all (4)" within "#SidebarRightContainer"
    Then I see "American boys school" as user info for "nch_employee@example.com"