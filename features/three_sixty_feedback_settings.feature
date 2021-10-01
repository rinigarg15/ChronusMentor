@javascript @cross-browser
Feature: Admin adding/modifying Reviewer Groups

Background: Admin logs in and enabled Required Features
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"  
  And I enable "three_sixty" feature as a super user
  
Scenario: Admin adding new reviewer Group
  And I follow "Manage"
  And I follow "360 Degree Survey Tool"
  And I follow "Settings"
  And I fill in "three_sixty_reviewer_group_name" with "Line Manager"
  Then I press "Add"
  Then I should see "Reviewer Group already exists."
  And I fill in "reviewer_group_threshold" with "text"
  Then I press "Add"
  Then I should see "Reviewer Group already exists and threshold must be a number greater than or equal to 0."
  And I fill in "three_sixty_reviewer_group_name" with "Product Manager"
  Then I press "Add"
  Then I should see "Threshold must be a number greater than or equal to 0."
  Then I fill in "reviewer_group_threshold" with "1"
  Then I press "Add"
  Then I should see "Product Manager"
  #Validate
  Then I follow "Surveys"
  And I follow "Edit"
  Then I fill in "Product Manager" as reviewer group
  Then I should see "Product Manager"
  And I press "Proceed to Questions"
  Then I logout

Scenario: Admin deleting existing Reviewer Group
  And I follow "Manage"
  And I follow "360 Degree Survey Tool"
  And I follow "Settings"
  Then I delete a reviewer group
  And I should see "Are you sure you want to delete the reviewer group?"
  Then I confirm popup
  And I should not see "Line Manager"
  Then I logout

Scenario: Admin editing existing Reviewer Group
  And I follow "Manage"
  And I follow "360 Degree Survey Tool"
  And I follow "Settings"
  Then I edit the reviewer group "Peer" with "Line Manager" and "0" in "primary"
  Then I should see "Reviewer Group already exists."
  Then I update the reviewer group "Peer" with "Line Manager" and "text" in "primary"
  Then I should see "Reviewer Group already exists and threshold must be a number greater than or equal to 0."
  Then I update the reviewer group "Peer" with "Reep" and "text" in "primary"
  Then I should see "Threshold must be a number greater than or equal to 0."
  Then I update the reviewer group "Peer" with "Reep" and "7" in "primary"
  Then I should see "Reep"
  Then I should not see "Peer"
  Then I logout