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
    And I stub chronus s3 utils

  @javascript @cross-browser
  Scenario: Delete recurrent meetings inside a group
    And I enable "mentoring_connection_meeting" feature as a super user
    Given Admin update expiry date of group named "name & madankumarrajan" to "Jan 26, 2021"
    When I have logged in as "robert@example.com"
    And I select "Albers Mentor Program" from the program selector
    And I follow "name & madankumarrajan"
    And I follow "Add Meeting" in the page actions bar
    And I follow "Add New Meeting" in the page actions bar
    And I fill in "new_meeting_title" with "Recurrent Daily Meeting"
    And I fill in "meeting_description" with "Let us meet and have a recurrent meeting"
    And I select "January 26, 2020" for "#new_meeting_form_date" from datepicker
    And I check "meeting_recurrent"
    And I select "Daily" from "meeting_schedule_rule"
    And I select "February 5, 2020" for "#meeting_repeats_end_date" from datepicker
    And I press "Create"
    Then I wait for ajax to complete
    Then I in "60" seconds should see "Recurrent Daily Meeting"
    And I remove occurrence number "1" with "Only this meeting" option
    Then I in "60" seconds should see "Recurrent Daily Meeting"
    And I remove occurrence number "0" with "Following meetings" option
    Then I should not see "Recurrent Daily Meeting"
    # Remove all meetings
    And I follow "Add Meeting" in the page actions bar
    And I follow "Add New Meeting" in the page actions bar
    And I fill in "new_meeting_title" with "Recurrent Daily Meeting"
    And I fill in "meeting_description" with "Let us meet and have a recurrent meeting"
    And I select "January 26, 2020" for "#new_meeting_form_date" from datepicker
    And I check "meeting_recurrent"
    And I select "Daily" from "meeting_schedule_rule"
    And I select "February 5, 2020" for "#meeting_repeats_end_date" from datepicker
    And I press "Create"
    Then I wait for ajax to complete
    Then I in "60" seconds should see "Recurrent Daily Meeting"    
    And I remove occurrence number "1" with "All meetings" option

  @javascript @cross-browser
  Scenario: Creating recurrent meeting from the Meetings index page of a group, RSVP for the recurrent meetings and Provide feedback for the past recurrent meetings.

    And I enable "mentoring_connection_meeting" feature as a super user
    Given Admin update expiry date of group named "name & madankumarrajan" to "Jan 26, 2021"
    When I have logged in as "robert@example.com"
    And I follow "name & madankumarrajan"
    And I follow "Add New Meeting"
    And I should not see "Please submit a request to this"
    And I fill in "new_meeting_title" with "Recurrent Daily Meeting"
    And I fill in "meeting_description" with "Let us meet and have a recurrent meeting"
    And I select "January 26, 2020" for "#new_meeting_form_date" from datepicker
    And I check "meeting_recurrent"
    And I select "Daily" from "meeting_schedule_rule"
    And I select "3" from "meeting_repeat_every"
    And I select "February 5, 2020" for "#meeting_repeats_end_date" from datepicker
    And I press "Create"
    Then I wait for ajax to complete
    Then I in "60" seconds should see "Recurrent Daily Meeting"
    And I should see "Sun, Jan 26, 2020"
    And I should see "Attending"
    And I should see "(Change)"
    And I should see "Wed, Jan 29, 2020"
    And I should see "Sat, Feb 01, 2020"
    And I should see "Tue, Feb 04, 2020"
    And I should see "08:00 am UTC (30 min)"
    And I should see "No location specified"
    And I should see "Recurrent Daily Meeting"
    And I should see "Let us meet and have a recurrent meeting"
    Then I logout
    And I have logged in as "mkr@example.com"
    And I follow "name & madankumarrajan"
    And I follow "See all »" within "div#side_pane_meetings"
    Then I RSVP the recurrent meetings
    Then I logout

  @javascript
  Scenario: Accept and decline meeting from sidepane(both mobile and desktop), meeting lisitng page.
    When I have logged in as "ram@example.com"
    Given the current program is "primary":""
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    And I enable "mentoring_connection_meeting" feature as a super user 
    And I logout
    And I have logged in as "mkr@example.com"
    When I select "Albers Mentor Program" from the program selector
    Then Admin update expiry date of group named "name & madankumarrajan" to a year from now
    And I follow "name & madankumarrajan"
    Then I follow "Add New Meeting"
    And I fill in "new_meeting_title" with "General Meeting"
    And I fill in "meeting_description" with "Let us meet and have a general meeting"
    Then I fill in datepicker with id "new_meeting_form_date" with current date
    And I select "12:00 am" from "meeting_start_time_of_day" within "#new_meeting"
    And I check "meeting_recurrent"
    And I select "Daily" from "meeting_schedule_rule"
    And I press "Create"
    Then I wait for ajax to complete
    Then I in "60" seconds should see "General Meeting"
    And I click on profile picture and click "Sign out"
    And I have logged in as "robert@example.com"
    And I follow "name & madankumarrajan"
    And I mark occurrence number "1" as "Yes" from "Side Pane"
    And I mark occurrence number "2" as "No" from "Side Pane"
    Then I should see "MEETINGS" within "ul.metismenu"
    Then I follow "Upcoming" within "ul.metismenu"
    Then I in "60" seconds should see "General Meeting"
    Then I scroll to bottom of the page
    And I mark occurrence number "5" as "Yes" from "Meeting Listing"
    And I mark occurrence number "6" as "No" from "Meeting Listing"
    And I follow "name & madankumarrajan"
    And I mark occurrence number "3" as "No" from "Side Pane mobile"
    And I mark occurrence number "4" as "Yes" from "Side Pane mobile"
    And I wait for ajax to complete
    And I logout

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
    Then I fill in "day(s) after the meeting request has been accepted and the meeting details were not decided" with "-1"
    And I press "Save"
    Then I should see "Please enter a valid positive value."
    Then I fill in "day(s) after the meeting request has been accepted and the meeting details were not decided" with "15"
    And I press "Save"
    Then I should see "Your changes have been saved"
    Then I logout

  @javascript
  Scenario: Closed group meeting should not have edit details from meeting show page
    Given the current program is "primary":""
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    And I enable "mentoring_connection_meeting" feature as a super user 
    And I have logged in as "robert@example.com"
    When I select "Albers Mentor Program" from the program selector

    Given there is a past meeting I attended inside of a group
    And I wait for ajax to complete
    And I click on profile picture and click "Sign out"
    When I have logged in as "ram@example.com"
    Given the current program is "primary":"Albers"

    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Mentoring Connection Settings"
    And I click "#program_allow_users_to_leave_connection_true"
    And I press "Save"
    And I wait for ajax to complete
    And I click on profile picture and click "Sign out"
    And I have logged in as "robert@example.com"

    Then I follow "Past" within "ul.metismenu"
    And I follow "Inside Group"
    And I should see "Edit Details"
    And I follow "name & madankumarrajan"
    And I follow "Close Mentoring Connection"
    And I press "Close Mentoring Connection"
    And I follow "name & madankumarrajan"
    Then I follow "Past" within "ul.metismenu"
    And I follow "Inside Group"
    And I should not see "Edit Details"
    Then I logout

