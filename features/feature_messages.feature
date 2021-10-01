@message
Feature: Messages and reply
  In order to perform the above steps
  As an admin
  I want to login and enter the appropriate as required

Background: The current program is albers
  Given the current program is "primary":"albers"

@javascript @cross_browser
Scenario: Student sends message to mentor
  # Student logs in.
  When I have logged in as "rahim@example.com"
  When I navigate to "robert@example.com" profile in "albers"
  When I click "#mentor_profile div.btn-group a.dropdown-toggle"
  Then I follow "Send Message"
  # Fill message form with errors
  And I fill in "message_content" with "Start working right away"
  And I press "Send"
  Then I should see "Please fill all the required fields. Fields marked * are required"
  # Fix the error now
  When I fill in "message_subject" with "Work towards your goals"
  And I fill in "message_content" with "Start working right away"
  And I press "Send"
  Then I should see "Your message has been sent"
  And I logout
  # Mentor follows email link.
  When I open new mail
  And I follow "message" in the email
  And I fill in "email" with "robert@example.com"
  And I fill in "password" with "monkey"
  And I press "Login"
  Then I should see "Work towards your goal"

@javascript @cross_browser
Scenario: Reply to message
  # Mentor logs in, notices a new message and visits the message page.
  When I have logged in as "robert@example.com"
  Then I visit inbox with "4" unread messages
  When I click message "First message" of "Inbox" message list
  Then I should see "Studenter"
  Then I wait for "3" seconds
  Then I open reply pane for the message "1"
  And I fill in "message[content]" with "I dint say fantastic"
  And I press "Reply"
  And I logout
  # Student opens email and views the reply
  When I open new mail
  And I follow "message" in the email
  And I fill in "email" with "mentrostud@example.com"
  And I fill in "password" with "monkey"
  And I press "Login"
  # New reply
  Then I should see "First message"
  Then I should see "I dint say fantastic"
  # Original message
  Then I click "span.cjs_toggle_thread"
  Then I should see "This is going to be very interesting"
  # Mentor link
  Then I should see "Good unique name"

@javascript
Scenario: Admin Send message should point to organization level messages new irrespective of allow_user_to_send_message_outside_mentoring_area value when admin tries to send message at org level
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  When I follow "Manage"
  And I follow "Member Views" manage icon
  Then I wait for ajax to complete
  And I follow "arun"
  When I click "#mentor_profile div.btn-group a.dropdown-toggle"
  Then I should see "Send Message"
  Then I should see "href" attribute for link "Send Message" matches with "/messages/new?receiver_id="
  Then I logout

@javascript
Scenario: Admin Send message should point to messages new irrespective of allow_user_to_send_message_outside_mentoring_area value
  And I have logged in as "ram@example.com"
  When I follow "Manage"
  And I follow "Program Settings" manage icon
  And I follow "Permissions"
  Then I choose "program_allow_user_to_send_message_outside_mentoring_area_true"
  And I press "Save"
  Then I follow "Mentors"
  When I click "div#mentor_3 div.btn-group a.dropdown-toggle"
  Then I should see "Send Message" within "div#mentor_3"
  Then I should see "data-click" attribute for link "Send Message" matches with "jQueryShowQtip" within "div#mentor_3"
  And I follow "Good unique name"
  When I click "#mentor_profile div.btn-group a.dropdown-toggle"
  Then I should see "Send Message"
  Then I should see "href" attribute for link "Send Message" matches with "/p/albers/messages/new?receiver_id=" within "#mentor_profile div.btn-group"
  And I follow "Ongoing mentoring connections"
  And I hover over class "cjs-user-link-container"
  Then I wait for ajax to complete
  Then I should see "Message" within "div.cjs-hovercard-container"
  Then I should see "href" attribute for link "Message" matches with "/p/albers/messages/new?receiver_id=" within "div.cjs-hovercard-container"
  When I go back
  And I should see "Articles (1)"
  When I follow "Australia Kangaroo extinction"
  When I follow "Manage"
  And I follow "Program Settings" manage icon
  And I follow "Permissions"
  Then I choose "program_allow_user_to_send_message_outside_mentoring_area_false"
  And I press "Save"
  Then I follow "Mentors"
  When I click "div#mentor_3 div.btn-group a.dropdown-toggle"
  Then I should see "Send Message" within "div#mentor_3"
  Then I should see "data-click" attribute for link "Send Message" matches with "jQueryShowQtip" within "div#mentor_3"
  And I follow "Good unique name"
  When I click "#mentor_profile div.btn-group a.dropdown-toggle"
  Then I should see "Send Message"
  Then I should see "href" attribute for link "Send Message" matches with "/p/albers/messages/new?receiver_id=" within "#mentor_profile div.btn-group"
  And I follow "Ongoing mentoring connections"
  And I hover over class "cjs-user-link-container"
  Then I wait for ajax to complete
  Then I should see "Message" within "div.cjs-hovercard-container"
  Then I should see "href" attribute for link "Message" matches with "/p/albers/messages/new?receiver_id=" within "div.cjs-hovercard-container"
  When I go back
  And I should see "Articles (1)"
  When I follow "Australia Kangaroo extinction"
  Then I logout

