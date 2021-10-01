# encoding: utf-8
Feature: Mentoring Connections Tab
  In order view all the mentoring connections
  As a user
  I want to see Mentoring Connections Tab

  Background:
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    Then I enable admin audit logs
    And I logout

  @javascript
  Scenario: Mentoring Connections Tab shouldnot be shown for organization view
    # Login as a Mentor
    When I have logged in as "robert@example.com"
    When I select "Primary Organization" from the program selector
    Then I should not see the tab "Mentoring Connections"

  @javascript
  Scenario: Discussion tab homepage
    Given the current program is "primary":"pbe"
    And I enable "moderate_forums" feature as a super user
    When I have logged in as "robert@example.com"
    And I should see "Discussion Board" within ".cjs_forum_tabs"
    Then I follow "Discussion Board" within "#cjs_connections_widget"
    When I follow "Start a Conversation"
    And I fill in "topic_title" with "Conversation 1"
    And I press "Create"
    Then I should not see "A new conversation has been started successfully."
    When I set the topic body of homepage to "This is the first message"
    And I press "Create"
    Then I should see the flash "A new conversation has been started successfully."
    Then I follow "Discussion Board" within "#cjs_connections_widget"
    And I should not see "You have no unread conversations."
    And I should see "Conversation 1" within "#cjs_connections_widget"
    And I should not see "Replies"
    And I should be following the conversation "Conversation 1"
    And I can delete the conversation "Conversation 1"
    Then I logout

    When I have logged in as "rahim@example.com"
    And I should see "Discussion Board" within ".cjs_forum_tabs"
    Then I follow "Discussion Board" within "#cjs_connections_widget"
    Then I should see "Conversation 1"
    And I cannot delete the conversation "Conversation 1"
    And I should be following the conversation "Conversation 1"
    When I unfollow the conversation "Conversation 1"
    Then I should see "You have stopped following this conversation."
    And I should not be following the conversation "Conversation 1"

    When I follow "Start a Conversation"
    And I fill in "topic_title" with "Conversation 2"
    And I press "Create"
    Then I should not see "A new conversation has been started successfully."
    When I set the topic body of homepage to "This is the second message"
    And I press "Create"
    Then I should see the flash "A new conversation has been started successfully."

    Then I click on the conversation "Conversation 1"
    Then I should see "Conversation 1" within "#SidebarRightHomeContent"
    Then I should see "This is the first message" within "#SidebarRightHomeContent"
    And I should see "No replies yet" within "#SidebarRightHomeContent"
    And I should see "Add reply" within "#SidebarRightHomeContent"
    Then I click ".cjs_add_comment_link"
    And I should not see "Add reply" within "#SidebarRightHomeContent"
    Then I click ".cjs_reply_cancel"
    And I should see "Add reply" within "#SidebarRightHomeContent"
    Then I click ".cjs_add_comment_link"
    And I should not see "Reply to Conversation"
    And I click ".fa-paper-plane-o"
    Then I should see "Please correct the below error(s) highlighted in red."
    Then I add a new reply "This is the new reply in coversation 1"
    And I wait for "1" seconds
    And I click ".fa-paper-plane-o"

    Then I should see "Your post is created."
    And I should see "Reply to Conversation"
    And I should see "This is the new reply in coversation 1" within ".cjs_ibox_content_scroll"
    And I can delete the post "This is the new reply in coversation 1" in the conversation "Conversation 1"
    And I click ".close-link" within ".cui-full-height-sidebar"
    And I should see "Welcome, student example" within "#SidebarRightContainer"
    Then I click on the conversation "Conversation 1"
    And I should not see "No replies yet" within "#SidebarRightHomeContent"
    And I should see "This is the new reply in coversation 1" within ".cjs_ibox_content_scroll"
    And I should see "Reply to Conversation"
    And I click ".cjs_add_message_sidepane .cui-comment-footer" within "#SidebarRightHomeContent"
    And I should not see "Reply to Conversation"
    And I logout

    When I have logged in as "robert@example.com"
    And I should see "Discussion Board" within ".cjs_forum_tabs"
    Then I follow "Discussion Board" within "#cjs_connections_widget"
    Then I click on the conversation "Conversation 1"
    And I cannot delete the post "This is the new reply in coversation 1" in the conversation "Conversation 1"
    And I logout

  @javascript @cross-browser
  Scenario: Mentor should see the tab
    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    Then I should see "MENTORING CONNECTIONS" within "ul.metismenu"
    And I should see "name & madankumarrajan"
    And I follow "View Profile"
    And I follow "Ongoing mentoring connections"
    And I should see the page title "Mentoring Connections"
    When I follow "Home" tab
    And I follow "View Profile"
    And I follow "Ongoing mentoring connections"
    And I should see the page title "Mentoring Connections"
    When I follow "Home" tab
    Then I logout

    When I have logged in as "ram@example.com"
    Then I login as super user
    When I select "Primary Organization" from the program selector
    And I enable "connection_profile" feature as a super user
    When I select "Albers Mentor Program" from the program selector
    Then I enable public mentoring connection option
    Then I should not see "MENTORING CONNECTIONS" within "ul.metismenu"
    Then I should not see "MENTORING CONNECTIONS" within "ul.metismenu"
    Then I logout

    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    Then I should see "MENTORING CONNECTIONS" within "ul.metismenu"
    And I should see "name & madankumarrajan"
    Then I follow "name & madankumarrajan"
    Then I should see the tab "name & madankumarrajan" selected
    And I should see the page title "name & madankumarrajan"

 @javascript
 Scenario: Admin visits mentoring connection
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    # Admin should not see the mentoring connections tab
    Then I should not see the tab "Mentoring Connections"
    And I should not see the tab "My Mentoring Connections"
    When I follow "Manage"
    And I follow "Mentoring Connections"
    Then I should not see the tab "Mentoring Connections"
    And I should see the tab "Manage" selected
    And I should see the page title "Mentoring Connections"
    When I follow "Visit Mentoring Connection"
    Then I should see the page title "Enter a reason to view confidential area"
    And I should not see the tab "Mentoring Connections"
    And I should see the tab "Manage" selected
    When I fill in "confidentiality_audit_log_reason" with "Time Pass"
    And I press "Proceed »"
    Then I should not see the tab "Mentoring Connections"
    And I should see the tab "Manage" selected

 @javascript @cross-browser
 Scenario: Admin visits mentoring connection and toggles between views
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    When I select "Primary Organization" from the program selector
    When I select "Albers Mentor Program" from the program selector
    # Admin should not see the mentoring connections tab
    Then I should not see the tab "Mentoring Connections"
    And I should not see the tab "My Mentoring Connections"
    When I follow "Manage"
    And I follow "Mentoring Connections"
    Then I should not see the tab "Mentoring Connections"
    And I should see the tab "Manage" selected
    And I should see the page title "Mentoring Connections"
    And I should see "Ongoing" within "li.ct_active"
    And I should see "Visit Mentoring Connection"
    And I click "#list_view"
    Then I should not see "Visit Mentoring Connection"
    Then I should see "Mentoring Connection Name" within "#cjs_group_record"
    And I follow "Closed"
    Then I should see "Closed" within "li.ct_active"
    Then I should not see "Visit Mentoring Connection"
    And I click "#detailed_view"
    Then I should see "Visit Mentoring Connection"
    And I follow "Drafted"
    Then I should see "Drafted" within "li.ct_active"
    Then I should see "Publish Mentoring Connection" within "#groups"
    And I click "#list_view"
    Then I should not see "Publish Mentoring Connection" within "#groups"

 @javascript @cross-browser
 Scenario: Admin visits mentoring connections page, filters the results and clears the filters
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    When I follow "Manage"
    And I follow "Mentoring Connections"
    And I should see "Ongoing" within "li.ct_active"
    And I should see "#reset_all" hidden
    Then I filter on student field
    And I should see "#reset_all" not hidden
    Then I follow "Reset all"
    Then I should see "#reset_all" hidden

 @javascript
 Scenario: Admin visits the mentoring connection of an inactive connection he/she is not part of
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    # Admin should not see the mentoring connections tab
    Then I should not see the tab "Mentoring Connections"
    And I should not see the tab "My Mentoring Connections"
    When I follow "Manage"
    And I follow "Mentoring Connections"
    Then I should not see the tab "Mentoring Connections"
    And I should see the tab "Manage" selected
    And I should see the page title "Mentoring Connections"
    Then I filter and see inactive connections
    When I follow "Visit Mentoring Connection"
    When I fill in "confidentiality_audit_log_reason" with "Time Pass"
    And I press "Proceed »"
    Then I should not see "Please help us understand the progress"

 @javascript @not_run_on_bs
 Scenario: Mentor/Mentee visits the mentoring connection of an inactive connection he/she is part of
    # IE driver not opening the provide feedback popup automatically
    Given the current program is "primary":"albers"
    And I have logged in as "mentor_1@example.com"
    And I should not see the tab "My Mentoring Connections" selected
     And I follow "View Profile"
    And I follow "Ongoing mentoring connections"
    And I should see "Ongoing" within "li.ct_active"
    Then I filter on student field
    When I follow "Visit Mentoring Connection"
    Then I should see "Please help us understand the progress"

