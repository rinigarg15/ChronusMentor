# encoding: utf-8
Feature: Admin adds and drafts users with validations

Background: Admin logs in
  And I perform missed migrations
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I login as super user
  And clear mail deliveries

@javascript
Scenario: Admin adding a user
  When I follow "Manage"
  And I follow "Add Users"
  And I check "role_admin"
  And I fill in "user_email" with "valid_o'email@iit.com"
  And I click "#cjs_add_user_next"
  And I check "role_mentor"

@javascript @cross_browser
Scenario: Admin logs in and adds admin and mentor directly and check for admin validations on education and experience
  When I follow "Manage"
  And a required education question is added for "mentor" to "Basic Information"
  And I follow "Add Users"
  And I check "role_admin"
  And I check "role_mentor"
  And I fill in "user_email" with "NewAdmin12@iit.com"
  And I click "#cjs_add_user_next"
  And I click on the section with header "Work and Education"
  And I click on the section with header "Mentoring Profile"
  And I fill in "user_member_first_name" with "New"
  And I fill in "user_member_last_name" with "Admin"
  And I press "save_and_add"
  Then I logout
  And a mail should go to "NewAdmin12@iit.com" having "You have been invited by Freakin Admin \(Administrator\) to join Albers Mentor Program as an Administrator and Mentor."
  And I open new mail
  And I follow "Accept and sign-up" in the email
  And I fill in "member_password" with "monkey"
  And I fill in "member_password_confirmation" with "monkey"
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "Sign up"
  And I press "submit_general"
  Then I should see "Please fill the highlighted fields with appropriate values to proceed"
  And I fill in education_question of "primary":"albers" of section "Basic Information" with ",Test Degree,Test Major" for 1 index of "new_education_attributes"
  And I press "submit_general"
  Then I should see "Please fill the highlighted fields with appropriate values to proceed"
  And I fill in education_question of "primary":"albers" of section "Basic Information" with "Correct,Test Degree,Test Major" for 1 index of "new_education_attributes"
  And I press "submit_general"
  And I fill in education_question of "primary":"albers" with ",Test Degree,Test Major"
  And I press "Proceed"
  Then I should see "Please fill the highlighted fields with appropriate values to proceed"
  And I fill in education_question of "primary":"albers" of section "Work and Education" with "Correct,Test Degree,Test Major" for 1 index of "new_education_attributes"
  And I press "Proceed"
  And I press "Proceed"
  And I press "Proceed"
  And I press "Proceed"
  And I click on profile picture and click "Edit Profile"
  And I click on the section with header "Basic Information"
  And I overwrite education_question of "primary":"albers" of section "Basic Information" of user "NewAdmin12@iit.com" with ",Test Degree,Test Major"
  And I press "Save"
  Then I should see "Please fill the highlighted fields with appropriate values"

@javascript @cross_browser
Scenario: Admin entering invalid values while adding mentors should not result in loss of data
  When I follow "Mentors"
  And I click "#action_1 .dropdown-toggle"
  And I follow "Add Mentors Directly"
  Then the "role_mentor" checkbox_id should be checked
  Then the "role_student" checkbox_id should not be checked
  Then the "role_admin" checkbox_id should not be checked
  And I fill in "user_email" with "NewMentor@iit.com"
  And I click "#cjs_add_user_next"
  And I click on the section with header "Work and Education"
  And I click on the section with header "Mentoring Profile"

  #Add Mentor with numericals in name results in error and it should not cause data loss
  Then I fill in "user_member_first_name" with "Another12"
  And I fill in "user_member_last_name" with "Mentor"
  And I fill in location_question of "primary":"albers" with "chennai"
  And I fill in experience_question of "primary":"albers" with "company,Developer"
  And I fill in the extended profile fields "About Me,Expertise" for "mentor" with "Testing Extended Fields"
  And I press "save_and_finish"
  Then I should see "contains numeric characters"
  And I click on the section with header "Mentoring Profile"
  And I should see "Testing Extended Fields"

  #Change the Email and save again
  Then I fill in "user_member_first_name" with "Another"
  And I press "save_and_finish"
  Then I should see "Another Mentor has been added as a Mentor."
  And a mail should go to "NewMentor@iit.com" having "You have been invited by Freakin Admin \(Administrator\) to join Albers Mentor Program as a mentor."
  When I visit the profile of "NewMentor@iit.com"
  Then I should see "Testing Extended Fields"

@javascript
Scenario: Admin entering invalid values while adding student should not result in loss of data
  When I follow "Students"
  And I click "#action_1 .dropdown-toggle"
  And I follow "Add Students Directly"
  And I fill in "user_email" with "NewStudent@iit.com"
  And I click "#cjs_add_user_next"
  And I click on the section with header "Work and Education"
  And I click on the section with header "Mentoring Profile"

  #Add Student with numericals is name results in error and it should not cause data loss
  Then I fill in "user_member_first_name" with "Another12"
  And I fill in "user_member_last_name" with "Student"
  And I fill in location_question of "primary":"albers" with "chennai"
  And I fill in experience_question of "primary":"albers" with "company,Developer"
  And I fill in the extended profile fields "About Me,Expertise" for "student" with "Testing Extended Fields"
  And I press "save_and_finish"
  Then I should see "contains numeric characters"
  And I click on the section with header "Mentoring Profile"
  And I should see "Testing Extended Fields"

  #Change the Email and save again
  Then I fill in "user_member_first_name" with "Another"
  And I press "save_and_finish"
  Then I should see "Another Student has been added as a Student."
  And a mail should go to "NewStudent@iit.com" having "You have been invited by Freakin Admin \(Administrator\) to join Albers Mentor Program as a student."
  When I visit the profile of "NewStudent@iit.com"
  Then I should see "Testing Extended Fields"

