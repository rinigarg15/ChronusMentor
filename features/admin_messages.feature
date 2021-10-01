Feature: Admin Messages and reply
In order to perform the above steps
As an admin
I want to login and do the necessity actions

#Admin comes to admin messages page
@javascript @not_run_on_tddium
Scenario: Administrator visits Admin Messages and sends message and view back the reply
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Administrator Inbox"
  Then I should see "Administrator Inbox" within "#page_heading"
# To check for number of unread messages
  And I should see "Inbox(2)" within "#cjs_messages_tabs li.active"
  When I click message "Second admin message" of "Inbox" message list
  Then I should see "Second admin message"
# Then I should see the compressed version of the first message
  Then I should see "This is not going to be interesting" within ".cjs_preview_active"
  Then I should not see "toAdministrator" within "div.cui_recipient_name"
# Then I expand the first message and delete it
  Then I click ".cjs_preview_active"
  Then I should see "toAdministrator" within "div.cui_recipient_name"
  Then I should see "This is not going to be interesting" within "div.cui_mail_content"
  Then I click ".cjs_detailed"
  Then I should not see "toAdministrator" within "div.cui_recipient_name"
  Then I should see "This is not going to be interesting" within ".cjs_preview_active"
# I should be able to see the last message open
  Then I should see "toTest User <test@chronus.com>" within "div.cui_recipient_name"
  Then I should see "Me" within "#cjs_detailed_section_15 .cui_sender_name"
  Then I should see "This is not going to be interesting" within "#cjs_detailed_section_15 div.cui_mail_content"
  Then I should not view threaded reply
  Then I click "span.cjs_toggle_thread"
  Then I should view threaded reply
  Then I click ".cjs_preview_active"
  Then I click delete for the message "1"
  Then I confirm popup
  Then I should see the flash "The message has been deleted"
  Then I should see "Second admin message"
# Now admin sends message to a mentor and a mentee
  Then I should see "Send Message to Members"
  And I follow "Send Message to Members"
  And I fill in "admin_message_subject" with "Test subject"
  And I fill in CKEditor "admin_message_content" with "lorem ipsum dolor sit"
  And I fill up to details
  Then I press "Send Message"
  And I should see the flash "Your message has been sent"
  And I follow "Manage"
  Given "1" last "admin message" exist
  And I follow "Administrator Inbox"
  And I should see "Sent"
  And I follow "Sent"
  Then I should see "Include system generated messages"
  Then I should see "Test subject - lorem ipsum dolor sit"
  Then I should see "student example, ..."
  When I click message "Test subject" of "Sent" message list
  And I should see "tostudent example and Good unique name"
  And I should see "lorem ipsum dolor sit"
  And I logout
# student sees it and replies
  When I have logged in as "rahim@example.com"
  Given "1" last "message" exist
  Then I visit inbox with "1" unread messages
  Then I should see "Freakin Admin (Administrator)"
  Then I should see "Test subject - lorem ipsum dolor sit"
  When I click message "Test subject" of "Inbox" message list
  Then I should see "Freakin Admin (Administrator)"
  And I should see "tome"
  And I should see "lorem ipsum dolor sit" within ".cui_mail_content"
  And I should see "Test subject" within "#page_heading"
  Then I open reply pane for the message "1"
  Then I fill in "admin_message[content]" with "reply 11"
  Then I press "Reply"
  And I should see the flash "Your message has been sent"
  Then I should see "toAdministrator"
  And I should see "reply 11"
  Then I should not view threaded reply
  Then I click "span.cjs_toggle_thread"
  Then I should view threaded reply
  Then I should see "lorem ipsum dolor sit" within "div.cui_thread"
  Then I click "span.cjs_toggle_thread"
  Then I should not view threaded reply
  And I should not see ".cjs_reply_link"
  Then I click ".cjs_preview_active"
  Then I open reply pane for the message "1"
  Then I fill in "admin_message[content]" with "student reply 12"
  Then I press "Reply"
  And I should see the flash "Your message has been sent"
  Then I should see "toAdministrator"
  And I should see "student reply 12"
  Then I should not view threaded reply
  Then I click "span.cjs_toggle_thread"
  Then I should view threaded reply
  Then I should see "lorem ipsum dolor sit" within "div.cui_thread"
  Then I should not see "reply 11" within "div.cui_thread"
  Then I click "span.cjs_toggle_thread"
  Then I should not view threaded reply
  And I should not see ".cjs_reply_link"
  Then I click ".cjs_preview_active"
  Then I open reply pane for the message "1"
  Then I fill in "admin_message[content]" with "student reply 13"
  Then I press "Reply"
  And I should see the flash "Your message has been sent"
  And I should see "student reply 13"
  And I should see "student reply 12"
  And I should see "lorem ipsum dolor sit"
  Then I click ".cjs_collapser"
  Then I should see "reply 11"
  And I logout
