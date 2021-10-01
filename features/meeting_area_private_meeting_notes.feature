@javascript
Feature: Meeting Area Notes
In order to log their personal notes
Meeting members should be able to add/remove/edit notes

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
Scenario: Mentee visits empty note page and posts the first note
  Given the current program is "primary":"albers"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Given mentors in "primary":"albers" are allowed to configure availability slots
  When I have logged in as "robert@example.com"
  Given there is a past meeting I attended outside of a group
  Then I should see "MEETINGS" within "ul.metismenu"

  Then I follow "Upcoming" within "ul.metismenu"
  Then I should see "Past"
  And I follow "Past"
  Then I should see "Outside Group" within "#archived_meetings"
  Then I follow "Provide Feedback" within "#archived_meetings"
  Then I should see "Update Meeting Status"
  Then I should see /Did your meeting, "Outside Group" with student example take place\?/
  Then I follow "Yes" within "#meeting_state_options"
  Then I wait for ajax to complete
  Then I should see "Meeting Feedback Survey"
  Then I close the qtip popup
  Then I should not see "Meeting Feedback Survey"
  Then I reload the page
  Then I should see "Meeting Feedback Survey"
  And I fill the answers "'Very satisfying', 'Great use of time'" of "Meeting Feedback Survey For Mentors" for "COMPLETED"
  Then I press "Submit"
  Then I should see "Thanks for completing Meeting Feedback Survey For Mentors"
  And "robert@example.com" has no private meeting notes
  And I follow "Notes"
  Then I should see "You can capture notes and file attachments for this meeting from this space. Add your first note."
  And I should see "New Note"
  Then I click ".add_private_meeting_note"

  When I type the note text "I met my mentor yesterday. We discussed about the goals."
  And I press "Add Note"
  And I should see "New Note"
  And I should see "I met my mentor yesterday. We discussed about the goals."

  # Second note entry
  Then I click ".add_private_meeting_note"
  When I type the note text "This is my second note. It's awesome!"
  # When I set the attachment for new note entry to "handbook_test_1.txt"
  And I submit the new note entry
  And I should see "New Note"
  And I should see "This is my second note. It's awesome!"
  # And I should see "handbook_test_1.txt"

  # Third note entry. But, invalid attachment
  Then I click ".add_private_meeting_note"
  When I type the note text "This is my thrid note. Let me attach my hard drive backup!"
  Then I logout
  # When I set an invalid attachment to the new note entry
  # And I should see "This is my thrid note. Let me attach my hard drive backup!"

  # Try again, but with invalid text
  # Then I click ".add_private_meeting_note"
  # When I type the note text ""
  # And I press "Add Note"
  # And I press "OK"

@javascript @cross-browser
Scenario: Mentor visits the note page and posts the first note
  When I have logged in as "ram@example.com"
  And I enable "mentoring_connection_meeting" feature as a super user
  And I logout
  Given Admin update expiry date of group named "name & madankumarrajan" to "Jan 26, 2021"
  When I have logged in as "robert@example.com"
  And I select "Albers Mentor Program" from the program selector
  And I follow "My Mentoring Connections"
  And I follow "name & madankumarrajan"
  And I follow "Plan"
  And I follow "Add Meeting" in the page actions bar
  And I follow "Add New Meeting" in the page actions bar
  And I fill in "new_meeting_title" with "Intro Meeting"
  And I fill in "meeting_description" with "Let us discuss about onboarding"
  And I select "January 25, 2020" for "#new_meeting_form #new_meeting_form_date" from datepicker
  And I press "Create"
  Then I should see "Upcoming Meetings"
  Then I should see "Let us discuss about onboarding"
  Then I follow "Intro Meeting"
  And "robert@example.com" has no private meeting notes
  And I follow "Notes"
  Then I click ".add_private_meeting_note"
  Then I type the note text "The mentee asked me good questions."
  And I press "Add Note"
  And I should see "New Note"
  And I should see "The mentee asked me good questions."
  And I should not see "You do not have any personal notes"
  And I should see "1 - 1 of 1"
  When I edit the note entry "The mentee asked me good questions."
  And I give edit note text for "The mentee asked me good questions." as "Some random text"
  When I cancel the note edit for "The mentee asked me good questions."
  Then I should see "The mentee asked me good questions."
  And I should not see "Some random text"

  # Try again
  When I edit the note entry "The mentee asked me good questions."
  Then I should see "The mentee asked me good questions."
  And I give edit note text for "The mentee asked me good questions." as "Cricket"
  And I submit the note edit for "The mentee asked me good questions."
  Then I should see "Cricket"
  And I should not see "The mentee asked me good questions."

  # Mentee logs in and sees only his note.
  When I logout
  And I have logged in as "mkr@example.com"
  And "mkr@example.com" has no private meeting notes
  And I follow "name & madankumarrajan"
  Then I should not see "Upcoming" within "ul.metismenu"
  Then I follow "Meetings" within "ul.metismenu"
  Then I should see "HELP & SUPPORT" within "ul.metismenu"
  Then I should see "Let us discuss about onboarding"
  Then I follow "Intro Meeting"
  And I follow "Notes"
  And I should see "1 - 1 of 1"
  Then I should not see "You do not have any personal notes"
  And I should see "Cricket"

