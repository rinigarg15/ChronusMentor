@javascript
Feature: Accept and Reject mentor requests
In order to perform the above steps
As an Mentor
I want to login and enter the appropriate as required

Background:
 Given the current program is "primary":"albers"
 Given there is one to many in "primary":"albers"

@javascript @p2
Scenario: Admin setting the Mentor Request Instructions
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  Then I follow "Customize Mentoring Request Form"
  Then I should see "Instructions for the student while sending mentoring request"
  Then I should see "Leave a note for the mentor about what you are looking for. The request can be seen only by the mentor and the program administrators." in the ckeditor "mentor_request_instruction_content"
  Then I fill in CKEditor "mentor_request_instruction_content" with "Why do you choose this mentor?"
  Then I press "Save"
  Then I should see "The instructions have been succesfully updated"
  Then I logout
  When I have logged in as "student_14@example.com"
  Then I follow "Mentors"
  When I navigate to "mentor_1@example.com" profile in "albers"
  Then I follow "Actions"
  And I follow "Request Mentoring Connection"
  Then I should see "Why do you choose this mentor?"
  Then I logout

@matching_scenario @cross-browser
Scenario: Accept Message popup after mentor accepts a connection request.
  When I have logged in as "student_14@example.com"
  Then I follow "Mentors"
  When I navigate to "mentor_1@example.com" profile in "albers"
  Then I follow "Actions"
  And I follow "Request Mentoring Connection"
  Then I should see the placeholder text "Example: Hi, I am reaching out to you because I am looking for guidance in the areas that you have experience. If you also think we would be a good fit, I'd be excited to partner with you!" in "#mentor_request_message"
  Then I fill in "mentor_request_message" with "please be my mentor"
  Then I press "Send request"
  Then I logout
  When I have logged in as "mentor_1@example.com"
  And I click ".pending_requests_notification_icon"
  Then I follow "Mentoring Requests"
  Then I follow "Actions"
  Then I follow "Accept request"
  Then I press "Create"
  And I should see "You are successfully connected"
  And I should see "You are currently mentoring 5 users and cannot accept requests from more. Change"
  Then I follow "Change"
  And I wait for "1" seconds
  And I should see "Connections Limit"
  And I fill in "Connections Limit" with "7"
  And I click "#submit_ongoing_settings"
  And I logout
  When I have logged in as "student_13@example.com"
  Then I follow "Mentors"
  When I navigate to "mentor_1@example.com" profile in "albers"
  Then I follow "Actions"
  And I follow "Request Mentoring Connection"
  Then I fill in "mentor_request_message" with "please be my mentor"
  Then I press "Send request"
  Then I logout
  When I have logged in as "mentor_1@example.com"
  And I click ".pending_requests_notification_icon"
  Then I follow "Mentoring Requests"
  Then I follow "Actions"
  Then I follow "Accept request"
  Then I press "Add"
  And I should see "You are currently mentoring 6 users and can accept requests from 1 more. Change"
  And I logout

@matching_scenario @cross-browser
Scenario: Logged in mentor accepts a mentee and creates new connection
  When I have logged in as "student_14@example.com"
  Then I follow "Mentors"
  When I navigate to "mentor_1@example.com" profile in "albers"
  Then I follow "Actions"
  And I follow "Request Mentoring Connection"
  Then I fill in "mentor_request_message" with "please be my mentor"
  Then I press "Send request"
  And I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_b chronus. You will be notified once the mentor accepts your request."
  Then I logout
  When I have logged in as "mentor_1@example.com"
  And I click ".pending_requests_notification_icon"
  Then I follow "Mentoring Requests"
  Given I follow "Accept" for the group "results_pane"
  Then I press "Create"
  Then I logout

@matching_scenario @cross-browser
Scenario: Logged in mentor accepts a mentee and adds to an existing connection
  When I have logged in as "student_14@example.com"
  Then I follow "Mentors"
  When I navigate to "mentor_1@example.com" profile in "albers"
  Then I follow "Actions"
  And I follow "Request Mentoring Connection"
  Then I fill in "mentor_request_message" with "please be my mentor"
  Then I press "Send request"
  And I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_b chronus. You will be notified once the mentor accepts your request."
  Then I logout
  When I have logged in as "mentor_1@example.com"
  And I click ".pending_requests_notification_icon"
  Then I follow "Mentoring Requests"
  Given I follow "Accept" for the group "results_pane"
  Then I press "Add"
  Then I logout

