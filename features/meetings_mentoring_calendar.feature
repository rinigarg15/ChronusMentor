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
    And I change meeting availability preference of member with email "robert@example.com" to configure availability slots
    And I change meeting availability preference of member with email "rahim@example.com" to configure availability slots
    And I stub chronus s3 utils

 @javascript
 Scenario: Mentor visits his self profile
    And I have logged in as "robert@example.com"
    And I click on profile picture and click "View Profile"
    And I should not see "Your Meetings"
    When I follow "Actions"
    Then I should not see "Edit your Availability Calendar"
    And I logout
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    And I have logged in as "robert@example.com"
    When I select "Albers Mentor Program" from the program selector
    And I click on profile picture and click "View Profile"
    And I should see "Meetings (0)"
    When I follow "Actions"
    Then I should see "Edit your Availability Calendar"
    When I follow "Meetings (0)"
    Then I should see "There are no upcoming meetings."
    Then I logout

  @javascript @cross-browser
  Scenario: Mentor visits mentoring connection
    And I have logged in as "robert@example.com"
    And I follow "name & madankumarrajan"
    And I logout

    When I have logged in as "ram@example.com"
    And I enable "mentoring_connection_meeting" feature as a super user
    And I logout

    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    And I have logged in as "robert@example.com"
    When I select "Albers Mentor Program" from the program selector
    When I follow "Home"
    And I follow "name & madankumarrajan"
    Then I should see "Meeting"
    And I should see "Add Meeting"

 @javascript @cross-browser
  Scenario: Accept and decline meeting from avalibilty calendar
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    And I have logged in as "ram@example.com"
    And I allow mentors in the program to configure availability slots
    And I enable "mentoring_connection_meeting" feature as a super user 
    And I logout
    Given there is a upcoming meeting outside of a group
    And I have logged in as "robert@example.com"
    When I select "Albers Mentor Program" from the program selector
    Then I follow "Home"
    And I follow "Upcoming"
    Then I click on the event with text "Outside Group"
    Then I should see "This slot is blocked because you have a pending request at this time."
    Then I press "OK"
    Then I accept upcoming meeting outside if a group
    Then I reset rsvp responses for the last meeting
    Then I follow "Home"
    And I follow "Upcoming"
    Then I click on the event with text "Outside Group"
    And I follow "No" within "div.meeting_modal"
    Then I close modal
    Then I follow "Home"
    And I follow "Upcoming"
    Then I click on the event with text "Outside Group"
    And I follow "No" within "div.meeting_modal"
    And I follow "Decline Meeting"
    Then I click on the event with text "Outside Group"
    And I should see "Not Attending(Change)" within "div.meeting_modal"
    And I follow "Change" within "div.meeting_modal"
    And I should see "Attending(Change)" within "div.meeting_modal"
    And I follow "Change" within "div.meeting_modal"
    Then I wait for "1" seconds
    And I follow "Reschedule Meeting"
    And I fill in "edit_meeting_location" with "U.S.A"
    And I select "04:00 am" from "meeting_start_time_of_day" within "#edit_meeting"
    And I press "Save"
    And I wait for ajax to complete
    Then I reload the page
    Then I click on the event with text "Outside Group"
    And I should see "04:00 am" within "div.meeting_modal"  
    And I should see "U.S.A" within "div.meeting_modal"
    And I close modal
    And I destroy all meetings for member with email "robert@example.com"
    Given there is an accepted upcoming meeting outside of a group
    Then I reset rsvp responses for the last meeting
    Then I follow "Home"
    And I follow "Upcoming"
    Then I click on the event with text "Outside Group"
    And I should see "Yes" within "div.modal-content"
    And I should see "No" within "div.meeting_modal"
    And I follow "Yes" within "div.meeting_modal"
    And I should see "Attending(Change)" within "div.meeting_modal"
    And I logout

 @javascript @cross-browser
 Scenario: Mentor Setting and removing the availablity
    And I have logged in as "robert@example.com"
    And I should not see "Set Availability"
    And I logout
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    And I have logged in as "ram@example.com"
    And I allow mentors in the program to configure availability slots
    And I logout
    And I have logged in as "robert@example.com"
    When I select "Albers Mentor Program" from the program selector
    Then I follow "Home"
    And I follow "Upcoming"
    
    Then I should see "HSB"
    Then I should see "1:00 - 2:00"
    Then I click on the event created
    Then I should see "Availability Slot"
    Then I click to edit event
    And I fill in "mentoring_slot_location" with "MSB"
    And I press "save_mentoring_slot"
    
    Then I should see "MSB"
    Then I should see "1:00 - 2:00"
    Then I click on the event created
   
    Then I click to delete event
    Then I should not see "MSB"
    Then I should not see "1:00 - 2:00"
    And I should see "Click here to set your time zone or change your availability settings."
    And I logout

  @javascript @cross-browser
  Scenario: User who is not a mentor in current program should not see set availability slots
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    And I enable "calendar" feature that was removed from UI as super user of "primary":"nwen"
    Given the current program is "primary":"nwen"
    And I have logged in as "ram@example.com"
    And I allow mentors in the program to configure availability slots
    And I logout
    Given the current program is "primary":"albers"
    Given mentors in "primary":"albers" are allowed to configure availability slots
    And I have logged in as "rahim@example.com"
    Then I follow "Upcoming" within "ul.metismenu"
    Then I should not see "Set your availability"
    And I should not see "Click here to add a timeslot"
    And I enable "calendar" feature that was removed from UI as super user of "primary":"nwen"
    When I select "NWEN" from the program selector
    And I follow "Upcoming"
    Then I should see "Set your availability"
    And I should see "Click here to add a timeslot"
    And I logout

  @javascript @cross-browser
  Scenario: Mentee clicks on busy slot should see popup
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    And I have logged in as "ram@example.com"
    And I allow mentors in the program to configure availability slots
    And I logout
    Given the current program is "primary":"albers"
    And I have logged in as "student_0@example.com"
    Given there is an accepted upcoming meeting outside of a group
    Then I follow "Mentoring Calendar" within "ul.metismenu"
    Then I click on the event with text "Busy - Good unique name"
    And I should see "Good unique name has marked this time as busy and will not be available"
    And I press "OK"
    And I logout

  @javascript @cross-browser
  Scenario: Mentee visits the mentoring calendar page
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    And I have logged in as "ram@example.com"
    And I allow mentors in the program to configure availability slots
    And I logout
    Given the current program is "primary":"albers"
    And I have logged in as "student_0@example.com"
    Then I follow "Mentoring Calendar" within "ul.metismenu"
   
    Then I should see "HSB"
    Then I should see "1:00 - 2:00"
    Then I click on the event created
   
    Then I should see "Good unique name"
    Then I close remote modal
    Then I fill in "sf_quick_search" with "microsoft"
    And I press "Go"
    
    And I should see "Keyword (microsoft)"
    Then I should see "HSB"
    Then I should see "1:00 - 2:00"
    Then I follow "Mentors"
    Then I follow "Mentoring Calendar" within "ul.metismenu"
    And I follow "Apply last search"
    And the text field "sf_quick_search" in "div#quick_search" should have value "microsoft"
    And I should see "Keyword (microsoft)"
    Then I should see "HSB"
    Then I should see "1:00 - 2:00"
    Then I fill in "sf_quick_search" with "sample"
    And I press "Go"
    And I should see "Keyword (sample)"
    Then I should not see "HSB"
    Then I should not see "1:00 - 2:00"
    And I press browser back
    And I should see "Keyword (microsoft)"
    Then I should see "HSB"
    Then I should see "1:00 - 2:00"
    Then I follow "View Mentors"
    And I should see "Keyword (microsoft)"
    Then I should see "Mentors" within "div#title_box"
    When I check "filter_available_for_a_meeting"
    Then I should see "Availability Status" within "span#filter_item_availability_status"
    Then I follow "See Mentoring Calendar"
    Then I should see "Mentoring Calendar" within "div#title_box"
    And I should see "Keyword (microsoft)"
    Then I should see "Availability Status" within "span#filter_item_availability_status"

  @javascript @cross-browser
  Scenario: Mentee visits the mentoring calendar page
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    Given the current program is "primary":"albers"
    And I have logged in as "student_0@example.com"
    Then I follow "Mentors"
    When I check "filter_available_for_a_meeting"
    And I wait for ajax to complete
    Then I filter a mentor with name "Good unique name" using quick find
    Then I should see "No mentors found"
    Then I remove filter with id "filter_item_quick_search"
    Then I filter a mentor "Kal Raman" using quick find
    Then I uncheck "filter_long_term_availability"
    Then I uncheck "filter_available_for_a_meeting"
    Then I filter a mentor "Good unique name" using quick find
    Then I check "filter_long_term_availability"
    Then I filter a mentor with name "Good unique name" using quick find
    Then I should see "No mentors found"
    Then I remove filter with id "filter_item_quick_search"
    Then I filter a mentor "Kal Raman" using quick find
    Then I should see "1 - 10 of 19"
    Then I uncheck "filter_long_term_availability"
    Then I filter a mentor "Good unique name" using quick find
    Then I filter a mentor "Kal Raman" using quick find
    Then I should see "1 - 10 of 22"
    When I check "filter_available_for_a_meeting"
    Then I filter a mentor "Good unique name" using quick find
    Then I filter a mentor "Kal Raman" using quick find
    Then I check "filter_long_term_availability"
    Then I filter a mentor with name "Good unique name" using quick find
    Then I should see "No mentors found"
    Then I remove filter with id "filter_item_quick_search"
    Then I filter a mentor "Kal Raman" using quick find

  @javascript @cross-browser
  Scenario: Other users should be able to view the availability
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    And I have logged in as "ram@example.com"
    And I allow mentors in the program to configure availability slots
    And I logout
    And I have logged in as "student_0@example.com"
    When I navigate to "robert@example.com" profile in "albers"
    And I follow "Actions"
    And I follow "Request Meeting"
    And I fill in "new_meeting_title" with "Calendar Meeting"
    And I fill in "new_meeting_description" with "Let us meet and have a general meeting"
    Then I follow "Proceed to Select Times"
    Then I should see "HSB"
    Then I should see "01:00 PM"
    Then I should see "02:00 PM"
    Then I follow "Choose" within ".cjs_availability_slot_list"
    Then I should see "( Change Slot )"
    Then I follow "Change Slot"
    Then I follow "Enter Topic & Description"
    And I fill in "new_meeting_title" with "General Meeting"
    Then I follow "Proceed to Select Times"
    Then I should not see "( Change Slot )"
    Then I follow "Choose" within ".cjs_availability_slot_list"
    Then I should see "( Change Slot )"
    Then I press "Request Meeting"
    Then I should see "Your request for a meeting with Good unique name has been successfully sent. You will be notified when Good unique name responds to your request. You can look for other mentors who are available and reach out to them from here."


  @javascript @cross-browser
  Scenario: Mentee requests mentor with slot available using general availability message 
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    And I have logged in as "ram@example.com"
    And I allow mentors in the program to configure availability slots
    And I create a mentoring slot from "13:00:00" to "19:30:00" after "15" days for "robert@example.com"
    And I logout
    And I have logged in as "student_0@example.com"
    When I navigate to "robert@example.com" profile in "albers"
    And I follow "Actions"
    And I follow "Request Meeting"
    And I fill in "new_meeting_title" with "Calendar Meeting"
    And I fill in "new_meeting_description" with "Let us meet and have a general meeting"
    Then I follow "Proceed to Select Times"
    Then I should see "HSB"
    Then I should see "01:00 PM"
    Then I should see "07:30 PM"
    Then I should see "Choose" within ".cjs_availability_slot_list"
    Then I follow "Propose other times"
    Then I follow "Request Meeting"
    Then I should see "Please propose at least one timeslot or enter your availability preferences."
    And I fill in "mentee_general_availability_message" with "mentee general availability message"
    Then I follow "Request Meeting"
    Then I should see "Your request for a meeting with Good unique name has been successfully sent. You will be notified when Good unique name responds to your request. You can look for other mentors who are available and reach out to them from here."

  
  @javascript @cross-browser
  Scenario: Mentee requests meeting by proposing slots to mentor
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    And I have logged in as "ram@example.com"
    And I allow mentors in the program to configure availability slots
    And I logout
    When I have logged in as "robert@example.com"
    And I follow "Edit Profile"
    Then I follow "Settings"
    And I click on the section with header "One-time Mentoring"
    And I choose "member_will_set_availability_slots_false"
    And I fill in "member[availability_not_set_message]" with "Please contact me directly"
    And I press "Save" within "div#settings_content_onetime"
    And I logout
    And I have logged in as "student_0@example.com"
    When I navigate to "robert@example.com" profile in "albers"
    And I follow "Actions"
    And I follow "Request Meeting"
    And I fill in "new_meeting_title" with "Calendar Meeting"
    And I fill in "new_meeting_description" with "Let us meet and have a general meeting"
    Then I follow "Propose Meeting Times"
    And I click ".cjs_edit_slot" within "#cjs_proposed_slot_1_container"
    And I select "January 26, 2020" for "#cjs_meeting_slot_1_date" from datepicker
    And I fill in "cjs_meeting_slot_1_location" with "Hyderabad"
    And I follow "Save" within "#cjs_proposed_slot_1_container"
    And I click ".cjs_edit_slot" within "#cjs_proposed_slot_2_container"
    And I fill in "cjs_meeting_slot_2_location" with "Hyderabad"
    And I follow "Save" within "#cjs_proposed_slot_2_container"
    And I fill in datepicker with id "cjs_meeting_slot_2_date" with current date
    And I follow "Save" within "#cjs_proposed_slot_2_container"
    Then I should see "Meeting times cannot be in the past."
    And I click ".cjs_remove_slot" within "#cjs_proposed_slot_2_container"
    Then I should not see "#cjs_proposed_slot_2_container"
    Then I follow "Propose Another Timeslot"
    And I click ".cjs_edit_slot" within "#cjs_proposed_slot_3_container"
    And I select "January 20, 2020" for "#cjs_meeting_slot_3_date" from datepicker
    And I fill in "cjs_meeting_slot_3_location" with "Hyderabad"
    And I follow "Cancel" within "#cjs_proposed_slot_3_container"
    And I click ".cjs_edit_slot" within "#cjs_proposed_slot_3_container"
    Then I should see "" within "#cjs_meeting_slot_3_location"
    And I select "January 26, 2020" for "#cjs_meeting_slot_3_date" from datepicker
    And I fill in "cjs_meeting_slot_3_location" with "Hyderabad"
    And I follow "Save" within "#cjs_proposed_slot_3_container"
    Then I follow "Request Meeting"
    Then I should see "Your request for a meeting with Good unique name has been successfully sent. You will be notified when Good unique name responds to your request. You can look for other mentors who are available and reach out to them from here."