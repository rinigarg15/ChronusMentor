Feature:  A new user must be able to join as mentor by clicking on join now  when no approval is required

Background: Admin modifies program setting to allow users to join directly without approval.

  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Membership"
  And I specify the joining option as "No approval required" for "Mentor"
  And I specify the joining option as "No approval required" for "Student"
  And I choose "program_show_multiple_role_option_true"
  And I press "Save"
  And I logout

@javascript @enrollment_scenario

Scenario:  A new user joins as mentor

  Given the current program is "primary":"albers"
  Then I want to join as "Mentor" with "harrypotter@test.com"
  And I open new mail
  And I follow "Complete Sign Up" in the email
  Then I should see "To join as Mentor, complete and submit the form below."
  Then email should be filled with "harrypotter@test.com" in landing page
  And I fill in the following details in membership request
  | FirstName       | Harry  |
  | LastName        | Potter |
  | Password        | monkey |
  | ConfirmPassword | monkey |
  And I press "Submit"
  Then I should see "Welcome to Albers Mentor Program. Please complete your online profile to proceed."
  Then I should see "Basic Information"
  And I fill in "Phone" with "001-125845-78"
  And I fill in "Skype ID" with "harry.potter"
  And I fill in "Location" with "Chennai, Tamil Nadu, India"
  And I press "submit_general"
  And I should see "Work and Education"
  And I should see "Click here to import your experience"
  Then I answer the education experience questions for "harrypotter@test.com"
  And I press "Proceed"
  Then I should see "Mentoring Profile"
  And I press "Proceed"
  Then I should see "More Information"
  And I press "Proceed"
  Then I should see "Mentoring Preferences"
  And I press "Proceed"
  Then I should see "Messages"
  Then I should see "All Activity"
  And I logout

@javascript  @enrollment_scenario @cross_browser

Scenario: A new user joins as mentee (with trailing spaces in email field)

  Given the current program is "primary":"albers"
  Then I want to join as "Student" with "  hermoine@test.com  "
  And I open new mail
  And I follow "Complete Sign Up" in the email
  Then I should see "To join as Student, complete and submit the form below."
  Then email should be filled with "hermoine@test.com" in landing page
  And I fill in the following details in membership request
  | FirstName       | Hermoine |
  | LastName        | Granger  |
  | Password        | monkey   |
  | ConfirmPassword | monkey   |
  And I press "Submit"
  Then I should see "Welcome to Albers Mentor Program. Please complete your online profile to proceed."
  Then I should see "Basic Information"
  And I fill in "Phone" with "001-125845-78"
  And I fill in "Skype ID" with "Hermoine.Granger"
  And I fill in "Location" with "Chennai, Tamil Nadu, India"
  And I press "submit_general"
  And I should see "Work and Education"
  And I should see "Click here to import your experience"
  Then I answer the education experience questions for "hermoine@test.com"
  And I press "Proceed"
  Then I should see "Mentoring Profile"
  And I press "Proceed"
  Then I should see "More Information"
  And I press "Proceed"
  Then I should see "Messages"
  Then I should see "All Activity"
  And I logout

@javascript  @enrollment_scenario @cross_browser

Scenario: A new user joins as mentor and mentee and tries to reuse the invite

  Given the current program is "primary":"albers"
  Then I want to join as "mentor__student" with "ron@test.com"
  And I open new mail
  And I follow "Complete Sign Up" in the email
  Then I should see "To join as Mentor and Student, complete and submit the form below."
  Then email should be filled with "ron@test.com" in landing page
  And I fill in the following details in membership request
  | FirstName       | Ron     |
  | LastName        | Weasley |
  | Password        | monkey  |
  | ConfirmPassword | monkey  |
  And I press "Submit"
  Then I should see "Welcome to Albers Mentor Program. Please complete your online profile to proceed."
  Then I should see "Basic Information"
  And I fill in "Phone" with "001-125845-78"
  And I fill in "Skype ID" with "Ron.Weasley"
  And I fill in "Location" with "Chennai, Tamil Nadu, India"
  And I press "submit_general"
  And I should see "Work and Education"
  And I should see "Click here to import your experience"
  Then I answer the education experience questions for "ron@test.com"
  And I press "Proceed"
  Then I should see "Mentoring Profile"
  And I press "Proceed"
  Then I should see "More Information"
  And I press "Proceed"
  Then I should see "More Information Students"
  And I press "Proceed"
  Then I should see "Mentoring Preferences"
  And I press "Proceed"
  Then I should see "Messages"
  Then I should see "All Activity"
  And I logout
  And I open the email with subject "Complete signing-up for Albers Mentor Program"
  And I follow "Complete Sign Up" in the email
  Then I should see "The signup code is invalid"

@javascript @enrollment_scenario

Scenario: A user who is already a mentor tries to sign up as mentor again

  Given the current program is "primary":"albers"
  Then I want to join as "Mentor" with "mentor_1@example.com"
  And I open new mail
  Then I should see "Sign in to Albers Mentor Program" in the email subject
  Then I should see "We noticed you already have login credentials." in the email body
  And I follow "Login to continue" in the email
  Then I should see "Login"

@javascript @enrollment_scenario

Scenario: A user who is already a mentee tries to sign up as mentee again.

  Given the current program is "primary":"albers"
  Then I want to join as "Student" with "rahim@example.com"
  And I open new mail
  Then I should see "Sign in to Albers Mentor Program" in the email subject
  Then I should see "We noticed you already have login credentials." in the email body
  And I follow "Login to continue" in the email
  Then I should see "Login"

@javascript @enrollment_scenario @cross_browser

Scenario: A user who is already a mentor/mentee tries to sign up for either role

  Then I want to join as "Student" with "mentrostud@example.com"
  And I open new mail
  Then I should see "Sign in to Albers Mentor Program" in the email subject
  Then I should see "We noticed you already have login credentials." in the email body
  And I follow "Login to continue" in the email
  Then I should see "Login"
  Then I want to join as "Mentor" with "mentrostud@example.com"
  And I open new mail
  Then I should see "Sign in to Albers Mentor Program" in the email subject
  Then I should see "We noticed you already have login credentials." in the email body

@javascript @enrollment_scenario @cross_browser

Scenario: Verify enrollment page checkbox

  Given the feature "enrollment_page" is enabled for "primary"
  Given the current program is "primary":"albers"
  And I have logged in as "userram@example.com"
  Then I visit the all programs listing
  Then I follow enrollment page link for "primary":"albers"
  Then the "student_role" checkbox_id should be checked


