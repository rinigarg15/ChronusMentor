Feature: Unifying the messages and the mentoring area scraps

@javascript
Scenario: Message to the connected member should be placed in both Mentoring area and Inbox

  Given the current program is "primary":"albers"
  And I have logged in as "mkr@example.com"
  Then I follow "Mentors"
  Then I filter a mentor with name "Good unique" using quick find
  And I remove the status filter
  Then I wait for "2" seconds
  And I follow "Actions"
  And I follow "Send Message"
  Then I should see "Add an attachment"
  When I fill in "message_subject" with "Unification of inbox-scrap"
  And I fill in "message_content" with "The message is being sent from listing page"
  And I press "Send"
  Then I should see "Your message has been sent"
  And I logout
  Then I have logged in as "robert@example.com"
  And I follow "name & madankumarrajan"
  And I should see "Unification of inbox-scrap" within "div.cjs-scrap-subject"
  Given "1" last "message" exist
  Then I visit inbox with "5" unread messages
  When I click message "Unification of inbox-scrap" of "Inbox" message list
  Then I should see "mkr_student madankumarrajan"
  Then I wait for "3" seconds
  Then I open reply pane for the message "1"
  Then I fill in "scrap[content]" with "Sample"
  And I should see "Cancel"
  And I fill in "scrap[content]" with "Replying from inbox should be posted in mentoring area"
  And I press "Reply"
  Then I follow "Home" within "#side-menu"
  And I follow "name & madankumarrajan"
  Then I should not see the sibling scrap "Replying from inbox should be posted in mentoring area"
  When I click "div.cjs-scrap-subject"
  Then I should see the sibling scrap "Replying from inbox should be posted in mentoring area"
  And I logout

@javascript @cross_browser
 Scenario: Messages exchanged before getting connected should be placed in the mentoring area once the connection is established and replies should not be posted to the closed mentoring connection.

   Given the current program is "primary":"albers"
   And I have logged in as "student_13@example.com"
   When I visit the profile of "mentor_13@example.com"
   When I click "#mentor_profile div.btn-group a.dropdown-toggle"
   Then I follow "Send Message"
   When I fill in "message_subject" with "First message before connecting"
   And I fill in "message_content" with "The first message being sent from the profile page"
   And I press "Send"
   Then I follow "Mentors"
   Then I filter a mentor with name "mentor_n" using quick find
   And I follow "Connect"
   Then I follow "Send Message"
   Then I should see "Add an attachment"
   When I fill in "message_subject" with "Second message before connecting"
   And I fill in "message_content" with "The second message is being sent from listing page"
   And I press "Send"
   And I logout
   When I have logged in as "mentor_13@example.com" without asserting signout
   Then I set english as locale for "mentor_13@example.com"
   Given "1" last "message" exist
   Then I visit inbox with "2" unread messages
   Then I should see "Second message before connecting"
   And I logout
   Given the current program is "primary":"albers"
   When I have logged in as "ram@example.com"
   And I follow "Manage"
   Then I follow "Mentoring Connections"
   And I follow "Create New Mentoring Connection"
   And I fill in "mentor" field of "primary":"albers" with "mentor_n chronus <mentor_13@example.com>"
   And I fill in "student" field of "primary":"albers" with "student_n example <student_13@example.com>"
   And I click "#create_and_publish"

   Then I should see "chronus & example"
   Then I enable the option for users to leave mentoring connection
   And I logout
   Then I have logged in as "mentor_13@example.com"
   Then I follow "chronus & example" within "ul.metismenu"
   Then I should see "There are no messages exchanged yet."
   Then I visit inbox with "2" unread messages
   When I click message "Second message before connecting" of "Inbox" message list
   Then I wait for "3" seconds
   Then I open reply pane for the message "1"
   And I fill in "message[content]" with "Replying to before connected message should be posted in mentoring area now"
   And I press "Reply"
   Then I follow "chronus & example" within "ul.metismenu"
   Then I should see "Second message before connecting" within "div.cjs-scrap-subject"
   And I should not see "First message before connecting" within "div.cjs-scrap-subject"
   And I click "div.cjs-scrap-subject"
   Then I should see "Replying to before connected message should be posted in mentoring area now"
   And I reply to the inbox message from mentoring area
   Then I visit inbox with "1" unread messages
   And I follow "Sent"
   And I click message "Second message before connecting" of "Sent" message list
   Then I should see "Replying to inbox message from the mentoring area"
   And I logout
   Given the current program is "primary":"albers"
   When I have logged in as "student_13@example.com"
   Then I visit inbox with "1" unread messages
   Then I follow "chronus & example" within "ul.metismenu"
   Then I should see "Second message before connecting" within "div.cjs-scrap-subject"
   And I click "div.cjs-scrap-subject"
   Then I should see "Replying to before connected message should be posted in mentoring area now"
   And I should see "Replying to inbox message from the mentoring area"
   Then I follow "New Message"
   Then I should see "Cancel"
   And I fill in "scrap[subject]" with "Message to check after closing this connection"
   And I fill in "scrap[content]" with "Replies should not be posted to the closed connection"
   And I press "Send Message"
   Then I close the flash
   And I logout
   When I have logged in as "mentor_13@example.com"
   Given "1" last "message" exist
   Then I visit inbox with "2" unread messages
   And I click message "Message to check after closing this connection" of "Inbox" message list
   And I wait for "3" seconds
   Then I open reply pane for the message "1"
   Then I fill in "scrap[content]" with "Sample"
   Then I should see "Cancel"
   Then I follow "chronus & example" within "ul.metismenu"
   Then I follow "Close Mentoring Connection"
   And I fill in "group_termination_reason" with "Test close"
   Then I press "Close Mentoring Connection"
   Given "1" last "message" exist
   Then I visit inbox with "1" unread messages
   And I click message "Message to check after closing this connection" of "Inbox" message list
   And I click "span.caret" within "div#content_wrapper"
   And I should not see "Reply"
   And I logout