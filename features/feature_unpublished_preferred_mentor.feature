@javascript @cross-browser
Feature: Preferred mentors - Mentees should see only active preferred mentors where as the admin can see and add unpublished accounts to preferred mentors list. 
Background: 
  Given the current program is "annauniv":"psg"
  Then I maximize the window

Scenario: Change one of the mentors state to pending. Admin adds admin role to a mentee. This mentee adds two mentors to preferred mentors list (including one whose state is set to pending). Now, the mentee should see two people in the preferred mentors list. Now admin removes the admin role for the mentee. Now, when the mentee logs in, he should see only one preferred mentor. If the mentee adds one more mentor, the count should show two instead of three. The same logic sustains in the send a message to mentor page

  # Set one of the mentors state to pending state!
  When I set "mentor3@psg.com" state to pending

  # Admin visits the users page and suspends & removes the users added as preferred mentor
  And I have logged in as "ceg_admin@example.com"
  Then I follow "Manage"
  And I follow "User Views"
  And I add "Admin" role to "stud1@psg.com" from admin users page
  Then I logout

  When I have logged in as "stud1@psg.com"
  And I follow "Mentors"
  And I add "mentor3@psg.com" to preferred mentors list
  And the div "div.cjs_preferred_mentors_box" should have the link with title "PSG mentorc"
  And the div "div.cjs_preferred_mentors_box" should have the link with title "(Remove)"
  And I add "mentor2@psg.com" to preferred mentors list
  And the div "div.cjs_preferred_mentors_box" should have the link with title "PSG mentorb"
  And the div "div.cjs_preferred_mentors_box" should have the link with title "(Remove)"
  Then I follow "Request Mentoring Connection"
  And I should see "PSG mentorc"
  And I should see "PSG mentorb"
  Then I logout