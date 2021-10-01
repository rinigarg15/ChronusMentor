@mentor_steps
Feature: Mentor edits profile
  In order to test the features pertaining to the mentor
  As a mentor
  I want to login and enter the appropriate as required

Background: Mentor logs in
  Given the current program is "primary":"albers"
  And I have logged in as "robert@example.com"

@javascript
Scenario: Mentor contacts admin
  When I follow "Contact Administrator"
  And I fill in "admin_message_subject" with "test subject"
  And I fill in "admin_message_content" with "test message"
  Then I press "Send Message"
  And a mail should go to "userram@example.com" having "You have a message"
  And I should see the flash "Your message has been sent to Administrator"

@javascript
Scenario: Mentor should be able to change the notification settings from All to Aggregate and that should not delete educations/experiences
  Given the notifications setting of "robert@example.com" is "all"
  And I click on profile picture and click "Edit Profile"
  Then I follow "Notifications" within "div#mentor_profile"
  And I change the notification setting to "aggregate"
  Then creating a new "mentor" announcement should not trigger a mail to "robert@example.com"
  When I visit the profile of "robert@example.com"
  Then I should see "American boys school"
  And I should see "Science"
  And I should see "Mechanical"
  And I should see "Lead Developer"
  And I should see "Microsoft"

@javascript
Scenario: Mentor logs out
  And I logout
  Given the current program is "primary":"albers"
  Then I should see "There are no pages"
