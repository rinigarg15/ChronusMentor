Feature: Project Owner

Background: Admin logs in
  Given the current program is "primary":"pbe"
  And pbe program has custom term
  And I have logged in as "ram@example.com"
  Then I enable admin audit logs
  And I logout

  @javascript
  Scenario: Admin enable/disbale project rquest reminder
    And I have logged in as "ram@example.com"
    And I login as super user
    And I follow "Manage"
    And I follow "Program Settings"
    When I follow "Matching Settings"
    And I should see "Remind the owner if the project requests are pending"
    And I should see "remind them after" hidden
    Then the "program_needs_project_request_reminder" checkbox_id should not be checked
    Then I check "program_needs_project_request_reminder"
    And I should see "remind them after"
    And I press "Save"

    Then the "program_needs_project_request_reminder" checkbox_id should be checked
    And value of "#program_project_request_reminder_duration" should be "3"

    Then I uncheck "program_needs_project_request_reminder"
    And I should see "remind them after" hidden
    And I press "Save"

    Then I should see "remind them after" hidden

@javascript
Scenario: Non pbe program should not see reminder setting
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I login as super user
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Mentoring Connection Settings"
    And I should not see "Remind the owner"

  @javascript @cross-browser
  Scenario: Admin updating owner
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Projects"
    And I click on dropdown of the group "project_group"
    And I should see "Add/Remove Owners"
    And I follow "Add/Remove Owners"
    Then I should see "Owner of the project get to perform all the action administrator can, like start the project, end the project, manage members of the project"
    Then I fill owners for group "project_group" with "Good unique name" in "primary":"pbe"
    And I press "Update"

    Then I should see "Good unique name (Owner)"
    Then I follow "project_group"
    And I fill in "confidentiality_audit_log_reason" with "Updating connection"
    And I press "Proceed »"
    And I should see "Add/Remove Owners"
    And I expand the "mentor" listing of mentoring area members pane
    Then I should see "Good unique name" in the "mentor" listing of mentoring area members pane in "primary":"pbe"
    And I follow "Add/Remove Owners"
    Then I should see "Owner of the project get to perform all the action administrator can, like start the project, end the project, manage members of the project"
    Then I logout


    And I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Projects"
    When I follow "Create New Project"
    Then I should be on new group page in primary:pbe program
    And I fill in "similar_connection_name" with "TODO app in IOS"
    And I fill in "Maximum number of students who can participate" with "3"
    When I press "Save and proceed to Add Members »"
    Then I should see "TODO app in IOS"
    And I press "Save and Continue Later"

    Then I should be on groups page in primary:pbe program
    And I should see "Drafted (2)" within "li.ct_active"
    When I visit drafted project profile
    And I should not see "Add/Remove Owners"

    When I visit published project profile
    And I should see "Add/Remove Owners"
    And I follow "Add/Remove Owners"
    Then I should see "Owner of the project get to perform all the action administrator can, like start the project, end the project, manage members of the project"

    When I visit closed project profile
    And I should not see "Add/Remove Owners"