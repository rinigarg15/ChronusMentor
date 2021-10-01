Feature: Article Customize Terminology
  Mentee, mentor, admin must see the names of the article as per the customized terminology

@javascript
Scenario: Create article in the applied custom terminology
  Given the current program is "primary":"albers"
  And "Article" "pluralized_term" is called as "Resources" in "primary":"albers"
  #Mentor Logs in
  And I have logged in as "robert@example.com"
  Then I follow "Advice"
  Then I follow "Resources"
  Then I logout
  #Mentee Logs in
  Given the current program is "primary":"albers"
  And I have logged in as "rahim@example.com"
  Then I follow "Advice"
  Then I follow "Resources"
  Then I logout
  #Admin Logs in
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I follow "Advice"
  Then I follow "Resources"
  Then I should see "Resources" within "div#title_box"
  Then I logout

@javascript
Scenario: Check custom terminology for Mentor
  Given the current program is "primary":"albers"
  And "mentor" role "pluralized_term" is called as "Experts" in "primary":"albers"
  #Mentor Logs in
  And I have logged in as "robert@example.com"
  Then I follow "Experts" within "nav#sidebarLeft"
  Then I logout
  #Mentee Logs in
  Given the current program is "primary":"albers"
  And I have logged in as "rahim@example.com"
  Then I follow "Experts" within "nav#sidebarLeft"
  Then I logout
  #Admin Logs in
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I follow "Experts" within "nav#sidebarLeft"
  Then I should see "Experts" within "div#title_box"
  Then I logout

@javascript
Scenario: Check custom terminology for Mentee
  Given the current program is "primary":"albers"
  And "student" role "pluralized_term" is called as "Experts" in "primary":"albers"
  #Mentor Logs in
  And I have logged in as "robert@example.com"
  Then I follow "Experts" within "nav#sidebarLeft"
  Then I logout
  #Mentee Logs in
  Given the current program is "primary":"albers"
  And I have logged in as "rahim@example.com"
  Then I follow "Experts" within "nav#sidebarLeft"
  Then I logout
  #Admin Logs in
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I follow "Experts" within "nav#sidebarLeft"
  Then I should see "Experts" within "div#title_box"
  Then I logout

@javascript @cross_browser
Scenario: Update all custome terms
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  Then I login as super user
  And I follow "Manage"
  Then I follow "Program Settings"
  And I follow "Terminology"
  Then I fill the custom terms in "primary"
  Then I should see "The new terminology has been saved"
  Given the current program is "primary":"albers"
  And I follow "Manage"
  Then I follow "Track Settings"
  Then I follow "Terminology"
  Then I fill the custom program terms in "primary":"albers"
  Then I should see "The new terminology has been saved"
  Then I logout
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  Then I follow "Advice"
  And I follow "Snippets"
  Then I should see "Snippets" within "div#title_box"
  Then I follow "Manage"
  Then I should see "Helpdesks"
  And I should see "Track Settings"
  Given the current program is "primary":""
  Then I follow "Manage"
  And I should see "Admins"
  Then I logout

@javascript
Scenario: Terminology visible only for Super Login - Org Level
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  Then I follow "Program Settings"
  Then I should not see "Terminology"
  Then I login as super user
  And I follow "Manage"
  Then I follow "Program Settings"
  Then I should see "Terminology"
  Then I logout

@javascript
Scenario: Terminology visible only for Super Login - Program Level
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  Then I hover over "My Programs"
  And I follow "Albers Mentor Program"
  And I follow "Manage"
  Then I follow "Program Settings"
  Then I should not see "Terminology"
  Then I login as super user
  Then I hover over "My Programs"
  And I follow "Albers Mentor Program"
  And I follow "Manage"
  Then I follow "Program Settings"
  Then I should see "Terminology"
  Then I logout

@javascript
Scenario: Terminology update Org Level
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  Then I login as super user
  And I follow "Manage"
  Then I follow "Program Settings"
  Then I follow "Terminology"
  Then I fill the custom terms in "primary"
  Then I should see "The new terminology has been saved"
  Then I logout
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  Then I follow "Manage"
  And I should see "Admins" within "div#manage"
  Then I logout

@javascript
Scenario: Terminology update Program Level
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I login as super user
  And I follow "Manage"
  Then I follow "Program Settings"
  Then I follow "Terminology"
  Then I fill the custom program terms in "primary":"albers"
  Then I should see "The new terminology has been saved"
  Then I logout
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I follow "Advice"
  And I follow "Snippets"
  Then I should see "Snippets" within "div#title_box"
  Then I follow "Manage"
  Then I should see "Helpdesks" within "div#manage"
  And I should see "Links" within "div#manage"
  And I should see "Trainers" within "nav#sidebarLeft"
  And I should see "Trainee" within "nav#sidebarLeft"
  Then I logout

@javascript
Scenario: Terminology update Standalone Level
  Given the current program is "foster":"main"
  And I have logged in as "fosteradmin@example.com"
  And I login as super user
  And I follow "Manage"
  Then I follow "Program Settings"
  Then I follow "Terminology"
  Then I fill the standalone custom terms in "foster"
  Then I should see "The new terminology has been saved"
  Then I logout
  Given the current program is "foster":"main"
  And I have logged in as "fosteradmin@example.com"
  Then I follow "Advice"
  And I follow "Snippets"
  Then I should see "Snippets" within "div#title_box"
  Then I follow "Manage"
  Then I should see "Helpdesks" within "div#manage"
  And I should see "Track Settings" within "div#manage"
  And I should see "Admin Inbox" within "div#manage"
  And I should see "Links" within "div#manage"
  And I should see "Trainers" within "nav#sidebarLeft"
  And I should see "Trainees" within "nav#sidebarLeft"
  Then I logout