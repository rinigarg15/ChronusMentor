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
  Scenario: Creating meetings inside a group
    When I have logged in as "ram@example.com"
    When I select "Primary Organization" from the program selector
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    And I logout

    When I have logged in as "ram@example.com"
    And I enable "mentoring_connection_meeting" feature as a super user
    And I logout

    Given Admin update expiry date of group named "name & madankumarrajan" to "Jan 26, 2021"
    When I have logged in as "robert@example.com"
    And I select "Albers Mentor Program" from the program selector

    And I follow "My Mentoring Connections"
    And I follow "name & madankumarrajan"
    And I follow "Add Meeting" in the page actions bar
    And I follow "Add New Meeting" in the page actions bar
    And I should not see "Please submit a request to this"
    And I fill in "new_meeting_title" with "General Meeting"
    And I fill in "meeting_description" with "Let us meet and have a general meeting"
    And I select "January 26, 2020" for "#new_meeting_form #new_meeting_form_date" from datepicker
    And I press "Create"
    And I should see the tab "Meetings" selected in "mentoring_area_tabs"
    And I should not see the tab "Upcoming" selected
    And I should see "Sun, Jan 26, 2020"
    And I should see "08:00 am UTC (30 min)"
    And I should see "Set Location"
    And I should see "General Meeting"
    And I should see "Let us meet and have a general meeting"
    And I follow "General Meeting"
    And I should see "Sun, Jan 26, 2020"
    And I should see "08:00 am UTC (30 min)"
    And I should see "Set Location"
    And I should see "General Meeting"
    And I should see "Let us meet and have a general meeting"
    And I should see "RSVP Attending"
    And I should see "Good unique name"
    And I should see "mkr_student madankumarrajan"
    And I should see "Tips"
    And I should see "Capture the meeting notes, followups and resource attachments from the notes tab."

  @javascript @cross-browser
  Scenario: Creating daily recurrent meetings inside a group
    When I have logged in as "ram@example.com"
    And I enable "mentoring_connection_meeting" feature as a super user
    And I logout

    Given Admin update expiry date of group named "name & madankumarrajan" to "Jan 26, 2021"
    When I have logged in as "robert@example.com"
    And I select "Albers Mentor Program" from the program selector
    And I follow "My Mentoring Connections"
    And I follow "name & madankumarrajan"
    And I follow "Add Meeting" in the page actions bar
    And I follow "Add New Meeting" in the page actions bar
    
    And I fill in "new_meeting_title" with "Recurrent Daily Meeting"
    And I fill in "meeting_description" with "Let us meet and have a recurrent meeting"
    And I select "January 26, 2020" for "#new_meeting_form #new_meeting_form_date" from datepicker
    And I check "meeting_recurrent"
    And I should see "month" within ".cjs-repeat-every-help"
    And I select "Daily" from "meeting_schedule_rule"
    And I should see "day" within ".cjs-repeat-every-help"
    And I select "Weekly" from "meeting_schedule_rule"
    And I should see "week" within ".cjs-repeat-every-help"
    And I select "Monthly" from "meeting_schedule_rule"
    And I should see "month" within ".cjs-repeat-every-help"
    And I select "Daily" from "meeting_schedule_rule"
    And I select "January 29, 2020" for "#meeting_repeats_end_date" from datepicker
    And I press "Create"
    
    And I should see "Sun, Jan 26, 2020"
    And I should see "Mon, Jan 27, 2020"
    And I should see "Tue, Jan 28, 2020"
    And I should see "Wed, Jan 29, 2020"
    And I should see "08:00 am UTC (30 min)"
    And I should see "No location specified"
    And I should see "Recurrent Daily Meeting"
    And I should see "Let us meet and have a recurrent meeting"

  @javascript
  Scenario: Creating daily with repeat option recurrent meetings inside a group
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
    And I select "January 26, 2020" for "#new_meeting_form #new_meeting_form_date" from datepicker
    And I check "meeting_recurrent"
    And I select "Daily" from "meeting_schedule_rule"
    And I select "3" from "meeting_repeat_every"
    And I select "February 5, 2020" for "#meeting_repeats_end_date" from datepicker
    And I press "Create"
    
    And I should see "Sun, Jan 26, 2020"
    And I should see "Wed, Jan 29, 2020"
    And I should see "Sat, Feb 01, 2020"
    And I should see "Tue, Feb 04, 2020"
    And I should see "08:00 am UTC (30 min)"
    And I should see "No location specified"
    And I should see "Recurrent Daily Meeting"
    And I should see "Let us meet and have a recurrent meeting"

  @javascript @cross_browser
  Scenario: Requests count for upcoming non responding meeting should change in footer
    When I have logged in as "ram@example.com"
    And I enable "mentoring_connection_meeting" feature as a super user
    And I logout
    Given Admin update expiry date of group named "name & madankumarrajan" to "Jan 26, 2021"
    When I have logged in as "robert@example.com"
    And I follow "name & madankumarrajan"
    And I follow "Add New Meeting"
    And I should not see "Please submit a request to this"
    And I fill in "new_meeting_title" with "Recurrent Daily Meeting"
    And I fill in "meeting_description" with "Let us meet and have a recurrent meeting"
    And I select "January 26, 2020" for "#new_meeting_form_date" from datepicker
    And I check "meeting_recurrent"
    And I select "3" from "meeting_repeat_every"
    And I select "February 5, 2020" for "#meeting_repeats_end_date" from datepicker
    And I press "Create"
    And I should see "Sun, Jan 26, 2020"
    And I should see "Attending"
    And I should see "(Change)"
    Then I logout
    And I have logged in as "mkr@example.com"
    Then I change to mobile view
    And I follow mentoring connections in mobile footer
    #And I should see "6" as total count and "5" as subcount for meeting requests #Time based failure count
    And I follow "No"
    And I follow "Decline"
    #And I should see "5" as total count and "4" as subcount for meeting requests
    And I logout

  @javascript @cross-browser
  Scenario: Creating monthly recurrent meetings with day of the month option inside a group
    When I have logged in as "ram@example.com"
    And I enable "mentoring_connection_meeting" feature as a super user
    And I logout

    Given Admin update expiry date of group named "name & madankumarrajan" to "Jan 26, 2021"
    When I have logged in as "robert@example.com"
    And I select "Albers Mentor Program" from the program selector
    And I follow "name & madankumarrajan"
    And I follow "Add Meeting" in the page actions bar
    And I follow "Add New Meeting" in the page actions bar
    
    And I fill in "new_meeting_title" with "Recurrent Monthly Meeting"
    And I fill in "meeting_description" with "Let us meet and have a recurrent meeting"
    And I select "January 26, 2020" for "#new_meeting_form #new_meeting_form_date" from datepicker
    And I check "meeting_recurrent"
    And I select "Monthly" from "meeting_schedule_rule"
    And I choose "meeting_repeats_by_month_date_true"
    And I select "April 26, 2020" for "#meeting_repeats_end_date" from datepicker
    And I press "Create"
    
    And I should see "Sun, Jan 26, 2020"
    And I should see "Wed, Feb 26, 2020"
    And I should see "Thu, Mar 26, 2020"
    And I should see "Sun, Apr 26, 2020"
    And I should see "08:00 am UTC (30 min)"
    And I should see "No location specified"
    And I should see "Recurrent Monthly Meeting"
    And I should see "Let us meet and have a recurrent meeting"

  @javascript
  Scenario: Creating monthly recurrent meetings with day of the week option inside a group
    When I have logged in as "ram@example.com"
    And I enable "mentoring_connection_meeting" feature as a super user
    And I logout

    Given Admin update expiry date of group named "name & madankumarrajan" to "Jan 26, 2021"
    When I have logged in as "robert@example.com"
    And I select "Albers Mentor Program" from the program selector
    And I follow "My Mentoring Connections"
    And I follow "name & madankumarrajan"
    And I follow "Add Meeting" in the page actions bar
    And I follow "Add New Meeting" in the page actions bar
    
    And I fill in "new_meeting_title" with "Recurrent Monthly Meeting"
    And I fill in "meeting_description" with "Let us meet and have a recurrent meeting"
    And I select "January 26, 2020" for "#new_meeting_form #new_meeting_form_date" from datepicker
    And I check "meeting_recurrent"
    And I select "Monthly" from "meeting_schedule_rule"
    And I choose "meeting_repeats_by_month_date_false"
    And I select "April 30, 2020" for "#meeting_repeats_end_date" from datepicker
    And I press "Create"
    
    And I should see "Sun, Jan 26, 2020"
    And I should see "Sun, Feb 23, 2020"
    And I should see "Sun, Mar 22, 2020"
    And I should see "Sun, Apr 26, 2020"
    And I should see "08:00 am UTC (30 min)"
    And I should see "No location specified"
    And I should see "Recurrent Monthly Meeting"
    And I should see "Let us meet and have a recurrent meeting"

  @javascript @cross-browser
  Scenario: Creating weekly recurrent meetings with day of the week option inside a group
    When I have logged in as "ram@example.com"
    And I enable "mentoring_connection_meeting" feature as a super user
    And I logout

    Given Admin update expiry date of group named "name & madankumarrajan" to "Jan 26, 2021"
    When I have logged in as "robert@example.com"
    And I select "Albers Mentor Program" from the program selector
    And I follow "name & madankumarrajan"
    And I follow "Add Meeting" in the page actions bar
    And I follow "Add New Meeting" in the page actions bar
    And I fill in "new_meeting_title" with "Recurrent Weekly Meeting"
    And I fill in "meeting_description" with "Let us meet and have a recurrent meeting"
    And I select "January 26, 2020" for "#new_meeting_form #new_meeting_form_date" from datepicker
    And I check "meeting_recurrent"
    And I select "Weekly" from "meeting_schedule_rule"
    And I check "S"
    And I check "M"
    And I select "February 15, 2020" for "#meeting_repeats_end_date" from datepicker
    And I press "Create"
    
    And I should see "Sun, Jan 26, 2020"
    And I should see "Mon, Jan 27, 2020"
    And I should see "Sun, Feb 02, 2020"
    And I should see "Mon, Feb 03, 2020"
    And I should see "Sun, Feb 09, 2020"
    And I should see "Mon, Feb 10, 2020"
    And I should see "08:00 am UTC (30 min)"
    And I should see "No location specified"
    And I should see "Recurrent Weekly Meeting"
    And I should see "Let us meet and have a recurrent meeting"

  @javascript
  Scenario: Record Past meeting in a group
    When I have logged in as "ram@example.com"
    And I enable "mentoring_connection_meeting" feature as a super user
    And I logout
    Given Admin update expiry date of group named "name & madankumarrajan" to "Jan 26, 2021"
    When I have logged in as "robert@example.com"
    And I select "Albers Mentor Program" from the program selector
    And I follow "My Mentoring Connections"
    And I follow "name & madankumarrajan"
    And I follow "Meetings" within "div#mentoring_area_tabs"
    And I follow "Upcoming Meetings" within "div#mentoring_area_tabs"
    And I follow "Add Meeting" in the page actions bar
    And I follow "Record Past Meeting" in the page actions bar
    And I fill in "new_meeting_title" with "Past Meeting"
    And I fill in "meeting_description" with "Skype call with Sherlock"
    And I select "January 26, 2000" for "#past_meeting_form #new_meeting_form_date" from datepicker
    And I should not see "repeat"
    And I press "Create"
    And I should see the tab "Meetings" selected in "mentoring_area_tabs"
    Then I should see "Past Meetings"
    And I should see "Skype call with Sherlock"

    And I follow "Add Meeting" in the page actions bar
    And I follow "Add New Meeting" in the page actions bar
    And I fill in "new_meeting_title" with "General Meeting"
    And I fill in "meeting_description" with "Let us meet and have a general meeting"
    And I select "January 26, 2020" for "#new_meeting_form #new_meeting_form_date" from datepicker
    And I should see "Repeat"
    And I press "Create"
    Then I should see "Upcoming Meetings"
    And I should see "Let us meet and have a general meeting"

    And I follow "Meetings" within "div#mentoring_area_tabs"
    And I follow "Past Meetings" within "div#mentoring_area_tabs"
    And I should see "Skype call with Sherlock"

    And I follow "Plan"
    Then I reload the page
    And I follow "Add Meeting" in the page actions bar
    And I follow "Add New Meeting" in the page actions bar
    And I fill in "new_meeting_title" with "Intro Meeting"
    And I fill in "meeting_description" with "Let us discuss about onboarding"
    And I select "January 25, 2020" for "#new_meeting_form #new_meeting_form_date" from datepicker
    And I press "Create"
    Then I should see "Upcoming Meetings"
    Then I should see "Let us discuss about onboarding"

    And I follow "Plan"
    And I follow "Add Meeting" in the page actions bar
    And I follow "Record Past Meeting" in the page actions bar
    And I fill in "new_meeting_title" with "Record Meeting"
    And I fill in "meeting_description" with "Informal meeting with mentor"
    And I select "January 25, 2000" for "#past_meeting_form #new_meeting_form_date" from datepicker
    And I press "Create"
    Then I should see "Past Meetings"
    Then I should see "Informal meeting with mentor"

    Then I follow "Plan"
    And I follow "Intro Meeting"
    And I should see "Capture the meeting notes, followups and resource attachments from the notes tab."
    And I should see "Let us discuss about onboarding"

  @javascript
  Scenario: Admin viewing meeting area for group meeting
    When I have logged in as "ram@example.com"
    And I enable "mentoring_connection_meeting" feature as a super user
    And I logout
    Given Admin update expiry date of group named "name & madankumarrajan" to "Jan 26, 2021"
    When I have logged in as "robert@example.com"
    And I select "Albers Mentor Program" from the program selector
    And I follow "My Mentoring Connections"
    And I follow "name & madankumarrajan"
    And I follow "Plan"

    And I follow "Add New Meeting" within "div#side_pane_meetings"
    And I fill in "new_meeting_title" with "Intro Meeting"
    And I fill in "meeting_description" with "Let us discuss about onboarding1"
    And I select "January 25, 2020" for "#new_meeting_form #new_meeting_form_date" from datepicker
    And I press "Create"
    Then I should see "Upcoming Meetings"
    Then I should see "Let us discuss about onboarding1"

    And I follow "Plan"
    And I follow "Record Past Meeting" within "div#side_pane_meetings"
    And I fill in "new_meeting_title" with "Intro Meeting"
    And I fill in "meeting_description" with "Let us discuss about onboarding2"
    And I select "January 26, 2000" for "#past_meeting_form #new_meeting_form_date" from datepicker
    And I press "Create"
    Then I should see "Past Meetings"
    Then I should see "Let us discuss about onboarding2"
    

    And I follow "Plan"
    And I follow "Add Meeting" in the page actions bar
    And I follow "Add New Meeting" in the page actions bar
    And I fill in "new_meeting_title" with "Intro Meeting"
    And I fill in "meeting_description" with "Let us discuss about onboarding3"
    And I select "January 25, 2020" for "#new_meeting_form #new_meeting_form_date" from datepicker
    And I press "Create"
    Then I should see "Upcoming Meetings"
    Then I should see "Let us discuss about onboarding3"

    And I logout
    Then I have logged in as "ram@example.com"
    Then I follow "Mentors"
    And I follow "Good unique name"
    Then I follow "name & madankumarrajan"
    And I follow "Meetings"
    And I follow "Upcoming Meetings"
    And I follow "Intro Meeting"
    And I should see "Capture the meeting notes, followups and resource attachments from the notes tab."
    And I should see "Let us discuss about onboarding"
    And I should not see "RSVP"
    Then I follow "Manage"
    Then I follow "Surveys"

  @javascript
  Scenario: Non-responding meetings count
    When I have logged in as "ram@example.com"
    And I enable "mentoring_connection_meeting" feature as a super user
    And I logout
    Given Admin update expiry date of group named "name & madankumarrajan" to "Apr 30, 2020"
    When I have logged in as "robert@example.com"
    And I select "Albers Mentor Program" from the program selector
    And I follow "My Mentoring Connections"
    And I follow "name & madankumarrajan"
    And I follow "Add Meeting" in the page actions bar
    And I follow "Record Past Meeting" in the page actions bar
    And I fill in "new_meeting_title" with "Past Meeting 1"
    And I fill in "meeting_description" with "Skype call with Sherlock"
    And I select "January 26, 2000" for "#past_meeting_form #new_meeting_form_date" from datepicker
    And I press "Create"
    And I follow "Add Meeting" in the page actions bar
    And I follow "Record Past Meeting" in the page actions bar
    And I fill in "new_meeting_title" with "Past Meeting 2"
    And I fill in "meeting_description" with "Skype call with Mycroft"
    And I select "January 12, 2000" for "#past_meeting_form #new_meeting_form_date" from datepicker
    And I press "Create"
    And I should see "Skype call with Sherlock"
    And I should see "Skype call with Mycroft"


    And I follow "Add Meeting" in the page actions bar
    And I follow "Add New Meeting" in the page actions bar
    And I fill in "new_meeting_title" with "General Meeting 1"
    And I fill in "meeting_description" with "Let us meet and have a general meeting"
    And I select "January 26, 2020" for "#new_meeting_form #new_meeting_form_date" from datepicker
    And I press "Create"
    Then I in "60" seconds should see "Let us meet and have a general meeting"
    And I follow "Add Meeting" in the page actions bar
    And I follow "Add New Meeting" in the page actions bar
    And I fill in "new_meeting_title" with "General Meeting 2"
    And I fill in "meeting_description" with "Let us introduce ourselves"
    And I select "January 12, 2020" for "#new_meeting_form #new_meeting_form_date" from datepicker
    And I press "Create"
    And I in "60" seconds should see "Let us introduce ourselves"
    And I logout

    When I have logged in as "mkr@example.com"
    And I select "Albers Mentor Program" from the program selector
    And I follow "My Mentoring Connections"
    And I follow "name & madankumarrajan"
   # Then I should see "6" within ".cjs_non_responding_member_meetings"
    Then I follow "Yes" within "#group_side_pane .sidepane_asset_meeting_1"
    #Then I should see "5" within ".cjs_non_responding_member_meetings"

    And I follow "Add Meeting" in the page actions bar
    And I follow "Add New Meeting" in the page actions bar
    And I fill in "new_meeting_title" with "Recurrent Monthly Meeting"
    And I fill in "meeting_description" with "Let us meet and have a recurrent meeting"
    And I select "January 26, 2020" for "#new_meeting_form #new_meeting_form_date" from datepicker
    And I check "meeting_recurrent"
    And I select "Monthly" from "meeting_schedule_rule"
    And I choose "meeting_repeats_by_month_date_false"
    And I select "April 20, 2020" for "#meeting_repeats_end_date" from datepicker
    And I press "Create"
    Then I in "60" seconds should see "Sun, Jan 26, 2020"
    And I logout

    When I have logged in as "robert@example.com"
    And I select "Albers Mentor Program" from the program selector
    And I follow "My Mentoring Connections"
    And I follow "name & madankumarrajan"
    Then I should see "3" within ".cjs_non_responding_member_meetings"
    And I logout