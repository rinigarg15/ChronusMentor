@javascript
Feature: Program outcomes report feature

Background: Admin logs in
  Given the current program is "primary":"albers"
  Then I maximize the window
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I enable "program_outcomes_report" feature as a super user
  And I logout

Scenario: Checking program outcomes report when flash mentoring is enabled.
  When I have logged in as "ram@example.com"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Then I change engagement type of program "primary":"albers" to "career based"
  When I hover over "my_programs_container"
  And I select "Albers Mentor Program" from the program selector
  When I follow "Outcome Reports" within "nav#sidebarLeft"
  And I follow "Program Outcomes Report"

  Then I should see "Membership"
  And I should see "Users Total"
  And I should not see "Matching"
  And I should not see "Mentoring Connections"
  And I should see "Engagement - Completed Meetings"
  And I should see "Meetings"
  Then I should see "Positive Results Reported in Completed Meetings"
  Then I should see "Click here to configure the reported positive outcomes section"

  And I click ".cjs_positive_outcomes_popup"
  Then I should see "Configure Positive Outcomes Report"
  When I click ".select2-chosen"
  Then I should see "Meeting Feedback Survey For Mentors"
  And I should see "How was your overall meeting experience?"
  And I should see "What was discussed in your meeting?"
  And I should see "Why was the meeting cancelled?"
  And I should see "How well did this person meet your expectations?"
  And I should see "How would you rate the experience for the following, - Ease of finding a mentor"
  And I should see "How would you rate the experience for the following, - Ease of scheduling a meeting"
  Then I should see "Meeting Feedback Survey For Mentees"
  And I should see "How satisfying was your meeting experience?"
  And I should see "How well did your mentee utilize their time with you?"
  And I should see "Why was the meeting cancelled?"
  And I click on select2 result "How was your overall meeting experience?"
  When I click ".cjs_positive_outcome_choices"
  And I click on select2 result "Extremely useful"
  Then I press "Save"
  And I click ".cjs_positive_outcomes_popup"
  Then I should see "How was your overall meeting experience?"
  Then I should see "Extremely useful"
  Then I should see "Select a survey question"
  Then I follow "Cancel"
  And I logout
  And I disable calendar feature that was removed from UI as super user of "primary":"albers"

  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  When I hover over "my_programs_container"
  And I select "Albers Mentor Program" from the program selector
  Then I change engagement type of program "primary":"albers" to "career based and ongoing"
  When I follow "Outcome Reports" within "nav#sidebarLeft"
  And I follow "Program Outcomes Report"

  Then I should see "Membership"
  Then I should see "Users Total"
  Then I should see "Matching"
  Then I should see "Mentoring Connections"
  Then I should see "Engagement"
  Then I should see "Positive Results Reported in Completed Mentoring Connections"
  And I should not see "Meetings"

  Then I should see "Click here to configure the reported positive outcomes section "
  When I click ".cjs_positive_outcomes_popup"
  And I click ".select2-chosen"
  Then I should not see "Meeting Feedback Survey"
  But I should see "Mentoring Connection Activity Feedback"
  And I close the select2 dropdown
  And I click ".cjs-web-modal-cancel"
  And I logout

@cross-browser
Scenario: Testing profile filters
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  When I follow "Outcome Reports" within "nav#sidebarLeft"
  And I follow "Program Outcomes Report"
  Then I follow "filter_report"
  Then I should see "User Profile"
  Then I should see "Gender"
  Then I should see "Location"
  Then I should see "Education"
  Then I should see "Work"
  Then I should see "Industry"
  And I logout
