@reindex @manage_career_development @javascript

Feature: Manage Employees using Employee Vertical
  In order to view the Employees vertical in a Career Development Program
  I want to be an Admin

  Background:
    Given the current program is "nch":"portal"

  Scenario: Employee can view Employees vertical only if permission is present
    When I have logged in as "nch_employee@example.com"
    Then I should not see "Employees"
    Given employees have permission to view other employees
    And I reload the page
    Then I should see "Employees"
    When I follow "Employees"
    Then I should see "Showing 1 - 1 of 1"
    And I should not see "Manage Employees" within "#main_title_content"
    And I should not see "Invite Employees" within "#main_title_content"
    And I should not see "Add Employees Directly" within "#main_title_content"

  Scenario: Admin can view Employees vertical
    When I have logged in as "nch_admin@example.com"
    Then I should see "Employees"
    When I follow "Employees"
    Then I should see "Showing 1 - 1 of 1"
    When I quick search for "Invalid"
    Then I should not see "Showing 1 - 3 of 3"
    And I should see "No employees found matching your criteria. You can try the following."
    And I should see "Broaden your search by clearing a few filters."
    And I should see "View all employees"
    And I should see "href" attribute for link "View all employees" matches with "p/portal/users?view=employee"
    When I follow "View all employees"
    Then I should see "Showing 1 - 1 of 1"
    And I should see "Manage Employees" in the page actions bar
    When I click on dropdown toggle in the page actions bar
    And I should see "Invite Employees" in the page actions bar
    And I follow "Invite Employees" in the page actions bar
    Then I should see "Provide user details to invite"
    When I follow "Employees"
    When I click on dropdown toggle in the page actions bar
    Then I should see "Add Employees Directly" in the page actions bar
    And I follow "Add Employees Directly" in the page actions bar
    Then I should see "Add users manually"
    And the "role_employee" checkbox_id should be checked
    Given there are no employees in "nch":"portal"
    When I follow "Employees"
    Then I should see "There are no employees in the program yet." in the page canvas
    And I should see "Invite Employees" in the page canvas
    And I follow "Invite Employees" in the page canvas
    Then I should see "Provide user details to invite"
    When I follow "Employees"
    Then I should see "Add Employee Profiles" in the page canvas
    And I follow "Add Employee Profiles" in the page canvas
    Then I should see "Add users manually"
    And the "role_employee" checkbox_id should be checked
    Given admins cannot invite employees
    When I follow "Employees"
    Then I should not see "Invite Employees" in the page actions bar
    And I should not see "Invite Employees" in the page canvas
    Given admins cannot add other non admin profiles
    When I follow "Employees"
    Then I should not see "Add Employees Directly" in the page actions bar
    Then I should not see "Add Employee Profiles" in the page canvas
