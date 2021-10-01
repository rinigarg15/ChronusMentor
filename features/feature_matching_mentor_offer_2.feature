Feature: Mentor must be able to offer mentoring to mentees

Background: Enable Mentoring Connections V2 Feature
  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  #Then I enable admin audit logs
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I have enabled "mentoring_connections_v2" feature
  And I logout
  And I stub chronus s3 utils

@javascript @matching_scenario @cross_browser
Scenario: A mentor offers mentoring to mentee in group mentoring program in an existing connection where mentee acceptance is required

  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Mentoring Connection Settings"
  And I choose "Group"
  And I press "Save"
  And I follow "Matching Settings"
  And I check "Mentors offer mentoring to students" in ongoing mentoring settings
  And I press "Save"
  Then the disabled "program_mentor_request_style_0" checkbox_id should be checked
  Then the "cjs_offer_mentor_check" checkbox_id should be checked
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I follow "Advanced Options"
  And I choose "program_mentor_offer_needs_acceptance_true"
  And I press "Save"
  And I logout
  Then I have logged in as "mentor_0@example.com"
  Then I follow "Edit Profile"
  And I follow "Settings"
  And I click on the section with header "Ongoing Mentoring"
  And I fill in "Connections Limit" with "5"
  Then I press "Save" within "#settings_section_ongoing"
  And I follow "Students"
  Then I should see "Mentor Studenter"
  And I offer mentoring for "Mentor Studenter" in mentees listing
  Then I should see "Offer mentoring to Mentor Studenter"
  Then I should see "Type an optional message to Mentor Studenter"
  And I fill in "message" with "I would be glad to offer mentoring to you"
  And I press "Offer Mentoring"
  Then I should see "Students"
  Then I should see the flash "Your offer for mentoring has been sent to Mentor Studenter for acceptance"
  And I logout
  And I open new mail
  Then I should see "has offered to be your mentor" in the email body
  And I have logged in as "mentrostud@example.com"
  And I click ".pending_requests_notification_icon"
  And I follow "Mentoring Offers"
  Then I should see "Received Mentoring Offers"
  Then I should see "I would be glad to offer mentoring to you"
  And I "Accept" the offer from "mentor_a chronus"
  Then I should see "Congratulations on your mentoring connection with mentor_a chronus"
  Then I should see "chronus & Studenter"
  Then I should see "Members"
  And I logout
  Then I have logged in as "mentor_0@example.com"
  And I open new mail
  Then I should see "has accepted to be your student" in the email body
  And I follow "Visit mentoring connection area" in the email
  Then I should see "chronus & Studenter"
  Then I should see "Members"
  And I follow "Students"
  Then I should see "rahim user"
  And I offer mentoring for "rahim user" in mentees listing
  Then I should see "Offer mentoring to rahim user"
  Then I should see "Offer Mentoring in"
  Then I should see "Type an optional message to rahim user"
  And I fill in "message" with "I would be glad to offer mentoring to you"
  And I choose "new_connection_existing"
  Then I should see "mentor_a chronus :: Mentor Studenter"
  And I follow "Offer"
  Then I should see "Students"
  Then I should see the flash "Your offer for mentoring has been sent to rahim user for acceptance"
  And I logout
  And I open new mail
  Then I should see "has offered to be your mentor" in the email body
  And I have logged in as "userrahim@example.com"
  And I click ".pending_requests_notification_icon"
  And I follow "Mentoring Offers"
  Then I should see "Received Mentoring Offers"
  Then I should see "I would be glad to offer mentoring to you"
  And I "Accept" the offer from "mentor_a chronus"
  Then I should see "Congratulations on your mentoring connection with mentor_a chronus"
  Then I should see "Members"
  Then I should see "chronus & Studenter"
  And I follow "Messages" within "div#mentoring_area_tabs"
  And I follow "New Message"
  Then I should see "To: Mentor Studenter and mentor_a chronus"
  And I logout
  Then I have logged in as "mentor_0@example.com"
  And I open new mail
  Then I should see "has accepted to be your student" in the email body
  And I follow "Visit mentoring connection area" in the email
  Then I should see "Members"
  Then I should see "chronus & Studenter"

