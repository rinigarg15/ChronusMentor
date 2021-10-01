@javascript @p2 @cross-browser
Feature: Adding/Deleting Tags to Mentors/Mentee

  Background: Set the program to albers
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And I enable "member_tagging" feature as a super user
  When I hover over "my_programs_container"
  And I select "Albers Mentor Program" from the program selector

  Scenario: Add tag to a mentor
  #Add Tag for mentee
  And I follow "Students"
  And I follow "arun albers"
  Then I follow "Add tags for this member"
  When I enter autocomplete with "tag3"
  Then I press "Save"
  Then I should see "tag3"

  # #Edit Tag
  And I follow "Edit"
  When I enter autocomplete with "tag1"
  Then I press "Save"
  Then I should see "tag3"
  Then I should see "tag1"

  #Add Tag for mentor
  Then I follow "Mentors"
  And I follow "mentor_c chronus"
  Then I follow "Add tags for this member"
  When I enter autocomplete with "tag3"
  Then I press "Save"
  Then I should see "tag3"

  #Delete Tag
  Then I should not see "Not yet tagged."
  And I follow "Edit"
  Then I remove tag
  And I press "Save"
  Then I should see "Not yet tagged."