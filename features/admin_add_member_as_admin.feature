Feature: Admin add member to program as admin

Background: Admin logs in
    Given the current program is "primary":""
    And I have logged in as "ram@example.com"

@javascript
  Scenario: Administrator add member to one program as admin
  And I follow "Manage"
  And I follow "Member Views"
  Then I follow "arun"
  And I should not see "Admin" within ".sidepane_asset_program_0"
  And I follow "Add User as Admin"
  Then I should see "Add as Admin"

  And I select "Albers Mentor Program" from "program_id"
  And I press "Add"
  Then I should see "Student" within ".sidepane_asset_program_0"
  Then I should see "Administrator" within ".sidepane_asset_program_0"
  And I should see "arun albers has been added to the list of administrators"

  And I follow "Add User as Admin"
  And I press "Add"
  Then I should see "Administrator" within ".sidepane_asset_program_0"
  And I should see "arun albers has been added to the list of administrators"

@javascript @p2
  Scenario: Admin adds a new member as admin
  And I set help text as "Name help text" for name question in organization "primary"
  And I follow "Manage"
  And I follow "Administrators"
  And I follow "Add administrator"
  Then I follow "New administrator"
  Then I should see "Add new Administrator"
  And I should see "Name help text"
  Then I fill in "Email" with "ashley@chronus.com"
  Then I fill in "Message" with "Welcome to our program!"
  And I fill in "Last name" with "Williams"
  Then I fill in "First name" with "Ashley1"
  Then I press "Add"
  Then I should see the flash "Please correct the below error(s) highlighted in red."
  Then I should see "contains numeric characters"
  Then I fill in "First name" with "Ashley"
  And I fill in "Last name" with "Williams1"
  Then I press "Add"
  Then I should see the flash "Please correct the below error(s) highlighted in red."
  Then I should see "contains numeric characters"
  And I fill in "Last name" with "Williams"
  Then I fill in "Email" with "ashleychronus"
  Then I press "Add"
  Then I should see the flash "Please correct the below error(s) highlighted in red."
  Then I should see "is not a valid email address"
  Then I fill in "Email" with "ashley@chronus.com"
  Then I press "Add"
  Then I should see "Ashley Williams has been added to the list of administrators"
  Then I should see "ashley@chronus.com"
  And mail should go to "ashley@chronus.com" having "has invited you to join Primary Organization as an administrator."

  @javascript @p2 @cross_browser
  Scenario: Admin adds an existing member as admin
  And I follow "Manage"
  And I follow "Administrators"
  And I follow "Add administrator"
  Then I follow "Existing user as administrator"
  Then I should see "Add new Administrator"
  Then I should see " Enter the name of an existing user"
  And I fill in by css "member_name_with_email" with "student example <rahim@example.com>"
  Then I press "Add"
  Then I should see "student example has been added to the list of administrators"
  Then I should see "rahim@example.com"
  # Remove Admin
  Then I follow "Remove Admin"
  And I should see "Are you sure you want to remove student example (Administrator) as administrator?"
  And I confirm popup
  Then I should see "student example has been removed from the list of administrators"
  And I should not see "rahim@example.com"
