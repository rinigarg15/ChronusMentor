Feature: Connection Proposals

Background: I go to the appropriate pbe track in org:primary
  Given the current program is "primary":"pbe"
  And pbe program has custom term

@javascript @matching_scenario
Scenario: Mentee proposes a group and Admin Accepts making him Owner
  When I enable end users to propose groups
  When I have logged in as "rahim@example.com"
  Then I hover over "my_programs_container"
  And I select "Project Based Engagement" from the program selector    
  Then I should see "Propose a new project" within "ul#cjs_mentoring_connection_header"
  Then I follow "Propose a new project"
  Then the help text for "student" role in "primary":"pbe" should be visible
  Then I fill in "similar_connection_name" with "Binge watch House of Cards"
  And I fill in "student" field with prefix "max_" of "primary":"pbe" with "3"
  Then I press "Save"
  Then I should see the flash "The project proposal was successful. You will be notified once the administrator accepts your project."
  Then I close all modals
  And I follow "My proposed projects"
  Then I should see "Projects" within "#page_heading"
  And I should see "Proposed (3)"
  Then I click on profile picture and click "Sign out"
  When I have logged in as "ram@example.com"
  When I open new mail
  Then I should see "Hi Freakin,  student example" in the email text part body
  Then I should see "has proposed a new project called Binge watch House of Cards" in the email text part body
  And I follow "View project" in the email
  Then I should see "Binge watch House of Cards"
  Then I follow "Accept & Make Available"
  Then I select "Project Based Engagement Template (Default)" from "assign_mentoring_model"
  Then I fill in "bulk_actions_message" with "Please go ahead and start working on it!!"
  Then I should not see "Assign student example as the owner"
  Then I press "Accept & Make Available"
  Then I logout
  When I have logged in as "rahim@example.com"
  When I open new mail
  Then I should see "Congratulations! We have accepted your proposed project" in the email text part body
  Then I should see "Please go ahead and start working on it!!" in the email text part body
  And I follow "Go to the project" in the email
  Then I should see "My Project"
  Then I should see "Manage Members"
  Then I logout

@javascript @matching_scenario
Scenario: Mentee proposes a group and Admin Accepts but does not make him Owner
  When I enable end users to propose groups
  When I have logged in as "rahim@example.com"
  Then I hover over "my_programs_container"
  And I select "Project Based Engagement" from the program selector    
  Then I should see "Propose a new project" within "ul#cjs_mentoring_connection_header"
  Then I follow "Propose a new project"
  Then the help text for "student" role in "primary":"pbe" should be visible
  Then I fill in "similar_connection_name" with "Binge watch House of Cards"
  And I fill in "student" field with prefix "max_" of "primary":"pbe" with "3"
  And I fill in "mentor" field with prefix "max_" of "primary":"pbe" with "1"
  And I fill in "teacher" field with prefix "max_" of "primary":"pbe" with "1"
  Then I press "Save"
  Then I should see the flash "The project proposal was successful. You will be notified once the administrator accepts your project."
  Then I close all modals
  And I follow "My proposed projects"
  Then I should see "Projects" within "#page_heading"
  And I should see "Proposed (3)"
  Then I click on profile picture and click "Sign out"
  When I have logged in as "ram@example.com"
  When I open new mail
  Then I should see "Hi Freakin,  student example" in the email text part body
  Then I should see "has proposed a new project called Binge watch House of Cards" in the email text part body
  And I follow "View project" in the email
  Then I should see "Binge watch House of Cards"
  Then I follow "Accept & Make Available"
  Then I select "Project Based Engagement Template (Default)" from "assign_mentoring_model"
  Then I fill in "bulk_actions_message" with "Please go ahead and start working on it!!"
  Then I should not see "Assign student example as the owner"
  Then I press "Accept & Make Available"
  Then I logout
  When I have logged in as "rahim@example.com"
  When I open new mail
  Then I should see "Congratulations! We have accepted your proposed project" in the email text part body
  Then I should see "Please go ahead and start working on it!!" in the email text part body
  And I follow "Go to the project" in the email
  Then I should see "My Project"
  Then I should see "Manage Members"
  Then I logout
  
