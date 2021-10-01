Feature: Mentor and mentee subscribe and unsubscribe to their forums
  In order to subscribe to a forum and recieve an email if some one posts
  As a mentor
  I want to login and enter the appropriate as required

Background: Set the program
  Given the current program is "primary":"albers"
  Given no subscriptions yet

@javascript
Scenario: Student2 subscribes to all forums
  And I have logged in as "rahim@example.com"
  Then I follow "Forums"
  And I should not see "Mentors forum"
  And I follow "Mentees Forum"
  And I follow "Join Forum"
  Then I should see the flash "You have joined 'Mentees Forum'"
  And I follow "Common forum"
  And I follow "Join Forum"
  Then I should see the flash "You have joined 'Common forum'"
  Then I follow "Sign out"
  And clear mail deliveries

@javascript
Scenario: Student1 doesnot receive an email when Student2 posts in Student forum
  When I have logged in as "rahim@example.com"
  Then I visit forum with name "Mentees Forum"
  And I follow "Start a Conversation"
  And I set the topic title to "First Conversation"
  And I set the topic body to "This is the first message"
  And I press "Create"
  Then no email is sent
  And I logout

@javascript @cross_browser
Scenario: Student1 can successfully attach a file while creating topic
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I follow "Mentors Forum" subtab in "Forums" tab
  And I follow "Start a Conversation"
  And I set the topic title to "First Conversation"
  And I set the topic body to "This is the first message"
  And I press "Create"
  Then I should see "A new conversation has been started successfully."
  Then I click on the conversation "First Conversation"
  Then I click ".cjs_add_comment_link"
  Then I add a new reply "This is the new reply in coversation 1"
  And I set the attachment field "post_attachment" to "pic_2.png"
  And I click ".fa-paper-plane-o"
  Then I should see the flash "Your post is created."
  And I logout

@javascript
Scenario: User views recent five topics of a forum and views all
  When I have logged in as "rahim@example.com"
  And I follow "Mentees Forum" subtab in "Forums" tab
  And I follow "Start a Conversation"
  And I set the topic title to "First Conversation"
  And I set the topic body to "This is the first conversation."
  And I press "Create"
  Then I should see "Following"
  And I follow "Start a Conversation"
  And I set the topic title to "Second Conversation"
  And I set the topic body to "This is the second conversation."
  And I press "Create"
  Then I should see "Following"
  And I should see "First Conversation" within "#SidebarRightContainer"
  When I follow "See all"
  Then I should see "Mentees Forum"
  And I logout

@javascript @cross_browser
Scenario: Nested posts + Deleting of a post
  When I have logged in as "ram@example.com"
  And I enable "moderate_forums" feature as a super user
  And I navigate to "Forums" from manage page
  And I follow "Mentors Forum"
  And I follow "Start a Conversation"
  And I set the topic title to "First Conversation"
  
  And I set the topic body to "This is the first topic"
  And I press "Create"
  Then I should see "A new conversation has been started successfully."

  Then I click on the conversation "First Conversation"
  And I wait for "1" seconds
  Then I click ".cjs_add_comment_link"
  Then I add a new reply "This is the body"
  And I click ".fa-paper-plane-o"
  Then I should see the flash "Your post is created."

  When I add 3 comments with the text "This is admin's comment" to the last post
  Then I should see "This is admin's comment" 3 times
  Then I should see the flash "Your post is created."
  And I logout

  When I have logged in as "robert@example.com"
  And I follow "Mentors Forum" subtab in "Forums" tab
  Then I click on the conversation "First Conversation"
  And I wait for "1" seconds
  Then I should see "This is admin's comment" 3 times

  When I add 3 comments with the text "This is robert's comment" to the last post
  Then I should see the flash "Thank you for your message. Your post will be uploaded to the forum shortly."
  And I logout

  When I have logged in as "ram@example.com"
  And I navigate to "Forums" from manage page
  And I follow "Mentors Forum"
  Then I click on the conversation "First Conversation"
  And I wait for "1" seconds
  Then I should see "This is admin's comment" 2 times
  And I should see "This is robert's comment" 3 times
  And I should see "View all 6 comments(3 unmoderated)"

  When I follow "View all 6 comments(3 unmoderated)"
  Then I should see "This is admin's comment" 3 times
  And I should see "This is robert's comment" 3 times
  And I should see "View less comments"

  Then I follow "View less comments"
  And I should see "This is admin's comment" 2 times
  And I should see "This is robert's comment" 3 times
  And I should see "View all 6 comments(3 unmoderated)"

  When I delete comment of the last post
  Then I should not see "View all"
  Then I logout

@javascript @cross_browser
  Scenario: Student1 subscribes and receives an email when Student2 posts in Student forum
  When I have logged in as "mkr@example.com"
  And I follow "Mentees Forum" subtab in "Forums" tab
  And I follow "Join Forum"
  Then I should see the flash "You have joined 'Mentees Forum'"
  And I logout

  And I have logged in as "rahim@example.com"
  And I follow "Mentees Forum" subtab in "Forums" tab
  And I follow "Start a Conversation"
  And I set the topic title to "First Conversation"
  And I set the topic body to "This is the first topic"
  And I press "Create"
  Then I should see "A new conversation has been started successfully."
  And individual mails should go to "mkr@example.com" having "started a conversation 'First Conversation' in the forum 'Mentees Forum'. Reply to conversation"
  And I logout

@javascript
Scenario: Mentor1 doesnot receive an email when Student2 posts in Common forum
  # Student
  Then I have logged in as "rahim@example.com"
  Then I visit forum with name "Common forum"
  And I follow "Start a Conversation"
  And I set the topic title to "This is first Common Topic"
  And I set the topic body to "This is the first common message"
  And I press "Create"
  Then I logout

@javascript
Scenario: Mentor1 subscribes and receives an email when Student2 posts in Common forum
  #Mentor_1
  When I have logged in as "robert@example.com"
  And I follow "Common forum" subtab in "Forums" tab
  And I follow "Join Forum"
  Then I should see the flash "You have joined 'Common forum'"
  And I logout

  #Student
  When I have logged in as "rahim@example.com"
  And I follow "Common forum" subtab in "Forums" tab
  And I follow "Start a Conversation"
  And I set the topic title to "This is first Common Topic"
  And I set the topic body to "This is the first topic"
  And I press "Create"
  Then I should see "A new conversation has been started successfully."
  And individual mails should go to "robert@example.com" having "started a conversation 'This is first Common Topic' in the forum 'Common forum'. Reply to conversation"
  And I logout

@javascript
Scenario: Mentor1 subscribes and unsubscibes when Student2 posts in Common forum
  When I have logged in as "robert@example.com"
  And I follow "Common forum" subtab in "Forums" tab
  And I follow "Join Forum"
  Then I should see "You have joined 'Common forum'"

  When I follow "Leave Forum"
  Then I should see "Are you sure you want to leave Common forum?"
  Then I confirm popup
  Then I should see "You have unsubscribed from 'Common forum'"
  And I logout

@javascript
Scenario: Student does not follow topic
  #Student
  When I have logged in as "rahim@example.com"
  And I visit forum with name "Common forum"
  And I follow "Start a Conversation"
  And I set the topic title to "This is first Common Topic"
  And I set the topic body to "This is the first common message"
  And I press "Create"
  Then no email is sent