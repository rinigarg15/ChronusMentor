# encoding: utf-8
Feature: Admin adds and drafts users with validations

Background: Admin logs in
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I login as super user
  And clear mail deliveries

@javascript @cross_browser
Scenario: Publication field validations
  When I follow "Manage"
  And I follow "Add Users"
  And I check "role_mentor"
  And I fill in "user_email" with "valid_o'email@iit.com"
  And I click "#cjs_add_user_next"
  And I click on the section with header "Work and Education"
  And I click on the section with header "Mentoring Profile"
  And I fill in "user_member_first_name" with "Weird"
  And I fill in "user_member_last_name" with "EmailMentor"
  # Year blank
  And I fill in publication_question of "primary":"albers" with title "Pub" and date "1,Mar,Year"
  And I press "save_and_add"
  Then I should see "Please fill the highlighted fields with appropriate values to proceed"
  # Year present, and day present, but month blank
  And I fill in publication_question of "primary":"albers" with title "Pub" and date "1,Month,2001"
  And I press "save_and_add"
  Then I should see "Please fill the highlighted fields with appropriate values to proceed"
  # Day blank
  And I fill in publication_question of "primary":"albers" with title "Pub" and date "Day,Feb,2001"
  And I press "save_and_add"
  And I should see the flash "Weird EmailMentor has been added as a Mentor. You can continue adding the next Mentor."
  And a mail should go to "valid_o'email@iit.com" having "You have been invited by Freakin Admin \(Administrator\) to join Albers Mentor Program as a mentor."

@javascript
Scenario: Existing member with admin not having permission
  And I remove member with email "ram@example.com" as global admin
  When I follow "Manage"
  And I follow "Add Users"
  And I check "role_mentor"
  And I fill in "user_email" with "moderated_mentor@example.com"
  And I click "#cjs_add_user_next"
  Then I should not see "Selected user *"
  Then I should see "Moderated Mentor is already present in Primary Organization and you do not have the permission to access the profile and the user. However, you can invite Moderated Mentor by clicking here or request the permission from Primary Organization administrators."
  And I give permission to admins in program "primary":"albers"
  When I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users manually"
  And I check "role_mentor"
  And I fill in "user_email" with "moderated_mentor@example.com"
  And I click "#cjs_add_user_next"
  Then I should see "Selected User *"
  Then I should see "Moderated Mentor"
  And I press "Publish and finish"
  Then I should see "Moderated Mentor has been added as a Mentor."

@javascript
Scenario: Admin trying to add existing suspended member to the track
  And I suspend member with email "moderated_mentor@example.com"
  When I follow "Manage"
  And I follow "Add Users"
  And I check "role_mentor"
  And I fill in "user_email" with "moderated_mentor@example.com"
  And I click "#cjs_add_user_next"
  Then I should not see "Selected user *"
  Then I should see "Moderated Mentor (moderated_mentor@example.com) has been suspended from Primary Organization and cannot be added to the program."
