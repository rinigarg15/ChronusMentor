# encoding: utf-8
Feature: Admin adds users directly

Background: Admin logs in
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I login as super user
  And clear mail deliveries

@javascript @enrollment_scenario @cross_browser
Scenario: Admin logs in and adds mentors directly. The user signs up and verifies the details
  When I follow "Mentors"
  And I follow "Add Mentors Directly" for the group "action_1"
  Then the "role_mentor" checkbox_id should be checked
  Then the "role_student" checkbox_id should not be checked
  Then the "role_admin" checkbox_id should not be checked
  And I fill in by css "user_email" with "NewMentor@iit.com"
  And I click "#cjs_add_user_next"
  And I click on the section with header "Work and Education"
  And I click on the section with header "Mentoring Profile"
  And I fill in by css "user_member_first_name" with "New"
  And I fill in by css "user_member_last_name" with "Mentor"
  And I fill in location_question of "primary":"albers" with "chennai"
  And I fill in education_question of "primary":"albers" with "Ivy League,Masters,CS"
  And I fill in experience_question of "primary":"albers" with "temp company,Developer"
  And I press "save_and_add"
  And I should see the flash "New Mentor has been added as a Mentor. You can continue adding the next Mentor."
  And a mail should go to "NewMentor@iit.com" having "You have been invited by Freakin Admin \(Administrator\) to join Albers Mentor Program as a mentor."

  And I fill in "user_email" with "AnotherMentor@iit.com"
  And I click "#cjs_add_user_next"
  And I click on the section with header "Work and Education"
  And I click on the section with header "Mentoring Profile"
  Then I fill in by css "user_member_first_name" with "Another"
  And I fill in by css "user_member_last_name" with "Mentor"
  And I fill in location_question of "primary":"albers" with "chennai"
  And I press "save_and_finish"
  And a mail should go to "AnotherMentor@iit.com" having "You have been invited by Freakin Admin \(Administrator\) to join Albers Mentor Program as a mentor."

  #user signup

  And I open new mail
  And I follow "Accept and sign up" in the email
  Then I should see "Welcome, Another Mentor!"
  Then the disabled "member_email" field should contain "AnotherMentor@iit.com"
  Then the "member_first_name" field should contain "Another"
  Then the "member_last_name" field should contain "Mentor"
  And I fill in by css "member_password" with "monkey"
  And I fill in by css "member_password_confirmation" with "monkey"
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "Sign up"
  Then I should see "Welcome to Albers Mentor Program. Please complete your online profile to proceed"
  Then I should see "Basic Information"
  And I fill in "Phone" with "001-125845-78"
  And I fill in "Skype ID" with "Another.mentor"
  And I fill in "Location" with "Chennai, Tamil Nadu, India"
  And I press "submit_general"
  And I should see "Work and Education"
  And I should see "Click here to import your experience"
  And I press "Proceed"
  Then I should see "Mentoring Profile"
  And I press "Proceed"
  Then I should see "More Information"
  And I press "Proceed"
  Then I should see "Mentoring Preferences"
  And I press "Proceed"
  #Then I should see "Please Reset Your Time Zone"
  Then I should see "Messages"
  Then I should see "All Activity"
  And I logout

@javascript @enrollment_scenario
Scenario: Admin logs in and adds mentors directly and invites him to publish profile. And the user signs up
  When I follow "Mentors"
  And I follow "Add Mentors Directly" for the group "action_1"
  Then the "role_mentor" checkbox_id should be checked
  Then the "role_student" checkbox_id should not be checked
  Then the "role_admin" checkbox_id should not be checked
  And I fill in by css "user_email" with "NewMentor@iit.com"
  And I click "#cjs_add_user_next"
  And I click on the section with header "Work and Education"
  And I click on the section with header "Mentoring Profile"

  And I fill in by css "user_member_first_name" with "ANew"
  And I fill in by css "user_member_last_name" with "AMentor"
  And I fill in location_question of "primary":"albers" with "chennai"
  And I fill in education_question of "primary":"albers" with "Ivy League,Masters,CS"
  And I fill in experience_question of "primary":"albers" with "Miami Corp, SVP"
  And I press "save_and_add"
  Then I should see "Add users manually"
  Then I should see the flash "ANew AMentor has been added as a Mentor. You can continue adding the next Mentor."
  And a mail should go to "NewMentor@iit.com" having " You have been invited by Freakin Admin \(Administrator\) to join Albers Mentor Program as a mentor."

  # Check pending user
  Then I follow "Manage"
  And I follow "User Views"
  When I create a new view
  Then I should see "New View"
  And I fill in by css "admin_view_title" with "A New View"
  Then I follow "Next »"
  Then I click view
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Mentor"
  And I check "admin_view_roles_and_status_state_pending"
  Then I follow "Next »"
  Then I should see "Select Fields to Display"
  Then I click view
  And I press "Create View"
  Then I follow "pending"
  Then I should see "The member has not yet published their profile"
  And I logout

  #user signups and verifies the details
  And I open new mail
  And I follow "Accept and sign up" in the email
  Then I should see "Welcome, ANew AMentor!"
  Then the disabled "member_email" field should contain "NewMentor@iit.com"
  Then the "member_first_name" field should contain "ANew"
  Then the "member_last_name" field should contain "AMentor"
  And I fill in by css "member_password" with "monkey"
  And I fill in by css "member_password_confirmation" with "monkey"
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "Sign up"
  Then I should see "Basic Information"
  And I fill in "Phone" with "001-125845-78"
  And I fill in "Skype ID" with "Anew.mentor"
  And I fill in "Location" with "Chennai, Tamil Nadu, India"
  And I press "submit_general"
  And I should see "Work and Education"
  And I should see "Click here to import your experience"
  And I press "Proceed"
  Then I should see "Mentoring Profile"
  And I press "Proceed"
  Then I should see "More Information"
  And I press "Proceed"
  Then I should see "Mentoring Preferences"
  And I press "Proceed"
  #Then I should see "Please Reset Your Time Zone"
  Then I should see "Messages"
  Then I should see "All Activity"
  And I logout

