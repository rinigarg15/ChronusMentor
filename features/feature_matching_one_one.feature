Feature: Creating a one-one mentoring connection between mentor and mentee

Background: Admin enables one-one mentoring

  And I perform missed migrations
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
  And I logout

@javascript @matching_scenario
Scenario: A mentee must be able to connect with a mentor from the listing page

  Given the current program is "primary":"albers"
  And I have logged in as "mentrostud@example.com"
  And I follow "Mentors"
  Then I should see "mentor_a chronus"
  Then I follow "Connect" text for user with email "mentor_0@example.com" in program "primary":"albers"
  Then I follow "Request Mentoring Connection" text for user with email "mentor_0@example.com" in program "primary":"albers"
  Then I should see "Request mentor_a chronus to be my mentor"
  Then I should see "Leave a note"
  And I press "Send request"
  Then I should see "Please fill all the required fields"
  And I fill in "mentor_request_message" with "Request mentoring connection"
  And I press "Send request"
  And I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_a chronus. You will be notified once the mentor accepts your request."
  Then I should see "Basic Information"
  And I open Actions from profile
  And I follow "View your pending request"
  Then I should see "Sent Mentoring Requests"
  Then I should see "mentor_a chronus"
  Then I should see "Request mentoring connection"
  And I logout
  And I open new mail
  Then I should see "You received a new mentoring request from Mentor Studenter" in the email subject
  Then I should see "has requested that you be their mentor" in the email body
  And I have logged in as "mentor_0@example.com"
  And I follow "View Request" in the email
  Then I should see "Received Mentoring Requests"
  And I "Accept request" the request from "Mentor Studenter"
  Then I should see "chronus & Studenter"
  Then I should see "Members"
  Then I should see "Messages"
  And I open new mail
  Then I should see "has accepted your mentoring request" in the email body
  And I follow "Visit mentoring connection area" in the email
  Then I should see "chronus & Studenter"
  Then I should see "Members"

@javascript @matching_scenario @cross_browser
Scenario: Mentee withdraws request after sending request to mentor

  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I follow "Advanced Options"
  And I choose "program_allow_mentee_withdraw_mentor_request_true"
  And I press "Save"
  And I logout
  And I have logged in as "mentrostud@example.com"
  And I follow "Mentors"
  Then I should see "mentor_a chronus"
  Then I follow "Connect" text for user with email "mentor_0@example.com" in program "primary":"albers"
  Then I follow "Request Mentoring Connection" text for user with email "mentor_0@example.com" in program "primary":"albers"
  Then I should see "Request mentor_a chronus to be my mentor"
  Then I should see "Leave a note"
  And I press "Send request"
  Then I should see "Please fill all the required fields"
  And I fill in "mentor_request_message" with "Request mentoring connection"
  And I press "Send request"
  And I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_a chronus. You will be notified once the mentor accepts your request."
  Then I should see "Basic Information"
  And I open Actions from profile
  And I follow "View your pending request"
  Then I should see "Sent Mentoring Requests"
  Then I should see "mentor_a chronus"
  Then I should see "Request mentoring connection"
  And I "Withdraw Request" the request for "mentor_a chronus"
  Then I should see "Withdraw Request"
  And I fill in "mentor_request[response_text]" with "withdrawal message. Sorry about that"
  And I press "Submit"
  Then I should see "Your response has been recorded and mentor_a chronus has been notified about your response"
  And I open new mail
  Then I should see "Mentor Studenter has withdrawn their request for mentoring sent to you" in the email body
  Then I should see "withdrawal message. Sorry about that" in the email body

