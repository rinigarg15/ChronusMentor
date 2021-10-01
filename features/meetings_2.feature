Feature: Calendar Feature
  In order to setup a meeting or preview my meetings
  As a member
  I should be able to access feature when the calendar feature is enabled

 Background:
    # The Last day in the calendar should be Time Travelled using time cop gem
    # because of the restrictions like meeting can be created 24 hours in advance
    # so, saturday is time travelled to avoid this issue
    Given valid and appropriate date time settings
    Given the current program is "primary":"albers"
    Given there are no meeting requests
    And I create a mentoring slot from "13:00:00" to "14:00:00" for "robert@example.com"
    And I create a mentoring slot from "13:00:00" to "19:30:00" for "rahim@example.com"
    And I change meeting availability preference of member with email "mentor2@psg.com" to configure availability slots
    And I change meeting availability preference of member with email "robert@example.com" to configure availability slots
    And I stub chronus s3 utils

@javascript
Scenario: User should be able to create meeting when availability slot of mentor is spanned across 2 different days due to time zone difference
    And I create a mentoring slot from "18:30:00" to "23:30:00" for "robert@example.com"
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    Then I have logged in as "ram@example.com"
    And I allow mentors in the program to configure availability slots
    And I enable "mentoring_connection_meeting" feature as a super user
    And I logout
    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    And I hover over "my_profile"
    And I click on profile picture and click "Edit Profile"
    Then I follow "Settings"
    Then I select "Asia" from "timezone_area"
    Then I select "(GMT+05:30) Kolkata" from "user_member_time_zone"
    Then I press "Save"
    And I logout
    When I have logged in as "mkr@example.com"
    And I click on profile picture and click "Edit Profile"
    Then I follow "Settings"
    Then I select "Asia" from "timezone_area"
    Then I select "(GMT+03:00) Riyadh" from "user_member_time_zone"
    Then I press "Save"
    When I navigate to "robert@example.com" profile in "albers"
    Then I should see "Good unique name"
    And I follow "Connect"
    Then I should see "Request Meeting"
    And I follow "Request Meeting"
    Then I should see "Enter Topic & Description"
    Then I should see "Topic *"
    Then I should see "Description *"
    And I fill in "new_meeting_title" with "Calendar Meeting"
    And I fill in "new_meeting_description" with "Let us meet and have a general meeting"
    Then I follow "Proceed to Select Times"
    Then I should not see "Description *"
    Then I should see "Good unique name's Availability (AST)"
    Then I should see "View Good unique's Calendar"
    Then I should see "Propose other times"
    Then I should see "02:30 AM"
    Then I follow "Choose" within ".cjs_availability_slot_list"
    Then I should see "( Change Slot )"
    Then I select "12:30 am (next day)" from "meeting_start_time_of_day"
    Then I press "Request Meeting"
    Then I should see "Your request for a meeting with Good unique name has been successfully sent. You will be notified when Good unique name responds to your request. You can look for other mentors who are available and reach out to them from here."
    Then I logout


