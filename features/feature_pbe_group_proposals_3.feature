Feature: Connection Proposals

Background: I go to the appropriate pbe track in org:primary
  Given the current program is "primary":"pbe"
  And pbe program has custom term

@javascript @reindex @cross-browser
Scenario: Admin browsing proposed and rejected projects
  #Then I reindex model "group"
  When I enable end users to propose groups
  When I have logged in as "ram@example.com"
  Then I create sample questions for pbe program
  Then I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I follow "Project Based Engagement"
  Then I follow "1"
  Then I follow "Proposed"
  And I should see "Proposed" selected under group tabs
  Then I hover over "my_programs_container"
  And I select "Project Based Engagement" from the program selector
  Then I follow "Manage"
  Then I should see "Projects"
  Then I follow "Projects"
  Then I should see "Projects" within "#page_heading"
  Then I follow "Proposed"    
  And I should see "Proposed" selected under group tabs
  And I should see "Proposed (4)"
  And I should see "Drafted" under group tabs
  And I should see "Ongoing" under group tabs
  And I should see "Closed" under group tabs
  And I should see "Rejected" under group tabs
  And I should see "Rejected (2)"
  And I should see "Available" under group tabs
  Then I should see "Strategy to finish Game of Thrones in a weekend :)"
  And I should see "Study the principles of Frank Underwood and share the learnings"
  And I should see "Learn high funda, over the top arguments from Suits"
  And I should see "Learn to decorate your Kill Room from Dexter"
  Then I should see "Proposed by"
  And I should see "Proposed date (recent first)" selected from "#sort_by"
  And I select "Proposed date (oldest first)" from "sort_by"
  Then I click "#list_view"
  And I should see "Edit Columns"
  Then I should see "Project Name"
  Then I should see "Mentors"
  Then I should see "Students"
  Then I should see "Notes"
  Then I should not see "Project Plan Templates" within "#filter_pane"
  Then I should see "Project Name" within "#filter_pane"
  Then I should see "Mentor" within "#filter_pane"
  Then I should see "Student" within "#filter_pane"
  Then I should see "Skyler or Claire ?" within "#filter_pane"
  And I click "#group_view_columns_update_link"
  And I should see "Select Fields to Display"
  And I select all group columns
  Then I should not see "Available since"
  Then I should not see "Pending Project requests"
  Then I should see "Proposed at"
  Then I should not see "Rejected at"
  Then I should not see "Rejected by"
  Then I should see "Proposed by"
  Then I follow "Learn high funda, over the top arguments from Suits"
  Then I should see "Administrator Actions"
  And I should see "Accept & Make Available"
  And I should see "Edit Project Profile"
  And I should see "Reject Project"
  Then I follow the back link
  Then I follow "Rejected (2)"
  And I click "#group_view_columns_update_link"
  And I should see "Select Fields to Display"
  And I select all group columns
  Then I should see "Project Name"
  Then I should see "Mentors"
  Then I should see "Students"
  Then I should see "Notes"
  Then I should see "Proposed at"
  Then I should see "Rejected at"
  Then I should see "Rejected by"
  Then I should see "Proposed by"
  Then I should see "Proposed by"
  Then I should see "Incorporate family values by watching Breaking Bad"
  And I should see "Misogyny, Drink, Smoke - Mad Men"
  Then I click "#detailed_view"
  Then I should see "Proposed on"
  Then I should see "Rejected on"
  Then I should see "Rejected by"
  Then I should see "Proposed by"
  Then I should see "Proposed by"
  And I should see "Rejected date (recent first)" selected from "#sort_by"
  And I select "Rejected date (oldest first)" from "sort_by"
  And I select "Proposed date (recent first)" from "sort_by"
  And I select "Proposed date (oldest first)" from "sort_by"
  Then I should not see "Project Plan Templates" within "#filter_pane"
  Then I should see "Project Name" within "#filter_pane"
  Then I should see "Mentor" within "#filter_pane"
  Then I should see "Student" within "#filter_pane"
  Then I should see "Skyler or Claire ?" within "#filter_pane"
  Then I follow "Incorporate family values by watching Breaking Bad"
  Then I should not see "Administrator Actions"

