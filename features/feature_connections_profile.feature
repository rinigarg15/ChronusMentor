Feature: Mentor/Mentee visits the mentoring connection and edit the connection profile when the feature is enabled.

Background: Set the program to albers
   Given the current program is "primary":"albers"

@p2 @javascript @reindex @cross_browser
Scenario: Admin enabling the feature and mentor/mentee edits the connection profile
  When I have logged in as "mkr@example.com"
  #Then I scroll to the element "#SidebarRightContainer" below my visibility
  Then I follow "My Mentoring Connections" within "#SidebarRightContainer"
  And I follow "Visit Mentoring Connection"
  Then I should not see "View Mentoring Connection Profile" within "#quick_links"
  Then I should not see "Edit Mentoring Connection Profile" within "#quick_links"
  And I logout
  Then I have logged in as "ram@example.com"
  And I select "Primary Organization" from the program selector
  And I enable "connection_profile" feature as a super user
  Then I create connection profile questions
  And I logout
  When I have logged in as "ram@example.com"
  And I enable "connection_profile" feature as a super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Mentoring Connection Settings"
  Then I follow "Advanced Options"
  Then I click "#program_allow_users_to_mark_connection_public_true"
  And I press "Save"
  And I should see "Your changes have been saved"
  And I logout
  When I have logged in as "mkr@example.com"
  Then I follow "My Mentoring Connections" within "#SidebarRightContainer"
  And I follow "Visit Mentoring Connection"
  Then I should see "View Mentoring Connection Profile" within "#quick_links"
  Then I should see "Edit Mentoring Connection Profile" within "#quick_links"
  Then I follow "Edit Mentoring Connection Profile" within "#quick_links"
  And I hover over "group_profile_public" and should see "Making the mentoring connection profile public will enable all the users of the program to view the mentoring connection. Please note that the mentoring connection remains exclusive to the members of the mentoring connection."
  Then I fill in answers "'connection is doing great', 'connection is doing great multi line', 'connection is doing great multiple entries', 'c1', 'd1', ''" for the connection profile questions
  Then I view the connection profile
  And I logout

@javascript @cross_browser
Scenario: My Connection icon in mobile footer when no connections are there and no resources
  Given the current program is "primary":"albers"
  And I have logged in as "mentor_0@example.com"
  Then I change to mobile view
  And I click my connection mobile icon
  And I should see "You don't have any ongoing mentoring mentoring connections."
  And I logout

@javascript @cross_browser
Scenario: My Connection icon in mobile footer with user with no connection
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user
  Then I follow "Albers Mentor Program"
  And I follow "Resources"
  And I follow "Working with the Mentoring Connection Plan"
  And I follow "Edit resource"
  And I check "Mentor"
  And I press "Save"
  And I logout
  And I have logged in as "mentor_0@example.com"
  Then I change to mobile view
  And I click my connection mobile icon
  And I should see "You don't have any ongoing mentoring mentoring connections."
  And I should not see "Browse Mentors"
  And I should see "Browse Resources"
  And I follow "Browse Resources" within "div#remoteModal"
  And I should see "Resources"
  And I should see "Working with the Mentoring Connection Plan"
  And I logout

@javascript @cross_browser
Scenario: My Connection icon in mobile footer with user having one connection will be redirected to that connection
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user
  And I logout
  When I have logged in as "mkr@example.com"
  Then I follow "Albers Mentor Program"
  Then I change to mobile view
  And I click by xpath "//*[@id='page-wrapper']/nav[2]/div/div/div[1]/div[2]"
  And I should see "name & madankumarrajan"
  And I click ".cjs_unread_scraps_count"
  And I should see "name & madankumarrajan"
  And I should see "New Message"
  And I should see "From:"
  And I logout

@javascript @cross_browser
Scenario: My Connection icon in mobile footer with user having more than one connection
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user
  And I logout
  When I have logged in as "student_2@example.com"
  Then I follow "Albers Mentor Program"
  Then I change to mobile view
  And I click my connection mobile icon
  And I should see "My Mentoring Connections"
  And I should see "mentor & example"
  And I should see "user & example"
  And I should see "chronus & example"
  And I should see "Last Activity on:"
  And I logout

@javascript @cross_browser
Scenario: My Connection icon in mobile footer with user having more than one connection for project based
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user
  And I logout
  When I have logged in as "robert@example.com"
  Then I follow "Project Based Engagement"
  Then I change to mobile view
  And I click my connection mobile icon
  And I should not see "Propose New"
  And I should see "Discover New"
  And I should see "VIEW ALL"
  And I should see "project_group"
  And I should see "Learn high funda, over the top arguments from Suits"
  And I should see "Learn to decorate your Kill Room from Dexter"
  And I should see "Ongoing Mentoring Connections"
  And I should see "Proposed Mentoring Connections"
  And I logout