@javascript @p2 @cross-browser
Scenario:Mentor creating meeting when the Admin allows the flag and Mentee RSVP the meeting
    Given the current program is "annauniv":""
    And I enable "mentoring_connection_meeting" feature as a super user
    And I enable "calendar" feature that was removed from UI as super user of "annauniv":"psg"
    Given the current program is "annauniv":"psg"
    And I have logged in as "ceg_admin@example.com"
    And I allow mentors in the program to configure availability slots
    And I logout

    Then I have logged in as "mentor2@psg.com"
    And I follow "Upcoming"
    And I follow "Click here"
    Then I should not see "Create a Meeting"
    And I should see "Availability Slot"
    And I logout
    And I have logged in as "psg@example.com"
    Then I follow "Manage"
    Then I follow "Program Settings"
    And I follow "Matching Settings"
    Then I choose "program_calendar_setting_allow_create_meeting_for_mentor_true"
    And I press "Save"
    And I logout
    Given the current program is "annauniv":"psg"
    Then I have logged in as "mentor2@psg.com"
    And I follow "Upcoming"
    And I follow "Click here"
    Then I should see "Create a Meeting"
    And I should see "Availability Slot"
    And I logout

  @javascript @p2 @cross-browser
    Scenario: Mentee creating meeting requests with non-calendar , Mentor Accept the meeting request using mobile footer and home in mobile footer
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    Then I enable the settings for mentor to connect without availability slots
    And I enable "mentoring_connection_meeting" feature as a super user
    Given the current program is "primary":"albers"
    And I have logged in as "userrobert@example.com"
    And I set the message for connecting without availability slots and set the maximum slots
    And I click on profile picture and click "Sign out"
    When I have logged in as "mkr@example.com"
    When I navigate to "userrobert@example.com" profile in "albers"
    Then I send a non-calendar meeting request to mentor with name "robert user"
    And I click on profile picture and click "Sign out"
    When I have logged in as "userrobert@example.com"
    Then I change to mobile view
    And I should see "6" within ".cjs_footer_total_requests"
    Then I follow requests in mobile footer  
    And I follow "Meeting Requests"
    And I should see "Received Meeting Requests"
    And I should see "mkr_student madankumarrajan"
    And I should see "Decline request"
    And I follow "Decline request"
    Then I fill in "meeting_request[response_text]" with "Sorry I wont be able to make it "
    Then I choose "Not the right match"
    And I press "Decline"
    And I should see "5" within ".cjs_footer_total_requests"
    Then I follow home in mobile footer

    Then I click ".fa-chevron-right"
    And I should see "All Activity"
    And I should see "My Activity"
    Then I click ".fa-chevron-left"
    Then I follow more in mobile footer
    And I should see "Account"
    And I should see "Mentors"
    And I should see "Students"
    And I should see "Requests"
    And I should see "Upcoming"
    And I should see "Past"
    And I should see "COMMUNITY"
    And I should see "Forums"
    And I should see "Advice"
    And I should see "Events"
    And I logout
    
  @javascript @p2 @cross-browser
    Scenario: Mentee creating meeting requests with calendar and non-calendar , Mentor Accept/Decline the request/propose slot , Mentee withdrawal of meeting requests, Mentor setting the maximum hours for a program, mentor proposing slots, set meeting time for a meeting
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    Then I enable the settings for mentor to connect without availability slots
    And I enable "mentoring_connection_meeting" feature as a super user
    Given the current program is "primary":"albers"
    And I have logged in as "userrobert@example.com"
    And I set the message for connecting without availability slots and set the maximum slots
    And I click on profile picture and click "Sign out"
    When I have logged in as "mkr@example.com"
    When I navigate to "userrobert@example.com" profile in "albers"
    Then I send two non-calendar meeting requests and withdraw one request
    And I click ".pending_requests_notification_icon"
    Then I should see "Upcoming Meetings" within "#pending_requests_dropdown"
    And I click on profile picture and click "Sign out"
    And I have logged in as "student_0@example.com"
    When I navigate to "userrobert@example.com" profile in "albers"
    Then I send a non-calendar meeting request to mentor with name "robert user"
    When I navigate to "robert@example.com" profile in "albers"
    Then I send a calendar meeting request
    And I click on profile picture and click "Sign out"
    And I have logged in as "userrobert@example.com"
    And I click on profile picture and click "Edit Profile"
    Then I follow "Settings"
    Then I click on the section with header "One-time Mentoring"
    Then I should see "One-time Mentoring"
    And I fill in Frequesny Slots with "0"
    And I press "Save" within "#settings_section_onetime"
    And I click on profile picture and click "Sign out"
    And I have logged in as "student_1@example.com"
    Then I try to request meeting when the maximum slots setting of the mentor is reached
    And I click on profile picture and click "Sign out"
    When I have logged in as "userrobert@example.com"
    And I click on profile picture and click "Edit Profile"
    Then I follow "Settings"
    Then I click on the section with header "One-time Mentoring"
    Then I should see "One-time Mentoring"
    And I fill in Frequesny Slots with "4"
    And I press "Save" within "#settings_section_onetime"
    Then I follow "Requests" within "ul.metismenu"
    Then I decline the other meeting request
    When I follow "Home"
    Then I follow "Requests" within "ul.metismenu"
    When I follow "Propose a time"
    Then I should see "Propose a Meeting Time"
    Then I should not see "Send a Message"
    Then I should not see "Click here to propose a new meeting time and send a message"
    Then I should see "Can't decide on the time? Send a message without proposing a time"
    Then I follow "Send a message"
    Then I should see "Send a Message"
    Then I should not see "Propose a Meeting Time"
    Then I should see "Click here to propose a new meeting time and send a message"
    Then I follow "Click here"
    Then I should see "Propose a Meeting Time"
    Then I should not see "Send a Message"
    Then I should see "Can't decide on the time? Send a message without proposing a time"
    Then I should not see "Click here to propose a new meeting time and send a message"
    And I select "January 26, 2040" for "#meeting_date" from datepicker
    Then I follow "Accept and Propose"
    Then I should see "You are successfully connected"
    Then I should see "A notification regarding the new meeting schedule has been sent to mkr_student madankumarrajan"
    Then I close modal
    And I click on profile picture and click "Sign out"
    When I have logged in as "robert@example.com"
    And I accept the calendar meeting request
    And I click ".pending_requests_notification_icon"
    Then I should see "Upcoming Meetings" within "#pending_requests_dropdown"
    Then I follow "Upcoming Meetings" within "#pending_requests_dropdown"
    Then I should see "Calendar Meeting"
    And I click on profile picture and click "Sign out"
    And I have logged in as "student_0@example.com"
    When I navigate to "userrobert@example.com" profile in "albers"
    Then I send a non-calendar meeting request to mentor with name "robert user"
    And I click on profile picture and click "Sign out"
    When I have logged in as "userrobert@example.com"
    And I click ".pending_requests_notification_icon"
    And I follow "Meeting Requests"
    When I follow "Propose a time"
    Then I should not see "Click here to propose a new meeting time and send a message"
    Then I should see "Can't decide on the time? Send a message without proposing a time"
    Then I follow "Send a message"
    Then I should see "Click here to propose a new meeting time and send a message"
    Then I should not see "Can't decide on the time? Send a message without proposing a time"
    And I fill in "meeting_acceptance_message" with "Test message"
    Then I follow "Accept and Send"
    Then I should see "You are successfully connected"
    Then I should see "A notification regarding the new meeting schedule has been sent to student_a example"
    Then I close modal
    Then I follow "Upcoming" within "ul.metismenu"
    Then I should see "Set meeting time"
    When I follow "Set meeting time"
    Then I should see "Set meeting time"
    When I press "Save"
    Then I should see the flash "The changes to this meeting were successfully saved and the attendees were notified about the update."
    And I should not see "Set meeting time"
    And I click on profile picture and click "Sign out"

