@javascript
Feature: AP 1365 - Preferred mentors issue

Background:
  Given the current program is "annauniv":"psg"
  Then I maximize the window

@cross-browser
Scenario: Mentee visits the mentors listing and adds preferred mentors. Admin removes one and suspends one mentor. Mentee should not see the suspended or removed mentor in his preferred mentors list

  When I have logged in as "stud1@psg.com"
  And I follow "Mentors"
  And I add "mentor3@psg.com" to preferred mentors list
  Then I should see the flash "You have 1 preferred mentor. Send a request to administrator for mentor assignment or continue adding mentors"
  And the div "div.cjs_preferred_mentors_box" should have the link with title "PSG mentorc"
  And the div "div.cjs_preferred_mentors_box" should have the link with title "Remove"
  When I follow "Request Mentoring Connection" within "div#sidebarRight"
  And I should see "PSG mentorc"

  And I follow "Mentors"
  Then I filter a mentor with name "PSG Remove" using quick find
  And I add "remove@psg.com" to preferred mentors list
  And the div "div.cjs_preferred_mentors_box" should have the link with title "PSG Remove"
  And the div "div.cjs_preferred_mentors_box" should have the link with title "Remove"
  When I follow "Request Mentoring Connection"
  Then I should see "PSG Remove"
  And I should see "PSG mentorc"

  And I should see "Select Mentor"
  When I click ".cjs_name_text_box input"
  Then I should see ".cjs_preferred_list" hidden

  And I follow "Remove"
  Then I should not see "PSG mentorc"
  When I click ".cjs_name_text_box input"
  Then I should see "PSG mentorc" within ".cjs_autocomplete_textarea"
  Then I select user with email "mentor3@psg.com" from dropdown in "annauniv":"psg" program
  Then I should see "PSG mentorc"

  And I should see "PSG Remove"
  And I should see ".m-r-xs" hidden
  And I should see "PSG Remove" hidden
  And I should see "PSG mentorc" hidden
  And I should see "Select Mentor"
  And I click ".cjs_name_text_box input"
  And I should see "PSG mentorc"
  # TODO: how to check the remove created is for the newly added mentor but not for the previous mentor!
  Then I logout

  # Admin visits the users page and suspends & removes the users added as preferred mentor
  And I have logged in as "ceg_admin@example.com"
  Then I follow "Manage"
  And I follow "User Views"
  And I suspend "mentor3@psg.com" from admin users page
  Then I wait for ajax to complete
  Then I should see "The selected users membership have been deactivated from the program."
  Then I close the flash
  And I remove "remove@psg.com" from admin users page
  Then I should see "The selected users have been removed from the program successfully"
  Then I logout

  # When the user logs in again, he should not see suspended / removed users in the list
  When I have logged in as "stud1@psg.com"
  And I follow "Mentors"
  Then I should not see "Preferred mentors"
  And I add "mentor1@psg.com" to preferred mentors list
  Then I should see "You have 1 preferred mentor."
  Then I should see "Preferred mentors"
  And the div "div.cjs_preferred_mentors_box" should have the link with title "PSG mentora"
  And the div "div.cjs_preferred_mentors_box" should have the link with title "Remove"
  When I follow "Request Mentoring Connection" within "div#sidebarRight"
  And I click ".cjs_name_text_box input"
  And I wait for ajax to complete
  Then I should see "PSG mentora"
  And I should not see "PSG Remove"
  And I should not see "PSG mentorc"
  And I click ".cjs_name_text_box input"
  And I wait for ajax to complete

  And I press "Send request"
  And I should see "Please fill all the required fields. Fields marked * are mandatory"
  Then I close the flash
  And I fill in "Your message *" with "request"
  And I press "Send request"
  And I should see "Your request has been sent to administrator and you will be notified once a mentor is assigned"
  And I click ".pending_requests_notification_icon"
  And I follow "Mentoring Requests"
  Then I should see "PSG mentora"
  Then I should see "request"
  Then I logout