@javascript @enrollment_scenario
Scenario: Admin logs in and adds mentee directly, And the mentee signs up
  When I follow "Students"
  And I follow "Add Students Directly" for the group "action_1"
  Then the "role_mentor" checkbox_id should not be checked
  Then the "role_student" checkbox_id should be checked
  Then the "role_admin" checkbox_id should not be checked
  And I fill in by css "user_email" with "NewStudent@iit.com"
  And I click "#cjs_add_user_next"
  And I click on the section with header "Work and Education"
  And I click on the section with header "Mentoring Profile"
  And I fill in by css "user_member_first_name" with "New"
  And I fill in by css "user_member_last_name" with "Student"
  And I fill in location_question of "primary":"albers" with "chennai"
  And I fill in experience_question of "primary":"albers" with "company,Developer"
  And I press "save_and_add"
  And I should see "New Student has been added as a Student. You can continue adding the next Student."
  And a mail should go to "NewStudent@iit.com" having "You have been invited by Freakin Admin \(Administrator\) to join Albers Mentor Program as a student."
  #adding another student
  And I check "role_student"
  And I fill in by css "user_email" with "anotherStudent@iit.com"
  And I click "#cjs_add_user_next"
  And I click on the section with header "Work and Education"
  And I click on the section with header "Mentoring Profile"
  Then I fill in by css "user_member_first_name" with "Another"
  And I fill in by css "user_member_last_name" with "AStudent"
  And I fill in location_question of "primary":"albers" with "chennai"
  And I fill in education_question of "primary":"albers" with "Ivy League,Masters,CS"
  And I fill in experience_question of "primary":"albers" with "Miami Corp, SVP"
  And I press "Publish and finish"
  And I should see "Another AStudent has been added as a Student."
  And a mail should go to "anotherStudent@iit.com" having "It is important that you review and complete your profile. A detailed profile helps find better matches"
  And I logout

  #user signup
  And I open new mail
  And I follow "Accept and sign up" in the email
  Then I should see "Welcome, Another AStudent!"
  Then the disabled "member_email" field should contain "anotherStudent@iit.com"
  Then the "member_first_name" field should contain "Another"
  Then the "member_last_name" field should contain "AStudent"
  And I fill in by css "member_password" with "monkey"
  And I fill in by css "member_password_confirmation" with "monkey"
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "Sign up"
  Then I should see "Welcome to Albers Mentor Program. Please complete your online profile to proceed."
  Then I should see "Basic Information"
  And I fill in "Phone" with "001-125845-78"
  And I fill in "Skype ID" with "Another.AStudent"
  And I fill in "Location" with "Chennai, Tamil Nadu, India"
  And I press "submit_general"
  And I should not see "Work and Education" within "div#profile_completion"
  And I should see "Work and Education" in green color
  And I should see "Mentoring Profile" in gray color 
  And I should see "Basic Information" in green color
  And I should see "More Information Students" in gray color
  And I should see "Your profile is 42% complete."
  And I should see "Sections 2 out of 4 completed."
  Then I should see "Mentoring Profile"
  And I press "Proceed"
  And I should see "Work and Education" in green color
  And I should see "Mentoring Profile" in green color 
  And I should see "Basic Information" in green color
  And I should see "More Information Students" in gray color
  Then I should see "More Information"
  And I press "Proceed"
  #Then I should see "Please Reset Your Time Zone"
  Then I should see "Messages"
  Then I should see "All Activity"

@javascript
Scenario: Admin logs in and adds mentors and mentees directly
  When I follow "Mentors"
  And I follow "Add Mentors Directly" for the group "action_1"
  And I check "role_mentor"
  And I check "role_student"
  And I fill in by css "user_email" with "NewMentor@iit.com"
  And I click "#cjs_add_user_next"
  And I click on the section with header "Work and Education"
  And I click on the section with header "Mentoring Profile"
  And I fill in by css "user_member_first_name" with "New"
  And I fill in by css "user_member_last_name" with "Mentor"
  And I fill in location_question of "primary":"albers" with "chennai"
  And I fill in experience_question of "primary":"albers" with "temp company,Developer"
  And I press "save_and_add"
  And I should see the flash "New Mentor has been added as a Mentor and Student. You can continue adding the next Mentor and Student."
  And a mail should go to "NewMentor@iit.com" having "You have been invited by Freakin Admin \(Administrator\) to join Albers Mentor Program as a Mentor and Student."