@javascript @p2
Scenario: Mentee should not be able to send requests when meetings limit/meeting request limit is reached
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Then I enable the settings for mentor to connect without availability slots
  Then I have logged in as "ram@example.com"
  Then I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I fill in "max_meetings_for_mentee" with "0"
  Then I press "Save"
  And I logout
  And I have logged in as "student_0@example.com"
  When I navigate to "userrobert@example.com" profile in "albers"
  And I follow "Actions"
  And I should see disabled "Request Meeting"
  When I hover over link with text "Request Meeting" within "#mentor_profile"
  Then I should see "You cannot send any more meeting requests as you have reached the limit for the number of meetings"
  And I logout
  Then I have logged in as "ram@example.com"
  Then I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I fill in "max_meetings_for_mentee" with "5"
  And I select "1 request" from "max_pending_meeting_requests_for_mentee"
  Then I press "Save"
  And I logout
  And I have logged in as "student_0@example.com"
  When I navigate to "userrobert@example.com" profile in "albers"
  Then I send a non-calendar meeting request to mentor with name "robert user"
  When I navigate to "userrobert@example.com" profile in "albers"
  And I follow "Actions"
  And I should see disabled "Request Meeting"
  When I hover over link with text "Request Meeting"
  Then I should see "You cannot send any more meeting requests as you have reached the limit for the number of concurrent pending requests. Please withdraw a pending request to send a new request."