@javascript @matching_scenario @cross-browser
Scenario: Admin trying to assign a Mentor who reached limit
  When I have logged in as "stud1@psg.com"
  And I follow "Mentors"
  And I fill in "query" with "mental"
  And I search
  And I add "mentor@psg.com" to preferred mentors list
  Then I follow "Send a request"
  And I should see "mental mentor"
  Then I fill in "mentor_request_message" with "Test Request"
  Then I press "Send request"
  Then I should see "Your request has been sent to administrator"
  Then I logout
  When I have logged in as "stud3@psg.com"
  And I follow "Mentors"
  And I fill in "query" with "mental"
  And I search
  And I add "mentor@psg.com" to preferred mentors list
  Then I follow "Send a request"
  And I should see "mental mentor"
  Then I fill in "mentor_request_message" with "Test Request"
  Then I press "Send request"
  Then I should see "Your request has been sent to administrator"
  Then I logout
  When I have logged in as "ceg_admin@example.com"
  And I change maximum connections limit of mentor with email "mentor@psg.com" in program "annauniv":"psg" to "1"
  Then I follow "Manage"
  Then I follow "Mentoring Requests"
  Then I assign mentor to both mentees
  Then I should see "mental mentor preferred not to have more than 1 students"
  Then I follow "Cancel"

@javascript @cross-browser
Scenario: Admin enables/disables preferred mentoring
  When I have logged in as "ceg_admin@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  Then element with id "#program_mentor_request_style_1" should not be disabled
  And the "program_mentor_request_style_1" checkbox_id should be checked
  And I should see element "#program_mentor_request_style_0"
  When I follow "Advanced Options"
  Then I should see the radio button "program_allow_preference_mentor_request_true" selected
  Then I should see "No limit" selected from "#program_min_preferred_mentors"
  When I click "#program_allow_preference_mentor_request_false"
  Then I should not see element "#program_min_preferred_mentors"

  When I click "#program_mentor_request_style_0"
  Then the "program_mentor_request_style_1" checkbox_id should not be checked
  When I follow "Advanced Options"
  Then I should not see element "#program_allow_preference_mentor_request_false"
  And I should not see element "#program_min_preferred_mentors"

  When I click "#program_mentor_request_style_1"
  Then the "program_mentor_request_style_0" checkbox_id should not be checked
  When I follow "Advanced Options"
  Then I should see the radio button "program_allow_preference_mentor_request_true" selected
  And I should see element "#program_mentor_request_style_0"
  Then I select "1 mentor" from "program_min_preferred_mentors"
  And I press "Save"

  Then I should see the flash "Your changes have been saved"
  And the "program_mentor_request_style_1" checkbox_id should be checked
  When I follow "Advanced Options"
  Then I should see the radio button "program_allow_preference_mentor_request_true" selected
  Then I should see "1 mentor" selected from "#program_min_preferred_mentors"
  Then I logout

  When I have logged in as "stud1@psg.com"
  And I follow "Mentors"
  And I add "mentor3@psg.com" to preferred mentors list
  Then I should see the flash "You have 1 preferred mentor. Send a request to administrator for mentor assignment or continue adding mentors"
  And the div "div.cjs_preferred_mentors_box" should have the link with title "PSG mentorc"
  And the div "div.cjs_preferred_mentors_box" should have the link with title "Remove"
  When I follow "Request Mentoring Connection" within "div#sidebarRight"
  And I fill in "Your message *" with "request"
  And I press "Send request"
  And I should see the flash "Your request has been sent to administrator and you will be notified once a mentor is assigned."
  Then I logout

  When I have logged in as "ceg_admin@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  Then the disabled "program_mentor_request_style_1" checkbox_id should be checked
  And I should see "There is a pending mentoring request that would be lost on changing this setting. Please close the mentoring request before proceeding."
  And element with id "#program_mentor_request_style_0" should be disabled
  And the "program_mentor_request_style_0" checkbox_id should not be checked
  When I follow "Advanced Options"
  Then I should see the radio button "program_allow_preference_mentor_request_true" selected
  Then I should see "1 mentor" selected from "#program_min_preferred_mentors"
  And element with id "#program_min_preferred_mentors" should not be disabled
  Then I logout

  When I have logged in as "stud1@psg.com"
  And I follow "Mentors"
  Then I follow "Request Mentoring Connection"
  And I fill in "Your message *" with "request"
  And I press "Send request"
  And I should see the flash "Your request has been sent to administrator and you will be notified once a mentor is assigned."
  Then I logout