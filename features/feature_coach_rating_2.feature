Feature: Coach Rating

Background:
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I enable "coach_rating" feature as a super user
  #Then I enable admin audit logs
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  Then I enable "mentoring_connections_v2" feature as a super user
  And I logout
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  #And I enable "coach_rating" feature as a super user

@javascript @cross_browser
Scenario: Mentee seeing the rating popup when comming form mail
  And I logout
  When I have logged in as "mkr@example.com"
  Given I close group for student with email "mkr@example.com" in program "primary":"albers"
  When "mkr@example.com" opens the email with subject "Rate your mentor"
  And I follow "Rate your mentor" in the email
  Then I should see "Rate Your Mentor"
  Then I should see "Rate Good unique name on a scale of 0.5 to 5"

@javascript @cross_browser
Scenario: Rating filter ad column in admin view
  #And I enable "coach_rating" feature as a super user
  And I follow "Manage"
  Then I follow "User Views"
  Then I should see "All Users"
  And I create a new view
  And I fill in "admin_view_title" with "Test View"
  Then I follow "Next »"
  Then I click view
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Mentor"
  And I click on the section with header "Engagement status"
  Then I should see "Mentor Rating"
  And I select "Less than" from "admin_view[connection_status][rating][operator]"
  And I select "5" from "admin_view[connection_status][rating][less_than]"
  And I select "Greater than" from "admin_view[connection_status][rating][operator]"
  And I select "3" from "admin_view[connection_status][rating][greater_than]"
  And I select "Equal to" from "admin_view[connection_status][rating][operator]"
  And I select "3" from "admin_view[connection_status][rating][equal_to]"
  And I select "Not Rated yet" from "admin_view[connection_status][rating][operator]"
  Then I follow "Next »"
  Then I click view
  Then I should see "Rating" within "div.multiselect-available-list"
  Then I should not see "Rating" within "div.multiselect-selected-list"
  Then I click by xpath "(//div[text()='Rating'])[last()]"
  Then I should see "Rating" within "div.multiselect-selected-list"
  And I press "Create View"
  Then I scroll until I see "Rating"
  Then I should see "Rating" within "div#cjs_admin_view_result"
  Then I should see "Not rated yet." within "div#cjs_admin_view_result"

@javascript
Scenario: Mentee sees rating option in hovercard
  And I logout
  When I have logged in as "mkr@example.com"
  Then I follow "name & madankumarrajan"
  And I expand the "mentor" listing of mentoring area members pane
  When I hover over link with text "Good unique name"
  Then I should see "Good unique name" within "div.cjs-hovercard-container"
  Then I should see "robert@example.com" within "div.cjs-hovercard-container"
  Then I should see "Message" within "div.cjs-hovercard-container"
  Then I should see "Mentor" within "div.cjs-hovercard-container"
  Then I should not see "name & madankumarrajan" within "div.cjs-hovercard-container"
  Then I should see "Location" within "div.cjs-hovercard-container"
  Then I should not see "Education" within "div.cjs-hovercard-container"
  Then I should not see "Work" within "div.cjs-hovercard-container"
  And I follow "Actions"
  Then I should see "Provide a rating"
  And I follow "Provide a rating"
  Then I should see "Your mentor evaluation will help us create better mentoring connections for other students."
  Then I should see "Your answers will be seen only by program administrators."
  Then I should see "Rate Your Mentor"
  Then I should see "Comments"
  Then I should see "Rate Good unique name on a scale of 0.5 to 5"
  And I press "Submit"
  Then I should see the flash "Please provide a valid rating."
  Then I click on the image with src "/assets/jquery.raty/star-off.png"
  And I press "Submit"
  Then I should see "Thank you for your feedback."