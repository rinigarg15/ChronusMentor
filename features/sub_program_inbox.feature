@sub_programs
Feature: Email notifications from a sub-program
  For users belonging to sub-programs
  The emails should give enough context about the program and the sub program   

Background:
    Given the current program is "annauniv":"psg"

@javascript @cross-browser
Scenario: User belonging to only one of the sub program sending message to a user belonging to two of the sub-programs
    Given I have logged in as "stud3@psg.com"
    And I visit the profile of "mentor@psg.com"
    When I click "#mentor_profile div.btn-group a.dropdown-toggle"
    And I follow "Send Message"

    And I set subject to "Meeting for lunch tomorrow" and content to "Lets meet tomorrow itself"
    And I press "Send"
    Then I should see "Your message has been sent"
    And I logout

    # Logging in as the student and seeing "Inbox (1)"
    Given I have logged in as "mentor@psg.com"
    Then I should see inbox link

    # Now, opening the email and following the link in it.
    When I open new mail
    Then I should see "psg" in the email body
    And I follow "message" in the email

    # Should be taken to the program from which the mail was created
    Then I should see the program title "psg"
    And I should see "Meeting for lunch tomorrow"

@javascript
Scenario: User belonging to only one of the sub program sending message to a user belonging to two of the sub-programs
    
    Given I have logged in as "mentor@psg.com"
    Then I visit the global profile of "stud3@psg.com" 
    When I click "#mentor_profile div.btn-group a.dropdown-toggle"
    And I follow "Send Message"

    And I set subject to "Meeting for lunch tomorrow" and content to "Lets meet tomorrow itself"
    And I press "Send"
    Then I should see "Your message has been sent"
    And I logout

# Logging in as the student and seeing "Inbox (1)"
    Given the current program is "annauniv":"psg"
    Given I have logged in as "stud3@psg.com"
    Then I should see inbox link

    # Now, opening the email and following the link in it.
    When I open new mail
    Then I should see "Anna University" in the email body
    And I follow "message" in the email

    # Should not be taken to any sub-program
    Then I should see the program title "psg"
    And I should see "Meeting for lunch tomorrow"

@javascript @cross-browser
Scenario: User belonging to more than one sub program sending admin message and admin replies and the user check it at the program level
    Given I have logged in as "mentor@psg.com"
    When I hover over "my_programs_container"
    And I select "psg" from the program selector
    And I follow "Contact Administrator"
    And I fill in "admin_message_subject" with "Meeting for lunch tomorrow"
    And I fill in "admin_message_content" with "Can meet tomorrow itself?"
    Then I press "Send"
    And I logout

    # Logging in as admin and replies
    When I have logged in as "psg@example.com"
    And I follow "Manage"
    Given "1" last "admin message" exist
    And I follow "Administrator Inbox"
    Then I should see "Meeting for lunch tomorrow"
    Then I should see "Can meet"
    When I click message "Meeting for lunch tomorrow" of "Inbox" message list
    Then I wait for "2" seconds
    Then I open reply pane for the message "1"
    And I fill in "admin_message[content]" with "Can we postpone it to day after tomorrow?"
    And I press "Reply"
    And I logout

    When I have logged in as "mentor@psg.com"
    When I hover over "my_programs_container"
    And I select "psg" from the program selector
    Then I should see inbox link
    When I hover over "my_programs_container"
    And I select "CEG Mentor Program" from the program selector
    Then I should see inbox link
    When I hover over "my_programs_container"
    And I select "Anna University" from the program selector
    Then I should see inbox link

@javascript @cross-browser
Scenario: Admin seeing the Admin messages navigation in top header
    Given I have logged in as "mentor@psg.com"
    When I hover over "my_programs_container"
    And I select "psg" from the program selector
    And I follow "Contact Administrator"
    And I fill in "admin_message_subject" with "Meeting for lunch tomorrow"
    And I fill in "admin_message_content" with "Can meet tomorrow itself?"
    Then I press "Send"
    And I logout

    # Logging in as admin and replies
    When I have logged in as "psg@example.com"
    And I follow "Manage"
    Given "1" last "admin message" exist
    Then I should see inbox link
    Then I visit inbox with "1" unread messages
    Then I should see "My Messages"
    Then I should see "Administrator Messages 1"
    And I follow "Administrator Messages"
    Then I should see "Meeting for lunch tomorrow"
    Then I should see "Can meet"
    When I click message "Meeting for lunch tomorrow" of "Inbox" message list
    Then I wait for "2" seconds
    Then I open reply pane for the message "1"
    And I fill in "admin_message[content]" with "Can we postpone it to day after tomorrow?"
    And I press "Reply"
    And I logout

    When I have logged in as "mentor@psg.com"
    When I hover over "my_programs_container"
    And I select "psg" from the program selector
    Then I should see inbox link
    Then I visit inbox with "1" unread messages