@user
Feature: First visit experience for a user.
  To block user who has not filled his profile completely

Background:
  And I perform missed migrations
  
@javascript @cross-browser
Scenario: Mentor first login
    Given the current program is "primary":""
    When I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Customize Profile"
    And I edit the "default" section of "primary" title to "Basic Information" And description to "Default Edited description"
    And I logout

    Given the current program is "primary":"albers"
    Given the current program admin has added required questions for "mentor"
    Given the feature "Calendar" is enabled for "primary"
    Given the current program admin has enabled allow_mentor_to_configure_availability_slots in calendar_settings

    When Admin sends program invitation email to "sarat_new@example.com" as "mentor"
    When I open new mail
    And I follow "Click here" in the email

    And I should see "Welcome! You have been invited to join Albers Mentor Program as a Mentor."
    And element with id "#member_email" should be disabled
    And I fill in "member_first_name" with "mentor"
    And I fill in "member_last_name" with "me"
    And I fill in "member_password" with "monkey"
    And I fill in "member_password_confirmation" with "monkey"
    Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
    And I press "Sign up »"

    Then I should see the flash "Welcome to Albers Mentor Program. Please complete and publish your online profile to proceed."
    And I should see "Basic Information"
    And I should see "Default Edited description"

    And I should not see max_capacity settings
    And I should not see max_connections_limit
    And I should not see the tabs in program header
    And I should not see "Account Settings"
    And I should see "Contact Administrator"
    And I fill in "member_last_name" with "Henry"
    And I fill in "Phone" with "033024382947329"
    And I fill in "Skype ID" with "fura.rafa"
    And I fill in "Location" with "Chennai, Tamil Nadu, India"
    And I press "submit_general"

    And I should see "Work and Education" within "div#profile_completion"
    And I should not see the tabs in program header
    And I should see "Click here to import your experience"
    Then I answer the education experience questions for "sarat_new@example.com"
    And I save section with header "Work and Education"

    Then I in "60" seconds should see "Mentoring Profile" within "div#profile_completion"
    And I should not see "Account Settings"
    And I should see "Contact Administrator"
    And I fill in the extended profile fields "Whats your age?" for "mentor" with "21"
    And I save section with header "Mentoring Profile"
    And I should see "More Information" within "div#profile_completion"
    Then I scroll to bottom of page
    And I save section with header "More Information"
    And I should see "Mentoring Preferences" within "div#profile_completion"
    And I should see max_connections_limit
    And I fill in "max_connections_limit" with "2"
    And I should see max_capacity settings
    And I fill in "max_connections_limit" with "10"
    And I press "Proceed"
    And I should see "Home"

@javascript @cross-browser
Scenario: Mentor first login does not allowed changes for connection limit
    Given the current program is "primary":"albers"
    Given the current program admin has added required questions for "mentor"
    Given the current program admin has connection_limit_permission NONE
    Given the feature "Calendar" is enabled for "primary"
    Given the current program admin has enabled allow_mentor_to_configure_availability_slots in calendar_settings
    When I have logged in as "ram@example.com"
    And I logout

    When Admin sends program invitation email to "sarat_new@example.com" as "mentor"
    When I open new mail
    And I follow "Click here" in the email

    And I should see "Welcome! You have been invited to join Albers Mentor Program as a Mentor."
    And element with id "#member_email" should be disabled
    And I fill in "member_first_name" with "mentor"
    And I fill in "member_last_name" with "me"
    And I fill in "member_password" with "monkey"
    And I fill in "member_password_confirmation" with "monkey"
    Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
    And I press "Sign up »"

    Then I should see the flash "Welcome to Albers Mentor Program. Please complete and publish your online profile to proceed."
    And I should see "Basic Information" within "div#profile_completion"

    And I should not see max_capacity settings
    And I should not see the tabs in program header
    And I should not see "Account Settings"
    And I should see "Contact Administrator"
    And I fill in "member_last_name" with "Henry"
    And I fill in "Phone" with "033024382947329"
    And I fill in "Skype ID" with "fura.rafa"
    And I fill in "Location" with "Chennai, Tamil Nadu, India"
    And I press "submit_general"

    And I should see "Work and Education" within "div#profile_completion"
    And I should not see the tabs in program header
    And I should see "Click here to import your experience"
    Then I answer the education experience questions for "sarat_new@example.com"
    And I save section with header "Work and Education"

    Then I in "60" seconds should see "Mentoring Profile" within "div#profile_completion"
    And I should not see "Account Settings"
    And I should see "Contact Administrator"
    And I fill in the extended profile fields "Whats your age?" for "mentor" with "21"
    And I save section with header "Mentoring Profile"

    And I should see "More Information" within "div#profile_completion"
    And I save section with header "More Information"

    And I should see "Mentoring Preferences" within "div#profile_completion"
    And I should not see max_connections_limit
    And I should see max_capacity settings
    And I press "Proceed"
    And I should see "Home"