@matching_scenario @cross-browser
Scenario: Logged in mentor rejects a mentee
  When I have logged in as "student_14@example.com"
  Then I follow "Mentors"
  When I navigate to "mentor_1@example.com" profile in "albers"
  Then I follow "Actions"
  And I follow "Request Mentoring Connection"
  Then I fill in "mentor_request_message" with "please be my mentor"
  Then I press "Send request"
  And I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_b chronus. You will be notified once the mentor accepts your request."
  Then I logout
  When I have logged in as "mentor_1@example.com"
  And I click ".pending_requests_notification_icon"
  Then I follow "Mentoring Requests"
  Given I follow "Decline" for the group "results_pane"
  Then I close modal
  Given I follow "Decline" for the group "results_pane"
  Then I fill the last mentor request request text with "Test Reject"
  Then I choose the value "1" for "mentor_request[rejection_type]"
  Then I press "Submit"
  # This is the flash message after rejection
  Then I should see "Thank you for your response. student_o example has been notified"

@javascript @matching_scenario
Scenario: Mentee trying to request a Mentor who chose One-Time Mentoring only
  Given the current program is "primary":"albers"
  Given I have logged in as "ram@example.com"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I change engagement type of program "primary":"albers" to "career based and ongoing"
  And I follow "Manage"
  Then I follow "Program Settings"
  Then I follow "Matching Settings"
  Then I check "program_allow_mentoring_mode_change"
  And I press "Save"
  And I change mentoring mode of mentor with email "mentor_3@example.com" in program "primary":"albers" to "one time"
  Then I logout
  When I have logged in as "student_14@example.com"
  When I navigate to "mentor_3@example.com" profile in "albers"
  Then I follow "Actions"
  And I should see disabled "Request Mentoring Connection"
  And I hover over the disabled link and should see "Mentor is not available for ongoing mentoring."

@javascript @matching_scenario
Scenario: Mentor trying to accept beyond connection limit
  Given the current program is "primary":"albers"
  Given the current program admin has connection_limit_permission NONE
  Given I have logged in as "ram@example.com"
  And I change maximum connections limit of mentor with email "robert@example.com" in program "primary":"albers" to "1"
  Then I logout
  Given I have logged in as "robert@example.com"
  Then I follow "Home"
  And I click ".pending_requests_notification_icon"
  Then I follow "Mentoring Requests"
  Given I follow "Accept" for the group "results_pane"
  Then I press "Add"
  Then I should see "You have reached the maximum mentoring connections limit."

@javascript @matching_scenario @cross-browser
Scenario: Mentor trying to accept beyond connection limit with "Allow mentors to increase their connection limit" set
  Given the current program is "primary":"albers"
  Given I have logged in as "robert@example.com"
  And I change maximum connections limit of mentor with email "robert@example.com" in program "primary":"albers" to "1"
  Then I follow "Home"
  And I click ".pending_requests_notification_icon"
  Then I follow "Mentoring Requests"
  Then I should see "student_k example"
  Then I select "Sort by oldest" from "sort_by"
  Then I should not see "student_k example"
  Then I select "Sort by most recent" from "sort_by"
  Then I should see "student_k example"
  Given I follow "Accept" for the group "results_pane"
  Then I press "Add"
  Then I should see "You have reached the maximum mentoring connections limit. Click here to change settings."
  Then I follow "Click here"
  Then I fill in "user_max_connections_limit" with "2"
  And I click "#submit_ongoing_settings"
  Then I follow "Home"
  And I click ".pending_requests_notification_icon"
  Then I follow "Mentoring Requests"
  Given I follow "Accept" for the group "results_pane"
  Then I press "Create"
  Then I should see "name & example"