@javascript
Scenario: Admin entering invalid values in text only field
  # Basic profile
  Given the current program is "primary":"main"
  And I follow "Manage"
  Then I should see "Preview"
  And I should see "Customize"
  And I follow "Customize"
  And I open section with header "Basic Information"
  And I click on add new question
  And I fill in "profile_question_text_0" with "New Text Field"
  And I select "Text Entry" from "profile_question_question_type_0"
  And I check "profile_question_text_only_option"
  And I press "Save" within "form#edit_profile_question_"
  Then I wait for ajax to complete
  And I follow "Programs"
  And I check "Student"
  Then I wait for ajax to complete

  Given the current program is "primary":"albers"
  When I follow "Students"
  And I follow "Add Students Directly" for the group "action_1"
  And I fill in "user_email" with "NewStudent@iit.com"
  And I click "#cjs_add_user_next"
  And I click on the section with header "Work and Education"
  And I click on the section with header "Mentoring Profile"
  And I fill the answer "New Text Field" with "test988"
  And I fill in "user_member_first_name" with "New"
  And I fill in "user_member_last_name" with "Student"
  And I fill in location_question of "primary":"albers" with "chennai"
  And I fill in experience_question of "primary":"albers" with "company,Developer"
  And I press "save_and_finish"
  Then I should see "cannot contain digits"

  And I fill the answer "New Text Field" with "test text type"
  And I press "save_and_finish"
  Then I should see "New Student has been added as a Student."


@javascript
Scenario: Admin logs in and adds mentors profiles with incorrect email
  When I follow "Manage"
  And I follow "Add Users"
  And I check "role_mentor"
  And I fill in "user_email" with ".InvalidEmail@iit.com"
  And I click "#cjs_add_user_next"
  Then I should not see "Basic Section"
  Then I should see "Please enter a valid email address"

@javascript
Scenario: Admin logs in and adds mentors profiles with publication field
  When I follow "Manage"
  And I follow "Add Users"
  And I check "role_mentor"
  And I fill in "user_email" with "valid_o'email@iit.com"
  And I click "#cjs_add_user_next"
  And I click on the section with header "Work and Education"
  And I click on the section with header "Mentoring Profile"
  And I fill in "user_member_first_name" with "Weird"
  And I fill in "user_member_last_name" with "EmailMentor"
  And I click on the section with header "More Information"
  And I fill in location_question of "primary":"albers" with "chennai"
  And I fill in experience_question of "primary":"albers" with "company,Developer"
  And I fill in publication_question of "primary":"albers" with ",publisher,author"
  And I should see "Add another publication"
  And I press "save_and_add"
  Then I should see "Add users manually"
  Then I should see "Please fill the highlighted fields with appropriate values to proceed"
  And I fill in publication_question of "primary":"albers" with "publication,publisher,author"
  #File upload Question
  And I set the attachment field with ".ajax-file-uploader" to "handbook_test.txt"
  And I wait for upload to complete
  Then I should see "File was successfully scanned for viruses"
  And I press "save_and_add"
  And I should see the flash "Weird EmailMentor has been added as a Mentor. You can continue adding the next Mentor."
  And a mail should go to "valid_o'email@iit.com" having "You have been invited by Freakin Admin \(Administrator\) to join Albers Mentor Program as a mentor."

@javascript @cross_browser
Scenario: Admin logs in and adds mentors profiles with manager field
  When I follow "Manage"
  And I follow "Add Users"
  And I check "role_mentor"
  And I fill in "user_email" with "valid_o'email@iit.com"
  And I click "#cjs_add_user_next"
  And I click on the section with header "Work and Education"
  And I click on the section with header "Mentoring Profile"
  And I fill in "user_member_first_name" with "Weird"
  And I fill in "user_member_last_name" with "EmailMentor"
  And I fill in experience_question of "primary":"albers" with "company,Developer"
  And I fill in publication_question of "primary":"albers" with "publication,publisher,author"
  And I fill in manager_question of "primary":"albers" with ",last name,manager@example.com"
  And I press "save_and_add"
  Then I should see "Add users manually"
  Then I should see "Please fill the highlighted fields with appropriate values to proceed"
  And I fill in manager_question of "primary":"albers" with "first_name,last name,wrong_email"
  And I press "save_and_add"
  Then I should see "Add users manually"
  And I fill in manager_question of "primary":"albers" with "first_name,last name,manager@example.com"
  And I press "save_and_add"
  And I should see the flash "Weird EmailMentor has been added as a Mentor. You can continue adding the next Mentor."
  And a mail should go to "valid_o'email@iit.com" having "You have been invited by Freakin Admin \(Administrator\) to join Albers Mentor Program as a mentor."