Feature: Allow multiple connections between student-mentor pair in group-mentoring admin match programs
In order to verify the display of warning messages when creating multiple connections between student-mentor pair
As an admin
I should see the warning messages when drafting/publishing connection(s) from the following pages: Connections Listing, Find a Mentor, Bulk Match

Background:
  Given the current program is "primary":"albers"
  Given I have enabled "bulk_matching" feature
  Given there is one to many in "primary":"albers"
  Given "primary":"albers" is admin-matching only program
  Given I change maximum connections limit of mentor with email "robert@example.com" in program "primary":"albers" to "10"

@javascript
Scenario: Admin create multiple connections between same student-mentor pair
  When I have logged in as "ram@example.com"
  When I navigate to "Program Settings" from manage page
  And I follow "Connection Settings"
  And element with id "#program_allow_one_to_many_mentoring_false" should not be disabled
  And element with id "#program_allow_one_to_many_mentoring_true" should not be disabled
  Then I should see the radio button "program_allow_one_to_many_mentoring_true" selected
  Then I should not see "To enable this setting, please ensure that only one active mentoring connection exists between all student - mentor pairs."
  And I should not see "Please click here to view the student - mentor pairs with multiple mentoring connections."
  And I follow "Students"
  And I quick search for "mkr_student madankumarrajan"
  And I follow "mkr_student madankumarrajan"
  And I follow "Find a Mentor"
  And I follow "Reset all"
  And I quick search for "Good unique name"
  And I follow "Connect" pertaining to the mentor "Good unique name" in "Find a Mentor" page
  And I follow "Draft a mentoring connection"
  Then I should see "Good unique name is a mentor to mkr_student madankumarrajan in name & madankumarrajan."
  When I press "Save as Draft"
  Then I should see "The mentoring connection has been saved as a draft. Click here to view the draft."

  Given I update the last connection's name to "Connection for Groups Alert - I"
  When I navigate to "Bulk Match" from manage page
  And I choose mentee view as "All Mentees" and mentor view as "All Mentors"
  And I press "Next"
  And I follow "Settings"
  And I choose "bulk_match_show_drafted_true"
  And I choose "bulk_match_show_published_true"
  And I press "Apply"
  And I select "Good unique name" as mentor for "mkr_student madankumarrajan" in "Bulk Match" page
  Then I should see available slots as "1" for the mentor "Good unique name" in "Bulk Match" page
  And I should see ongoing connections count as "1" for the mentor "Good unique name" in "Bulk Match" page
  And I should see "Good unique name" as "drafted" mentors for "mkr_student madankumarrajan" in "Bulk Match" page
  And I should see "Good unique name" as "connected" mentors for "mkr_student madankumarrajan" in "Bulk Match" page
  When I follow "Draft" pertaining to the student "mkr_student madankumarrajan" in "Bulk Match" page
  Then I should see "Add notes & Draft"
  And I should see "Good unique name is a mentor to mkr_student madankumarrajan in name & madankumarrajan."
  And I should see "Good unique name is drafted as a mentor to mkr_student madankumarrajan in Connection for Groups Alert - I."
  When I follow "Cancel"
  Then I wait for ajax to complete
  Then I set the focus to the main window
  And I follow "Settings"
  And I choose "bulk_match_request_notes_false"
  And I press "Apply"
  And I select "Good unique name" as mentor for "mkr_student madankumarrajan" in "Bulk Match" page
  And I follow "Draft" pertaining to the student "mkr_student madankumarrajan" in "Bulk Match" page
  Then I should not see "Add notes & Draft"
  And I should see "Good unique name is a mentor to mkr_student madankumarrajan in name & madankumarrajan."
  And I should see "Good unique name is drafted as a mentor to mkr_student madankumarrajan in Connection for Groups Alert - I."
  When I follow "Cancel"
  And I select the student "mkr_student madankumarrajan" in "Bulk Match" page
  And I follow "Bulk Actions"
  And I follow "Create Drafted Mentoring Connections"
  Then I should see "The selected users are already connected with each other in the following mentoring connections."
  And I should see "Good unique name is a mentor to mkr_student madankumarrajan in name & madankumarrajan."
  And I should see "Good unique name is drafted as a mentor to mkr_student madankumarrajan in Connection for Groups Alert - I."
  When I press "Draft"
  Then Confirmation dialog should contain "Mentoring Connections drafted successfully."
  And I confirm popup

  Given I add "mentor_4@example.com,student_5@example.com" to the connection "Connection for Groups Alert - I"
  When I follow "Bulk Actions"
  And I follow "Publish Drafted Mentoring Connections"
  Then I should see "The following set of users in the selected mentoring connections is already actively connected."
  And I should see "Good unique name is a mentor to mkr_student madankumarrajan in name & madankumarrajan."
  And I should not see "Good unique name is drafted as a mentor to mkr_student madankumarrajan in Connection for Groups Alert - I."
  And I should see "The following users were added to the drafted mentoring connection outside 'Bulk Match' tool."
  And I should see "student_f example and mentor_e chronus were added to the mentoring connection between mkr_student madankumarrajan and Good unique name."
  When I follow "Cancel"
  Then I wait for ajax to complete
  And I follow "Publish" pertaining to the student "mkr_student madankumarrajan" in "Bulk Match" page
  Then I should see "Good unique name is a mentor to mkr_student madankumarrajan in name & madankumarrajan."
  And I should not see "Good unique name is drafted as a mentor to mkr_student madankumarrajan in Connection for Groups Alert - I."
  And I should see "student_f example and mentor_e chronus were added to the mentoring connection between mkr_student madankumarrajan and Good unique name."
  When I follow "Cancel"
  Then I should see available slots as "1" for the mentor "Good unique name" in "Bulk Match" page
  And I should see ongoing connections count as "1" for the mentor "Good unique name" in "Bulk Match" page
  And I should see "Good unique name" as "drafted" mentors for "mkr_student madankumarrajan" in "Bulk Match" page
  And I should see "Good unique name" as "connected" mentors for "mkr_student madankumarrajan" in "Bulk Match" page

  When I navigate to "Mentoring Connections" from manage page
  And I follow "Create New Mentoring Connection"
  And I fill in "group_name" with "Connection for Groups Alert - II"
  And I add the following "mentors" with names "Good unique name,Mentor Studenter"
  And I add the following "mentees" with names "mkr_student madankumarrajan"
  And I press "Create and Publish"
  Then I should see "The selected users are already connected with each other in the following mentoring connections."
  And I should see "Good unique name is a mentor to mkr_student madankumarrajan in name & madankumarrajan."
  And I should see "Good unique name is drafted as a mentor to mkr_student madankumarrajan in Connection for Groups Alert - I."
  When I follow "No, Go Back"
  Then I should see "The selected users are already connected with each other in the following mentoring connections."
  And I should see "Good unique name is a mentor to mkr_student madankumarrajan in name & madankumarrajan."
  And I should see "Good unique name is drafted as a mentor to mkr_student madankumarrajan in Connection for Groups Alert - I."
  When I remove "Good unique name" from the selected list
  And I press "Create and Publish"
  Then I should see "Connection for Groups Alert - II"

  When I follow "Connection for Groups Alert - II"
  And I follow "Manage Members"
  Then I should not see "The selected users are already connected with each other in the following mentoring connections."
  When I follow "Add Mentor"
  And I fill in "add_member_mentor" with "Good unique name <robert@example.com>"
  And I press "Add"
  Then I should see "The selected users are already connected with each other in the following mentoring connections."
  And I should see "Good unique name is a mentor to mkr_student madankumarrajan in name & madankumarrajan."
  And I should see "Good unique name is drafted as a mentor to mkr_student madankumarrajan in Connection for Groups Alert - I."
  When I click on remove member "mkr_student madankumarrajan"
  And I press "Remove member"
  Then I should not see "The selected users are already connected with each other in the following mentoring connections."
  When I follow "Add Student"
  And I fill in "add_member_student" with "student example <rahim@example.com>"
  And I press "Add"
  Then I should not see "The selected users are already connected with each other in the following mentoring connections."
  When I follow "Add Student"
  And I fill in "add_member_student" with "mkr_student madankumarrajan <mkr@example.com>"
  And I press "Add"
  Then I should see "The selected users are already connected with each other in the following mentoring connections."
  And I should see "Good unique name is a mentor to mkr_student madankumarrajan in name & madankumarrajan."
  And I should see "Good unique name is drafted as a mentor to mkr_student madankumarrajan in Connection for Groups Alert - I."
  When I click on replace member "mkr_student madankumarrajan"
  And I fill in "student_c example" as replaced user
  And I press "Replace member"
  Then I should not see "The selected users are already connected with each other in the following mentoring connections."
  When I press "Save"
  Then I should see "The mentoring connection has been updated"

  When I navigate to "Mentoring Connections" from manage page
  Then I should see "Ongoing" selected under group tabs
  When I follow "Create New Mentoring Connection"
  And I fill in "group_name" with "Connection for Groups Alert - III"
  And I add the following "mentors" with names "Good unique name"
  And I add the following "mentees" with names "mkr_student madankumarrajan,student_c example"
  And I press "Save as draft"
  Then I should see "Good unique name is a mentor to mkr_student madankumarrajan in name & madankumarrajan."
  And I should see "Good unique name is a mentor to student_c example in Connection for Groups Alert - II."
  And I should see "Good unique name is drafted as a mentor to mkr_student madankumarrajan in Connection for Groups Alert - I."
  And I verify the link to the drafted connection "Connection for Groups Alert - I" in groups alert
  And I follow "Yes"
  Then I should see "Connection for Groups Alert - III"
  When I follow "Create New Mentoring Connection"
  And I fill in "group_name" with "Connection for Groups Alert - IV"
  And I add the following "mentors" with names "Good unique name,mentor_c chronus"
  And I add the following "mentees" with names "mkr_student madankumarrajan,student_c example,student example"
  And I press "Save as draft"
  Then I should see "Good unique name is a mentor to mkr_student madankumarrajan in name & madankumarrajan."
  And I should see "Good unique name is a mentor to student example and student_c example in Connection for Groups Alert - II."
  And I should see "Good unique name is drafted as a mentor to mkr_student madankumarrajan in Connection for Groups Alert - I."
  And I should see "Good unique name is drafted as a mentor to mkr_student madankumarrajan and student_c example in Connection for Groups Alert - III."
  When I follow "Yes"
  Then I should see "Connection for Groups Alert - IV"
  When I follow publish for the connection "Connection for Groups Alert - IV" from connections listing
  Then I should see "The following sets of users in the selected mentoring connection are already actively connected."
  And I should see "Good unique name is a mentor to mkr_student madankumarrajan in name & madankumarrajan."
  And I should see "Good unique name is a mentor to student example and student_c example in Connection for Groups Alert - II."
  And I follow "Cancel"
  When I select the connection "Connection for Groups Alert - IV" in connections listing
  And I select the connection "Connection for Groups Alert - III" in connections listing
  And I follow "Actions"
  And I follow "Publish Mentoring Connection"
  Then I should see "The following sets of users in the selected mentoring connections are already actively connected."
  And I should see "Good unique name is a mentor to mkr_student madankumarrajan in name & madankumarrajan."
  And I should see "Good unique name is a mentor to student_c example in Connection for Groups Alert - II."
  And I should see "Good unique name is a mentor to student example and student_c example in Connection for Groups Alert - II."
  And I should see "The following set of users in the selected mentoring connections is part of multiple drafted mentoring connections."
  And I should see "Good unique name is drafted as a mentor to mkr_student madankumarrajan and student_c example in Connection for Groups Alert - III and Connection for Groups Alert - IV."
  When I press "Publish"
  And I should see "Mentoring Connections published successfully"

  When I navigate to "Program Settings" from manage page
  And I follow "Matching Settings"
  Then I should see "To enable this setting, please ensure that only one active mentoring connection exists between all student - mentor pairs."
  And I should see "Please click here to view the student - mentor pairs with multiple mentoring connections."
  And I should see mentee requests mentor option disabled
  And I should see mentor offers mentee option disabled
  When I follow "click here"
  Then I should see "mkr_student madankumarrajan and Good unique name are actively connected in name & madankumarrajan, Connection for Groups Alert - III and Connection for Groups Alert - IV."
  And I should see "student_c example and Good unique name are actively connected in Connection for Groups Alert - II, Connection for Groups Alert - III and Connection for Groups Alert - IV."
  And I should see "student example and Good unique name are actively connected in Connection for Groups Alert - II and Connection for Groups Alert - IV."

  When I navigate to "Program Settings" from manage page
  And I follow "Connection Settings"
  And element with id "#program_allow_one_to_many_mentoring_true" should be disabled
  And element with id "#program_allow_one_to_many_mentoring_false" should be disabled
  Then I should see the radio button "program_allow_one_to_many_mentoring_true" selected
  Then I should see "To enable this setting, please ensure that only one active mentoring connection exists between all student - mentor pairs."
  And I should see "Please click here to view the student - mentor pairs with multiple mentoring connections."
  And I logout