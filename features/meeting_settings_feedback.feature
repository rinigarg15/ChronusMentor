
Feature: Calendar Feature
  Meeting Feedbacks, Meeting Requests and Admin/EndUser Settings

 Background:
    # The Last day in the calendar should be Time Travelled using time cop gem
    # because of the restrictions like meeting can be created 24 hours in advance
    # so, saturday is time travelled to avoid this issue
    Given valid and appropriate date time settings
    Given the current program is "primary":"albers"
    Given there are no meeting requests
    And I create a mentoring slot from "13:00:00" to "14:00:00" for "robert@example.com"
    And I create a mentoring slot from "13:00:00" to "19:30:00" for "rahim@example.com"
    And I stub chronus s3 utils

@javascript 
 Scenario: Cannot Provide meeting feedback for group meeting
    When I have logged in as "ram@example.com"
    And I enable "mentoring_connection_meeting" feature as a super user
    And I logout
    Given there is a past meeting I attended inside of a group
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    Given mentors in "primary":"albers" are allowed to configure availability slots
    And I have logged in as "mkr@example.com"
    Then I follow "Past" within "ul.metismenu"
    Then I should see "My Meetings"
    Then I should see "Inside Group"
    And I should not see "Provide feedback"


@javascript @p2 @cross-browser
 Scenario: Validate Calendar Sync Popup and Instructions Page
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    Then I disable the feature "calendar_sync" as a super user
    Given mentors in "primary":"albers" are allowed to configure availability slots
    And I have logged in as "mkr@example.com"
    Then I follow "Upcoming" within "ul.metismenu"
    Then I should see "My Meetings"
    Then I should see "Subscribe to Calendar"
    Then I follow "Subscribe to Calendar"
    Then I should see "To subscribe to your meetings on your ical or outlook calendar, please copy the above calendar feed url and add to your calendar."
    Then I should see "Please note:"
    Then I should see "For more details"
    Then I follow "For more details"
    Then I switch to latest window
    Then I should see "Subscribe to your meetings from your own calendar"
    Then I should see "The 'Subscribe to Calendar' option helps you to keep track of your meetings by syncing your meetings to Google Calendar, Apple Calendar, Outlook or any calendar that allows you to subscribe by URL. Once subscribed, you will see all your meeting details from your own calendar."
    Then I close the new window and switch to main window
    Then I logout    
    

@javascript @p2 
Scenario: Meeting Feedback Survey
  Given the current program is "primary":"albers"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I change meeting availability preference of member with email "robert@example.com" to configure availability slots
  Given mentors in "primary":"albers" are allowed to configure availability slots
  When I have logged in as "robert@example.com"
  Given there is a past meeting I attended outside of a group
  Then I follow "Upcoming" within "ul.metismenu"
  Then I should see "Past"
  When I follow "Past"
  Then I should see "Outside Group"
  And I should not see "View Feedback"
  When I follow "Provide Feedback" within "#archived_meetings"
  Then I should see /Did your meeting, "Outside Group" with student example take place\?/
  Then I follow "No, it was cancelled"
  Then I should see "Meeting Feedback Survey"
  And I fill the answers "'Attendee no-show'" of "Meeting Feedback Survey For Mentors" for "CANCELLED"
  Then I press "Submit"
  Then I should see "Thanks for completing Meeting Feedback Survey For Mentors"
  Then I should see "Status Canceled"
  And I should see "Tips"
  And I should see "Send and receive personalized messages related to the meeting from the messages tab."
  And I should see "Capture the meeting notes, followups and resource attachments from the notes tab."
  Then I follow "View Feedback"
  Then I should see "Attendee no-show"
  Then I logout