@javascript @matching_scenario @cross_browser
Scenario: A mentee must be able to send request to mentor using the quick connect box

  Given the current program is "primary":"albers"
  And I have logged in as "mentrostud@example.com"
  And I follow "View Profile"
  Then I should see "0 Ongoing mentoring connections"
  And I follow "Home"
  Then I should see "Featured Mentor Recommendations"
  Then I should see "mentor_a chronus"
  And I click connect from "mentor_a chronus" using quick connect box
  Then I should see "Request mentor_a chronus to be my mentor"
  Then I should see "Leave a note"
  And I press "Send request"
  Then I should see "Please fill all the required fields"
  And I fill in "mentor_request_message" with "Request mentoring connection"
  And I press "Send request"
  And I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_a chronus. You will be notified once the mentor accepts your request."
  Then I should see "Basic Information"
  And I open Actions from profile
  And I follow "View your pending request"
  Then I should see "Sent Mentoring Requests"
  Then I should see "mentor_a chronus"
  Then I should see "Request mentoring connection"
  And I logout
  And I open new mail
  Then I should see "You received a new mentoring request from Mentor Studenter" in the email subject
  Then I should see "has requested that you be their mentor" in the email body
  And I have logged in as "mentor_0@example.com"
  And I follow "View Request" in the email
  Then I should see "Received Mentoring Requests"
  And I "Accept request" the request from "Mentor Studenter"
  Then I should see "chronus & Studenter"
  Then I should see "Members"
  Then I should see "Messages"
  And I open new mail
  Then I should see "has accepted your mentoring request" in the email body
  And I follow "Visit mentoring connection area" in the email
  Then I should see "chronus & Studenter"
  Then I should see "Members"

@javascript @matching_scenario @reindex @cross_browser
Scenario: A mentee filters mentors from listing page, sorts by matching score and sends request

  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Customize"
  Then I should see "Customize User Profile Fields"
  And I open section with header "Mentoring Profile"
  When I scroll the div ".cjs-profile-question-slim-scroll"
  And I click on profile question with question text "Language"
  Then I should see "Name"
  Then I should see "Type"
  Then I should see "Choices"
  Then I follow "Roles"
  Then I click edit advanced options
  Then I should see "Visibility"
  Then I should see "Options"
  Then the "Available for advanced search" checkbox_id should be checked
  And I follow "Mentors"
  And I follow "More filters"
  Then I should see "Language"
  Then I open filter with header "Language"
  And I check "French"
  Then I should not see "mentor_a chronus"
  And I follow "Mentors"
  Then I follow "mentor_a chronus"
  And I follow "Work on Behalf"

  Then I should see "mentor_a chronus"
  Then I should see "You are currently working on behalf of mentor_a chronus"
  And I follow "Edit Profile"
  And I click on the section with header "Mentoring Profile"
  And I scroll to bottom of page
  Then I should see "Language"
  And I check "French"
  And I save section with header "Mentoring Profile"
  And I logout
  And I have logged in as "mentrostud@example.com"
  And I follow "Mentors"
  Then I should see "Availability Status"
  Then I filter a mentor with name "Kal Raman" using quick find
  Then I should see "Showing 1 - 1 of 1"
  And I should see "Kal Raman"
  And I follow "Mentors"
  And I follow "More filters"
  Then I should see "Language"
  Then I open filter with header "Language"
  And I check "French"
  Then I should see "mentor_a chronus"
  And I follow "Mentors"
  And I select "Name (Z-A)" from "sort_by"
  Then I should not see "Kal Raman"
  And I select "Match Score (High to Low)" from "sort_by"
  Then I should see "mentor_a chronus"
  Then I follow "Connect" text for user with email "mentor_0@example.com" in program "primary":"albers"
  Then I follow "Request Mentoring Connection" text for user with email "mentor_0@example.com" in program "primary":"albers"
  Then I should see "Request mentor_a chronus to be my mentor"
  Then I should see "Leave a note"
  And I press "Send request"
  Then I should see "Please fill all the required fields"
  And I fill in "mentor_request_message" with "Request mentoring connection"
  And I press "Send request"
  And I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_a chronus. You will be notified once the mentor accepts your request."
  Then I should see "Basic Information"
  And I open Actions from profile
  And I follow "View your pending request"
  Then I should see "Sent Mentoring Requests"
  Then I should see "mentor_a chronus"
  Then I should see "Request mentoring connection"
  And I logout
  And I open new mail
  Then I should see "You received a new mentoring request from Mentor Studenter" in the email subject
  Then I should see "has requested that you be their mentor" in the email body
  And I have logged in as "mentor_0@example.com"
  And I follow "View Request" in the email
  Then I should see "Received Mentoring Requests"
  And I "Accept request" the request from "Mentor Studenter"
  Then I should see "chronus & Studenter"
  Then I should see "Members"
  Then I should see "Messages"
  And I open new mail
  Then I should see "has accepted your mentoring request" in the email body
  And I follow "Visit mentoring connection area" in the email
  Then I should see "chronus & Studenter"
  Then I should see "Members"

