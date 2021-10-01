@reindex @manage_career_development

Feature: Manage Career Development Portals
  In order to add users from other programs to Career Development Portal
  I want to login into a portal as Admin and add users from other programs

  Background:
    Given the current program is "nch":"portal"
    And I give permission to admins in program "nch":"portal"
    And I have logged in as "nch_admin@example.com"
    When I follow "Manage"
    And I follow "Add Users"

  @javascript
  Scenario: Admin adds mentor from another sub program
    And I follow "Add users from Nation Wide Children Hospital Org"
    Then I should see "nch_mentor@example.com"
    And I should see "nch_mentee@example.com"
    Then I should see "Actions"

    When I select "nch_mentor@example.com" from the sub-program user import selector
    Then I follow "Add to Program" in the bulk actions
    And I check "Employee"
    And I press "Submit"
    Then I should see "The selected user (in Active state) has been imported to this program as Employee"

    When I logout
    And I have logged in as "nch_mentor@example.com"
    Then I list all the programs
    Then I should see program selector containing "NCH Mentoring Program" under "Nation Wide Children Hospital Org"
    And I should see program selector containing "Primary Career Portal" under "Nation Wide Children Hospital Org"
    Then I hover over "my_programs_container"
    Then I list all the programs

    When I select "Nation Wide Children Hospital Org" from the program selector
    And I click on profile picture and click "View Profile"
    Then I should see the role "Mentor" in "NCH Mentoring Program"
    And I should see the role "Employee" in "Primary Career Portal"

  @javascript
  Scenario: Admin adds mentee from another sub program
    And I follow "Add users from Nation Wide Children Hospital Org"
    Then I should see "nch_mentor@example.com"
    And I should see "nch_mentee@example.com"
    Then I should see "Actions"

    When I select "nch_mentee@example.com" from the sub-program user import selector
    Then I follow "Add to Program" in the bulk actions
    And I check "Employee"
    And I press "Submit"
    Then I should see "The selected user (in Active state) has been imported to this program as Employee"

    When I logout
    And I have logged in as "nch_mentee@example.com"
    Then I list all the programs
    Then I should see program selector containing "NCH Mentoring Program" under "Nation Wide Children Hospital Org"
    And I should see program selector containing "Primary Career Portal" under "Nation Wide Children Hospital Org"
    Then I hover over "my_programs_container"
    Then I list all the programs

    When I select "Nation Wide Children Hospital Org" from the program selector
    And I click on profile picture and click "View Profile"
    Then I should see the role "Student" in "NCH Mentoring Program"
    And I should see the role "Employee" in "Primary Career Portal"

  @javascript
  Scenario: Admin bulk adds mentors and mentees from another sub program
    And I follow "Add users from Nation Wide Children Hospital Org"
    Then I should see "nch_mentor@example.com"
    And I should see "nch_mentee@example.com"
    Then I should see "Actions"

    And I check "cjs_user_primary_checkbox"
    Then I follow "Add to Program" in the bulk actions
    And I check "Employee"
    And I press "Submit"
    Then I should see "The selected 2 users (in Active state) have been imported to this program as Employees"

@javascript
Scenario: Admin applies filters results by Role
  And I logout
  And I give permission to admins in program "nch":"main"
  Given the current program is "nch":"main"
  And I have logged in as "nch_admin@example.com"
  When I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from Nation Wide Children Hospital Org"
  Then I should see "nch_employee@example.com"
  And I should see "nch_sub_portal_admin@example.com"

  Then I check "Administrator"
  Then I should see "Program/Role" within "#filter_item_program_role"
  Then I should not see "nch_employee@example.com"
  And I should see "nch_sub_portal_admin@example.com"

  Then I check "Employee"
  Then I should see "Program/Role" within "#filter_item_program_role"
  Then I should see "nch_employee@example.com"
  And I should see "nch_sub_portal_admin@example.com"

  Then I uncheck "Administrator"
  Then I should see "Program/Role" within "#filter_item_program_role"
  Then I should see "nch_employee@example.com"
  And I should not see "nch_sub_portal_admin@example.com"

  Then I check "Dormant users"
  Then I should see "Program/Role" within "#filter_item_program_role"
  Then I should not see "nch_employee@example.com"
  And I should not see "nch_sub_portal_admin@example.com"
  And I should see "No users found with current filters"