@javascript @cross-browser
Scenario: Mentor edits a note entry and attachment
  When I have logged in as "ram@example.com"
  And I enable "mentoring_connection_meeting" feature as a super user
  And I logout
  Given Admin update expiry date of group named "name & madankumarrajan" to "Jan 26, 2021"
  When I have logged in as "mkr@example.com"
  And I select "Albers Mentor Program" from the program selector
  And I follow "My Mentoring Connections"
  And I follow "name & madankumarrajan"
  And I follow "Plan"
  And I follow "Add Meeting" in the page actions bar
  And I follow "Add New Meeting" in the page actions bar
  And I fill in "new_meeting_title" with "Intro Meeting"
  And I fill in "meeting_description" with "Let us discuss about onboarding"
  And I select "January 25, 2020" for "#new_meeting_form #new_meeting_form_date" from datepicker
  And I press "Create"
  Then I should see "Upcoming Meetings"
  Then I should see "Let us discuss about onboarding"
  Then I follow "Intro Meeting"
  When there is a private note entry "Hello" for "mkr@example.com" with attachment named "handbook_test.txt"
  And I follow "Notes"
  Then I should see "Hello"

  # Update the attachment.
  When I edit the note entry "Hello"
  And I give edit note text for "Hello" as "Bowling"
  And I remove the private note attachment for "Hello" note
  And I submit the note edit for "Hello"
  
  Then I should see "Bowling"
  And I should not see "Hello"
  And I should not see "handbook_test.txt"

  # Add another attachment.
  When I edit the note entry "Bowling"
  
  And I set the private note attachment for "Bowling" to "handbook_test.txt"
  And I submit the note edit for "Bowling"
  Then I should see "Bowling"
  And I should see "handbook_test.txt"

  # Update the attachment.
  When I edit the note entry "Bowling"
  When I remove the private note attachment for "Bowling" note
  When I set the private note attachment for "Bowling" to "handbook_test_1.txt"
  And I submit the note edit for "Bowling"
  Then I should see "Bowling"
  And I should see "handbook_test_1.txt"
  And I should not see "handbook_test.txt"

  When I delete "Bowling" note
  And I confirm popup
  Then I should see the flash "The note has been deleted"

@javascript 
Scenario: Error while updating entry
  When I have logged in as "ram@example.com"
  And I enable "mentoring_connection_meeting" feature as a super user
  And I logout
  Given Admin update expiry date of group named "name & madankumarrajan" to "Jan 26, 2021"
  When I have logged in as "mkr@example.com"
  When private note attachment limit one byte
  And I select "Albers Mentor Program" from the program selector
  And I follow "My Mentoring Connections"
  And I follow "name & madankumarrajan"
  And I follow "Plan"
  And I follow "Add Meeting" in the page actions bar
  And I follow "Add New Meeting" in the page actions bar
  And I fill in "new_meeting_title" with "Intro Meeting"
  And I fill in "meeting_description" with "Let us discuss about onboarding"
  And I select "January 25, 2020" for "#new_meeting_form #new_meeting_form_date" from datepicker
  And I press "Create"
  Then I should see "Upcoming Meetings"
  Then I should see "Let us discuss about onboarding"
  Then I follow "Intro Meeting"
  When there is a private note entry "Hello" for "mkr@example.com" with attachment named "handbook_test.txt"
  And I follow "Notes"
  Then I should see "Hello"

  # Update attachment error.
  When I edit the note entry "Hello"
  When I give edit note text for "Hello" as "Bowling"
  #When I set an invalid attachment while editing note "Hello"
  And I submit the note edit for "Hello"
  #Then I should see "Attachment file size must be less than 5 MB in size"

  # Update text error.
  When I edit the note entry "Bowling"
  When I give edit note text for "Bowling" as ""
  And I submit the note edit for "Bowling"
  Then I should see "Text can't be blank"
  When I give edit note text for "Bowling" as "Proper text"
  And I submit the note edit for "Bowling"
  Then I should see "Proper text"
  And I should not see "Hello"
