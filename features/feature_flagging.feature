@javascript
Feature: Flagging a content and resolving it
  In order to resolve a flagged content
  As an admin
  I want to login and go to the resolve page and resolve it

  Background: Enable Flagging
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    When I hover over "my_programs_container"
    When I select "Primary Organization" from the program selector
    And I enable "flagging" feature as a super user
    And I logout
    Given the current program is "primary":"albers"

  @javascript
  Scenario: Admin should see flagged content only when feature is enabled
    When I have logged in as "ram@example.com"
    And I login as super user
    And I follow "Manage"
    Then I should see "Flagged Content"
    And I disable the feature "flagging" as a super user
    Given the current program is "primary":"albers"
    Then I follow "Manage"
    Then I should not see "Flagged Content"
    Then I logout

  Scenario: User flags and admin allows it from resolve box in content show page (for Article)
    When I have logged in as "robert@example.com"
    Then I hover on tab "Advice"
    And I follow "Articles"
    And I follow "Capital city"
    Then I hover over "view_article"
    And I click article grey flag
    Then I should see "Report Inappropriate Content"
    And I fill in the reason
    Then I click report button
    Then I should see "Content has been flagged successfully"
    And I logout
    When I have logged in as "ram@example.com"
    And I follow "Albers Mentor Program"
    And I follow "Manage"
    And I follow "Flagged Content"
    Then I should see "Pending (1)"
    And I follow "View content"
    Then I hover over "view_article"
    Then I click the red flag
    Then I should see "reason"
    Then I should see "Ignore Flags"
    Then I should see "Delete Article"
    And I follow "Ignore Flags"
    Then I should see "All the flags for the content are ignored and the content is allowed"
    And I logout

  @javascript @p2 @cross_browser
  Scenario: User flags a question and admin deletes the question  (for Q&A)
    When I have logged in as "mkr@example.com"
    Then I hover on tab "Advice"
    And I follow "Question & Answers"
    Then I follow "where in this world is coimbatore?"
    And I click "span.caret" within "div#title_actions"
    And I follow "Report Content"
    Then I should see "Report Inappropriate Content"
    And I fill in the reason
    Then I click report button
    Then I should see "Content has been flagged successfully"
    Then I logout
    When I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Flagged Content"
    Then I should see "Pending (1)"
    Then I should see "View content"
    And I follow "View content"
    And I click "span.caret" within "div#title_actions"
    Then I follow "Resolve"
    Then I should see "reason"
    Then I should see "Ignore Flags"
    Then I should see "Delete Question"
    And I follow "Delete Question"
    Then I confirm popup
    Then I should see "The question has been deleted"
    And I logout


  @javascript @cross_browser
  Scenario: User flagging a Forum post and admin publishing it
    When I have logged in as "mkr@example.com"
    And I follow "Forums"
    And I follow "Mentees Forum"
    And I follow "Start a Conversation"
    And I fill in "topic_title" with "First Conversation"
    And I set the topic body of homepage to "This is the first conversation"
    And I press "Create"
    Then I should see "A new conversation has been started successfully."
    Then I click on the conversation "First Conversation"
    And I wait for "1" seconds
    Then I click ".cjs_add_comment_link"
    Then I add a new reply "This is a body"
    And I click ".fa-paper-plane-o"
    Then I should see "Your post is created."
    And I logout

    When I have logged in as "ram@example.com"
    And I follow "Forums"
    And I follow "Mentees Forum"
    Then I click on the conversation "First Conversation"
    Then I should see "This is a body"

    And I click "span.caret" within "div.cjs_posts_listing"
    And I follow "Report Content"
    And I fill in the reason
    And I click report button
    Then I should see the flash "Content has been flagged successfully"

    Then I go to the homepage
    And I follow "Albers Mentor Program"
    And I follow "Manage"
    And I follow "Flagged Content"
    Then I should see "Pending (1)"
    Then I should see "View content"
    And I follow "View content"
    Then I hover over "view_article"
    Then I click the red flag
    Then I should see "reason"
    Then I should see "Ignore Flags"
    Then I should see "Delete Forum Post"
    And I follow "Delete Forum Post"
    Then I confirm popup
    Then I should see "Post has been deleted"
    And I logout

  @javascript @cross_browser
  Scenario: User flagging a article comment and answer and admin ignoring/publishing it
    When I have logged in as "robert@example.com"
    Then I hover on tab "Advice"
    And I follow "Articles"
    And I follow "Capital city"
    And I fill in "comment_body" with "Sample comment"
    And I press "Comment"
    And I should see "less than a minute ago"
    And I should see "Sample comment"
    And I follow "Question & Answers"
    Then I follow "where in this world is coimbatore?"
    And I follow "Answer this question"
    And I give "Sample answer" as an answer
    And I should see "Sample answer"
    And I should see "Posted less than a minute ago"
    And I logout
    When I have logged in as "mkr@example.com"
    Then I hover on tab "Advice"
    And I follow "Articles"
    And I follow "Capital city"
    And I click "span.caret" within "div#page_canvas"
    And I follow "Report Content"
    Then I should see "Report Inappropriate Content"
    And I fill in "flag_reason" with " "
    Then I click report button
    And I should see the flash "Reason is required"
    And I fill in "flag_reason" with "Comment is inappropriate"
    Then I click report button
    Then I should see "Content has been flagged successfully"
    And I follow "Question & Answers"
    Then I follow "where in this world is coimbatore?"
    And I click "span.caret" within "div#page_canvas"
    And I follow "Report Content"
    Then I should see "Report Inappropriate Content"
    And I fill in "flag_reason" with " "
    Then I click report button
    And I should see the flash "Reason is required"
    And I fill in "flag_reason" with "Answer is inappropriate"
    Then I click report button
    Then I should see "Content has been flagged successfully"
    Then I logout
    When I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Flagged Content"
    Then I should see "Pending (2)"
    Then I should see "View content"
    And I click by xpath "//*[@id='page_canvas']/div/div/div[2]/table/tbody/tr[1]/td[4]/div/a"
    And I click "span.caret" within "div#page_canvas"
    Then I follow "Delete"
    And I confirm popup
    And I should not see "Sample answer"
    And I follow "Manage"
    And I follow "Flagged Content"
    And I follow "Resolved"
    And I should see "Deleted" in the xpath "//*[@id='page_canvas']/div/div/div[2]/table/tbody/tr[1]/td[4]"
    And I follow "Pending (1)"
    And I click by xpath "//*[@id='page_canvas']/div/div/div[2]/table/tbody/tr[1]/td[4]/div/a"
    And I click "span.caret" within "div#page_canvas"
    Then I follow "Resolve"
    And I follow "Ignore Flags"
    And I should see the flash "All the flags for the content are ignored and the content is allowed"
    And I follow "Manage"
    And I follow "Flagged Content"
    And I follow "Resolved"
    And I should see "Allowed" in the xpath "//*[@id='page_canvas']/div/div/div[2]/table/tbody/tr[2]/td[4]"
    And I follow "Pending (0)"
    And I logout


