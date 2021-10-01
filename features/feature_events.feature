Feature: Creating Program Events and RSVP to the events

  Background: Set the program to albers
    Given the current program is "primary":"albers"

  @javascript
  Scenario: Admin as super admin enables the events feature and visits the listing page
    When I have logged in as "ram@example.com"
    When I hover over "my_programs_container"
    When I select "Primary Organization" from the program selector
    And I enable "program_events" feature as a super user
    When I hover over "my_programs_container"
    When I select "Albers Mentor Program" from the program selector
    And I follow "Manage"
    And I follow "Events"
    And I should see "Create Event"
    And I should see "Upcoming (1)" within "li.ct_active"
    Then I should see "Birthday Party"
    And I should see "Yes"
    And I should see "No"
    And I should see "Maybe"
    And I follow "Drafted (1)"
    Then I should see "RoR Meetup"
    And I follow "Past (0)"
    Then I should see "There are no past events."
    And I logout
    When I have logged in as "robert@example.com"
    When I hover over "my_programs_container"
    When I select "Albers Mentor Program" from the program selector
    And I should see "Program Event Invites"
    And I should see "Birthday Party"
    And I should see "Program Event Invites (1)"
    And I follow "See all »"
    And I should see "Upcoming (1)"
    Then I follow "Past (0)"
    Then I should see "There are no past events."

    And I click ".pending_requests_notification_icon"
    Then I should see "Program Events"
    Then I follow "Program Events"
    And I should see "Birthday Party"
    Then I follow "Past (0)"
    Then I should see "There are no past events."
    And I logout

  @javascript
  Scenario: Admin searches for users in program events page
    When I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Events"
    And I should see "Birthday Party"
    And I follow "Birthday Party"
    And I follow "See all (44)"
    When I click "May be Attending" tab in dropdown menu
    Then I should see "No users found with current filters."
    And I click "Not Responded" tab in dropdown menu
    And I lookup for "Sample Name" in "search_content"
    Then I should see "No users found with current filters. Please clear some filters and try again."
    And I lookup for "rahim user" in "search_content"
    Then I should see "rahim user" within ".list-group"
    And I logout

  @javascript @cross_browser
  Scenario: Admin Adds new Program event and Updates the event
    And I stub chronus s3 utils
    When I have logged in as "ram@example.com"
    When I hover over "my_programs_container"
    When I select "Primary Organization" from the program selector
    And I enable "program_events" feature as a super user
    When I hover over "my_programs_container"
    When I select "Albers Mentor Program" from the program selector
    And I follow "Manage"
    And I follow "Events"
    And I should see "Create Event"
    And I follow "Create Event"
    And I fill in "program_event_title" with "Checking program event default start date"
    #And I click "#new_program_event_form_date"
    #This xpath represents the topmost left cell present in the calendar.
    Then I click by xpath "//*[@id='program_event_start_time']"
    And I select "10:30" from "program_event_start_time"
    And I check "program_event_email_notification"
    And I follow "Test Email"
    Then I should see "Please provide a comma separated list of email"
    Then I fill in "program_event_notification_list_for_test_email" with "test1@test.com"
    And I press "Send"
    When I select "Albers Mentor Program" from the program selector
    And I follow "Manage"
    And I follow "Events"
    And I should see "Create Event"
    And I should see "Upcoming (1)" within "li.ct_active"
    And I should see "Birthday Party"
    When I follow "Birthday Party"
    And I should see "Yes"
    And I should see "No"
    And I should see "Maybe"
    And I should see "Edit"
    When I follow "Edit Program Event"
    And I fill in "program_event_title" with "New Birthday Updated"
    And I fill in "new_program_event_form_date" with a date 20 days from now
    And I select "11:30" from "program_event_start_time"
    And I press "Post"
    And I should see "Changing the date and time of the program event will clear the RSVPs for the users who responded and new invites will be sent. Continue?"
    Then Confirmation dialog should contain "Update time and send invites"
    Then I cancel popup
    And I select "10:30" from "program_event_start_time"
    And I check "program_event_email_notification"
    And I follow "Test Email"
    Then I should see "Please provide a comma separated list of email"
    Then I fill in "program_event_notification_list_for_test_email" with "test1@test.com"
    And I press "Send"

    And a mail should go to "test1@test.com" having "has updated some of the following program event details"
    And I should see "Test emails have been sent to test1@test.com"
    And I press "Post"
    And I confirm popup
    And I in "60" seconds should see "The Program Event - New Birthday Updated has been updated successfully"
    Then I follow the back link
    Then I should see "Create Event"
    When I follow "Create Event"
    And I fill in "program_event_title" with "New Birthday Party"
    And I fill in "program_event_location" with "Chennai, Tamil Nadu"
    And I press "Post"
    Then I should see "Please fill all the required fields. Fields marked * are required"
    When I click "#s2id_program_event_admin_view_id > .select2-choice"
    And I click on select2 result "All Users"
    And I fill in "new_program_event_form_date" with a date 20 days from now
    And I select "10:30 am" from "program_event_start_time"
    And I select "Asia" from "timezone_area"
    And I select "(GMT+04:00) Muscat" from "program_event_time_zone"
    And I press "Save as draft"
    And I should see "Post Event"
    And I should see "Send Test Email"
    When I follow "Post Event"
    And I check "program_event_email_notification"
    And I press "Post"
    Then I in "60" seconds should see "The Program Event - New Birthday Party has been published successfully"
    And I open new mail
    And I follow "Yes, I will attend" in the email
    Then I should see the flash "Your RSVP has been updated successfully. Click here to set reminder."
    Then I follow "Click here"
    Then I should see "RSVP - YES(New Birthday Party)"
    Then I should see "Remind me one day before the event"
    And I logout

  @javascript @cross_browser
  Scenario: Mobile footer request tab should contain program event count
    When I have logged in as "ram@example.com"
    When I hover over "my_programs_container"
    When I select "Primary Organization" from the program selector
    And I enable "program_events" feature as a super user
    And I hover over "my_programs_container"
    And I select "Albers Mentor Program" from the program selector
    And I follow "Manage"
    And I follow "Events"
    Then I should see "Birthday Party"
    When I follow "Birthday Party"
    And I follow "See all (44)"
    Then I should see "Send Message"
    When I follow "Send Message"
    Then I should see "Not Responded Users (44)" within "#new_message_popup"
    And I fill in "admin_message_subject" with "Test Subject"
    And I fill in CKEditor "admin_message_content" with "Test Content"
    And I press "Send"
    Then I should see "Your message has been sent"
    And a mail should go to "drafted-user@chronus.com" having "You have a message"
    And I logout
    Then I change to mobile view

    When I have logged in as "robert@example.com" without asserting signout
    When I hover over "my_programs_container"
    And I should see "12" within ".cjs_footer_total_requests"
    Then I click by xpath "//*[@id='page-wrapper']/nav[2]/div/div/div[1]/div[3]/a/div"
    And I check the events status before rsvp
    And I follow "Program Events"
    And I should see "Upcoming (1)"
    And I should see "Birthday Party"
    Then I should see "Yes"
    Then I should see "No"
    Then I should see "Maybe"
    And I follow "Yes"
    Then I should see "Remind me one day before the event"
    And I check "event_invite[reminder]"
    And I press "Confirm"
    Then I should see "Your RSVP has been updated successfully"
    And I should see "11" within ".cjs_footer_total_requests"
    Then I click by xpath "//*[@id='page-wrapper']/nav[2]/div/div/div[1]/div[3]/a/div"
    And I check the events status after rsvp
    And I follow "Mentoring Requests"
    And I should see "Received Mentoring Requests"
    And I should see "student_k example"
    And I should see "Actions"
    And I follow "Actions"
    And I follow "Accept request"
    Then I close modal
    And I should see "10" within ".cjs_footer_total_requests"
    Then I click by xpath "//*[@id='page-wrapper']/nav[2]/div/div/div[1]/div[3]/a/div"
    And I should see "10" within ".list-group-item .media-body"
    And I logout

  @javascript @cross_browser
  Scenario: End User Viewing the Program event and updating his invite
    When I have logged in as "ram@example.com"
    When I hover over "my_programs_container"
    When I select "Primary Organization" from the program selector
    And I enable "program_events" feature as a super user
    And I hover over "my_programs_container"
    And I select "Albers Mentor Program" from the program selector
    And I follow "Manage"
    And I follow "Events"
    Then I should see "Birthday Party"
    When I follow "Birthday Party"
    And I follow "See all (44)"
    Then I should see "Send Message"
    When I follow "Send Message"
    Then I should see "Not Responded Users (44)" within "#new_message_popup"
    And I fill in "admin_message_subject" with "Test Subject"
    And I fill in CKEditor "admin_message_content" with "Test Content"
    And I press "Send"
    Then I should see "Your message has been sent"
    And a mail should go to "drafted-user@chronus.com" having "You have a message"
    And I logout

    When I have logged in as "robert@example.com"
    When I hover over "my_programs_container"
    When I select "Albers Mentor Program" from the program selector
    And I should see "Program Event Invites (1)"
    And I should see "Birthday Party"
    And I follow "See all »"
    And I should see "Upcoming (1)"
    Then I should see "Past (0)"
    When I follow "Birthday Party"
    Then I should see "Yes"
    Then I should see "No"
    Then I should see "Maybe"
    And I should see "See all (44)"
    And I follow "Yes"
    Then I should see "Remind me one day before the event"
    And I check "event_invite[reminder]"
    And I press "Confirm"
    Then I should see "Your RSVP has been updated successfully"
    And I should see "See all (1)"
    And I follow "Maybe"
    And I uncheck "event_invite[reminder]"
    And I press "Confirm"
    Then I should see "Your RSVP has been updated successfully"
    And I should see "See all (1)"
    And I follow "No"
    Then I should see "Are you sure, you don't want to attend this program event?"
    And I press "Confirm"
    Then I should see "Your RSVP has been updated successfully"
    And I should see "See all (1)"
    When I follow "See all (1)"
    Then I should see "Not Attending"
    And I should see "Good unique name"
    And I should not see "Send Message"
    And I logout
    
  Scenario: Export guests to CSV
    When I have logged in as "ram@example.com" in headless mode
    Given the feature "program_events" is enabled for "primary"
    And I follow "Manage"
    And I follow "Events"
    When I follow "Birthday Party"
    When I follow "Export Guest list to CSV"
    Then I should get a csv file