@javascript 
Scenario: Super user logs in and changes the calendar settings.
  And I have logged in as "ram@example.com"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I maximize the window
  And I login as super user
  Then I follow "Manage"
  Then I follow "Program Settings"
  Then I should see "Mentoring Connection Settings"
  Then I follow "Mentoring Connection Settings"
  And I press "Save"
  #TBD - step for highlighting of fields
  #Then I should see "Please fill all the required fields. Fields marked * are required"
  #TBD - step for highlighting of fields
  #Then I should see "Please enter a valid positive value."
  Then I fill in "day(s) after the meeting request has been accepted and the meeting details were not decided" with ""
  #TBD - step for highlighting of fields
  #Then I should see "Please fill all the required fields. Fields marked * are required"
  Then I fill in "day(s) after the meeting request has been accepted and the meeting details were not decided" with "-1"
  And I press "Save"
  Then I should see "Please enter a valid positive value."
  Then I fill in "day(s) after the meeting request has been accepted and the meeting details were not decided" with "15"
  And I press "Save"
  Then I should see "Your changes have been saved"
  Then I logout

@javascript @cross-browser 
Scenario: Meeting Request Calendar rejection with notes
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I change meeting availability preference of member with email "robert@example.com" to configure availability slots
  Then I enable the settings for mentor to connect without availability slots
  Given the current program is "primary":"albers"
  And I have logged in as "student_0@example.com"
  When I navigate to "robert@example.com" profile in "albers"
  Then I send a calendar meeting request
  Then I logout
  And I have logged in as "robert@example.com"
  And I click ".pending_requests_notification_icon"
  And I follow "Meeting Requests"
  And I follow "Decline request"
  Then I should see "Decline Request"
  Then I should see "Reason"
  Then I should see "Message"
  Then I fill in "meeting_request[response_text]" with "Sorry I wont be able to make it "
  Then I choose "Not the right match"
  And I press "Decline"
  Then I choose "list_rejected"
  Then I should see "Reason for declining"
  Then I should see "Sorry I wont be able to make it "

@javascript @cross-browser 
Scenario: Mentor rejecting a request with different reason may or may not change the limit
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Then I enable the settings for mentor to connect without availability slots
  Given the current program is "primary":"albers"
  And I have logged in as "userrobert@example.com"
  And I set the message for connecting without availability slots and set the maximum slots
  Then I logout
  And I have logged in as "student_0@example.com"
  When I navigate to "userrobert@example.com" profile in "albers"
  Then I send a non-calendar meeting request to mentor with name "robert user"
  Then I logout
  And I have logged in as "userrobert@example.com"
  And I click ".pending_requests_notification_icon"
  And I follow "Meeting Requests"
  And I follow "Decline request"
  Then I should see "Decline Request"
  Then I should see "Reason"
  Then I choose "Not the right match"
  Then I fill in "meeting_request[response_text]" with "Sorry I wont be able to make it "
  And I press "Decline"
  And I should see "Thank you for your response. student_a example has been notified."
  Then I logout
  And I have logged in as "student_0@example.com"
  When I navigate to "userrobert@example.com" profile in "albers"
  Then I send a non-calendar meeting request to mentor with name "robert user"
  Then I logout
  And I have logged in as "userrobert@example.com"
  And I click ".pending_requests_notification_icon"
  And I follow "Meeting Requests"
  And I follow "Decline request"
  Then I should see "Decline Request"
  Then I should see "Reason"
  Then I choose "Reached my limit"
  Then I fill in "meeting_request[response_text]" with "Sorry I wont be able to make it "
  And I press "Decline"
  And I should see the flash "Thank you for your response. student_a example has been notified. Your meeting limit per calendar month is updated to make sure you don't receive any new requests. You can always update your limit under your profile settings."
  Then I logout

@javascript @cross-browser 
Scenario: Mentor should not be able to reject request without writing the rejection message
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Then I enable the settings for mentor to connect without availability slots
  Given the current program is "primary":"albers"
  And I have logged in as "userrobert@example.com"
  And I set the message for connecting without availability slots and set the maximum slots
  Then I logout
  And I have logged in as "student_0@example.com"
  When I navigate to "userrobert@example.com" profile in "albers"
  Then I send a non-calendar meeting request to mentor with name "robert user"
  Then I logout
  And I have logged in as "userrobert@example.com"
  And I click ".pending_requests_notification_icon"
  And I follow "Meeting Requests"
  And I follow "Decline request"
  Then I should see "Decline Request"
  Then I should see "Reason"
  Then I should see "Message"
  And I press "Decline"
  Then I should see "Reason"
  Then I should see "Message"
  And I logout