@javascript @matching_scenario @cross_browser
Scenario: Searching mentors using filters having special characters.
  Given the current program is "foster":"main"
  Then I perform missed migrations  
  And I have logged in as "fosteradmin@example.com"
  And I follow "Manage"
  And I follow "Customize"
  And I open section with header "Mentoring Profile"
  And I click on add new question
  And I fill in "profile_question_text_0" with "New Mentor Field"
  And I select "Pick one answer" from "profile_question_question_type_0"
  And I should not see "allow_multiple"
  And I add choices "(bracket),pipe|,at@"
  When I scroll the div ".cjs-side-panel-slim-scroll"
  And I press "Save" within "form#edit_profile_question_"
  Then I wait for ajax to complete
  And I check "Mentor"
  Then I wait for ajax to complete
  And I follow "Mentors"
  And I should see "Miller Adams"
  And I follow "More filters"
  Then I should see "New Mentor Field"
  Then I open filter with header "New Mentor Field"
  And I check "pipe|"
  And I should see "No mentors found matching your criteria."

@javascript @matching_scenario
Scenario: Mentor rejects the request from mentee

  Given the current program is "primary":"albers"
  And I have logged in as "mentrostud@example.com"
  And I follow "Mentors"
  Then I should see "mentor_a chronus"
  Then I follow "Connect" text for user with email "mentor_0@example.com" in program "primary":"albers"
  Then I follow "Request Mentoring Connection" text for user with email "mentor_0@example.com" in program "primary":"albers"
  Then I should see "Request mentor_a chronus to be my mentor"
  Then I should see "Leave a note"
  And I press "Send request"
  Then I should see "Please fill all the required fields"
  And I fill in "mentor_request_message" with "Request mentoring connection"
  And I press "Send request"
  And I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_a chronus. You will be notified once the mentor accepts your request."
  Then I should see "Basic Information"
  And I open Actions from profile
  And I follow "View your pending request"
  Then I should see "Sent Mentoring Requests"
  Then I should see "mentor_a chronus"
  Then I should see "Request mentoring connection"
  And I logout
  And I open new mail
  Then I should see "You received a new mentoring request from Mentor Studenter" in the email subject
  Then I should see "has requested that you be their mentor" in the email body
  And I have logged in as "mentor_0@example.com"
  And I follow "View Request" in the email
  Then I should see "Received Mentoring Requests"
  And I follow "Actions"
  And I follow "Decline request"
  Then I fill in "mentor_request[response_text]" with "Sorry I wont be able to make it "
  Then I choose the value "1" for "mentor_request[rejection_type]"
  Then I should see "Your message will be mailed to the user. The reason selected from the list above will not."
  And I press "Submit"
  Then I should see "Thank you for your response. Mentor Studenter has been notified."
  And I logout
  And I open new mail
  Then I should see "was unable to accept your request for mentoring" in the email body
  And I have logged in as "mentrostud@example.com"
  And I follow "View more Mentors" in the email
  Then I should see "Mentors"