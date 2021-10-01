# encoding: utf-8
@javascript @cross-browser
Feature: Drafted connections labels for users

Background: Admin is logged in
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector

Scenario: Admin sees label
  And I select "Albers Mentor Program" from the program selector
  And I follow "Mentors"
  Then I filter a mentor with drafted connections using quick find
  Then I should see "robert user 1 drafted mentoring connection"
  When I follow "1 drafted mentoring connection"
  Then I should see "Drafted" within ".inner_tabs"

Scenario: User does not see label
  And I logout
  When I have logged in as "mkr@example.com"
  And I follow "Mentors"
  Then I filter a mentor with drafted connections using quick find
  And I remove the status filter
  Then I should see "robert user"
  And I should not see "robert user 1 drafted mentoring connection"