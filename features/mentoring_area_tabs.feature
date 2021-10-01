@javascript
  Feature: Mentoring Connection Tabs

Background: Enable Mentoring Connections V2 Feature
  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user
  And I enable "mentoring_connection_meeting" feature as a super user
  Given the current program is "primary":"albers"
  And I login as super user
  And I follow "Manage"
  And I follow "Mentoring Connection Plan Templates"
  And I follow "Edit"
  And I follow "CONFIGURE FEATURES"
  Then the disabled "cjs_mentoring_model_users_manage_mm_tasks" checkbox_id should be checked
  And I check "cjs_mentoring_model_users_manage_mm_milestones"
  And I check "cjs_mentoring_model_users_manage_mm_goals"
  And I press "Save and Continue Later"
  And I follow "Manage"
  Then I follow "Mentoring Connections"
  And I follow "Create New Mentoring Connection"
  And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>"
  And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"
  And I click "#create_and_publish"
  Then I should see "name & example"
  And I logout
  And I stub chronus s3 utils

@javascript
  Scenario: Navigate through tabs in mentoring area

  And I have logged in as "robert@example.com"
  And I follow "name & example"
  And I should see the tab "Plan" selected in "mentoring_area_tabs"
  And I should see "Add Meeting" in the page actions bar
  And I follow "Add Meeting" in the page actions bar
  And I should see "Add New Meeting" in the page actions bar
  And I should see "Record Past Meeting" in the page actions bar
  And I should see "New Message" in the page actions bar
  Then I follow "Messages" within "div#mentoring_area_tabs"
  And I should see the tab "Messages" selected in "mentoring_area_tabs"
  And I should see "Add Meeting" in the page actions bar
  And I follow "Add Meeting" in the page actions bar
  And I should see "Add New Meeting" in the page actions bar
  And I should see "Record Past Meeting" in the page actions bar
  And I should see "New Message" in the page actions bar
  Then I follow "Meetings" within "div#mentoring_area_tabs"
  Then I follow "Upcoming Meetings" within "div#mentoring_area_tabs"
  And I should see the tab "Meetings" selected in "mentoring_area_tabs"
  And I should not see the tab "Upcoming" selected
  And I should see "Add Meeting" in the page actions bar
  And I follow "Add Meeting" in the page actions bar
  And I should see "Add New Meeting" in the page actions bar
  And I should see "Record Past Meeting" in the page actions bar
  And I should see "New Message" in the page actions bar
  Then I follow "Goals"
  And I should see the tab "Goals" selected in "mentoring_area_tabs"
  And I should see "Add Meeting" in the page actions bar
  And I follow "Add Meeting" in the page actions bar
  And I should see "Add New Meeting" in the page actions bar
  And I should see "Record Past Meeting" in the page actions bar
  And I should see "New Message" in the page actions bar
  And I should see "Add New Goal"
  Then I follow "Journal"
  And I should see the tab "Journal" selected in "mentoring_area_tabs"
  And I should see "Add Meeting" in the page actions bar
  And I follow "Add Meeting" in the page actions bar
  And I should see "Add New Meeting" in the page actions bar
  And I should see "Record Past Meeting" in the page actions bar
  And I should see "New Message" in the page actions bar
  And I should see "Add New Note"

@javascript
  Scenario: Messages in mentoring area
  And I have logged in as "robert@example.com"
  And I follow "name & example"
  And I should see "New Message" in the page actions bar
  And I follow "New Message"
  And I fill in "scrap[subject]" with "WestWorld"
  And I fill in "scrap[content]" with "Artificial Human Bots"
  And I press "Send Message"

  And I follow "New Message"
  And I fill in "scrap[subject]" with "Brooklyn Nine Nine"
  And I fill in "scrap[content]" with "Police sitcom"
  And I press "Send Message"
  Then I should see "Your message has been sent"
  And I logout

  And I have logged in as "rahim@example.com"
  And I follow "name & example"
  Then I should see "2" within ".cjs_unread_scraps_count"
  And I follow "Messages" within "div#mentoring_area_tabs"
  Then I should see "1 - 2 of 2"
  And I click unread scrap message with subject "WestWorld"
  Then I should see "1" within ".cjs_unread_scraps_count"
  Then I click ".scrap-actions"
  Then I click ".cjs_reply_link"

  And I reply "Awesome new series" to the scrap with subject "WestWorld"
  And I press "Reply"
  And I click unread scrap message with subject "Brooklyn Nine Nine"
  Then I should not see element ".cjs_unread_scraps_count"

  And I follow "New Message"
  And I fill in "scrap[subject]" with "Lucifer"
  And I fill in "scrap[content]" with "Vampire in San Francisco"
  And I press "Send Message"
  Then I should see "1 - 3 of 3"
  And I logout

  And I have logged in as "robert@example.com"
  And I follow "name & example"
  And I follow "Messages" within "div#mentoring_area_tabs"
  Then I should see "2" within ".cjs_unread_scraps_count"
  And I click unread scrap message with subject "Lucifer"
  Then I click ".scrap-actions"
  Then I click ".cjs_reply_link"
  And I reply "Yeah I know right" to the scrap with subject "Lucifer"
  And I press "Reply"
  Then I should see "1" within ".cjs_unread_scraps_count"
  And I click unread scrap message with subject "Lucifer"
  Then I should see "1" within ".cjs_unread_scraps_count"
  And I click unread scrap message with subject "WestWorld"
  Then I should not see element ".cjs_unread_scraps_count"
  And I logout

@javascript
  Scenario: User should be able to see tasks and add comments to a task in homepage connections widget
  When I have logged in as "robert@example.com"
  Then I should see "name & example"
  When I follow "name & example"
  Then I should see "Add Milestone"
  When I click ".cjs_add_new_custom_milestone"
  And I fill in "cjs_mentoring_model_milestone_title_" with "Hello Milestone Title Again"
  And I press "Save" within ".modal.in"
  And I wait for remote Modal to be hidden
  Then I should see "Hello Milestone Title Again"
  When I click ".cjs_milestone_description_handler"
  Then I should see "Add New Task"
  When I follow "Add New Task"
  Then I should see "Assign To"  
  And I fill in "mentoring_model_task_title" with "End User Task"
  And I press "Save Task"  
  Then I should see "End User Task"
  When I follow "Home"
  Then I should see "My Mentoring Connections (2)"
  And I should see "name & example" within "#cjs_connections_widget"
  And I should see "End User Task" within ".cjs-connection-plan-container"
  Then I click task title
  Then I wait for ajax to complete
  Then I should see "End User Task" within "#SidebarRightHomeContent"
  And I should see "Good unique name" within "#SidebarRightHomeContent"
  And I should see "Hello Milestone Title Again" within "#SidebarRightHomeContent"
  And I should see "No Comments Yet" within "#SidebarRightHomeContent"
  Then I click ".cjs_add_task_comment_sidepane"
  And I wait for "1" seconds
  And I should see "Notify others in the mentoring connection"
  Then I add a new comment "This is a task comment"
  Then I wait for ajax to complete
  Then I click ".cjs_comment_button"
  Then I should see "This is a task comment" within ".cjs-task-comments-container"
  Then I click ".delete-task"
  Then I should see "Are you sure you want to delete?"
  Then I confirm popup
  And I wait for "1" second
  And I should see "No Comments Yet" within "#SidebarRightHomeContent"
  And I logout