@javascript
Scenario: User Send message should point messages new action if allow_user_to_send_message_outside_mentoring_area value is true
  And I have logged in as "ram@example.com"
  When I follow "Manage"
  And I follow "Program Settings" manage icon
  And I follow "Permissions"
  Then I choose "program_allow_user_to_send_message_outside_mentoring_area_true"
  And I press "Save"
  Then I logout
  And I have logged in as "robert@example.com"
  Then I follow "Students"
  And I fill in "sf[quick_search]" with "arun albers"
  And I click "#quick_search .btn.btn-primary"
  Then I wait for ajax to complete
  Then I click ".list-group a.btn.dropdown-toggle"
  Then I should see "Send Message"
  Then I should see "data-click" attribute for link "Send Message" matches with "jQueryShowQtip"
  And I follow "arun albers"
  When I click "#mentor_profile div.btn-group a.dropdown-toggle"
  Then I should see "Send Message"
  Then I should see "href" attribute for link "Send Message" matches with "/p/albers/messages/new?receiver_id="
  Then I follow "Students"
  And I fill in "sf[quick_search]" with "mkr_student madankumarrajan"
  And I click "#quick_search .btn.btn-primary"
  Then I wait for ajax to complete
  Then I click ".list-group a.btn.dropdown-toggle"
  Then I should see "Send Message"
  Then I should see "data-click" attribute for link "Send Message" matches with "jQueryShowQtip"
  And I follow "mkr_student madankumarrajan"
  When I click "#mentor_profile div.btn-group a.dropdown-toggle"
  Then I should see "Send Message"
  Then I should see "href" attribute for link "Send Message" matches with "/p/albers/messages/new?receiver_id="
  Then I follow "name & madankumarrajan" within "ul.metismenu"
  And I expand the "student" listing of mentoring area members pane
  When I hover over link with text "mkr_student madankumarrajan" in the side pane
  Then I should see "Message" within "div.cjs-hovercard-container"
  Then I should see "href" attribute for link "Message" matches with "/p/albers/messages/new?receiver_id=" within "div.cjs-hovercard-container"
  Then I logout

