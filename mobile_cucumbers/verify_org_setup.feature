@javascript
Feature: Verify Organization Page

@javascript
Scenario: Enter Organization URL
  Given I should see in mobile "Enter Your Program URL"
  Then I fill in mobile in "Enter Your Program URL" with "primary.test.host"
  Then I click in mobile on "Get Started"
  Then I should see in mobile "Login"
  Then I fill in mobile in "Email" with "ram@example.com"
  Then I fill in mobile in "Password" with "monkey"
  Then I click in mobile on "Login"
  Then I should see in mobile "Please Reset Your Time Zone"

@javascript
Scenario: Enter Program URL
  Given I should see in mobile "Enter Your Program URL"
  Then I fill in mobile in "Enter Your Program URL" with "primary.test.host/p/albers"
  Then I click in mobile on "Get Started"
  Then I should see in mobile "Login"
  Then I fill in mobile in "Email" with "ram@example.com"
  Then I fill in mobile in "Password" with "monkey"
  Then I click in mobile on "Login"
  Then I should see in mobile "Dashboard"