@javascript @matching_scenario @cross_browser
Scenario: A mentor offers mentoring to mentee in one-one program where mentee acceptance is required and admin closes the offer request (bulk mode)

  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Mentoring Connection Settings"
  And I choose "One-on-one"
  And I press "Save"
  And I follow "Matching Settings"
  And I check "Mentors offer mentoring to students" in ongoing mentoring settings
  And I press "Save"
  Then the disabled "program_mentor_request_style_0" checkbox_id should be checked
  Then the "cjs_offer_mentor_check" checkbox_id should be checked
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I follow "Advanced Options"
  And I choose "program_mentor_offer_needs_acceptance_true"
  And I press "Save"
  And I logout
  Then I have logged in as "mentor_0@example.com"
  Then I follow "Edit Profile"
  And I follow "Settings"
  And I click on the section with header "Ongoing Mentoring"
  And I fill in "Connections Limit" with "5"
  Then I press "Save" within "#settings_section_ongoing"
  And I follow "Students"
  Then I should see "Mentor Studenter"
  And I offer mentoring for "Mentor Studenter" in mentees listing
  Then I should see "Offer mentoring to Mentor Studenter"
  Then I should see "Type an optional message to Mentor Studenter"
  And I fill in "message" with "I would be glad to offer mentoring to you"
  And I press "Offer Mentoring"
  Then I should see "Students"
  Then I should see the flash "Your offer for mentoring has been sent to Mentor Studenter for acceptance"
  And I logout
  And I open new mail
  Then I should see "has offered to be your mentor" in the email body
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Mentoring Offers"
  Then I should see "Sender"
  Then I should see "mentor_a chronus"
  Then I should see "Recipient"
  Then I should see "Mentor Studenter"
  And I check "cjs_primary_checkbox"
  And I follow "Actions"
  And I follow "Close Offers"
  Then I should see "Close Offer"
  Then I should see "Reason for closing"
  And I fill in "bulk_actions_reason" with "Closing all offers"
  And I check "sender"
  And I check "recipient"
  And I press "Close Offer"
  Then I should see "The selected offer has been closed."
  And I logout
  And I open the email with subject "Administrator has closed mentor_a chronus's mentoring offer"
  Then I should see "Closing all offers" in the email body
  Then I should see "has been closed by the administrator" in the email body
  When "mentor_0@example.com" opens the email
  Then I should see "Closing all offers" in the email body
  Then I should see "Administrator closed your offer for mentoring" in the email body
  And I have logged in as "mentrostud@example.com"
  And "mentrostud@example.com" opens the email with subject "You have received a new offer for mentoring!"
  And I follow "View Offer" in the email
  Then I should see "Received Mentoring Offers"
  Then I should see "There are no offers for mentoring matching the chosen criteria"

@javascript @matching_scenario
Scenario: A mentor offers mentoring to mentee in one-one program after connection limit

  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Mentoring Connection Settings"
  And I choose "One-on-one"
  And I press "Save"
  And I follow "Matching Settings"
  And I check "Mentors offer mentoring to students" in ongoing mentoring settings
  And I press "Save"
  Then the disabled "program_mentor_request_style_0" checkbox_id should be checked
  Then I should see "There are 15 pending mentoring requests that would be lost on changing this setting. Please close the mentoring requests before proceeding."
  Then the "cjs_offer_mentor_check" checkbox_id should be checked
  Then the "program_can_increase_connection_limit" checkbox_id should be checked
  And I logout
  Then I have logged in as "mentor_0@example.com"
  Then I follow "Edit Profile"
  And I follow "Settings"
  And I click on the section with header "Ongoing Mentoring"
  And I fill in "Connections Limit" with "0"
  Then I press "Save" within "#settings_section_ongoing"
  And I follow "Students"
  Then I should see "Mentor Studenter"
  And I click on connect for "Mentor Studenter" in mentees listing
  Then I should not see "Offer mentoring to Mentor Studenter"
  And I follow "Home"

  Then I follow "Edit Profile"
  And I follow "Settings"
  And I click on the section with header "Ongoing Mentoring"
  And I fill in "Connections Limit" with "1"
  Then I press "Save" within "#settings_section_ongoing"
  And I follow "Students"
  Then I should see "Mentor Studenter"
  And I offer mentoring for "Mentor Studenter" in mentees listing
  Then I should see "Offer mentoring to Mentor Studenter"
  Then I should see "Type an optional message to Mentor Studenter"
  And I fill in "message" with "I would be glad to offer mentoring to you"
  And I press "Offer Mentoring"
  Then I should see "Students"
  Then I should see the flash "Your offer for mentoring has been sent to Mentor Studenter for acceptance"

@javascript @matching_scenario @reindex
Scenario: A mentee tries to accept offer from a Mentor who reached connection limit
  Given the current program is "primary":"albers"
  #Then I reindex model "user"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Mentoring Connection Settings"
  And I choose "One-on-one"
  And I press "Save"
  And I follow "Matching Settings"
  And I check "Mentors offer mentoring to students" in ongoing mentoring settings
  And I press "Save"
  Then the disabled "program_mentor_request_style_0" checkbox_id should be checked
  Then the "cjs_offer_mentor_check" checkbox_id should be checked
  Then the "program_can_increase_connection_limit" checkbox_id should be checked
  And I logout
  Then I have logged in as "mentor_0@example.com"
  Then I follow "Edit Profile"
  And I follow "Settings"
  And I click on the section with header "Ongoing Mentoring"
  And I fill in "Connections Limit" with "1"
  Then I press "Save" within "#settings_section_ongoing"
  And I follow "Students"
  Then I should see "Mentor Studenter"
  And I offer mentoring for "Mentor Studenter" in mentees listing
  Then I should see "Offer mentoring to Mentor Studenter"
  Then I should see "Type an optional message to Mentor Studenter"
  And I fill in "message" with "I would be glad to offer mentoring to you"
  And I press "Offer Mentoring"
  Then I should see "Students"
  Then I should see the flash "Your offer for mentoring has been sent to Mentor Studenter for acceptance"
  And I logout
  And I have logged in as "mentrostud@example.com"
  And I follow "Mentors"
  Then I should see "mentor_a chronus"
  And I follow "mentor_a chronus"
  And I open Actions from profile
  And I hover over the disabled link and should see "Mentor has already reached the mentoring connection limit and currently not available for Ongoing mentoring"