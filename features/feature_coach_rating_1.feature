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
  And I enable "coach_rating" feature as a super user

@javascript
Scenario: Super user should be able to see coach rating in feature listing
  And I login as super user
  When I hover over "my_programs_container"
  And I select "Primary Organization" from the program selector
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Features"
  Then I should see "Mentors Rating"

@javascript @cross_browser
Scenario: Mentee rates mentor
  And I logout
  When I have logged in as "mkr@example.com"
  Then I follow "name & madankumarrajan"
  And I expand the "mentor" listing of mentoring area members pane
  When I hover over link with text "Good unique name"

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

@javascript
Scenario: Admin can see rating in mentor's profile
  And I follow "Mentors"
  And I follow "Good unique name"
  Then I hover over rating of mentor with email "robert@example.com" in program "primary":"albers"
  Then I should see "Not rated yet."
  Then I create rating for mentor with email "robert@example.com" in program "primary":"albers"
  Then I follow "Mentors"
  And I follow "Good unique name"
  Then I hover over rating of mentor with email "robert@example.com" in program "primary":"albers"
  Then I should see "4.5"
  Then I open ratings of mentor with email "robert@example.com" in program "primary":"albers"
  Then I should see "Good unique name's Rating" within ".modal.in"
  Then I should see "very helpful" within "div.mentor-rating-content"
  Then I should see "mkr_student madankumarrajan" within "div.mentor-rating-content .nickname"

@javascript @cross_browser
Scenario: Admin can see rating in find a mentor
  And I follow "Students"
  Then I follow "Actions"
  And I follow "Find a Mentor"
  Then I filter a mentor with name "Good unique" using quick find
  Then I remove the status filter
  Then I hover over rating of mentor with email "robert@example.com" in program "primary":"albers"
  Then I should see "Not rated yet."
  Then I create rating for mentor with email "robert@example.com" in program "primary":"albers"
  Then I follow "Students"
  Then I follow "Actions"
  And I follow "Find a Mentor"
  Then I remove the status filter
  Then I filter a mentor with name "Good unique" using quick find
  Then I hover over rating of mentor with email "robert@example.com" in program "primary":"albers"
  Then I should see "4.5"
  Then I open ratings of mentor with email "robert@example.com" in program "primary":"albers"
  Then I should see "Good unique name's Rating" within ".modal.in"
  Then I should see "very helpful" within "div.mentor-rating-content"
  Then I should see "mkr_student madankumarrajan" within "div.mentor-rating-content .nickname"

@javascript @not_run_on_tddium
Scenario: Admin can see rating in hovercard
  And I enable "bulk_matching" feature as a super user
  Then I create rating for mentor with email "request@example.com" in program "primary":"albers"
  And I follow "Manage"
  And I follow "Bulk Match"
  When I click "#s2id_bulk_match_mentee_view_id > .select2-choice"

  And I click on select2 result "All Mentees"
  When I click "#s2id_bulk_match_mentor_view_id > .select2-choice"

  And I click on select2 result "All Mentors"
  And I press "Next »"
  Then I should see "Settings"
  Then I scroll down by "10000"
  Then I wait for ajax to complete
  Then I should see "Requestable mentor"
  And I hover over link with title "Requestable mentor"
  Then I wait for ajax to complete
  Then I hover over rating of mentor with email "request@example.com" in program "primary":"albers"
  Then I open ratings of mentor with email "request@example.com" in program "primary":"albers"
  Then I should see "Requestable mentor's Rating" within ".modal.in"
  Then I should see "very helpful" within "div.mentor-rating-content"
  Then I should see "student_e example" within "div.mentor-rating-content .nickname"