@javascript @cross-browser
  Scenario: Groups should not be accessible if the permission is set to "disabled"
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Mentoring Connections"
    And I follow "chronus & example"
    And I login as super user
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Permissions"
    Then I should see "Disabled"
    Then I choose "admin_access_disabled"
    And I press "Save"
    And I logout as super user
    And I follow "Manage"
    And I follow "Mentoring Connections"
    And the page should not have the link with title "chronus & example"

@javascript @cross-browser
  Scenario: Groups should be accessible if the permission is set to "Open"
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I login as super user
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Permissions"
    Then I should see "Open"
    Then I choose "admin_access_open"
    And I press "Save"
    And I logout as super user
    And I follow "Manage"
    And I follow "Mentoring Connections"
    Then I follow "chronus & example"
    And I logout

@javascript @cross-browser
  Scenario: Admin adds a new closure reason and closes a mentoring connection
    Given the current program is "primary":"albers"
    Then I maximize the window
    When I have logged in as "ram@example.com"
    Then I enable admin audit logs
    When I select "Primary Organization" from the program selector
    Then I enable "mentoring_connections_v2" feature as a super user
    And I logout
    And I stub chronus s3 utils
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I login as super user
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Mentoring Connection Settings"
    And I follow "Advanced Options"
    Then I should see "Closure reasons"
    And I add a new closure reason as "Mentoring Connection closed by admin" with "yes" for consider completed
    And I press "Save"
    And I follow "Manage"
    And I follow "Mentoring Connections"
    Then I should see "chronus & example"
    And I follow "chronus & example"
    When I fill in "confidentiality_audit_log_reason" with "Time Pass"
    And I press "Proceed »"
    And I follow "Close Mentoring Connection"
    Then I should see "Reason"
    And I select "Mentoring Connection closed by admin" from "group_closure_reason"
    And I fill in "group_termination_reason" with "testing new closure reason"
    And I press "Close"
    And I follow "Mentors"
    Then I should scroll by "1000"
    And I follow "mentor_b chronus"
    And I follow "Mentoring Connections (1)"
    And I follow "Closed (1)"
    Then I should see "chronus & example"
    Then I should see "Closed By:"
    Then I follow "View reason"
    Then I should see "Mentoring Connection closed by admin"