@javascript @cross-browser 
Scenario: Meeting Request Non-Calendar rejection with notes
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Then I enable the settings for mentor to connect without availability slots
  Given the current program is "primary":"albers"
  And I have logged in as "userrobert@example.com"
  And I set the message for connecting without availability slots and set the maximum slots
  Then I logout
  And I have logged in as "student_0@example.com"
  When I navigate to "userrobert@example.com" profile in "albers"
  Then I send a non-calendar meeting request to mentor with name "robert user"
  Then I logout
  And I have logged in as "userrobert@example.com"
  And I click ".pending_requests_notification_icon"
  And I follow "Meeting Requests"
  And I follow "Decline request"
  Then I should see "Decline Request"
  Then I should see "Reason"
  Then I should see "Message"
  Then I fill in "meeting_request[response_text]" with "Sorry I wont be able to make it "
  Then I choose "Reached my limit"
  And I press "Decline"
  Then I should see "Thank you for your response. student_a example has been notified. Your meeting limit per calendar month is updated to make sure you don't receive any new requests. You can always update your limit under your profile settings."
  And a mail should go to "student_0@example.com" having "Sorry I wont be able to make it "
  Then I choose "list_rejected"
  Then I should see "Reason for declining"
  Then I should see "Sorry I wont be able to make it "

@javascript @cross-browser 
Scenario: Meeting Request Report with requests
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I change meeting availability preference of member with email "robert@example.com" to configure availability slots
  Then I enable the settings for mentor to connect without availability slots
  Given the current program is "primary":"albers"
  And I have logged in as "userrobert@example.com"
  And I set the message for connecting without availability slots and set the maximum slots
  Then I logout
  When I have logged in as "mkr@example.com"
  When I navigate to "userrobert@example.com" profile in "albers"
  Then I send two non-calendar meeting requests and withdraw one request
  Then I logout
  And I have logged in as "student_0@example.com"
  When I navigate to "userrobert@example.com" profile in "albers"
  Then I send a non-calendar meeting request to mentor with name "robert user"
  When I navigate to "robert@example.com" profile in "albers"
  Then I send a calendar meeting request
  Then I logout
  And I have logged in as "ram@example.com"
  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Meeting Requests"
  And I should see "Meeting Requests"
  Then I should not see "There are no meeting requests matching the chosen criteria"
  Then I should see "Calendar Meeting"
  And I should see "Kindly help needed in ruby"
  And I should see "Kindly help needed in rails"
  Then I follow "cjs_reports_export"
  Then I wait for download to complete
  And I follow "report_date_range"
  And I fill in sent between field with "01/01/1925 - 01/01/1975"
  And I press "Go"
  Then I should see "There are no meeting requests matching the chosen criteria"
  And I should not see "Kindly help needed in ruby"
  Then I reload the page
  And I should see "Kindly help needed in ruby"
  And I should see "Kindly help needed in rails"
  Then I follow "Accepted"
  Then I should see "There are no meeting requests matching the chosen criteria"
  Then I follow "Declined"
  Then I should see "There are no meeting requests matching the chosen criteria"
  Then I follow "Withdrawn"
  Then I should see "Test Withdrawal"
  Then I logout

