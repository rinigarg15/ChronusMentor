Feature: User id disallowed to set his previous passwords from a limit set by the admin
  In order to enable the password history feature
  As an admin
  I want to login and enter a non zero value in the security tab of the organization level program settings

  Background: Albers Program
    Given the current program is "primary":""
    When I have logged in as "ram@example.com"
    And I login as super user
    Then I should see "title" attribute for profile picture matches with "Freakin Admin (Administrator)"
    Then I follow "Manage"
    Then I follow "Program Settings"
    Then I follow "Security"
    Then I check "password_history_limit"
    And I fill in "organization_security_setting_attributes_password_history_limit" with "2"
    Then I press "Save"
    And I logout

  @javascript
  Scenario: Mentor tries to change his password with password_history enabled
    And I have logged in as "robert@example.com"
    And I click on profile picture and click "Account Settings"
    And I fill in "member[current_password]" with "monkey"
    And I fill in "member[password]" with "NewPassword"
    And I fill in "member[password_confirmation]" with "NewPassword"
    And I follow "Change"
    Then I should see "Your password has been successfully changed"
    And I click on profile picture and click "Account Settings"
    Then I should see "New password"
    Then I should see "Re-type new password"
    And I fill in "member[current_password]" with "NewPassword"
    And I fill in "member[password]" with "NewPassword"
    And I fill in "member[password_confirmation]" with "NewPassword"
    And I follow "Change"
    Then I should see the flash "Your new password must differ from your last 2 passwords"

  @javascript @cross-browser
  Scenario: Mentor tries to change his password from Forgot Password link
    And I have logged in as "robert@example.com"
    And I click on profile picture and click "Account Settings"
    And I fill in "member[current_password]" with "monkey"
    And I fill in "member[password]" with "NewPassword"
    And I fill in "member[password_confirmation]" with "NewPassword"
    And I follow "Change"
    Then I should see the flash "Your password has been successfully changed"
    And I logout
    And I follow "Login"
    And I follow "Forgot Password?"
    Then I should see "Forgot Your Password?"
    And I fill in "member_email_email" with "robert@example.com"
    And I fill in "captcha" with "IJKKCL"
    And I press "Send Instructions"
    Then a mail should go to "robert@example.com" having "reset your password"
    And I visit the reset password page
    Then I should see "Change Password"
    And I fill in "member_password" with "NewPassword"
    And I fill in "member_password_confirmation" with "NewPassword"
    And I follow "Change"
    Then I should see the flash "Your new password must differ from your last 2 passwords"

    And I fill in "member_password" with "MyPassword"
    And I fill in "member_password_confirmation" with "MyPassword"
    And I follow "Change"
    Then I should see the flash "Your password has been successfully changed"

@javascript @cross-browser
Scenario: User must be prompted to reset the password when it has expired

    When I have logged in as "ram@example.com"
    And I login as super user
    Then I should see "title" attribute for profile picture matches with "Freakin Admin (Administrator)"
    Then I follow "Manage"
    Then I follow "Program Settings"
    Then I follow "Security"
    And I change password to automatically expire after "30" days
    And I press "Save"
    And I logout

    And I expire the password for "robert@example.com" by changing the password updated at to 30 days ago
    And I have logged in as "robert@example.com" without asserting signout
    Then I should see "Your password has expired. Please check your email for instructions to reset your password."
    Then a mail should go to "robert@example.com" having "Your password has expired"
    When I open new mail
    When I follow "Reset Password" in the email
    Then I should see "Change Password"
    And I fill in "member_password" with "monkey"
    And I fill in "member_password_confirmation" with "monkey"
    And I follow "Change"
    Then I should see "Your new password must differ from your last 2 passwords"
    And I fill in "member_password" with "newpassword"
    And I fill in "member_password_confirmation" with "newpassword"
    And I follow "Change"
    Then I should see "Your password has been successfully changed. Please login with your new password."
    Then the "email" field should contain "robert@example.com"
    And I fill in "password" with "newpassword"
    And I press "Login"
    Then I should see "Home"

@javascript @not_run_on_tddium
Scenario: Password must not contain user name or email

    And I have logged in as "mentor_0@example.com"
    And I hover over "my_profile"
    And I click on profile picture and click "Account Settings"
    And I fill in "member[current_password]" with "monkey"
    And I fill in "member[password]" with "NewPassword"
    And I fill in "member[password_confirmation]" with "NewPassword"
    And I follow "Change"
    Then I should see "Your password has been successfully changed"

    And I hover over "my_profile"
    And I click on profile picture and click "Account Settings"
    Then I should see "New password"
    Then I should see "Re-type new password"
    And I fill in "member[current_password]" with "NewPassword"
    And I fill in "member[password]" with "mentor_a chronus"
    And I fill in "member[password_confirmation]" with "mentor_a chronus"
    And I follow "Change"
    Then I should see "New Password should not contain your name or your email address"
    And I fill in "member[current_password]" with "NewPassword"
    And I fill in "member[password]" with "mentor_0@example.com"
    And I fill in "member[password_confirmation]" with "mentor_0@example.com"
    And I follow "Change"
    Then I should see "New Password should not contain your name or your email address"