@javascript
Scenario: Meeting edit with all three options from meeting show page for reccurrent meeting

  Given the current program is "primary":""
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I enable "mentoring_connection_meeting" feature as a super user 

  And I have logged in as "robert@example.com"
  When I select "Albers Mentor Program" from the program selector
  Then Admin update expiry date of group named "name & madankumarrajan" to "January 26, 2021"

  And I follow "name & madankumarrajan"
  Then I follow "Add New Meeting"
  And I fill in "new_meeting_title" with "General Meeting"
  And I fill in "meeting_description" with "Let us meet and have a general meeting"
  And I select "January 26, 2020" for "#new_meeting_form_date" from datepicker
  And I check "meeting_recurrent"
  And I select "Daily" from "meeting_schedule_rule"
  And I press "Create"
  Then I wait for ajax to complete
  Then I in "60" seconds should see "General Meeting"
  And I follow "General Meeting"
  Then I should see "Edit Details"
  And I follow "Edit Details"
  And I fill in "edit_meeting_location" with "London(U.K)"
  And I fill in "edit_meeting_topic" with "Edited General Meeting"
  Then I save the edited meeting with ".all-option" option
  Then I wait for ajax to complete
  Then I in "60" seconds should see "London(U.K)"
  Then I should see "Edited General Meeting"
  And I follow "Edited General Meeting"
  Then I should see "Edit Details"
  And I follow "Edit Details"
  And I fill in "edit_meeting_topic" with "General Meeting"
  And I fill in "edit_meeting_location" with "U.S.A"
  And I select "04:00 am" from "meeting_start_time_of_day" within "#edit_meeting"
  Then I save the edited meeting with ".current-option" option
  Then I validate data for edited things and destroy meeting
  And I follow "Edited General Meeting"
  Then I should see "Edit Details"
  And I follow "Edit Details"
  And I fill in "edit_meeting_location" with "U.S.A"
  And I select "04:00 am" from "meeting_start_time_of_day" within "#edit_meeting"
  Then I save the edited meeting with ".following-option" option
  Then I validate data for edited things and destroy meeting
  Then I logout