@javascript
Scenario: Mentor viewing pending requests notification icon in header
  Given valid and appropriate date time settings
  And I change meeting availability preference of member with email "robert@example.com" to configure availability slots
  Given there are no meeting requests
  And There are no mentor requests for "student_0@example.com" in "primary":"albers"
  And There are no mentor requests for "robert@example.com" in "primary":"albers"
  And There are no program events in "primary":"albers"
  And I stub chronus s3 utils
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Then I enable the settings for mentor to connect without availability slots
  And I create a mentoring slot from "13:00:00" to "14:00:00" for "robert@example.com"
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I login as super user
  Then I follow "Manage"
  And I follow "Program Settings"
  And I follow "Connection Settings"
  And Then I enable "offer_mentoring" feature
  And I press "Save"
  And I logout

  And I have logged in as "student_0@example.com"

  And I click ".pending_requests_notification_icon"
  Then I should see "1" within ".pending_requests_notification_icon .label-danger"
  Then I should see "Connect with a Mentor 1" within "#pending_requests_dropdown"
  Then I logout
  Then I have logged in as "robert@example.com"
  Then I follow "Home"

  And I click ".pending_requests_notification_icon"
  Then I should not see "1" within ".pending_requests_notification_icon"
  Then I should not see "Connect with a Student 1" within ".cui_pending_requests_dropdown_text_container"
  Then I should see "Connect with a Student" within "#pending_requests_dropdown"
  Then I follow "Home"
  Then I wait for "2" seconds
  Then I logout

  And I have logged in as "student_0@example.com"

  When I navigate to "robert@example.com" profile in "albers"
  Then I send a calendar meeting request
  Then I follow "Home"

  And I click ".pending_requests_notification_icon"
  Then I should not see "Meeting Requests 1" within "#pending_requests_dropdown"
  Then I should see "Connect with a Mentor" within "#pending_requests_dropdown"
  Then I logout
  Given I have logged in as "robert@example.com"
  Then I follow "Home"

  And I click ".pending_requests_notification_icon"
  Then I should see "Mentoring Requests" within "#pending_requests_dropdown"
  Then I should see "Meeting Requests 1" within "#pending_requests_dropdown"
  Then I should see "Upcoming Meetings" within "#pending_requests_dropdown"
  Then I should see "Requests 1" within "nav#sidebarLeft"
  Then I should see "Connect with a Student" within "#pending_requests_dropdown"
  Then I should see "Mentoring Offers" within "#pending_requests_dropdown"
  Then I follow "Mentoring Requests" within "#pending_requests_dropdown"
  Then I should see "Received Mentoring Requests" within "div.cjs_title_text"
  And I click ".pending_requests_notification_icon"
  Then I follow "Meeting Requests" within "#pending_requests_dropdown"
  Then I should see "Received Meeting Requests" within "div.cjs_title_text"
  And I click ".pending_requests_notification_icon"
  Then I follow "Connect with a Student" within "#pending_requests_dropdown"
  Then I should see "Students" within "div.cjs_title_text"
  And I click ".pending_requests_notification_icon"
  Then I follow "Mentoring Offers" within "#pending_requests_dropdown"
  Then I should see "Mentoring Offers Initiated" within "div.cjs_title_text"
  When I follow "Home"

  And I accept the calendar meeting request
  And I click ".pending_requests_notification_icon"
  Then I should see "Upcoming Meetings" within "#pending_requests_dropdown"
  Then I follow "Upcoming Meetings" within "#pending_requests_dropdown"
  Then I should see "Set your availability"
  Then I should see "Calendar Meeting"
  Then I should see "Let us meet and have a general meeting"
  Then I reset rsvp responses for the last meeting
  When I follow "Home"
  And I click ".pending_requests_notification_icon"
  Then I should see "Upcoming Meetings 1" within "#pending_requests_dropdown"
  Then I should see "Upcoming 1" within "nav#sidebarLeft"

@javascript
Scenario: Mentor should not be able to reject request without reason message being present
  When I have logged in as "student_14@example.com"
  Then I follow "Mentors"
  When I navigate to "mentor_1@example.com" profile in "albers"
  Then I follow "Actions"
  And I follow "Request Mentoring Connection"
  Then I fill in "mentor_request_message" with "please be my mentor"
  Then I press "Send request"
  And I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_b chronus. You will be notified once the mentor accepts your request."
  Then I logout
  When I have logged in as "mentor_1@example.com"
  And I navigate to "student_14@example.com" profile in "albers"
  And I follow "Decline"
  Then I should see "Reason"
  Then I should see "Message"
  And I press "Submit"
  Then I should see "Reason"
  Then I should see "Message"
  And I logout

@javascript
Scenario: While rejecting request if mentor selects reached limit or busy as reason his limit should be changed
  When I have logged in as "student_14@example.com"
  Then I follow "Mentors"
  When I navigate to "mentor_1@example.com" profile in "albers"
  Then I follow "Actions"
  And I follow "Request Mentoring Connection"
  Then I fill in "mentor_request_message" with "please be my mentor"
  Then I press "Send request"
  And I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_b chronus. You will be notified once the mentor accepts your request."
  Then I logout
  When I have logged in as "mentor_1@example.com"
  And I navigate to "student_14@example.com" profile in "albers"
  And I follow "Decline"
  Then I choose the value "1" for "mentor_request[rejection_type]"
  Then I fill the last mentor request request text with "Test Reject"
  And I press "Submit"
  And I should see "Thank you for your response. student_o example has been notified"
  Then I logout
  When I have logged in as "student_14@example.com"
  Then I follow "Mentors"
  When I navigate to "mentor_1@example.com" profile in "albers"
  Then I follow "Actions"
  And I follow "Request Mentoring Connection"
  Then I fill in "mentor_request_message" with "please be my mentor"
  Then I press "Send request"
  And I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_b chronus. You will be notified once the mentor accepts your request."
  Then I logout
  When I have logged in as "mentor_1@example.com"
  And I navigate to "student_14@example.com" profile in "albers"
  And I follow "Decline"
  Then I choose the value "2" for "mentor_request[rejection_type]"
  Then I fill the last mentor request request text with "Test Reject"
  And I press "Submit"
  And I should see "Thank you for your response. student_o example has been notified. Your mentoring connections limit is updated to make sure you don't receive any new requests. You can always update your limit under your profile settings."
  Then I logout

