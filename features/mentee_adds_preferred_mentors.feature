@javascript @cross-browser
Feature: Remember search filters

Background: Mentor logs in
  Given the current program is "primary":"modprog"
  Then I maximize the window
  When I have logged in as "moderated_student@example.com"

Scenario: Mentee visits the mentors listing and adds preferred mentor
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I follow "Mentors"
  When I add "moderated_mentor@example.com" to preferred mentors list
  Then I should see "Preferred mentors"
  And the div "div.cjs_preferred_mentors_box" should have the link with title "Moderated Mentor"
  And the div "div.cjs_preferred_mentors_box" should have the link with title "Remove"
  And I should see "Add to preferred mentors" "not present" for "modprog" mentor with email "moderated_mentor@example.com"
  And I should see "Send Message"
  And I follow "Mentors"
  And the div "div.cjs_preferred_mentors_box" should have the link with title "Moderated Mentor"
  And the div "div.cjs_preferred_mentors_box" should have the link with title "Remove"
  And I follow "Remove"
  And I confirm popup
  And I should not see "Preferred mentors"

  # Mentee visits the mentors listing and applies some filters
  Then I fill in "sf_quick_search" with "Moderated Mentor"
  And I press "Go"
  And the text field "sf_quick_search" in "div#quick_search" should have value "Moderated Mentor"
  And I should see "Keyword (Moderated Mentor)"
  And I follow "Moderated Mentor"
  And I press browser back
  And I should see "Keyword (Moderated Mentor)"
  And I follow "Moderated Mentor"
  And I follow "Mentors"
  And I follow "Apply last search"
  And the text field "sf_quick_search" in "div#quick_search" should have value "Moderated Mentor"
  And I should see "Keyword (Moderated Mentor)"
  Then I logout