# mentor seees the same admin message and replies as well
  When I have logged in as "robert@example.com"
  Then I visit inbox with "4" unread messages
  Then I should see "Freakin Admin (Administrator)"
  Then I should see "Test subject - lorem ipsum dolor sit"
  When I click message "Test subject" of "Inbox" message list
  Then I should see "Freakin Admin (Administrator)"
  And I should see "tome"
  And I should see "lorem ipsum dolor sit" within ".cui_mail_content"
  And I should see "Test subject" within "#page_heading"

  Then I open reply pane for the message "1"
  Then I fill in "admin_message[content]" with "mentor reply 11"
  Then I press "Reply"
  And I should see the flash "Your message has been sent"
  Then I should see "toAdministrator"
  And I should see "mentor reply 11"
  Then I should not view threaded reply
  Then I click "span.cjs_toggle_thread"
  Then I should view threaded reply
  Then I should see "lorem ipsum dolor sit" within "div.cui_thread"
  Then I click "span.cjs_toggle_thread"
  Then I should not view threaded reply
  And I should not see ".cjs_reply_link"
  Then I click ".cjs_preview_active"
  Then I open reply pane for the message "1"
  Then I fill in "admin_message[content]" with "mentor reply 12"
  Then I press "Reply"
  And I should see the flash "Your message has been sent"
  Then I should see "toAdministrator"
  And I should see "mentor reply 12"
  Then I should not view threaded reply
  Then I click "span.cjs_toggle_thread"
  Then I should view threaded reply
  Then I should see "lorem ipsum dolor sit" within "div.cui_thread"
  Then I should not see "mentor reply 11" within "div.cui_thread"
  Then I click "span.cjs_toggle_thread"
  Then I should not view threaded reply
  And I should not see ".cjs_reply_link"
  Then I click ".cjs_preview_active"
  Then I open reply pane for the message "1"
  Then I fill in "admin_message[content]" with "mentor reply 13"
  Then I press "Reply"
  And I should see the flash "Your message has been sent"
  And I should see "mentor reply 13"
  And I should see "mentor reply 12"
  And I should see "lorem ipsum dolor sit"
  Then I click ".cjs_collapser"
  Then I should see "reply 11"
  And I logout
