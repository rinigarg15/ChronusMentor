@javascript @cross-browser
Feature: Forum Moderation

Background: Content moderation feature is enabled
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I enable "moderate_forums" feature as a super user
  And I logout

@javascript
Scenario: Admin creates a new topic/post with moderation enabled.
  When I have logged in as "ram@example.com"
  And I follow "Mentors Forum" subtab in "Forums" tab
  And I follow "Start a Conversation"
  And I set the topic title to "First Conversation"
  And I set the topic body to "This is the first conversation"
  And I press "Create"
  Then I should see the flash "A new conversation has been started successfully."
  And I should see "First Conversation"
  And I should see "This is the first conversation"
  Then I click on the conversation "First Conversation"
  Then I click ".cjs_add_comment_link"
  Then I add a new reply "Replying to the first conversation"
  And I click ".fa-paper-plane-o"
  Then I should see the flash "Your post is created."
  And I should see "Replying to the first conversation"
  And I logout

@javascript
Scenario: Mentor creates a new topic/post with moderation enabled; Admin approves
  When I have logged in as "robert@example.com"
  And I follow "Mentors Forum" subtab in "Forums" tab
  And I follow "Start a Conversation"
  And I set the topic title to "First Conversation"
  And I set the topic body to "This is the first conversation"
  And I press "Create"
  Then I should see the flash "A new conversation has been started successfully."
  And I should see "First Conversation"
  And I should see "This is the first conversation"
  Then I click on the conversation "First Conversation"
  Then I click ".cjs_add_comment_link"
  Then I add a new reply "Replying to the first conversation"
  And I click ".fa-paper-plane-o"
  Then I should see the flash "Thank you for your message. Your post will be uploaded to the forum shortly."
  And I should not see "Replying to the first conversation"
  And I logout

  When I have logged in as "ram@example.com"
  And I follow "Mentors Forum" subtab in "Forums" tab
  Then I click on the conversation "First Conversation"
  Then I should see "Replying to the first conversation"
  When I follow "Publish" in moderate posts
  Then I should see the flash "Post by Good unique name is published."
  And I logout

  When I have logged in as "robert@example.com"
  And I follow "Mentors Forum" subtab in "Forums" tab
  Then I click on the conversation "First Conversation"
  Then I should see "Replying to the first conversation"
  And I logout

@javascript
Scenario: Mentor creates a new post in a topic created by admin; Admin declines
  When I have logged in as "ram@example.com"
  And I follow "Mentors Forum" subtab in "Forums" tab
  And I follow "Start a Conversation"
  And I set the topic title to "First Conversation"
  And I set the topic body to "This is the first conversation"
  And I press "Create"
  Then I should see the flash "A new conversation has been started successfully."
  And I should see "First Conversation"
  And I should see "This is the first conversation"
  And I logout

  When I have logged in as "robert@example.com"
  And I follow "Mentors Forum" subtab in "Forums" tab
  Then I click on the conversation "First Conversation"
  Then I click ".cjs_add_comment_link"
  Then I add a new reply "Replying to the first conversation"
  And I click ".fa-paper-plane-o"
  Then I should see the flash "Thank you for your message. Your post will be uploaded to the forum shortly."
  And I should not see "Replying to the first conversation"
  And I logout

  When I have logged in as "ram@example.com"
  And I follow "Mentors Forum" subtab in "Forums" tab
  Then I click on the conversation "First Conversation"
  Then I should see "Replying to the first conversation"
  When I follow "Decline" in moderate posts
  Then I should see "Decline Post"
  When I fill in "reason" with "This content is not allowed"
  And I press "Send"
  Then I should see the flash "The post was not published."
  And I logout

  When I have logged in as "robert@example.com"
  And I follow "Mentors Forum" subtab in "Forums" tab
  Then I click on the conversation "First Conversation"
  Then I should not see "Replying to the first conversation"
  And I logout

@javascript
Scenario: Check if Content Awaiting Moderation page is filled with posts by mentor
  When I have logged in as "robert@example.com"
  And I follow "Mentors Forum" subtab in "Forums" tab
  And I follow "Start a Conversation"
  And I set the topic title to "First Conversation"
  And I set the topic body to "This is the first conversation"
  And I press "Create"
  Then I click on the conversation "First Conversation"
  Then I click ".cjs_add_comment_link"
  Then I add a new reply "Replying to the first conversation"
  And I click ".fa-paper-plane-o"
  And I should not see "Replying to the first conversation"
  And I logout

  When I have logged in as "ram@example.com"
  Given the current program is "primary":"albers"
  And I navigate to "Moderate Content" from manage page
  Then I should see "Replying to the first conversation"
  When I follow "First Conversation"
  And I follow the back link
  Then I should see "Content Awaiting Moderation"
  When I follow "Publish"
  Then I should not see "Replying to the first conversation"
  And I logout

@javascript
Scenario: Check if Content Awaiting Moderation page is updated when admin declines the post
  When I have logged in as "robert@example.com"
  And I follow "Mentors Forum" subtab in "Forums" tab
  And I follow "Start a Conversation"
  And I set the topic title to "First Conversation"
  And I set the topic body to "This is the first conversation"
  And I press "Create"
  Then I click on the conversation "First Conversation"
  Then I click ".cjs_add_comment_link"
  Then I add a new reply "Replying to the first conversation"
  And I click ".fa-paper-plane-o"
  And I should not see "Replying to the first conversation"
  And I logout

  When I have logged in as "ram@example.com"
  Given the current program is "primary":"albers"
  And I navigate to "Moderate Content" from manage page
  Then I should see "Replying to the first conversation"
  When I follow "Decline"
  Then I should see "Decline Post"
  When I fill in "reason" with "This content is not allowed" within "#remoteModal"
  And I press "Send"
  Then I should see the flash "The post was not published."
  And I should not see "Replying to the first conversation"
  And I logout