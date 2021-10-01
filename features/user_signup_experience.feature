@user
Feature: Signup experience for a user.
  To block user who has not filled his profile completely

@javascript @cross-browser
Scenario: Uploaded image visibility
    Given the current program is "primary":"albers"
    And the current program admin has added required questions for "mentor" to "Basic Information"
    And the current program admin has added required questions for "mentor" to "Mentoring Profile"
    When Admin sends program invitation email to "sarat_new@example.com" as "mentor"
    And I open new mail
    And I follow "Click here" in the email
    Then I should see "Welcome! You have been invited to join Albers Mentor Program as a Mentor."

    And element with id "#member_email" should be disabled
    And I fill in "member_first_name" with "mentor"
    And I fill in "member_last_name" with "me"
    And I fill in "member_password" with "monkey"
    And I fill in "member_password_confirmation" with "monkey"
    Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
    And I press "Sign up »"
    Then I should see the flash "Welcome to Albers Mentor Program. Please complete and publish your online profile to proceed."
    When I fill in "profile_picture_image" with file "files/pic_2.png"
    And I fill in "Whats your age?" with "22"
    And I press "submit_general"
    And I logout
    And I have logged in as "sarat_new@example.com"
    Then I should see "Work and Education"

@javascript
Scenario: Mentor first login
    Given the current program is "primary":"albers"
    Given the current program admin has added required questions for "mentor"
    When I have logged in as "ram@example.com"
    And I logout
    When Admin sends program invitation email to "sarat_new@example.com" as "mentor"
    When I open new mail
    And I follow "Click here" in the email
    And I should see "Welcome! You have been invited to join Albers Mentor Program as a Mentor."

    #Do not allow numeric characters
    Then I fill in "member_first_name" with "mentor123"
    Then I fill in "member_last_name" with "sample"
    And I fill in "member_password" with "monkey"
    And I fill in "member_password_confirmation" with "monkey"
    And element with id "#member_email" should be disabled
    Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
    And I press "Sign up »"
    Then I should see "contains numeric characters"

    And I should see "Welcome! You have been invited to join Albers Mentor Program as a Mentor."
    Then I fill in "member_first_name" with "mentor"
    Then I fill in "member_last_name" with "me"
    And I fill in "member_password" with "monkey"
    And I fill in "member_password_confirmation" with "monkey"
    And element with id "#member_email" should be disabled
    Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
    And I press "Sign up »"
    Then I should see the flash "Welcome to Albers Mentor Program. Please complete and publish your online profile to proceed."
    And I should see "Basic Information"
    And I should not see the tabs in program header
    And I should not see "Account Settings"
    And I should see "Contact Administrator"
    And I fill in "member_last_name" with "Henry"
    And I fill in "Phone" with "033024382947329"
    And I fill in "Skype ID" with "fura.rafa"
    And I fill in "Location" with "Chennai, Tamil Nadu, India"
    And I press "submit_general"
    And I should see "Work and Education"
    Then I should not see "Organization *"
    Then I should not see "College/School name *"
    Then I should not see "Title *"
    Then I should not see "Email *"
    Then I should not see "First name *"
    Then I should not see "Last name *"
    Then I should not see "Name *"

    And I should not see the tabs in program header
    And I logout

    # logging in again should show the mentor profile edit page
    When I have logged in as "sarat_new@example.com"
    Then I should see the flash "Your mentor profile is incomplete. Please fill all the required fields and publish your profile."
    And I should not see the tabs in program header
    And I should not see "Account Settings"
    And I should see "Contact Administrator"
    And I try to go to articles page
    Then I should see the flash "Your mentor profile is incomplete. Please fill all the required fields and publish your profile."
    And I should see "Work and Education"
    And I should see "Click here to import your experience"
    And I fill in education_question of "primary":"albers" with ",Test Degree,Test Major"
    And I fill in experience_question of "primary":"albers" with ", Test Job"
    And I press "Proceed"
    Then I should see "Please fill the highlighted fields with appropriate values to proceed"
    And I fill in education_question of "primary":"albers" of section "Work and Education" with "Correct,Test Degree,Test Major" for 1 index of "new_education_attributes"
    And I fill in experience_question of "primary":"albers" of section "Work and Education" with "Correct,Test " for 2 index of "new_experience_attributes"
    And I press "Proceed"
    Then I answer the required questions for "sarat_new@example.com"
    And I press "Proceed" within ".cui_custom_fields_container"
    Then I follow "Advice"
    And I follow "Articles"
    Then I should see the page title "Articles"

@javascript
Scenario: When a new question is added by admin which makes a complete profile incomplete
    Given the current program is "primary":"albers"
    Given the current program admin has added required questions for "mentor"
    When I have logged in as "robert@example.com"
    Then I should see the profile update message "The administrator has added a few mandatory fields to the profile. Click here to update your profile."
    And I logout

