@back_mark
Feature: Back mark behaviour

Background: Mentor logs in
  Given the current program is "primary":"albers"
  When I have logged in as "rahim@example.com"

@javascript
Scenario: One level of back link history
  And I try to go to articles page
  And I click on profile picture and click "Contact Administrator"
  Then I fill in "admin_message_subject" with "Work towards your goals"
  Then I fill in "admin_message_content" with "Start working right away"
  And I press "Send Message"
  # Should not go back to the contact admin form. Should be taken to articles listing page.
  Then I should see the page title "Articles"

@javascript
Scenario: Two levels of back link history
  And I try to go to articles page
  And I follow "Mentors"
  And I follow "Contact Administrator"
  Then I fill in "admin_message_subject" with "Work towards your goals"
  Then I fill in "admin_message_content" with "Start working right away"
  And I press "Send Message"
  # Should not go back to the Ask a Question page or articles listing. Should take to mentors listing form.
  Then I should see the page title "Mentors"