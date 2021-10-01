@wob_steps
Feature: Admin works on behalf of mentor
  In order to perform the above steps
  As an admin
  I want to login and enter the appropriate as required

  Background: Admin logs in
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    Then I enable WOB in "primary"

  @javascript @cross_browser
  Scenario: Admin works on behalf of mentor and checks his inbox and programs listing
    And I follow "Mentors"
    And I follow "Good unique"
    And I follow "Work on Behalf"
    Then I should see "You are currently working on behalf of Good unique name"
    Then wob banner should be shown below Chronus Header
    Then I close all modals
    Then I click ".my_programs_listing_link"
    And I should see program selector containing "Albers Mentor Program" under "Primary Organization"
    And I should see program selector containing "NWEN" under "Primary Organization"
    And I should see program selector containing "Project Based Engagement" under "Primary Organization"
    Then I click ".my_programs_listing_link"

    And I select "Project Based Engagement" from the program selector
    Then I should see "You are currently working on behalf of Good unique name"
    And I select "Albers Mentor Program" from the program selector
    Then I should see "You are currently working on behalf of Good unique name"
    Then I close all modals
    And I select "Primary Organization" from the program selector
    Then I should see "You are currently working on behalf of Good unique name"
    Then I should not see "Manage" within "#side-menu"
    But I should see "Program Overview"
    And I should see "My Programs"
    Then I should not see "Manage" within "#side-menu"
    And I follow "Switch back to Freakin Admin"
    Then I should not see "You are currently working on behalf of Good unique name"

  @javascript
  Scenario: Program Admins works on behalf of an user and moves to other program - he should work on behalf of himself
    Given "ram@example.com" is "student" in "primary":"albers"
    Given "rahim@example.com" is "admin" in "primary":"albers"
    Then I logout
    Given the current program is "primary":"albers"
    And I have logged in as "rahim@example.com"
    Then I follow "Students"
	Then I navigate to "ram@example.com" profile in "albers"
    Then I should not see "Work on Behalf"
    Then I follow "Students"
    Then I follow "rahim user"
    Then I should see "rahim user"
    And I follow "Work on Behalf"
    Then I should see "You are currently working on behalf of rahim user"
    Then wob banner should be shown below Chronus Header
    Then I should not see "My Programs"
    Given the current program is "primary":"nwen"
    Then I should see "You are currently working on behalf of student example"
    Given the current program is "primary":""
    Then I should see "You are currently working on behalf of student example"
    Given the current program is "primary":"albers"
    Then I should see "You are currently working on behalf of rahim user"

@javascript
  Scenario: Wob banner should not be see in other programs
    Given the current program is "foster":"main"
    And I should not see "You are currently working on behalf"
    And I have logged in as "fosteradmin@example.com"
    Then I should see "foster"
    And I should not see "You are currently working on behalf"

@javascript
  Scenario: Admin works on behalf of a mentee and goes to article
    And I follow "Students"
    And Mentees cannot publish article
    And I follow "rahim user"
    And I follow "Work on Behalf"
    Then I should see "rahim user"
    Then I should see "You are currently working on behalf of rahim user"
    Then wob banner should be shown below Chronus Header
    Then I close all modals
    And I follow "Home"
    Then I should not see "Write an article"
    And I try to go to articles page
    Then I should not see "Write new Article"

@javascript
  Scenario: Admin works on behalf of a mentor and goes to article
    And I follow "Mentors"
    And I follow "mentor_a chronus"
    And I follow "Work on Behalf"
    Then I should see "mentor_a chronus"
    Then I should see "You are currently working on behalf of mentor_a chronus"
    Then wob banner should be shown below Chronus Header
    And I try to go to articles page
    And I follow "Write New Article"
    And I scroll and click the element "div#a_media" below my visibility
    And I set the article title to "My new arbit media article"
    And I set the article embed code to "Video"
    And I set the article content to "This is the video comment"
    And I publish the article
    Then I should see "My new arbit media article"
    And I should see "This is the video comment"
    And I should not see "Mark as helpful"
    And I should see the article contributor "mentor_a"

@javascript
  Scenario: Admin works on behalf in a standalone program and sees inbox
    Given the current program is "foster":"main"
    And I have logged in as "fosteradmin@example.com"
    Then I enable WOB in "foster"
    And I follow "Mentors"
    And I follow "Miller Adams"
    And I follow "Work on Behalf"
    Then I should see "You are currently working on behalf of Miller Adams"
    Then wob banner should be shown below Chronus Header
    Then I should see "Messages"

  @javascript
  Scenario: Program Admins works on behalf of an user and should not see mentoring arear feedback form
    Then I logout
    Given the current program is "primary":"albers"
    And I have logged in as "student_2@example.com"
    Then I hover over "My Mentoring Connections"
    Then I follow "chronus & example"
    Then I should see "#connection_inactivity_feedback_form" not hidden
    And I logout
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    And I follow "Students"
    And I follow "student_c example"
    And I follow "Work on Behalf"
    Then I should see "You are currently working on behalf of student_c example"
    Then wob banner should be shown below Chronus Header
    Then I close all modals
    Then I hover over "My Mentoring Connections"
    Then I follow "chronus & example"
    Then I should see "#connection_inactivity_feedback_form" hidden
    Then I logout