# Admin logs in and checks the inbox
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Albers Mentor Program"
  And I should see "Administrator Inbox"
  Given "7" last "admin message" exist
  And I follow "Manage"
  And I follow "Administrator Inbox"
  And I should see "Inbox(7)" within "#cjs_messages_tabs li.active"
  Then I should see "me .. Good unique name (7)"
  Then I should see "Test subject - mentor reply 13"
  When I click message "Test subject" of "Inbox" message list
  Then I should see "lorem ipsum dolor sit" as read message
  Then I should see "reply 11" as unread message
  Then I should see "student reply 12" as unread message
  Then I should see "student reply 13" as unread message
  Then I should see "mentor reply 11" as unread message
  Then I should see "mentor reply 12" as unread message
  Then I should see "mentor reply 13" as unread message
  When I click message "Test subject" of "Inbox" message list
  Then I should see "lorem ipsum dolor sit"
  Then I should see "mentor reply 12"
  Then I should see "mentor reply 13"
  Then I should see "4 read messages"
  Then I click ".cjs_compressed_count"
  Then I click on preview text "student reply 13"
  Then I should see "reply 11"
  Then I should see "student reply 12"
  Then I should see "student reply 13"
  Then I should see "mentor reply 11"

  Then I open reply pane for the message "1"
  Then I fill in "admin_message[content]" with "admin reply to student message 13"
  Then I press "Reply"
  Then I should see "5 read messages"
  Then I should see "admin reply to student message 13"
  Then I click "span.cjs_toggle_thread"
  Then I should view threaded reply
  Then I should see "student reply 13" within "div.cui_thread"
  Then I should see "lorem ipsum dolor sit" within "div.cui_thread"
  Then I click on preview text "mentor reply 13"
  Then I open reply pane for the message "1"
  Then I fill in "admin_message[content]" with "admin reply to mentor message 13"
  Then I press "Reply"
  Then I should see "Inbox(7)"
  And I logout
# student sees the admin reply
  When I have logged in as "rahim@example.com"
  Given "1" last "admin message" exist
  Then I visit inbox with "1" unread messages
  Then I should see "Freakin Admin (Administrator)"
  Then I should see "Test subject - lorem ipsum dolor sit"
  When I click message "Test subject" of "Inbox" message list
  Then I should see "Freakin Admin (Administrator)"
  And I should see "tome"
  And I should see "admin reply to student message 13" within ".cui_mail_content"
  And I should see "Test subject" within "#page_heading"
  Then I click "span.cjs_toggle_thread"
  Then I should view threaded reply
  Then I should see "student reply 13" within "div.cui_thread"
  Then I should see "lorem ipsum dolor sit" within "div.cui_thread"
  Then I should see "Inbox(1)"
  And I logout
# similarly mentor sees the admin reply
  When I have logged in as "robert@example.com"
  Given "1" last "admin message" exist
  Then I visit inbox with "4" unread messages
  Then I should see "Freakin Admin (Administrator)"
  Then I should see "Test subject - lorem ipsum dolor sit"
  When I click message "Test subject" of "Inbox" message list
  Then I should see "Freakin Admin (Administrator)"
  And I should see "tome"
  And I should see "admin reply to mentor message 13" within ".cui_mail_content"
  Then I click "span.cjs_toggle_thread"
  Then I should view threaded reply
  Then I should see "mentor reply 13" within "div.cui_thread"
  Then I should see "lorem ipsum dolor sit" within "div.cui_thread"
  Then I should see "Inbox(1)"
  And I logout

@javascript @cross_browser
Scenario: Logged in Student contacts admin
    Given the current program is "primary":"albers"
    When I have logged in as "rahim@example.com"
    And I follow "Contact Administrator"
    Then I should see "Send Message to Administrator"
    And I fill in "admin_message_subject" with "Test subject"
    And I fill in "admin_message_content" with "test message"
    Then I press "Send Message"
    Then individual mails should go to "userram@example.com,ram@example.com" having "You have a message"
    #And I should see the flash "Your message has been"
    And I logout
# Admin see's his email and replies
    When I open new mail
    And I follow "message" in the email
    And I fill in "email" with "ram@example.com"
    And I fill in "password" with "monkey"
    And I press "Login"
    Then I should see "Test subject"
    Then I should see "test message"
    Then I open reply pane for the message "1"
    And I set the attachment field with "message[attachment]:last" to "TEST.JPG"
    #Then I should see "Remove"
    Then I should see "1" within "span.badge"
    And I follow "Cancel"
    Then I open reply pane for the message "1"
    Then I should not see "Remove"
    Then I should not see "span.badge"
    And I fill in "admin_message[content]" with "Test message reply"
    And I press "Reply"
    And a mail should go to "rahim@example.com" having "You have a message"
    And I should see the flash "Your message has been sent"
