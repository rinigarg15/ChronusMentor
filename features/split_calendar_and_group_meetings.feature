Feature: Calendar Split Feature
  In order to setup a meeting or preview my meetings
  As a member
  I should be able to access feature when the calendar feature is enabled

 Background:
    # The Last day in the calendar should be Time Travelled using time cop gem
    # because of the restrictions like meeting can be created 24 hours in advance
    # so, saturday is time travelled to avoid this issue
    Given valid and appropriate date time settings
    Given the current program is "primary":"albers"
    And I create a mentoring slot from "13:00:00" to "14:00:00" for "robert@example.com"
    And I create a mentoring slot from "13:00:00" to "19:30:00" for "rahim@example.com"

  @javascript
  Scenario: Group Meetings Enabled & Disabled with Calendar Feature Enabled & Disabled
    And I disable calendar feature that was removed from UI as super user of "primary":"albers"

    When I have logged in as "ram@example.com"
    And I enable "mentoring_connection_meeting" feature as a super user
    Then I logout

    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    Then I should see "Meetings" within "ul.metismenu"
    And I should not see "Edit your Availability Calendar"
    And I follow "name & madankumarrajan" subtab inside opened navigation header
    Then I should see "Add Meeting"
    And I follow "Add Meeting"
    Then I should see "Add New Meeting"
    Then I should see "Record Past Meeting"
    Then I logout

    When I have logged in as "ram@example.com"
    And I disable the feature "mentoring_connection_meeting" as a super user
    Then I logout

    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    Then I should not see "Meetings" within "ul.metismenu"
    And I should not see "Edit your Availability Calendar"
    And I follow "name & madankumarrajan" subtab inside opened navigation header
    Then I should not see "Add Meeting"
    Then I logout

  @javascript
  Scenario: Enable & Disable Groups Meeting Feature
    When I have logged in as "ram@example.com"
    And I enable "mentoring_connection_meeting" feature as a super user
    Then I logout

    And I have logged in as "robert@example.com"
    When I select "Albers Mentor Program" from the program selector
    And I click on profile picture and click "View Profile"
    Then I should not see "Edit your Availability Calendar"
    Then I logout

    When I have logged in as "ram@example.com"
    And I enable "mentoring_connection_meeting" feature as a super user
    Then I logout

    And I have logged in as "robert@example.com"
    When I select "Albers Mentor Program" from the program selector
    And I click on profile picture and click "View Profile"
    Then I should not see "Edit your Availability Calendar"
    Then I logout

  @javascript @cross-browser
  Scenario: Group Meetings Enabled with Enabling & Disabling Calendar Feature
    When I have logged in as "ram@example.com"
    And I change meeting availability preference of member with email "robert@example.com" to configure availability slots
    And I enable "mentoring_connection_meeting" feature as a super user
    Then I logout

    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"

    And I have logged in as "ram@example.com"
    And I allow mentors in the program to configure availability slots
    And I logout

    And I have logged in as "robert@example.com"
    When I select "Albers Mentor Program" from the program selector
    And I click on profile picture and click "Edit Profile"
    Then I should see "MEETINGS" within "ul.metismenu"
    And I follow "Actions"
    And I should see "Edit your Availability Calendar"
    When I follow "Edit your Availability Calendar"
    Then I should see "Set your availability"
    And I should see "Click here to add a timeslot"
    And I logout

    And I have logged in as "student_0@example.com"
    Given the current program is "primary":"albers"
    Then I should see the tab "Mentoring Calendar"
    And I should see the tab "Upcoming"
    And I should see the tab "Past"
    And I should see the tab "Requests"
    And I logout

    And I disable calendar feature that was removed from UI as super user of "primary":"albers"

    And I have logged in as "robert@example.com"
    When I select "Albers Mentor Program" from the program selector

    And I click on profile picture and click "View Profile"
    Then I should see "Meetings" within "ul.metismenu"

    And I follow "Actions"
    And I should not see "Edit your Availability Calendar"
    And I logout

    And I have logged in as "student_0@example.com"
    Then I should see "Meetings" within "ul.metismenu"
    And I logout

  @javascript
  Scenario: Group Meetings Enabled & Disabled with Calendar Enabled
    And I disable calendar feature that was removed from UI as super user of "primary":"albers"

    When I have logged in as "ram@example.com"
    And I enable "mentoring_connection_meeting" feature as a super user
    Then I logout

    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    And I should not see "Edit your Availability Calendar"
    And I follow "name & madankumarrajan" subtab inside opened navigation header
    Then I should see "Add Meeting"
    And I follow "Add Meeting"
    Then I should see "Add New Meeting"
    Then I should see "Record Past Meeting"
    Then I should see "Add New Meeting"
    Then I follow "Add New Meeting"
    And I should not see "Clear"
    And I should not see "Select all"
    Then I cancel modal
    Then I logout

    When I have logged in as "ram@example.com"
    And I disable the feature "mentoring_connection_meeting" as a super user
    Then I logout

    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    And I should not see "Edit your Availability Calendar"
    And I follow "name & madankumarrajan" subtab inside opened navigation header
    Then I should not see "Add Meeting"
    And I logout

  @javascript
  Scenario: Select all deselect all attendees
    Given the current program is "annauniv":"psg"
    When I have logged in as "ceg_admin@example.com"
    And I enable "mentoring_connection_meeting" feature as a super user
    Then I logout
    And I have logged in as "mentor1@psg.com"
    And I follow "mentora, mentorb, mentorc, psg, psg, & psg"
    And I follow "Add Meeting"
    And I follow "Add New Meeting"
    Then the "studa psg" checkbox_id should be checked
    Then the "studb psg" checkbox_id should be checked
    Then the "studc psg" checkbox_id should be checked
    Then the "PSG mentorc" checkbox_id should be checked
    Then the "PSG mentorb" checkbox_id should be checked
    And I follow "Clear"
    Then the "studa psg" checkbox_id should not be checked
    Then the "studb psg" checkbox_id should not be checked
    Then the "studc psg" checkbox_id should not be checked
    Then the "PSG mentorc" checkbox_id should not be checked
    Then the "PSG mentorb" checkbox_id should not be checked
    And I follow "Select all"
    Then the "studa psg" checkbox_id should be checked
    Then the "studb psg" checkbox_id should be checked
    Then the "studc psg" checkbox_id should be checked
    Then the "PSG mentorc" checkbox_id should be checked
    Then the "PSG mentorb" checkbox_id should be checked