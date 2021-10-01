Feature: Subscription Feature

Background: Member did not confirmed terms and conditions accesses program first time
  Given the current program is "primary":""
  And "ram@example.com" not confirmed terms and conditions

@javascript @cross-browser
Scenario: Member should be redirected to terms confirmation
  When I have logged in as "ram@example.com"
  Then I should see "Welcome, Freakin Admin!"
  Then I should not see "Your computer's time zone doesn't match your profile. Stay on top of your meetings and appointments by making them the same. You can also change these settings later through Account Settings."
  And I should see "Please click on 'Accept' below to indicate that you have read and agreed to the Acceptable Use Policy. You are also indicating that you have read the Privacy Policy which also contains information on our use of cookies."
  Then I press "Accept"
  When I logout
  Then I should not see "Welcome, Freakin Admin!"

@javascript @cross-browser @not_run_on_tddium
Scenario: Member should be able to read terms
  When I have logged in as "ram@example.com"
  When I follow "Terms & Conditions"
  Then I should not see "Your computer's time zone doesn't match your profile. Stay on top of your meetings and appointments by making them the same. You can also change these settings later through Account Settings."
  Then I should not see "Welcome, Freakin Admin! You have signed up to join Primary Organization first time."
  And I should see "Terms & Conditions"
  When I follow "Privacy Policy"
  Then I should not see "Welcome, Freakin Admin! You have signed up to join Primary Organization first time."
  

@javascript @cross-browser
Scenario: Member should be able to accept T&C
  When I have logged in as "ram@example.com"
  Then I should see "Welcome, Freakin Admin!"
  And I should see "Please click on 'Accept' below to indicate that you have read and agreed to the Acceptable Use Policy. You are also indicating that you have read the Privacy Policy which also contains information on our use of cookies."
  Then I should not see "Your computer's time zone doesn't match your profile. Stay on top of your meetings and appointments by making them the same. You can also change these settings later through Account Settings."
  And I click "#continue-terms"
  Then I should see "Primary Organization"
  And I should see "Albers Mentor Program"
  And I should see "Moderated Program"

@javascript @cross-browser
Scenario: Member should not be able to visit T&C confirmation page twice
  When I have logged in as "ram@example.com"
  And I click "#continue-terms"
  When I visit "ram@example.com" T&C page
  Then I should not see "Welcome, Freakin Admin!"