# Then I visit sent folder
    When I follow "Home"
    Given "1" last "admin message" exist
    And I follow "Manage"
    And I follow "Administrator Inbox"
    And I follow "Sent"
    Then I should see "Test subject"
    When I click message "Test subject" of "Sent" message list
    Then I should see "Test subject"
    Then I should see "Test message reply"
    #Then I should not see "Reply"
    And I logout
# Login as other admin
    Given the current program is "primary":"albers"
    When I have logged in as "userram@example.com"
    And I follow "Manage"
    Given "1" last "admin message" exist
    And I follow "Administrator Inbox"
    Then I should see "Test subject"
    Then I should see "Test message"
    When I click message "Test subject" of "Inbox" message list
    And I logout
# Student see's his email and replies
    When I open new mail
    And I follow "message" in the email
    And I fill in "email" with "rahim@example.com"
    And I fill in "password" with "monkey"
    And I press "Login"
    Then I should see "Test message reply"
    Then I click ".cui_content_preview"
    Then I should see "Administrator"
    Then I should see "Test subject"
    Then I should see "Test message reply"
    Then I open reply pane for the message "2"
    And I fill in "admin_message[content]" with "This is the final one in the thread"
    And I press "Reply"
    Then individual mails should go to "userram@example.com,ram@example.com" having "You have a message"
    And I should see the flash "Your message has been sent"
    And I logout

@javascript @cross_browser
Scenario: NonLogged in Student contacts admin
    Given the current program is "primary":"albers"
    And I follow "Contact Administrator"
    Then I should see "Send Message to Administrator"
    Then I press "Send Message"
    Then I should see "Please fill all the required fields. Fields marked * are required"
    And I fill in "admin_message_sender_name" with "Test User"
    And I fill in "Your email" with "test@"
    And I fill in "admin_message_subject" with "Unlogged in subject"
    And I fill in "admin_message_content" with "Unlogged in message"
    And I fill in "captcha" with "TEST"
    Then I press "Send Message"
    Then I should see "Please enter a valid email address"
    And I fill in "Your email" with "test@example.com"
    Then I press "Send Message"
    Then individual mails should go to "userram@example.com,ram@example.com" having "You have a message"
    And I should see the flash "Your message has been sent to Administrator"
    # Admin see's his email
    When I open new mail
    And I follow "message" in the email
    And I fill in "email" with "ram@example.com"
    And I fill in "password" with "monkey"
    And I press "Login"
    Then I should see "Test User"
    Then I should see "Unlogged in subject"
    Then I should see "Unlogged in message"
    Then I open reply pane for the message "1"
    And I fill in "admin_message[content]" with "Unlogged in message reply"
    And I press "Reply"
    And a mail should go to "test@example.com" having "Unlogged in message reply"
    And I should see the flash "Your message has been sent"
    # Then I visit sent folder
    When I follow "Home"
    Given "1" last "admin message" exist
    And I follow "Manage"
    And I follow "Administrator Inbox"
    And I follow "Sent"
    Then I should see "Unlogged in subject"
    When I click message "Unlogged in subject" of "Sent" message list
    Then I should see "Unlogged in subject"
    Then I should see "Unlogged in message reply"
    #Then I should not see "Reply"
    And I logout


 @javascript @p2
 Scenario: Admin sends message to mentoring connections and the connected members view it
    Given the current program is "primary":"albers"
    And I change engagement type of program "primary":"albers" to "career based and ongoing"
    When I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Administrator Inbox"
    Then I send a admin message to mentoring connection
    Then individual mails should go to "student_2@example.com,non_request@example.com" having "You have a message"
    And I should see the flash "Your message has been sent"
    And I follow "Manage"
    Given "1" last "admin message" exist
    And I follow "Administrator Inbox"
    And I should see "Sent"
    And I follow "Sent"
    Then I should see "Sent(1)"
    When I click message "Subject" of "Sent" message list
    And I should see "tostudent_c example and Non requestable mentor"
    And I should see "Message to the Mentoring Connection"
    Then I logout
    

