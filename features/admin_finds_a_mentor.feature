@javascript @cross_browser
Feature: Find a Mentor option in student list
In order to perform the above steps
As an admin
I want to login and enter the appropriate as required

Scenario: Logged in admin finds a mentor
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  Then I follow "Students"
  Then I follow "Actions" in the users listing
  Then I should see "Send Message"
  Then I should see "Find a Mentor"
  Then I check "filter_unconnected_mentees"
  Then I follow "Actions" in the users listing
  Then I should see "Send Message"
  Then I should see "Find a Mentor"
  Then I uncheck "filter_unconnected_mentees"
  Then I check "filter_connected_mentees"
  Then I follow "Actions" in the users listing
  Then I should see "Find a Mentor"
  Then I uncheck "filter_connected_mentees"
  Then I check "filter_unconnected_mentees"
  Then I follow "Actions" in the users listing
  Then I follow "Find a Mentor"
  Then I should see "Selected Student"
  Then I logout

@javascript
Scenario: List only mentors with ongoing or one_time_and_ongoing mentoring mode
  Given the current program is "primary":"modprog"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"modprog"
  When I have logged in as "moderated_admin@example.com"
  When I login as super user
  And I follow "Manage"
  Then I follow "Program Settings"
  Then I follow "Matching Settings"
  Then I check "program_allow_mentoring_mode_change"
  And I press "Save"
  Then I follow "Students"
  And I follow "Actions" in the users listing
  Then I follow "Find a Mentor"
  Then I should see "Moderated Mentor"
  Then I should not see "Good unique name"