@javascript 
Scenario: Admin setting max capacity limit for students

  When I have logged in as "ram@example.com"
  And I login as super user
  And I go to feature listing page in primary:albers program
  Then I scroll down by "1000"
  And I check "mentoring_connection_meeting"
  And I press "Save"
  And I logout

  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  When I have logged in as "ram@example.com"
  And I select "Albers Mentor Program" from the program selector
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I fill in "max_meetings_for_mentee" with "-2"
  And I select "4 requests" from "max_pending_meeting_requests_for_mentee"
  And I press "Save"
  Then I should see the flash "Max meetings for mentee must be greater than or equal to 0"
  And I fill in "max_meetings_for_mentee" with "2"
  And I select "4 requests" from "max_pending_meeting_requests_for_mentee"
  And I press "Save"
  Then I should see "#max_meetings_for_mentee" filled as "2"
  And I should see "4 requests" within "#max_pending_meeting_requests_for_mentee"
  And I logout

@javascript @cross-browser 
Scenario: Mentor sets setting not to ask for availability
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I change meeting availability preference of member with email "robert@example.com" to configure availability slots
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I login as super user
  When I follow "Albers Mentor Program"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I check "program_calendar_setting_allow_mentor_to_configure_availability_slots"
  And I check "program_calendar_setting_allow_mentor_to_describe_meeting_preference"
  And I press "Save"
  And I logout
  And I have logged in as "robert@example.com"
  When I select "Albers Mentor Program" from the program selector
  And I click on profile picture and click "Edit Profile"
  Then I follow "Settings"
  Then I click on the section with header "One-time Mentoring"
  And I should see the radio button "member_will_set_availability_slots_true" selected
  And I follow "Actions"
  And I should see "Edit your Availability Calendar"
  And I follow "Home" tab
  And I should see "Upcoming" within "ul#side-menu"
  And I click on profile picture and click "Edit Profile"
  And I follow "Actions"
  And I follow "Edit your Availability Calendar"
  And I should see "Set your availability"

  And I follow "Home" tab
  And I click on profile picture and click "Edit Profile"
  Then I follow "Settings"
  Then I click on the section with header "One-time Mentoring"
  Then I choose "member_will_set_availability_slots_false" within "#settings_section_onetime"
  And I fill in "member[availability_not_set_message]" with "Please contact me directly"
  And I press "Save" within "#settings_section_onetime"
  Then I follow "Settings"
  Then I click on the section with header "One-time Mentoring"
  Then I should see the radio button "member_will_set_availability_slots_false" selected 
  And I follow "Home" tab
  
  Then I follow "Upcoming" within "ul.metismenu"
  And I should not see "Set your availability"
  And I logout

  Then I have logged in as "student_0@example.com"
  When I navigate to "robert@example.com" profile in "albers"
  And I follow "Actions"
  And I follow "Request Meeting"
  And I fill in "new_meeting_title" with "Calendar Meeting"
  And I fill in "new_meeting_description" with "Please help me on a few topics"
  Then I follow "Proceed to Propose Times"
  And I fill in "mentee_general_availability_message" with "mentee general availability message"
  Then I follow "Request Meeting"
  Then I should see "Your request for a meeting with Good unique name has been successfully sent. You will be notified when Good unique name responds to your request. You can look for other mentors who are available and reach out to them from here."
  Then I should not see "HSB"
  Then I should not see "01:00 PM"
  Then I should not see "02:00 PM"
  And I follow "Home" tab

  And I click ".pending_requests_notification_icon"
  And I follow "Meeting Requests"
  Then I should see "Please help me on a few topics"
  And I should see "Withdraw Request"
  And I logout

  Given the current program is "primary":"albers"
  And I have logged in as "robert@example.com"
  And I click ".pending_requests_notification_icon"
  And I follow "Meeting Requests"
  Then I should see "Please help me on a few topics"
  Then I should see "Accept"
  And I follow "Home" tab
  And I click on profile picture and click "Edit Profile"
  Then I follow "Settings"
  Then I click on the section with header "One-time Mentoring"
  And I choose "member_will_set_availability_slots_true"
  And I press "Save"
  Then I follow "Settings"
  Then I click on the section with header "One-time Mentoring"
  Then I should see "Add Timeslot"
  And I logout