Scenario: Test invalid utf8 byte sequence url request result in page not found
  Given the current program is "primary":"albers"
  And I try to visit malformed contact admin url and get page not found result

@javascript @cross_browser
Scenario: Administrator visits org level Admin Messages and sends message
  Given the current program is "primary":""
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Administrator Inbox"
  Then I should see "Administrator Inbox" within "#page_heading"
  And I should see "Inbox" within "#cjs_messages_tabs li.active"
  And I should see "Send Message to Members"
  And I follow "Send Message to Members"
  Then I should see "New Message from Administrator"
  And I fill in "admin_message_subject" with "Test subject"
  And I fill in CKEditor "admin_message_content" with "lorem ipsum dolor sit"
  And I fill up to details
  Then I press "Send Message"
  And I should see the flash "Your message has been sent"
  Given "1" last "admin message" exist
  And I follow "Manage"
  And I follow "Administrator Inbox"
  And I should see "Sent"
  And I follow "Sent"
  Then I should see "Test subject - lorem ipsum dolor sit"
  Then I should see "student example, ..."
  When I click message "Test subject" of "Sent" message list
  Then I should see "me"
  And I should see "tostudent example and Good unique name"
  And I should see "lorem ipsum dolor sit"
  And I logout

@javascript
Scenario: Administrator visits admin messages show page and doesn't find the option to send message to mentoring connections
  Given the current program is "primary":"albers"
  Then I change engagement type of program "primary":"albers" to "career based and ongoing"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Administrator Inbox"
  Then I should see "Send Message to Members"
  Then I click on dropdown toggle within "#action_1"
  And I should see "Send Message to Mentoring Connections"
  When I click message "Second admin message" of "Inbox" message list
  Then I should see "Send Message to Members"
  Then I click on dropdown toggle within "#action_1"
  And I should see "Send Message to Mentoring Connections"
  And I change engagement type of program "primary":"albers" to "career based"
  And I follow "Manage"
  And I follow "Administrator Inbox"
  And I should not see ".dropdown-toggle"
  When I click message "Second admin message" of "Inbox" message list
  And I should not see ".dropdown-toggle"
  And I logout

@javascript @cross_browser
Scenario: Administrator searches for a message
  Given the current program is "primary":"albers"
  Then I change engagement type of program "primary":"albers" to "career based and ongoing"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Administrator Inbox"
  Then I fill in "search_content" with "student"
  Then I should see "Status"
  And I click on "Status" header
  Then I wait for ajax to complete
  Then I should see "Read"
  Then I check "Read"
  Then I wait for ajax to complete
  Then I should see "There are no messages."
  Then I fill in "search_content" with "admin message"
  Then I should see "Status"
  Then I should see "Read"
  Then I check "Unread"
  Then I wait for ajax to complete
  Then I should see "Second admin message"
  Then I logout


@javascript
Scenario: Admin sends message to many recipients
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Administrator Inbox"
  And I follow "Send Message to Members"
  And I fill in "admin_message_subject" with "Test subject"
  And I fill in CKEditor "admin_message_content" with "lorem ipsum dolor sit"
  And I fill up to details for many recipients
  Then I press "Send Message"
  Given "1" last "admin message" exist
  And I follow "Manage"
  And I follow "Administrator Inbox"
  And I follow "Sent"
  When I click message "Test subject" of "Sent" message list
  And I should not see "student_c example"
  And I follow "1 more user"
  Then I wait for ajax to complete
  And I should see "student_c example"
  And I logout