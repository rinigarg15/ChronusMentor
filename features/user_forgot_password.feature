@forgot_password
@javascript
Feature: Admin forgets the password
  In order to receive the mail
  As an Admin
  I want to fill in the appropriate details

  Scenario: Forgot Password
    Given the current program is "primary":"albers"
    And I follow "Login"
    And I follow "Forgot Password?"
    Then I should see "Forgot Your Password?"
    And I fill in "member_email_email" with "ram@example.com"
    And I fill in "captcha" with "IJKKCL"
    And I press "Send Instructions"
    Then a mail should go to "ram@example.com" having "reset your password"
    And I visit the reset password page
    Then I should see "Change Password"
    And I fill in "member_password" with ""
    And I fill in "member_password_confirmation" with ""
    And I follow "Change"
    Then I should see the flash "Required fields cannot be blank"
    Then I should see "Change Password"
    And I fill in "member_password" with "abcdef"
    And I fill in "member_password_confirmation" with "fcedba"
    And I follow "Change"
    Then I should see the flash "Required fields cannot be blank"
    Then I should see "Change Password"
    And I fill in "member_password" with "abcdef"
    And I fill in "member_password_confirmation" with "abcdef"
    And I follow "Change"
    # Flash
    Then I should see "Login"

    Then the "email" field should contain "ram@example.com"
    When I fill in "email" with "ram@example.com"
    And I fill in "password" with "abcdef"
    And I press "Login"
    Then I should see "Dashboard"
    And I should not see "Invalid reset code"