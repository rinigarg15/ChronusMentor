    Feature: User id disallowed to log in to the website after a specified number of unsuccessful login attempts
  In order to enable the account lockout feature
  As an admin
  I want to login and enter a non zero value in the security tab of the organization level program settings

  Background: Albers Program
    Given the current program is "primary":""

  @javascript
  Scenario: Mentor or Mentee logs in
    Given I have logged in as "ram@example.com"
    Then I should see "title" attribute for profile picture matches with "Freakin Admin (Administrator)"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Security"
    And I check "account_lockout"
    And I fill in by css "organization_security_setting_attributes_maximum_login_attempts" with "-2"
    And I fill in by css "organization_security_setting_attributes_auto_reactivate_account" with "-2.0"
    And I press "Save"
    Then I should see the flash "Security setting maximum login attempts must be greater than or equal to 0 Security setting auto reactivate account must be greater than or equal to 0"
    And I check "account_lockout"
    And I fill in by css "organization_security_setting_attributes_maximum_login_attempts" with "2"
    And I fill in by css "organization_security_setting_attributes_auto_reactivate_account" with "2.0"
    And I press "Save"
    Then I should see the flash "Your changes have been saved"
    And I logout

    Given the current program is "primary":"albers"
    When I follow "Login"
    And I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey1"
    And I press "Login"
    Then I should see "Login failed"

    When I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey1"
    And I press "Login"
    Then I should see "Login failed"

    When I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey1"
    And I press "Login"
    Then I should see "Your account has been blocked due to multiple incorrect attempts to login"

    When I follow "Login"
    And I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey"
    And I press "Login"
    Then I should see "Your account has been blocked due to multiple incorrect attempts to login"

    When I follow "Login"
    And I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey1"
    And I press "Login"
    Then I should see "Your account has been blocked due to multiple incorrect attempts to login"

    When I open new mail
    And I follow "Reactivate Account" in the email
    Then I should see "Change Password"
    When I fill in by css "member_password" with "abcdef"
    And I fill in by css "member_password_confirmation" with "abcdef"
    And I follow "Change"
    Then I should see "Your account has been successfully reactivated. Please login with your new password."

    When I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "abcdef"
    And I press "Login"
    Then I should see "student example"

@javascript
  Scenario: Mentor or Mentee trying login with wrong password and admin unchecks account_lockout
    Given I have logged in as "ram@example.com"
    Then I should see "title" attribute for profile picture matches with "Freakin Admin (Administrator)"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Security"
    And I check "account_lockout"
    And I fill in by css "organization_security_setting_attributes_maximum_login_attempts" with "2"
    And I fill in by css "organization_security_setting_attributes_auto_reactivate_account" with "2.0"
    And I press "Save"
    Then I should see the flash "Your changes have been saved"
    And I logout

    When I follow "Login"
    And I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey1"
    And I press "Login"
    Then I should see "Login failed"

    When I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey1"
    And I press "Login"
    Then I should see "Login failed"

    When I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey1"
    And I press "Login"
    Then I should see "Your account has been blocked due to multiple incorrect attempts to login"

    When I follow "Login"
    And I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey"
    And I press "Login"
    Then I should see "Your account has been blocked due to multiple incorrect attempts to login"

    Given I have logged in as "ram@example.com"
    Then I should see "title" attribute for profile picture matches with "Freakin Admin (Administrator)"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Security"
    And I uncheck "account_lockout"
    And I press "Save"
    And I logout

    When I follow "Login"
    And I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey1"
    And I press "Login"
    Then I should see "Login failed"

    And I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey"
    And I press "Login"
    Then I should see "Home"
    And I logout


  @javascript @p2 @cross_browser
  Scenario: Admin unblocking the users without reactivation mail
    Given I have logged in as "ram@example.com"
    Then I should see "title" attribute for profile picture matches with "Freakin Admin (Administrator)"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Security"
    And I check "account_lockout"
    And I uncheck "organization_security_setting_attributes_reactivation_email_enabled"
    And I fill in by css "organization_security_setting_attributes_maximum_login_attempts" with "2"
    And I press "Save"
    And I logout

    When I follow "Login"
    And I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey1"
    And I press "Login"
    Then I should see "Login failed"

    When I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey1"
    And I press "Login"
    Then I should see "Login failed"

    When I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey1"
    And I press "Login"
    Then I should see "Your account has been blocked due to multiple incorrect attempts to login. Please contact the program administrator"

    When I have logged in as "ram@example.com"
    Then I should see "title" attribute for profile picture matches with "Freakin Admin (Administrator)"
    When I follow "Manage"
    And I follow "Account blocked users" within "div#manage"
    Then I should see "student example"
    When I follow "Unblock"
    Then I should see "There are no users whose account has been blocked."
    And I logout

    When I have logged in as "rahim@example.com"
    Then I should see "title" attribute for profile picture matches with "student example"
    And I logout

  @javascript
  Scenario: Admin disables Remember me option on login page
    Given I have logged in as "ram@example.com"
    And I login as super user
    Then I should see "title" attribute for profile picture matches with "Freakin Admin (Administrator)"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Security"
    And I choose "organization_security_setting_attributes_can_show_remember_me_false"
    And I press "Save"
    And I logout

    When I follow "Login"
    Then I should not see "Keep me signed in"

    When I fill in by css "email" with "ram@example.com"
    And I fill in by css "password" with "monkey"
    And I press "Login"
    And I login as super user
    Then I should see "title" attribute for profile picture matches with "Freakin Admin (Administrator)"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Security"
    And I choose "organization_security_setting_attributes_can_show_remember_me_true"
    And I press "Save"
    And I logout

    When I follow "Login"
    Then I should see "Keep me signed in"
    And the "remember_me" checkbox_id should be checked

  @javascript
  Scenario: Automatically reactivate account after 24 hours
    Given I have logged in as "ram@example.com"
    And I login as super user
    Then I should see "title" attribute for profile picture matches with "Freakin Admin (Administrator)"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Security"
    And I check "account_lockout"
    And I block login after "2" maximum attempts
    And I set "24" hours for automatic reactivate account
    And I "disallow" send emails for account reactivation
    And I press "Save"
    And I logout

    When I follow "Login"
    And I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey1"
    And I press "Login"
    Then I should see "Login failed"

    When I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey1"
    And I press "Login"
    Then I should see "Login failed"

    When I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey1"
    And I press "Login"
    Then I should see "Your account has been blocked due to multiple incorrect attempts to login. Please contact the program administrator"

    When I change the account locked at time to 12 hours prior for "rahim@example.com"
    And I follow "Login"
    And I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey"
    And I press "Login"
    Then I should see "Your account has been blocked due to multiple incorrect attempts to login. Please contact the program administrator"

    When I change the account locked at time to 24 hours prior for "rahim@example.com"
    And I follow "Login"
    And I fill in by css "email" with "rahim@example.com"
    And I fill in by css "password" with "monkey"
    And I press "Login"
    Then I should see "Home"