@javascript
Scenario: Meeting Reschedule with all three options
  When I have logged in as "ram@example.com"
  Given the current program is "primary":""
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I enable "mentoring_connection_meeting" feature as a super user 
  And I logout
  And I have logged in as "robert@example.com"
  When I select "Albers Mentor Program" from the program selector
  Then Admin update expiry date of group named "name & madankumarrajan" to "January 26, 2021"

  And I follow "name & madankumarrajan"
  Then I follow "Add New Meeting"
  And I fill in "new_meeting_title" with "General Meeting"
  And I fill in "meeting_description" with "Let us meet and have a general meeting"
  And I select "January 26, 2020" for "#new_meeting_form_date" from datepicker
  And I check "meeting_recurrent"
  And I select "Daily" from "meeting_schedule_rule"
  And I press "Create"
  Then I wait for ajax to complete
  Then I in "60" seconds should see "General Meeting"
  And I reschedule occurrence number "0"
  And I fill in "edit_meeting_location" with "London(U.K)"
  Then I save the edited meeting with ".all-option" option
  Then I in "60" seconds should see "London(U.K)"
  And I reschedule occurrence number "1"
  And I fill in "edit_meeting_location" with "U.S.A"
  And I select "04:00 am" from "meeting_start_time_of_day" within "#edit_meeting"
  Then I save the edited meeting with ".current-option" option
  Then I validate data for edited things and destroy meeting
  And I reschedule occurrence number "1"
  And I fill in "edit_meeting_location" with "U.S.A"
  And I select "04:00 am" from "meeting_start_time_of_day" within "#edit_meeting"
  Then I save the edited meeting with ".following-option" option
  Then I validate data for edited things and destroy meeting
  Then I logout

@javascript
Scenario: Group Meeting non Recurrent Redirect to Meeting Show Page
  Given the current program is "primary":""
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I enable "mentoring_connection_meeting" feature as a super user 
  And I have logged in as "robert@example.com"
  When I select "Albers Mentor Program" from the program selector
  Then Admin update expiry date of group named "name & madankumarrajan" to "January 26, 2021"

  And I follow "name & madankumarrajan"
  Then I follow "Add New Meeting"
  And I fill in "new_meeting_title" with "General Meeting"
  And I fill in "meeting_description" with "Let us meet and have a general meeting"
  And I select "January 26, 2020" for "#new_meeting_form_date" from datepicker
  And I press "Create"

  And I go_to Meeting Show Page
  And I Reschedule meeting with topic "General Meeting"
  And I wait for ajax to complete
  And I fill in "edit_meeting_location" with "U.S.A"
  And I select "04:00 am" from "meeting_start_time_of_day" within "#edit_meeting"
  And I press "Save"
  And I should see "Details"
  And I should see "Notes"
  And I should see "Let us meet and have a general meeting"
  Then I logout