@javascript @p2
Scenario: Mentor should be able to accept and decline requests from mentee profile page and listing page and Set Meeting Time in Meeting Area
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Then I enable the settings for mentor to connect without availability slots
  And I enable "mentoring_connection_meeting" feature as a super user
  Given the current program is "primary":"albers"
  And I have logged in as "userrobert@example.com"
  And I set the message for connecting without availability slots and set the maximum slots
  And I click on profile picture and click "Sign out"
  When I have logged in as "mkr@example.com"
  When I navigate to "userrobert@example.com" profile in "albers"
  Then I send a non-calendar meeting request to mentor with name "robert user"
  And I click on profile picture and click "Sign out"
  And I have logged in as "student_1@example.com"
  When I navigate to "userrobert@example.com" profile in "albers"
  Then I send a non-calendar meeting request to mentor with name "robert user"
  And I click on profile picture and click "Sign out"
  When I have logged in as "userrobert@example.com"
  When I navigate to "mkr@example.com" profile in "albers"
  Then I should see "Mkr_student's Requests to You" within ".cui-request-pane"
  And I should see "Meeting Request" within ".cui-request-pane"
  When I follow "Propose a time"
  Then I should see "Propose a Meeting Time"
  And I select "January 26, 2040" for "#meeting_date" from datepicker
  Then I follow "Accept and Propose"
  When I navigate to "student_1@example.com" profile in "albers"
  When I follow "Decline"
  Then I choose the value "4" for "mentor_request[rejection_type]"
  Then I fill in "mentor_request[response_text]" with "Test Reject"
  When I press "Submit"
  Then I should see "Meeting Request" within ".cui-request-pane"
  And I follow "Decline request"
  And I choose "Other"
  Then I fill in "meeting_request[response_text]" with "Sorry I wont be able to make it "
  And I press "Decline"
  Then I wait for ajax to complete
  Then I should see "Thank you for your response."
  And I click on profile picture and click "Sign out"
  When I have logged in as "mkr@example.com"
  When I navigate to "userrobert@example.com" profile in "albers"
  Then I send a non-calendar meeting request to mentor with name "robert user"
  And I change the description of the last created meeting to empty
  And I click on profile picture and click "Sign out"
  When I have logged in as "userrobert@example.com"
  And I follow "Students"
  Then I should see "View Pending Request" within ".user_9"
  When I follow "View Pending Request"
  Then I should see "Mkr_student's Requests to You"
  When I follow "Propose a time"
  Then I should not see "Click here to propose a new meeting time and send a message"
  Then I should see "Can't decide on the time? Send a message without proposing a time"
  Then I follow "Send a message"
  Then I should see "Click here to propose a new meeting time and send a message"
  Then I should not see "Can't decide on the time? Send a message without proposing a time"
  And I fill in "meeting_acceptance_message" with "Test message"
  Then I follow "Accept and Send"
  And I should see "No description provided."
  Then I close modal
  Then I should see "Set meeting time"
  When I follow "Set meeting time"
  Then I should see "Set meeting time"
  When I press "Save"
  And I should not see "Set meeting time"
  And I click on profile picture and click "Sign out"

@javascript @p2
Scenario: Meeting Feedback Survey
  Given the current program is "primary":"albers"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Given mentors in "primary":"albers" are allowed to configure availability slots
  When I have logged in as "robert@example.com"
  Given there is a past meeting I attended outside of a group
  Then I follow "Past" within "ul.metismenu"
  Then I should see "Outside Group" within "#archived_meetings"
  Then I follow "Provide Feedback" within "#archived_meetings"
  Then I should see "Update Meeting Status"
  Then I should see /Did your meeting, "Outside Group" with student example take place\?/
  Then I follow "Yes"
  Then I wait for ajax to complete
  Then I should see "Meeting Feedback Survey"
  And I fill the answers "'Very satisfying', 'Great use of time'" of "Meeting Feedback Survey For Mentors" for "COMPLETED"
  Then I press "Submit"
  Then I should see "Thanks for completing Meeting Feedback Survey For Mentors"
  Then I should see "Status Completed"
  And I should see "Tips"
  And I should see "Send and receive personalized messages related to the meeting from the messages tab."
  And I should see "Capture the meeting notes, followups and resource attachments from the notes tab."
  Then I should see "RSVP"
  Then I should see "View Feedback"
  Then I should see "Edit Details"
  Then I follow "View Feedback"
  Then I should see "Very satisfying"
  Then I should see "Great use of time"
  Then I logout
  Then I have logged in as "ram@example.com"
  Then I follow "Manage"
  Then I follow "Surveys"
  Then I follow "1 new response this week"
  Then I follow "Responses (1)"
  Then I follow "Outside Group"
  Then I should not see "RSVP"
  Then I should not see "View Feedback"
  Then I should not see "Edit Details"