@javascript @matching_scenario @reindex
Scenario: End users editing projects before acceptance
  #Then I reindex model "group"
  When I enable end users to propose groups
  When I have logged in as "rahim@example.com"
  And I follow "My proposed projects"
  Then I should see "Strategy to finish Game of Thrones in a weekend :)"
  Then I follow "Strategy to finish Game of Thrones in a weekend :)"
  And I should not see "Edit Project Profile"
  When I create sample questions for pbe program
  And I follow "My proposed projects"
  Then I follow "Strategy to finish Game of Thrones in a weekend :)"
  Then I follow "Edit Project Profile"
  Then I fill in the last connection question with "Great Match"
  Then I press "Save"
  Then I logout
  When I have logged in as "rahim@example.com"
  And I follow "My proposed projects"
  Then I should see "Strategy to finish Game of Thrones in a weekend :)"
  Then I follow "Strategy to finish Game of Thrones in a weekend :)"
  Then I should see "Great Match"
  Then I follow "Edit Project Profile"
  Then I fill in the last connection question with "Not so great match"
  Then I press "Save"
  Then I logout
  When I have logged in as "rahim@example.com"
  And I follow "My proposed projects"
  Then I follow "Strategy to finish Game of Thrones in a weekend :)"
  Then I should see "Not so great match"

@javascript @matching_scenario @reindex @cross-browser
Scenario: Admins performing accept/reject actions
  #Then I reindex model "group"
  When I enable end users to propose groups
  When I have logged in as "ram@example.com"
  Then I follow "Manage"
  Then I should see "Projects"
  Then I follow "Projects"
  Then I follow "Proposed"
  Then I should see "Strategy to finish Game of Thrones in a weekend :)"
  Then I follow "Strategy to finish Game of Thrones in a weekend :)"
  Then I click on the link "accept_and_mark_available_" of "Strategy to finish Game of Thrones in a weekend :)"
  Then I select "Project Based Engagement Template (Default)" from "assign_mentoring_model"
  Then I fill in "bulk_actions_message" with "Please go ahead and start working on it!!"
  Then I should see "Owners of the project can manage users, tasks and the duration of the project. They can also start and end the project at any point of time"
  Then I should see "Assign student example as the owner"
  Then the "make_proposer_owner" checkbox_id should be checked
  Then I press "Accept & Make Available"
  Then I should see "Administrator Actions"
  Then I should see "Available"
  Then I should see "Publish Project"
  Then I should see "Edit Project Profile"
  Then I should see "Manage Members"
  Then I should see "Assign Project Plan Template"
  Then I logout
  When I have logged in as "rahim@example.com"
  When I open new mail
  Then I should see "Congratulations! We have accepted your proposed project" in the email text part body
  Then I should see "Please go ahead and start working on it!!" in the email text part body
  And I follow "Go to the project" in the email
  Then I should see "My Project"
  Then I should see "Manage Members"
  Then I click ".cjs_mentoring_connection_header"
  Then I logout
  When I have logged in as "ram@example.com"
  Then I follow "Manage"
  Then I should see "Projects"
  Then I follow "Projects"
  Then I follow "Proposed"
  Then I follow "Study the principles of Frank Underwood and share the learnings"
  Then I click on the link "reject_project_proposal_" of "Study the principles of Frank Underwood and share the learnings"
  Then I should see "Reject Project"
  Then I fill in "bulk_actions_message" with "Objective not clear, rework on it"
  Then I press "Reject Project"
  Then I should not see "Administrator Actions"
  Then I should not see "Publish Project"
  Then I should not see "Edit Project Profile"
  Then I should not see "Manage Members"
  Then I should not see "Assign Project Plan Template"
  Then I logout
  When I have logged in as "rahim@example.com"
  When I open new mail
  Then I should see "Hi student,Unfortunately, we have to reject your proposed project" in the email text part body
  Then I should see "we have to reject your proposed project, Study the principles of Frank Underwood and share the learnings" in the email text part body
  Then I should see "Objective not clear, rework on it" in the email text part body
  Then I logout

@javascript
Scenario: Users browsing manage mentoring connections in regular mentoring
  When I enable end users to propose groups
  When I have logged in as "ram@example.com"
  Then I hover over "my_programs_container"
  And I select "Albers Mentor Program" from the program selector
  Then I should not see "Proposed mentoring connections"
  Then I follow "Manage"
  Then I follow "Mentoring Connections"
  Then I should not see "Proposed"
  Then I should not see "Rejected"
  Then I should not see "Pending"
  Then I follow "mkr_student madankumarrajan"
  Then I should see "Mentoring Connections (1)"
  Then I follow "Mentoring Connections (1)"
  Then I should not see "Proposed"
  Then I should not see "Rejected"
  Then I should not see "Pending"
  Then I follow "Manage"
  Then I follow "Mentoring Connections"
  Then I follow "Good unique name"
  Then I should see "Mentoring Connections (1)"
  Then I follow "Mentoring Connections (1)"
  ## Here the show pages for code is different is for mentor/mentee.
  ## So, repeating the test cases for mentor as well :(
  Then I should not see "Proposed"
  Then I should not see "Rejected"
  Then I should not see "Pending"
  Then I logout