@javascript
Scenario: Mentor should be able to accept mentor requests from student profile page
  When I have logged in as "student_14@example.com"
  Then I follow "Mentors"
  When I navigate to "mentor_1@example.com" profile in "albers"
  Then I follow "Actions"
  And I follow "Request Mentoring Connection"
  Then I fill in "mentor_request_message" with "please be my mentor"
  Then I press "Send request"
  And I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_b chronus. You will be notified once the mentor accepts your request."
  Then I logout
  When I have logged in as "mentor_1@example.com"
  And I navigate to "student_14@example.com" profile in "albers"
  Then I should see "Student_o's Requests to You (1)" within ".cui-request-pane"
  And I should see "Mentoring Connection Request" within ".cui-request-pane"
  When I follow "Accept"
  Then I press "Create"
  Then I should see "chronus & example" within ".cjs_title_text"

@javascript
Scenario: Mentor should be able to accept mentor requests from student listing page
  When I have logged in as "mkr@example.com"
  Then I follow "Mentors"
  When I navigate to "mentor_1@example.com" profile in "albers"
  Then I follow "Actions"
  And I follow "Request Mentoring Connection"
  Then I fill in "mentor_request_message" with "please be my mentor"
  Then I press "Send request"
  And I should see the flash "Your request for a mentoring connection has been successfully sent to mentor_b chronus. You will be notified once the mentor accepts your request."
  Then I logout
  When I have logged in as "mentor_1@example.com"
  When I navigate to "mkr@example.com" profile in "albers"
  Then I should see "Mkr_student's Requests to You"
  And I follow "Questions"
  Then I should see "Mkr_student's Requests to You"
  And I follow "Answers"
  Then I should see "Mkr_student's Requests to You"
  And I follow "Students"
  Then I should see "View Pending Request" within ".user_9"
  When I follow "View Pending Request"
  Then I should see "Mkr_student's Requests to You"
  And I should see "Mentoring Connection Request"
  When I follow "Accept"
  Then I press "Create"
  Then I should see "chronus & madankumarrajan" within ".cjs_title_text"

@javascript
Scenario: Mentor should be able to reject mentor requests from student listing and profile page
  When I have logged in as "mkr@example.com"
  Then I follow "Mentors"
  When I navigate to "mentor_1@example.com" profile in "albers"
  Then I follow "Actions"
  And I follow "Request Mentoring Connection"
  Then I fill in "mentor_request_message" with "please be my mentor"
  Then I press "Send request"
  Then I logout
  When I have logged in as "mentor_1@example.com"
  And I follow "Students"
  Then I should see "View Pending Request" within ".user_9"
  When I follow "View Pending Request"
  Then I should see "Mkr_student's Requests to You"
  And I should see "Mentoring Connection Request"
  When I follow "Decline"
  Then I fill the last mentor request request text with "Test Reject"
  Then I choose the value "1" for "mentor_request[rejection_type]"
  Then I press "Submit"
  Then I should see the flash "Thank you for your response. mkr_student madankumarrajan has been notified"
  Then I logout
  When I have logged in as "mkr@example.com"
  Then I follow "Mentors"
  When I navigate to "mentor_1@example.com" profile in "albers"
  Then I follow "Actions"
  And I follow "Request Mentoring Connection"
  Then I fill in "mentor_request_message" with "please be my mentor"
  Then I press "Send request"
  Then I logout
  When I have logged in as "mentor_1@example.com"
  When I navigate to "mkr@example.com" profile in "albers"
  Then I should see "Mkr_student's Requests to You" within ".cui-request-pane"
  And I should see "Mentoring Connection Request" within ".cui-request-pane"
  When I follow "Decline"
  Then I choose the value "1" for "mentor_request[rejection_type]"
  Then I fill the last mentor request request text with "Test Reject"
  Then I press "Submit"
  Then I should see the flash "Thank you for your response. mkr_student madankumarrajan has been notified"