@javascript @p2
Scenario: Edit Meeting Time inside Meeting Area
  Given the current program is "primary":"albers"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Given mentors in "primary":"albers" are allowed to configure availability slots
  When I have logged in as "robert@example.com"
  Given there is a past meeting I attended outside of a group
  Then I follow "Past" within "ul.metismenu"
  Then I should see "Outside Group" within "#archived_meetings"
  Then I follow "Outside Group"
  Then I should see "Update Meeting Status"
  Then I should see /Did your meeting, "Outside Group" with student example take place\?/
  Then I follow "Update Time"
  Then I wait for ajax to complete
  Then I should see "Edit Meeting" within ".modal-title"
  And I select a date 2 years from now for "meeting_date_for_mentor" from datepicker
  Then I press "Save"
  Then I should see a date 2 years from now
  And I should see "Tips"
  And I should see "Send and receive personalized messages related to the meeting from the messages tab."
  And I should see "Capture the meeting notes, followups and resource attachments from the notes tab."
  Then I logout


@javascript
Scenario: Messages in meeting area
  Given the current program is "primary":"albers"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Given mentors in "primary":"albers" are allowed to configure availability slots
  When I have logged in as "robert@example.com"
  Given there is a past meeting I attended outside of a group
  Then I follow "Past" within "ul.metismenu"
  Then I should see "Outside Group" within "#archived_meetings"
  Then I follow "Outside Group"
  Then I should see "Update Meeting Status"
  And I close modal
  Then I follow "Messages" within "li.cjs_meeting_messages_tab"
  And I follow "New Message"
  And I fill in "scrap[subject]" with "Meeting WestWorld"
  And I fill in "scrap[content]" with "Artificial Human Bots"
  And I press "Send Message"

  And I follow "New Message"
  And I fill in "scrap[subject]" with "Brooklyn Nine Nine"
  And I fill in "scrap[content]" with "Police sitcom"
  And I press "Send Message"
  Then I wait for ajax to complete
  And I logout
  
  And I have logged in as "rahim@example.com"
  Then I follow "Past" within "ul.metismenu"
  Then I should see "Outside Group" within "#archived_meetings"
  Then I follow "Outside Group"
  Then I should see "Update Meeting Status"
  And I close modal
  Then I should see "2" within ".cjs_unread_scraps_count"
  And I follow "Messages" within "li.cjs_meeting_messages_tab"
  Then I should see "1 - 2 of 2"
  And I click unread scrap message with subject "Meeting WestWorld"
  Then I should see "1" within ".cjs_unread_scraps_count"
  Then I click ".scrap-actions"
  Then I click ".cjs_reply_link"

  And I reply "Awesome new series" to the scrap with subject "Meeting WestWorld"
  And I press "Reply"
  And I click unread scrap message with subject "Brooklyn Nine Nine"
  Then I should not see element ".cjs_unread_scraps_count"

  And I follow "New Message"
  And I fill in "scrap[subject]" with "Lucifer"
  And I fill in "scrap[content]" with "Vampire in San Francisco"
  And I press "Send Message"
  Then I should see "1 - 3 of 3"
  And I logout

  And I have logged in as "robert@example.com"
  Then I follow "Past" within "ul.metismenu"
  Then I should see "Outside Group" within "#archived_meetings"
  Then I follow "Outside Group"
  Then I should see "Update Meeting Status"
  And I close modal
  And I follow "Messages" within "li.cjs_meeting_messages_tab"
  Then I should see "2" within ".cjs_unread_scraps_count"
  And I click unread scrap message with subject "Lucifer"
  Then I should see "1" within ".cjs_unread_scraps_count"
  And I click unread scrap message with subject "Lucifer"
  Then I should see "1" within ".cjs_unread_scraps_count"


@javascript
Scenario: New Message will not be shown for cancelled/completed meetings in meeting area
  Given the current program is "primary":"albers"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Given mentors in "primary":"albers" are allowed to configure availability slots
  When I have logged in as "robert@example.com"
  Given there is a past meeting I attended outside of a group
  Then I follow "Past" within "ul.metismenu"
  Then I should see "Outside Group" within "#archived_meetings"
  Then I follow "Outside Group"
  Then I follow "No, it was cancelled"
  Then I follow "Messages" within "li.cjs_meeting_messages_tab"
  Then I should not see "New Message"