@javascript @cross-browser
Scenario: Mentor first login with availability_slots settings
    Given the current program is "primary":"albers"
    Given the current program admin has added required questions for "mentor"
    Given the feature "Calendar" is enabled for "primary"
    Given the current program admin has enabled allow_mentor_to_configure_availability_slots in calendar_settings
    When I have logged in as "ram@example.com"
    And I logout

    When Admin sends program invitation email to "sarat_new@example.com" as "mentor"
    When I open new mail
    And I follow "Click here" in the email

    And I should see "Welcome! You have been invited to join Albers Mentor Program as a Mentor."
    And element with id "#member_email" should be disabled
    And I fill in "member_first_name" with "mentor"
    And I fill in "member_last_name" with "me"
    And I fill in "member_password" with "monkey"
    And I fill in "member_password_confirmation" with "monkey"
    Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
    And I press "Sign up »"

    Then I should see the flash "Welcome to Albers Mentor Program. Please complete and publish your online profile to proceed."
    And I should see "Basic Information" within "div#profile_completion"

    And I should not see the tabs in program header
    And I should not see "Account Settings"
    And I should see "Contact Administrator"
    And I should not see max_capacity settings
    And I fill in "member_last_name" with "Henry"
    And I fill in "Phone" with "033024382947329"
    And I fill in "Skype ID" with "fura.rafa"
    And I fill in "Location" with "Chennai, Tamil Nadu, India"
    And I press "submit_general"

    And I should see "Work and Education" within "div#profile_completion"
    And I should not see the tabs in program header
    And I should see "Click here to import your experience"
    Then I answer the education experience questions for "sarat_new@example.com"
    And I save section with header "Work and Education"

    Then I in "60" seconds should see "Mentoring Profile" within "div#profile_completion"
    And I should not see "Account Settings"
    And I should see "Contact Administrator"
    And I fill in the extended profile fields "Whats your age?" for "mentor" with "21"
    And I save section with header "Mentoring Profile"

    And I should see "More Information" within "div#profile_completion"
    And I save section with header "More Information"

    And I should see "Mentoring Preferences" within "div#profile_completion"
    And I should see max_connections_limit
    And I should see max_capacity settings
    And I fill in "max_connections_limit" with "10"
    And I fill in Frequesny Slots with "10"
    And I should see "I would like to set specific dates and times"
    And I should see "My schedule varies"
    And I choose "true" value in "member"s radiobutton "will_set_availability_slots"
    And I should see "Add Timeslot"
    And I choose "false" value in "member"s radiobutton "will_set_availability_slots"
    And I should not see "Add Timeslot"
    And I press "Proceed"
    And I should see "Home"

@javascript @cross-browser
Scenario: Mentor first login does not allowed decreasing for connection limit
    Given the current program is "primary":"albers"
    Given the current program admin has added required questions for "mentor"
    Given the current program admin has connection_limit_permission ONLY_INCREASE
    Given the feature "Calendar" is enabled for "primary"
    Given the current program admin has enabled allow_mentor_to_configure_availability_slots in calendar_settings
    When I have logged in as "ram@example.com"
    And I logout

    When Admin sends program invitation email to "sarat_new@example.com" as "mentor"
    When I open new mail
    And I follow "Click here" in the email

    And I should see "Welcome! You have been invited to join Albers Mentor Program as a Mentor."
    And element with id "#member_email" should be disabled
    And I fill in "member_first_name" with "mentor"
    And I fill in "member_last_name" with "me"
    And I fill in "member_password" with "monkey"
    And I fill in "member_password_confirmation" with "monkey"
    Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
    And I press "Sign up »"

    Then I should see the flash "Welcome to Albers Mentor Program. Please complete and publish your online profile to proceed."
    And I should see "Basic Information" within "div#profile_completion"

    And I should not see max_capacity settings
    And I should not see the tabs in program header
    And I should not see "Account Settings"
    And I should see "Contact Administrator"
    And I fill in "member_last_name" with "Henry"
    And I fill in "Phone" with "033024382947329"
    And I fill in "Skype ID" with "fura.rafa"
    And I fill in "Location" with "Chennai, Tamil Nadu, India"
    And I press "submit_general"

    And I should see "Work and Education" within "div#profile_completion"
    And I should not see the tabs in program header
    And I should see "Click here to import your experience"
    Then I answer the education experience questions for "sarat_new@example.com"
    And I save section with header "Work and Education"

    Then I in "60" seconds should see "Mentoring Profile" within "div#profile_completion"
    And I should not see "Account Settings"
    And I should see "Contact Administrator"
    And I fill in the extended profile fields "Whats your age?" for "mentor" with "21"
    And I save section with header "Mentoring Profile"

    And I should see "More Information" within "div#profile_completion"
    And I save section with header "More Information"

    And I should see "Mentoring Preferences" within "div#profile_completion"
    And I should see max_connections_limit
    And I fill in "max_connections_limit" with "10"
    And I should see max_capacity settings
    And I press "submit_mentoring_settings_profile"
    And I should see "Home"