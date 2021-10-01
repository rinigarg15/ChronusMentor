Feature: Discussion Board in Mentoring Area
As a member of the connection
I can start, reply to, delete, follow the conversations; comment on, delete replies; delete comments
As an admin who is not part of the connection
I can only read conversations and posts

Background:
  Given the current program is "primary":"pbe"
  And I enable "moderate_forums" feature as a super user

@javascript
Scenario: Discussion Board
  Given I have logged in as "robert@example.com"
  And I click ".profile_header_image"
  And I follow "View Profile"
  And I follow "Ongoing mentoring connections"
  Then I should see "0 Posts in 0 Conversations"
  And I should not see "Messages" within "div#content_wrapper"
  When I follow "project_group"
  Then I should see the mentoring area tab "Plan" selected

  #Default Collapsed members list for Group Mentoring
  And I should see "Members (2)" within "#SidebarRightContainer"
  And I should see "Mentor (1)" within "#SidebarRightContainer"
  And I expand the "mentor" listing of mentoring area members pane
  And I should see "Good unique name"
  And I should see "Student (1)" within "#SidebarRightContainer"
  And I expand the "student" listing of mentoring area members pane
  And I should see "student example"

  And I should not see "About Discussion Board"
  And I should see the mentoring area tab "Discussion Board"
  And I should not see the mentoring area tab "Messages"
  When I follow "Discussion Board"
  Then I should see the mentoring area tab "Discussion Board" selected
  And I should see "About Discussion Board"
  And I should see "There are no conversations"
  When I follow "Start a Conversation"
  And I set the topic title to "Conversation 1"
  And I press "Create"
  Then I should not see "A new conversation has been started successfully."
  When I set the topic body to "This is the first message"
  And I press "Create"
  Then I should see the flash "A new conversation has been started successfully."
  And I should not see "There are no conversations"
  And I should see "Conversation 1"
  And I should not see "Replies"
  And I should be following the conversation "Conversation 1"
  And I can delete the conversation "Conversation 1"
  And I logout

  When I have logged in as "rahim@example.com"
  And I click ".profile_header_image"
  And I follow "View Profile"
  And I follow "Ongoing mentoring connections"
  Then I should see "0 Posts in 1 Conversation"
  When I follow "project_group"
  And I follow "Discussion Board"
  Then I should see "Conversation 1"
  And I cannot delete the conversation "Conversation 1"
  And I should be following the conversation "Conversation 1"
  When I unfollow the conversation "Conversation 1"
  Then I should see "You have stopped following this conversation."
  And I should not be following the conversation "Conversation 1"

  When I follow "Start a Conversation"
  And I set the topic title to "Conversation 2"
  And I press "Create"
  Then I should not see "A new conversation has been started successfully."
  When I set the topic body to "This is the second message"
  And I press "Create"
  Then I should see the flash "A new conversation has been started successfully."

  Then I click on the conversation "Conversation 1"
  And I should see "No replies yet" within "#SidebarRightHomeContent"
  And I should see "Add reply" within "#SidebarRightHomeContent"
  Then I click ".cjs_add_comment_link"
  And I should not see "Add reply" within "#SidebarRightHomeContent"
  Then I click ".cjs_reply_cancel"
  And I should see "Add reply" within "#SidebarRightHomeContent"
  Then I click ".cjs_add_comment_link"
  And I should not see "Reply to Conversation"
  And I click ".fa-paper-plane-o"
  Then I should see "Post can't be blank"
  Then I add a new reply "This is the new reply in coversation 1"
  And I wait for "1" seconds
  And I click ".fa-paper-plane-o"

  Then I should see "Your post is created."
  And I should see "Reply to Conversation"
  And I should see "This is the new reply in coversation 1" within ".cjs_ibox_content_scroll"
  And I can delete the post "This is the new reply in coversation 1" in the conversation "Conversation 1"
  And I click ".close-link" within ".cui-full-height-sidebar"
  And I should see "Members (2)" within "#SidebarRightContainer"
  Then I click on the conversation "Conversation 1"
  And I should see "Replies" within "#SidebarRightHomeContent"
  And I should not see "No replies yet" within "#SidebarRightHomeContent"
  And I should see "This is the new reply in coversation 1" within ".cjs_ibox_content_scroll"
  And I should see "Reply to Conversation"
  And I click ".cui-comment-fixed-bottom"
  And I should not see "Reply to Conversation"
  Then I click on the conversation "Conversation 2"
  Then I click ".cjs_add_comment_link"
  Then I add a new reply "This is the new reply in coversation 2"
  And I wait for "1" seconds
  And I click ".fa-paper-plane-o"
  Then I should see "Your post is created."
  And I logout

  When I have logged in as "robert@example.com"
  Then I should see "2" within ".cjs_unread_posts_count"
  Then I click on the conversation "Conversation 2"
  Then I should see "1" within ".cjs_unread_posts_count"
  And I click ".profile_header_image"
  And I follow "View Profile"
  And I follow "Ongoing mentoring connections"
  Then I should see "2 Posts in 2 Conversations"
  When I follow "project_group"
  Then I should see "1" within ".cjs_unread_posts_count"
  And I follow "Discussion Board"
  Then I click on the conversation "Conversation 1"
  And I should not see element ".cjs_unread_posts_count"
  And I cannot delete the post "This is the new reply in coversation 1" in the conversation "Conversation 1"
  And I logout