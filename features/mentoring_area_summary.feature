Feature: Mentoring Connection Summary
  In order to understand what the mentoring connection is all about
  Connected members should be able to see who the other members are

Background: Enable Mentoring Connections V2 Feature
  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  Then I enable admin audit logs
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user
  And I logout
  And I stub chronus s3 utils

@javascript
Scenario: One to One - Mentee and Mentor should see only other's information
    Given the current program is "primary":"albers"
    Given I have logged in as "mkr@example.com"
    And I follow "name & madankumarrajan"
    Then I follow "Messages" within "div#mentoring_area_tabs"
    Then I should see "New Message"
    Then I should see "mkr_student madankumarrajan" in the "student" listing of mentoring area members pane in "primary":"albers"
    Then I logout
    Given I have logged in as "robert@example.com"
    And I follow "name & madankumarrajan"
    Then I follow "Messages" within "div#mentoring_area_tabs"
    Then I should see "New Message"
    Then I should see "Good unique name" in the "mentor" listing of mentoring area members pane in "primary":"albers"

@javascript @cross-browser
Scenario: One to Many - Mentor and Students view the summary pane
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    Then I enable admin audit logs
    Then I logout
    Given there is a mentoring connection between the mentor "mentor_7@example.com" and the students "student_7@example.com,student_8@example.com,student_9@example.com" in "primary":"albers"
    Given the current program is "primary":"albers"
    When I have logged in as "mentor_7@example.com"
    Then I follow "chronus, example, example, & example"
    Then I should see "Edit Mentoring Connection Name and Picture"
    Then I follow "Messages" within "div#mentoring_area_tabs"
    Then I should see "New Message"
    And I expand the "student" listing of mentoring area members pane
    Then I should see "student_h example" in the "student" listing of mentoring area members pane in "primary":"albers"
    Then I should see "student_i example" in the "student" listing of mentoring area members pane in "primary":"albers"
    Then I should see "student_j example" in the "student" listing of mentoring area members pane in "primary":"albers"

    # One of the students views the page now.
    Then I logout
    Given I have logged in as "student_8@example.com"
    Then I hover over "my_programs_container"
    And I select "Albers Mentor Program" from the program selector
    Then I follow "chronus, example, example, & example"
    Then I follow "Messages" within "div#mentoring_area_tabs"
    Then I should see "New Message"
    And I expand the "mentor" listing of mentoring area members pane
    Then I should see "mentor_h chronus" in the "mentor" listing of mentoring area members pane in "primary":"albers"
    And I expand the "student" listing of mentoring area members pane
    Then I should see "student_i example" in the "student" listing of mentoring area members pane in "primary":"albers"
    Then I should see "student_j example" in the "student" listing of mentoring area members pane in "primary":"albers"
    And I follow "Journal"

    # Now, the admin views the page
    Then I logout
    Given I have logged in as "ram@example.com"
    And I visit the mentoring connection between "mentor_7@example.com" and "student_7@example.com,student_8@example.com,student_9@example.com" with the reason "some reason"
    Then I should not see "New Message"
    And I expand the "student" listing of mentoring area members pane
    Then I should see "student_h example" in the "student" listing of mentoring area members pane in "primary":"albers"
    And I expand the "mentor" listing of mentoring area members pane
    Then I should see "mentor_h chronus" in the "mentor" listing of mentoring area members pane in "primary":"albers"
    And I should not see "Private Journal"
    And I should see "Goals"

@javascript
Scenario: Do not show any provide feeedback when the feature is disabled in the program
    Given the current program is "primary":"albers"
    When I have logged in as "mkr@example.com"
    And I follow "name & madankumarrajan"

    Then I should see "Provide Feedback"
    And I logout

    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Connection Settings"
    Then I should not see "Allow feedback for Mentoring Connection"
    Then I login as super user
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Connection Settings"
    And I follow "Advanced Options"
    Then I should see "Allow feedback for Mentoring Connection"
    And I should see the radio button "program_allow_connection_feedback_true" selected
    And I choose "program_allow_connection_feedback_false"
    And I press "Save"
    Then I logout as super user
    Then I logout

    Given the current program is "primary":"albers" 
    When I have logged in as "mkr@example.com"    
    And I follow "name & madankumarrajan"    
    
    Then I should not see "Provide feedback"
    And I logout

    @javascript @p2
    Scenario: Provide feeedback in Mentoring Area
    Given the current program is "primary":"albers" 
    When I have logged in as "mkr@example.com"    
    And I follow "name & madankumarrajan"
       
    Then I should see "Provide Feedback"
    And I follow "Provide Feedback"
    Then I check "Mentoring Area"
    Then I choose "Good"
    Then I press "Submit"
    Then I should see "Thank you for your feedback"
    And I logout

@javascript
Scenario: Admin can change the feedback survey to be sent when Mentoring Connections V2 enabled
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Connection Settings"
  Then I should see "Mentoring Connection Activity Feedback" selected from "#program_feedback_survey_id"

  # Feedback Survey Effectiveness and Connection mode questions are non-editable
  And I follow "(what is this?)"
  And I follow "here"
  Then I should see "Mentoring Connection Activity Feedback"
  And I should not see edit action for feedback question of mode 0
  And I should not see edit action for feedback question of mode 1
  And I see warning for removing feedback question of mode 0
  And I see warning for removing feedback question of mode 1
  When I press browser back
  And I select "Create a new survey" from "program_feedback_survey_id"
  Then I should see "New Survey"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I disable the feature "mentoring_connections_v2" as a super user
  When I hover over "my_programs_container"
  And I select "Albers Mentor Program" from the program selector
  When I follow "Manage"
  And I follow "Program Settings"
  And I follow "Connection Settings"
  Then I should not see "Mentoring Connection Activity Feedback"
  And I logout