@javascript @matching_scenario @cross-browser
Scenario: End user who is both a mentor and mentee proposes a group
  When I enable end users to propose groups
  When I have logged in as "ram@example.com"
  Then I navigate to "rahim@example.com" profile in "pbe"
  Then I click "#change_roles_link"
  Then I check "role_names_mentor"
  Then I press "Submit"
  Then I logout
  When I have logged in as "rahim@example.com"
  Then I hover over "my_programs_container"
  And I select "Project Based Engagement" from the program selector
  Then I should see "Propose a new project" within "ul#cjs_mentoring_connection_header"
  Then I follow "Propose a new project"
  Then the help text for "student" role in "primary":"pbe" should be visible
  Then I should see "Select your role in this project"
  And I select "Mentor" from "group_join_as_role_id"
  Then the help text for "student" role in "primary":"pbe" should not be visible
  Then I fill in "similar_connection_name" with "Understand the character traits of Debra Morgan"
  Then I press "Save"
  Then I should see the flash "The project proposal was successful. You will be notified once the administrator accepts your project."
  Then I logout
  When I have logged in as "ram@example.com"
  When I open new mail
  Then I should see "Hi Freakin,student example" in the email text part body
  Then I should see "has proposed a new project called Understand the character traits of Debra Morgan" in the email text part body
  And I follow "View project" in the email
  Then I should see "Understand the character traits of Debra Morgan"
  Then I should see "Administrator Actions"
  And I should see "Accept & Make Available"
  And I should see "Edit Project Profile"
  And I should see "Reject Project"
  Then I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  Then I uncheck "mentor" of "primary":"pbe" having idprefix as "program_send_group_proposals_"
  Then I press "Save"
  Then I logout
  When I have logged in as "rahim@example.com"
  Then I should see "Propose a new project" within "ul#cjs_mentoring_connection_header"
  Then I follow "Propose a new project"
  Then I logout

@javascript @reindex @cross-browser
Scenario: Student browsing proposed and rejected projects
  #Then I reindex model "group"
  When I enable end users to propose groups
  When I create sample questions for pbe program
  When I have logged in as "rahim@example.com"
  Then I hover over "my_programs_container"
  And I select "Project Based Engagement" from the program selector
  And I follow "My proposed projects"
  Then I should see "Strategy to finish Game of Thrones in a weekend :)"
  And I should see "Study the principles of Frank Underwood and share the learnings"
  And I should not see "Learn high funda, over the top arguments from Suits"
  And I should not see "Learn to decorate your Kill Room from Dexter"
  Then I follow "Study the principles of Frank Underwood and share the learnings"
  Then I should not see "Administrator Actions"    
  Then I should see "Quick links"
  Then I should see "Edit Project Profile"
  Then I should see "View Project Profile"
  And I follow "My proposed projects"
  Then I should not see "Proposed by"
  And I should see "Proposed date (recent first)" selected from "#sort_by"
  And I select "Proposed date (oldest first)" from "sort_by"
  Then I follow "Rejected (1)"
  And I should see "Incorporate family values by watching Breaking Bad"
  And I should not see "Misogyny, Drink, Smoke - Mad Men"
  And I should see "Rejected date (recent first)" selected from "#sort_by"
  And I select "Rejected date (oldest first)" from "sort_by"
  And I select "Proposed date (oldest first)" from "sort_by"
  And I select "Proposed date (recent first)" from "sort_by"
  And I should see "Closed" under group tabs
  And I should see "Rejected" under group tabs
  And I should see "Open" under group tabs
  And I should see "Proposed" under group tabs
  Then I should not see "Proposed by"
  Then I follow "Incorporate family values by watching Breaking Bad"
  Then I should not see "Administrator Actions"
  Then I should not see "Edit Project Profile"
  Then I should not see "View Project Profile"
  Then I logout