@javascript
Scenario: Users should be able to see messages & notes count for meetings in meeting listing page
  Given the current program is "primary":"albers"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Given mentors in "primary":"albers" are allowed to configure availability slots
  When I have logged in as "robert@example.com"
  Given there is an accepted upcoming meeting outside of a group
  Then I follow "Upcoming" within "ul.metismenu"
  Then I follow "Outside Group"
  And I follow "Notes"
  Then I should see "You can capture notes and file attachments for this meeting from this space. Add your first note."
  And I should see "New Note"
  Then I click ".add_private_meeting_note"
  Then I type the note text "I met my mentor yesterday. We discussed about the goals."
  And I press "Add Note"
  Then I follow "Messages" within "li.cjs_meeting_messages_tab"
  And I follow "New Message"
  And I fill in "scrap[subject]" with "Meeting WestWorld"
  And I fill in "scrap[content]" with "Artificial Human Bots"
  And I press "Send Message"
  Then I follow "Upcoming" within "ul.metismenu"
  Then I should see "1 note" with in the meeting with topic "Outside Group" and occurrence "0"
  Then I should see "1 message" with in the meeting with topic "Outside Group" and occurrence "0"
  Then I logout
  When I have logged in as "mkr@example.com"
  Then I follow "Upcoming" within "ul.metismenu"
  Then I should see "1 note" with in the meeting with topic "Outside Group" and occurrence "0"
  Then I should see "1 message" with in the meeting with topic "Outside Group" and occurrence "0"
  Then I should see "1 unread" with in the meeting with topic "Outside Group" and occurrence "0"

@javascript
Scenario: Dual Request Mode
  Given the current program is "primary":"albers"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  When I have logged in as "student_14@example.com"
  And I follow "Mentors"
  And I navigate to "mentor_1@example.com" profile in "albers"
  And I follow "Actions"
  And I follow "Request Mentoring Connection"
  And I should see "I am open to a 30 minute meeting with mentor_b chronus if the mentoring connection request cannot be accepted."
  Then I fill in "mentor_request_message" with "please be my mentor"
  Then I press "Send request"
  And I follow "Mentors"
  And I navigate to "mentor_1@example.com" profile in "albers"
  And I follow "Actions"
  And I should see "View your pending request"
  Then I logout
  When I have logged in as "mentor_1@example.com"
  And I click ".pending_requests_notification_icon"
  Then I follow "Mentoring Requests"
  Given I follow "Decline" for the group "results_pane"
  Then I choose the value "1" for "mentor_request[rejection_type]"
  Then I should see "Your message will be mailed to the user. The reason selected from the list above will not."
  Then I choose the value "2" for "mentor_request[rejection_type]"
  Then I should not see "Your message will be mailed to the user. The reason selected from the list above will not."
  Then I should see "We understand that you are not available for a mentoring connection. Would you like to have a 30 minute meeting with student_o example instead?"
  Then I follow "No"
  Then I should see "We understand that you are not available for a mentoring connection. Would you like to have a 30 minute meeting with student_o example instead?"
  Then I should see "Your message will be mailed to the user. The reason selected from the list above will not."
  Then I choose the value "2" for "mentor_request[rejection_type]"
  Then I follow "Yes"
  Then I wait for ajax to complete
  Then I should see "Accept Meeting"
  Then I should see "You are just a step away from accepting a 30 minute meeting. We recommend that you propose a meeting time. Please note that completing this action will notify student_o example."
  Then I should see "#meeting_slot_message" filled as "I am not able to accept a mentoring connection at this point. I am proposing a time for a meeting instead."
  Then I follow "Send a message"
  Then I should see "#meeting_acceptance_message" filled as "I am not able to accept a mentoring connection at this point. I am open for a meeting instead and would like to discuss further on the next steps."
  Then I follow "Click here"
  And I select "January 26, 2040" for "#meeting_date" from datepicker
  Then I follow "Accept and Propose"
  Then I should see "You are successfully connected"
  Then I should see "chronus & example"
  Then I should see "please be my mentor"
  And I logout
  When I have logged in as "student_14@example.com"
  And I follow "Mentors"
  And I navigate to "mentor_1@example.com" profile in "albers"
  And I follow "Actions"
  And I should not see "View your pending request"
  And I follow "Request Mentoring Connection"
  And I should not see "I am open for a meeting if mentor_b chronus could not accept this request."
  Then I fill in "mentor_request_message" with "please be my mentor"
  Then I press "Send request"
  Then I logout
  When I have logged in as "mentor_1@example.com"
  And I click ".pending_requests_notification_icon"
  Then I follow "Mentoring Requests"
  Given I follow "Decline" for the group "results_pane"
  Then I choose the value "2" for "mentor_request[rejection_type]"
  Then I should not see "We understand that you are not available for a mentoring connection. Would you like to have a 30 minute meeting with student_o example instead?"
  And I logout
  
