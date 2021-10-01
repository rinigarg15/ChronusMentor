# encoding: utf-8
@sub_programs
Feature: Non-Loggedin access to sub programs
  Non-loggedin users should be able to visit program and sub program 
  And request to join the sub-programs there

Background:
  Given "annauniv":"ceg" has the custom page "About CEG 1"
  And "annauniv":"ceg" has the custom page "About CEG 2"
  And "annauniv":"psg" has the custom page "About PSG"
  And "Program" "term" is called as "Community" in "annauniv"
  And "Program" "pluralized_term" is called as "Communities" in "annauniv"
  And "Program" "term_downcase" is called as "community" in "annauniv"
  And membership questions are not mandatory in "ceg"

Scenario: User visits sub program home page and joins a sub program
  Given the current program is "annauniv":"ceg"
  Then I should see the program title "CEG Mentor Program"
  And I should see "About CEG 2" within "#navbar .nav-tabs"
  And I should see "Anna University" within "#navbar .nav-tabs"
  But I should not see "About PSG" within "#navbar .nav-tabs"

@javascript @enrollment_scenario
Scenario: Show parent program only to program admins if there is only one subprogram
  Given the current program is "annauniv":"psg"
  When I have logged in as "psg@example.com"
  Then I should not be shown program selector
  # Org name
  But I should not see "CEG Mentor Program"

  # Program admin
  When I logout
  And I have logged in as "ceg_admin@example.com"
  Then I should see the program title "psg"
  And I click ".my_programs_listing_link"
  And I should see program selector containing "CEG Mentor Program" under "Anna University"
  And I should see program selector containing "psg" under "Anna University"

@javascript @enrollment_scenario
Scenario: User of one subprogram cannot join other sub program without login
  Given the current program is "annauniv":"psg"
  And I have logged in as "mentor1@psg.com"
  And I logout

  When the current program is "annauniv":"ceg"
  When I want to join as "Student" with "mentor1@psg.com"
  Then I click on the login link sent in email meant for existing users to "mentor1@psg.com"
  And I sign in as "mentor1@psg.com"
  Then I should see "Your request has been sent to the community administrators. You will receive an email once the request is accepted."