@javascript @p2 @cross-browser
Feature: Checking for the existence of at least one Education/Experience fields in case of mandatory

Scenario: Admin populate mandatory edu/exp questions and checking in all places for the existence condition
  Given the current program is "primary":""
  Then I perform missed migrations
  When I have logged in as "ram@example.com"
  Given there are some mandatory multiple experience fields
  Then I follow "Manage"
  And I follow "Add Users"
  And I check "role_mentor"
  And I fill in "user_email" with "user@chronus.com"
  And I click "#cjs_add_user_next"
  Then I should see "Basic Information"
  Then I click on the section with header "Mentoring Profile"
  Then I should see "Photo"
  Then I should see "enter link to picture"
  Then I click on the section with header "Work and Education"
  Then I remove mandatory experience field
  Then I remove non-mandatory education field
  And I logout 
  Then I have logged in as "request@example.com"
  Then I should see "New mandatory fields have been added to the Work and Education section of the profile. Please fill them out to complete your profile."
  Then I should see "Update Your Profile"
  And I fill in last experience_question of "primary":"" with "Correct,Test"
  Then I press "Save & Proceed"

  And I follow "Edit Profile"
  Then I click on the section with header "Work and Education"
  Then I remove mandatory experience field
  Then I remove non-mandatory education field
  Given I visit "request@example.com" first time profile completion in "primary":"albers"
  And I press "Proceed" within "#general_profile"
  Then I remove non-mandatory education field
  Then I logout
  Given the current program is "primary":"albers"
  When I want to join as "Mentor" with "example@chronus.com"
  Then I click on the signup link sent in email to "example@chronus.com"
  Then I remove mandatory experience field 