@javascript
Scenario: When admin adds a mentor directly.
    Given the current program is "primary":"albers"
    Given the current program admin has added required questions for "mentor"
    # admin logged in
    When I have logged in as "ram@example.com"
    And I follow "Mentors"
    And I click "#action_1 .dropdown-toggle"
    And I follow "Add Mentors Directly"
    And I fill in "user_email" with "sarat_mentor@example.com"
    And I click "#cjs_add_user_next"
    Then I should see "Basic Information"
    And I click on the section with header "Work and Education"
    And I click on the section with header "Mentoring Profile"
    And I fill in "user_member_first_name" with "New"
    And I fill in "user_member_last_name" with "Mentor"
    And I fill in location_question of "primary":"albers" with "chennai"
    And I fill in "Whats your age?" with "22"
    And I press "save_and_add"
    And a mail should go to "sarat_mentor@example.com" having "You have been invited by Freakin Admin \(Administrator\) to join Albers Mentor Program as a mentor"
    And I logout
    When I open new mail
    And I follow "Accept and sign up" in the email
    And I should see "Welcome, New Mentor!"
    And I should see "Sign up with Password"
    And I fill in "member_password" with "monkey"
    And I fill in "member_password_confirmation" with "monkey"
    Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
    And I press "Sign up »"
    And I press "Proceed" within "#general_profile"
    Then I should see "Work and Education"
    And I logout

@javascript
Scenario: When admin adds a mentor directly published case.
    Given the current program is "primary":"albers"
    Given the current program admin has added required questions for "mentor"
    # admin logged in
    When I have logged in as "ram@example.com"
    And I follow "Mentors"
    And I click "#action_1 .dropdown-toggle"
    And I follow "Add Mentors Directly"
    And I fill in "user_email" with "sarat_mentor@example.com"
    And I click "#cjs_add_user_next"
    Then I should see "Basic Information"
    And I click on the section with header "Work and Education"
    And I click on the section with header "Mentoring Profile"
    And I fill in "user_member_first_name" with "New"
    And I fill in "user_member_last_name" with "Mentor"
    And I fill in location_question of "primary":"albers" with "chennai"
    And I press "save_and_add"
    And a mail should go to "sarat_mentor@example.com" having "You have been invited by Freakin Admin \(Administrator\) to join Albers Mentor Program as a mentor"
    And I logout
    When I open new mail
    And I follow "Accept and sign up" in the email
    And I should see "Welcome, New Mentor!"
    And I fill in "member_password" with "monkey"
    And I fill in "member_password_confirmation" with "monkey"
    Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
    And I press "Sign up »"
    And I should not see the tabs in program header
    And I press "Proceed" within "#general_profile"
    And I should not see the tabs in program header
    Then I should see "Work and Education"

@javascript @cross-browser
Scenario: When there are no required questions, The user has no restrictions.
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I logout
    When Admin sends program invitation email to "sarat_new@example.com" as "mentor"
    When I open new mail
    And I follow "Click here" in the email
    Then I fill in "member_first_name" with "mentor"
    Then I fill in "member_last_name" with "me"
    And I fill in "member_password" with "monkey"
    And I fill in "member_password_confirmation" with "monkey"
    And element with id "#member_email" should be disabled
    Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
    And I press "Sign up »"
    And I should see "Home"
    And I follow "Advice"
    And I follow "Articles"
    Then I should see the page title "Articles"

@javascript
Scenario: Student first login
    Given the current program is "primary":"albers"
    Given the current program admin has added required questions for "student"
    When I have logged in as "ram@example.com"
    And I logout
    When Admin sends program invitation email to "sarat_student@example.com" as "student"
    When I open new mail
    And I follow "Click here" in the email
    And I should see "Welcome! You have been invited to join Albers Mentor Program as a Student."
    Then I fill in "member_first_name" with "student"
    Then I fill in "member_last_name" with "me"
    And I fill in "member_password" with "monkey"
    And I fill in "member_password_confirmation" with "monkey"
    And element with id "#member_email" should be disabled
    Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
    And I press "Sign up »"
    Then I should see the flash "Welcome to Albers Mentor Program. Please complete and publish your online profile to proceed."
    And I should not see the tabs in program header
    And I should not see "Account Settings"
    And I should see "Contact Administrator"
    And I press "Proceed" within "#general_profile"
    Then I should see the flash "You have successfully completed your basic profile. Please follow up by completing your full profile."
    And I should not see the tabs in program header
    And I logout

    # logging in again should show the student profile edit page
    When I have logged in as "sarat_student@example.com"
    Then I should see the flash "Your student profile is incomplete. Please fill all the required fields and publish your profile."
    And I should not see the tabs in program header
    And I should not see "Account Settings"
    And I should see "Contact Administrator"
    And I try to go to articles page
    Then I should see the flash "Your student profile is incomplete. Please fill all the required fields and publish your profile."
    And I should see "Click here to import your experience"
    Then I answer the education experience questions for "sarat_student@example.com"
    And I press "Proceed"
    Then I answer the required questions for "sarat_student@example.com"
    And I press "Proceed" within ".cui_custom_fields_container"
    Then I click on profile picture and click "View Profile"
    Then I should see "student me"
    Then I follow "Advice"
    And I follow "Articles"
    Then I should see the page title "Articles"