@javascript
Scenario: User Send message should point mentoring area messages action if allow_user_to_send_message_outside_mentoring_area value is false
  And I have logged in as "ram@example.com"
  When I follow "Manage"
  And I follow "Program Settings" manage icon
  And I follow "Permissions"
  Then I choose "program_allow_user_to_send_message_outside_mentoring_area_false"
  And I press "Save"
  Then I logout
  And I have logged in as "robert@example.com"
  Then I follow "Students"
  And I fill in "sf[quick_search]" with "arun albers"
  And I click "#quick_search .btn.btn-primary"
  Then I wait for ajax to complete
  Then I should not see "connect" within "div.listing"
  And I follow "arun albers"
  Then I should not see "Send Message"
  Then I follow "Students"
  And I fill in "sf[quick_search]" with "mkr_student madankumarrajan"
  And I click "#quick_search .btn.btn-primary"
  Then I wait for ajax to complete
  Then I should not see "connect" within "div.listing"
  Then I click ".list-group a.btn.dropdown-toggle"
  Then I should see "Send Message"
  Then I should see "href" attribute for link "Send Message" matches with "/p/albers/groups/"
  And I follow "mkr_student madankumarrajan"
  When I click "#mentor_profile div.btn-group a.dropdown-toggle"
  Then I should see "Send Message"
  Then I should see "href" attribute for link "Send Message" matches with "/p/albers/groups/"
  Then I follow "name & madankumarrajan" within "ul.metismenu"
  And I expand the "student" listing of mentoring area members pane
  When I hover over link with text "mkr_student madankumarrajan" in the side pane
  Then I should see "Message" within "div.cjs-hovercard-container"
  Then I should see "href" attribute for link "Message" matches with "/p/albers/groups/" within "div.cjs-hovercard-container"
  Then I logout

@javascript @engagement_scenario
Scenario: Reply to must not be seen for a message from a removed user

  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user
  And I follow "Manage"
  And I follow "Albers Mentor Program"
  And I follow "Program Settings"
  And I follow "Mentoring Connection Settings"
  And I choose "Group"
  And I press "Save"
  And I follow "Manage"
  And I follow "Mentoring Connections"
  Then I filter on "Student" with name "student_b example"
  Then I should see "chronus & example"
  And I follow "chronus & example"
  And I follow "Manage Members"
  Then I should see "Mentors(1)"
  Then I should see "Students(1)"
  Then I should see "Add Mentor"
  And I follow "Add Mentor"
  When I enter "mentor_a chronus" in "add_member_mentor" autocomplete it with "mentor_a chronus"
  And I choose Add "mentor"-assigned tasks
  And I press "Add"
  And I press "Save"
  And I follow "Manage Members"
  Then I should see "Mentors(2)"
  Then I should see "Students(1)"
  And I logout

  Then I have logged in as "mentor_1@example.com"
  Then I follow "View Profile"
  Then I follow "Ongoing mentoring connections"
  Then I filter on "Mentor" with name "mentor_a chronus"
  Then I wait for ajax to complete
  Then I should see "chronus & example" within "#cjs_groups_listing"
  And I follow "chronus & example" within "#cjs_groups_listing"
  And I follow "Messages" within "div#mentoring_area_tabs"
  And I follow "New Message"
  Then I should see "To: student_b example and mentor_a chronus"
  And I fill in "scrap[subject]" with "Discussion"
  And I fill in "scrap[content]" with "Am creating a discussion"
  And I press "Send Message"
  Then individual mails should go to "mentor_0@example.com,student_1@example.com" having "Am creating a discussion"
  And I logout

  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Mentoring Connections"
  Then I should see "chronus & example"
  And I follow "chronus & example"

  And I follow "Manage Members"
  Then I click on remove member "mentor_b chronus"
  And I choose "group_remove_member_option_1_26"
  Then I press "Remove member"
  And I press "Save"
  And I follow "Manage Members"
  Then I should see "Mentors(1)"
  Then I should see "Students(1)"
  And I press "Save"
  And I logout

  Then I have logged in as "mentor_0@example.com"
  And I follow "chronus & example" within "ul.metismenu"
  Then I follow "Messages" within "div#mentoring_area_tabs"
  Then I should see "Discussion"
  Then I should see "mentor_b chronus"
  And I logout

  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Mentors"
  And I follow "mentor_b chronus"
  And I follow "Remove mentor_b chronus"
  And I press "Remove User"
  And I logout

  Then I have logged in as "mentor_0@example.com"
  Then I should see "chronus & example" within "ul.metismenu"
  And I follow "chronus & example"
  Then I follow "Messages" within "div#mentoring_area_tabs"
  Then I should see "Discussion"
  Then I should see "mentor_b chronus"
  And I open unread scrap message from "mentor_b chronus"
  Then the page should not have the link with title "Reply"
  And I logout