@javascript @cross_browser
Scenario: Tabs in Pending Groups
  Given the current program is "primary":"pbe"
  And I have logged in as "ram@example.com"
  And pbe program has custom term
  And I login as super user
  Then I create messages enabled project template with task templates
  And I create messages enabled project template without task templates
  And I create both disabled project template without task templates
  And I create both disabled project template with task templates
  Then I follow "Manage"
  And I follow "Projects"
  And I follow "Available (5)"
  When I follow "project_a"
  Then I should see "Discussion Board"
  And I should see "There are no conversations"
  And I should not see "Start a conversation"
  And I should not see "Join Project"
  And I should not see the mentoring area tab "Plan"
  And I should not see the mentoring area tab "Information"
  Then I follow "Assign Project Plan Template"
  When I select "Messages enabled without task templates" from "assign_mentoring_model"
  And I press "Assign"
  Then I should not see "Discussion Board"
  And I should see "Messages"
  And I should not see the mentoring area tab "Plan"
  And I should not see the mentoring area tab "Information"
  Then I follow "Assign Project Plan Template"
  When I select "Messages enabled with task templates" from "assign_mentoring_model"
  And I press "Assign"
  And I should see the mentoring area tab "Plan" selected
  And I should see the mentoring area tab "Messages"
  And I should not see the mentoring area tab "Information"
  And I should not see the mentoring area tab "Discussion Forum"
  Then I follow "Assign Project Plan Template"
  When I select "Both disabled with task templates" from "assign_mentoring_model"
  And I press "Assign"
  Then I should not see the mentoring area tab "Messages"
  And I should not see the mentoring area tab "Discussion Forum"
  Then I follow "Assign Project Plan Template"
  When I select "Both disabled without task templates" from "assign_mentoring_model"
  And I press "Assign"
  And I should not see the mentoring area tab "Plan"
  And I should not see the mentoring area tab "Information"
  And I should not see the mentoring area tab "Messages"
  And I should not see the mentoring area tab "Discussion Forum"
  
  And I follow "Manage"
  Then I should see "Manage" within "div#main_title_content"
  When I follow "Customize Projects Profile Fields"
  Then I should see "Add New Question"
  And I follow "Add New Question"
  And I fill in "survey_question_question_text_new" with "Question1"
  And I fill in "help_text_new" with "Question1 Description"
  When I press "Add"
  Then I should see "Question1"
  And I follow "Manage"
  And I follow "Projects"
  And I follow "Available (5)"
  When I follow "project_a"
  Then I follow "Assign Project Plan Template"
  And I select "Messages enabled with task templates" from "assign_mentoring_model" within "div#remoteModal"
  And I press "Assign"
  Then I should see the mentoring area tab "Information" selected
  And I should see the mentoring area tab "Plan"
  And I should see the mentoring area tab "Messages"
  And I should see "Edit Project Profile"
  And I should not see "New Message"
  Then I logout
  And I have logged in as "student_0@example.com"
  When I follow "project_a"
  Then I should see the mentoring area tab "Information" selected
  And I should see the mentoring area tab "Plan"
  And I should see the mentoring area tab "Messages"
  And I should not see "Edit Project Profile"
  When I follow "Messages" within "div#mentoring_area_tabs"
  And I follow "New Message"
  And I fill in "scrap[subject]" with "First Message"
  And I fill in "scrap[content]" with "How are you?"
  And I press "Send Message"
  And I wait for ajax to complete
  Then I should see "First Message"
  And I logout
  And I have logged in as "student_1@example.com"
  And I follow "Discover"
  When I follow "project_a"
  And I should see the mentoring area tab "Information" selected
  And I should see the mentoring area tab "Plan"
  And I should not see the mentoring area tab "Messages"
  And I should not see "New Message"
  And I should see "Join Project"
  Then I logout
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Projects"
  And I follow "Available (5)"
  And I follow "project_a"
  And I follow "Manage Members"
  And I "Remove" member with email "student_0@example.com" in "pbe" as "student"
  And I press "Remove member"
  And I "Remove" member with email "student_5@example.com" in "pbe" as "student"
  And I press "Remove member"
  And I press "Save"
  And I logout
  Then I have logged in as "student_0@example.com"
  When I follow "project_a"
  And I should see the mentoring area tab "Information" selected
  And I should see the mentoring area tab "Plan"
  And I should not see the mentoring area tab "Messages"
  Then I should not see "New Message"
  And I should see "Join Project"
  Then I logout