@javascript @cross-browser
Scenario: Meeting Edit with all three options
  When I have logged in as "ram@example.com"
  Given the current program is "primary":""
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I enable "mentoring_connection_meeting" feature as a super user 
  And I logout
  And I have logged in as "robert@example.com"
  When I select "Albers Mentor Program" from the program selector
  Then Admin update expiry date of group named "name & madankumarrajan" to "January 26, 2021"

  And I follow "name & madankumarrajan"
  Then I follow "Add New Meeting"
  And I fill in "new_meeting_title" with "General Meeting"
  And I fill in "meeting_description" with "Let us meet and have a general meeting"
  And I select "January 26, 2020" for "#new_meeting_form_date" from datepicker
  And I check "meeting_recurrent"
  And I select "Daily" from "meeting_schedule_rule"
  And I press "Create"
  Then I wait for ajax to complete
  Then I in "60" seconds should see "General Meeting"

  And I edit occurrence number "0"
  And I fill in "edit_meeting_location" with "London(U.K)"
  Then I save the edited meeting with ".all-option" option
  Then I in "60" seconds should see "London(U.K)"
  And I edit occurrence number "1"
  And I fill in "edit_meeting_location" with "U.S.A"
  And I select "04:00 am" from "meeting_start_time_of_day" within "#edit_meeting"
  Then I save the edited meeting with ".current-option" option
  Then I validate data for edited things and destroy meeting
  And I edit occurrence number "1"
  And I fill in "edit_meeting_location" with "U.S.A"
  And I select "04:00 am" from "meeting_start_time_of_day" within "#edit_meeting"
  Then I save the edited meeting with ".following-option" option
  Then I validate data for edited things and destroy meeting
  Then I logout

@javascript @cross-browser
Scenario: Edit Recurring meeting inside a group
  When I have logged in as "ram@example.com"
  And I enable "mentoring_connection_meeting" feature as a super user
  And I logout

  Given Admin update expiry date of group named "name & madankumarrajan" to "Jan 26, 2021"
  When I have logged in as "robert@example.com"
  And I select "Albers Mentor Program" from the program selector

  And I follow "name & madankumarrajan"
  And I follow "Add Meeting" in the page actions bar
  And I follow "Add New Meeting" in the page actions bar
  And I fill in "new_meeting_title" with "Recurrent Daily Meeting"
  And I fill in "meeting_description" with "Let us meet and have a recurrent meeting"
  And I select "January 26, 2020" for "#new_meeting_form_date" from datepicker
  And I check "meeting_recurrent"
  And I select "Daily" from "meeting_schedule_rule"
  And I select "February 5, 2020" for "#meeting_repeats_end_date" from datepicker
  And I press "Create"
  Then I wait for ajax to complete
  Then I in "60" seconds should see "Recurrent Daily Meeting"
  And I edit occurrence number "0"
  And I select "" for "#edit_meeting #new_meeting_form_date" from datepicker
  Then I follow "Save"
  Then I should see "Edit Meeting" within ".modal-title"
  And I select "January 25, 2020" for "#edit_meeting #new_meeting_form_date" from datepicker
  Then I follow "Save"
  Then I in "60" seconds should see "Sat, Jan 25, 2020" within "#upcoming_meetings"

  @javascript @cross-browser
  Scenario: Accepting a meeting request
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I check "One-time Mentoring"
  And I press "Save"
  And I logout

  When I have logged in as "student_14@example.com"

  And I create a Meeting Request having topic "Meeting in this month" with "robert@example.com" in program "albers" for "1 day from now"
  And I create a Meeting Request having topic "Meeting in next month" with "robert@example.com" in program "albers" for "1 month from now"
  And I logout
  When I have logged in as "robert@example.com"

  And I click ".pending_requests_notification_icon"
  And I follow "Meeting Requests"
  And I accept meeting request with topic "Meeting in this month"
  And I validate accept message popup data for meeting with topic "Meeting in this month", count as "1" and limit as "0"
  Then I close modal
  Then I follow "Requests" within "ul.metismenu"
  And I accept meeting request with topic "Meeting in next month"
  And I validate accept message popup data for meeting with topic "Meeting in next month", count as "1" and limit as "0"
  And I follow "Change"
  And I wait for "1" seconds
  And I should see "Maximum number of meetings in a calendar month"
  And I logout
