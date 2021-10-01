# encoding: utf-8
Feature: Subprograms
  In order to facilitate subprograms
  As an admin
  I want to create and manage subprograms

@javascript
Scenario: Create a subprogram
    Given the current program is "foster":"main"
    And "Program" "term_downcase" is called as "community" in "foster"
    And "Program" "term" is called as "Community" in "foster"
    And I have logged in as "fosteradmin@example.com"
    And I follow "Manage"

    # Requires super login.
    Then I should not see "New Community"

    When I login as super user
    And I follow "Manage"
    Then I should see "New Community"

    When I follow "New Community"
    Then I should see the page title "Setup New Community"
    Then I fill in "program_name" with "2nd Year"
    And I fill in "program_description" with "Test description for new sub program"
    Then I choose "program_program_type_mentor"
    Then I follow "Next »"

    Then I choose "creation_way_0"
    Then I choose "program_engagement_type_1"
    Then I check "program_engagement_type"
    Then I check "cjs_mentee_can_request_mentor"
    And I choose "program_mentor_request_style_0"
    And I choose "program_allow_one_to_many_mentoring_false"
    Then I follow "Next »"

    # Step 2
    And I fill in "cur_prog_name" with "1st Year"
    And I fill in "org_name" with "Foster General Mentoring Program"
    And I press "Done"

    Then I should see the flash "The Community has been successfully setup!"
    And I should see the program title "2nd Year"

    Then I list all the programs
    Then I should see program selector containing "1st Year" under "Foster General Mentoring Program"
    And I should see program selector containing "2nd Year" under "Foster General Mentoring Program"

  @javascript
  Scenario: Creating sub program from Organization
    Given the current program is "annauniv":"psg"
    And "Program" "term_downcase" is called as "school" in "annauniv"
    And "Program" "term" is called as "School" in "annauniv"

    # Sub program admin cannot create another sub-program.
    And I have logged in as "psg@example.com"
    And I follow "Manage"
    Then I should not see "New School"

    # Come in as Anna Univ admin within PSG.
    When I logout
    And I have logged in as "ceg_admin@example.com"
    And I follow "Manage"
    Then I should not see "New School"

    # Switch to Anna Univ.
    When I select "Anna University" from the program selector
    And I follow "Manage"

    # Requires super login.
    Then I should not see "New School"

    When I login as super user
    And I follow "Manage"
    Then I should see "New School"

    When I follow "New School"
    Then I should see the page title "Setup New School"
    Then I fill in "program_name" with "MIT"
    And I fill in "program_description" with "Test description for new sub program"
    Then I choose "program_program_type_mentor"
    Then I follow "Next »"

    Then I choose "creation_way_0"
    Then I choose "program_engagement_type_1"
    Then I check "program_engagement_type"
    Then I check "cjs_mentee_can_request_mentor"
    And I choose "program_mentor_request_style_0"
    And I choose "program_allow_one_to_many_mentoring_false"
    # No Step 2.
    And I press "Done"

    Then I should see the flash "The School has been successfully setup!"
    And I should see the program title "MIT"

    Then I list all the programs
    Then I should see program selector containing "CEG Mentor Program" under "Anna University"
    And I should see program selector containing "psg" under "Anna University"
    And I should see program selector containing "MIT" under "Anna University"
  
  @javascript
  Scenario: Organization admin cannot create a subprogram when feature disabled
    Given the current program is "foster":"main"
    And "Program" "term" is called as "Community" in "foster"
    And I have logged in as "fosteradmin@example.com"
    And I follow "Manage"

    # Requires feature enabled.
    Then I should not see "New Community"

  @javascript @cross-browser
  Scenario: Organization admin can create a subprogram when feature enabled
    Given the current program is "foster":""
    And I have logged in as "fosteradmin@example.com"
    And I enable "subprogram_creation" feature as a super user
    And I follow "Manage"
    Then I should see "New Program"

    When I follow "New Program"
    Then I should see the page title "Setup New Program"
    And I should not see "If you wish, you can change the name and the web address below"
    And I should not see "Web address"
    Then I fill in "program_name" with "2nd Year"
    And I fill in "program_description" with "Test description for new sub program"
    And I choose "program_program_type_mentor"
    And I fill in "program_number_of_licenses" with "777"
    Then I follow "Next »"
    Then I should see "I will do it all by myself"
    Then I should see the radio button "creation_way_0" selected
    Then I should see "Engagement Type"
    Then I should see "Career Based"
    Then I should see "Project Based Engagements"
    And I choose "program_engagement_type_1"
    And I check "program_engagement_type"
    And I check "cjs_mentee_can_request_mentor"
    Then I choose "program_mentor_request_style_0"
    Then I choose "program_allow_one_to_many_mentoring_false"
    Then I follow "Next »"

    # Step 2
    And I fill in "cur_prog_name" with "1st Year"
    And I should not see "If you wish, you can change the name and the web address below"
    And I should not see "Web address"
    And I fill in "org_name" with "Foster General Mentoring Program"
    And I press "Done"

    Then I should see the flash "The Program has been successfully setup!"
    And I should see the program title "2nd Year"

    Then I list all the programs
    Then I should see program selector containing "1st Year" under "Foster General Mentoring Program"
    And I should see program selector containing "2nd Year" under "Foster General Mentoring Program"

@javascript @cross-browser
  Scenario: Manage a subprogram
    Given the current program is "annauniv":"psg"
    And "Program" "term" is called as "School" in "annauniv"

    When I have logged in as "ceg_admin@example.com"
    Then I follow "Manage"
    Then I should see "School Settings"
    And I should see "School Overview"
    And I should see "Administrator Inbox"
    And I should not see "Handbooks"

    When I login as super user
    When I select "Anna University" from the program selector
    Then I should see the program title "Anna University"
    When I follow "Manage"
    And I should see "School Settings"
    And I should see "Administrators"
    And I should see "School Branding"

    When I select "psg" from the program selector
    When I follow "Manage"
    And I follow "School Settings"
    Then I should see "General Settings"
    And I should see "Connection Settings"
    But I should see "Features"
    And I should see "Terminology"
    Then I fill in "program_name" with "GCT"
    And I press "Save"
    Then I should see the flash "Your changes have been saved"
    And I should see the program title "GCT"

    Then I list all the programs
    And I should see program selector containing "GCT" under "Anna University"

    When I follow "Connection Settings"
    And I fill in "program_mentoring_period_value" with "2"
    And I select "Days" from "program_mentoring_period_unit"
    And I press "Save"
    Then I should see the flash "Your changes have been saved. The duration of mentoring connection will be applied only to newly formed mentoring connections."


@javascript
  Scenario: Program Admin edits the "Allow the Mentors to choose the Engagement models" option.
    Given the current program is "annauniv":"psg"
    And "Program" "term" is called as "School" in "annauniv"
    When I have logged in as "ceg_admin@example.com"
    When I login as super user
    Then I follow "Manage"
    Then I follow "School Settings"
    Then I follow "Connection Settings"
    Then I should not see "Allow mentors to choose the Mentoring Connection mode"
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    Then I follow "Features"
    Then I check "mentoring_connections_v2"
    And I press "Save"
    Then I should see "Your changes have been saved"
    Then I follow "Matching Settings"
    Then I check "One-time Mentoring"
    Then I check "program_allow_mentoring_mode_change"
    And I press "Save"
    Then the "program_allow_mentoring_mode_change" checkbox_id should be checked
    Then I should see the flash "Your changes have been saved"

@javascript @cross-browser
  Scenario: Program Admin adds a subprogram admin and program admin
    Given the current program is "annauniv":"psg"
    And I have logged in as "ceg_admin@example.com"
    When I hover over "my_programs_container"
    And I select "Anna University" from the program selector
    Then I follow "Manage"
    Then I follow "Administrators"
    Then I click "a.dropdown-toggle.btn"
    Then I follow "Existing user as administrator"
    Then I fill in "member_name_with_email" with "PSG mentorb <mentor2@psg.com>"
    And I press "Add" within "#exisiting_user_to_admin"
    Then I should see the flash "PSG mentorb has been added to the list of administrators"
    And I should see "PSG mentorb" as an administrator in the organization

    When I hover over "my_programs_container"
    And I select "psg" from the program selector
    Then I follow "Manage"
    Then I follow "User Views"
    Then I filter table by "email" with "mentor3@psg.com"
    Then I check "cjs_admin_view_primary_checkbox"
    And I click on "cjs_add_role" in Actions
    Then I should see "What additional roles would you like to assign"
    And I check "Administrator"
    And I press "Submit"
    When I navigate to "mentor3@psg.com" profile in "psg"
    And I follow "Change Roles"
    Then I should see "Administrator"

  @javascript
  Scenario: Invite Mentors to Subprogram
    Given the current program is "annauniv":"psg"
    When I have logged in as "psg@example.com"
    Then I follow "Manage"
    Then I follow "Invitations"
    And I choose "role_assign_roles"
    And I check "Mentor"
    And I fill in "recipients" with "mentor_abc@example.com, mentor_xyz@chronus.com"
    And I press "Send Invites"
    Then I logout

    When I open new mail
    And I follow "Click here" in the email
    And I should see "Welcome! You have been invited to join psg as a Mentor."
    Then I fill in "member_first_name" with "mentor"
    Then I fill in "member_last_name" with "me"
    And I fill in "member_password" with "monkey"
    And I fill in "member_password_confirmation" with "monkey"
    And element with id "#member_email" should be disabled
    Then I valdiate and give my consent for terms and conditions by clicking "Sign up »"
    And I press "Sign up »"
    Then I should see the flash "Welcome to psg. Please complete your online profile to proceed."
    And I should not be shown program selector

  @javascript
  Scenario: Customize Mentor Profile Fields
    Given the current program is "annauniv":"psg"

    # Organization admin
    When I have logged in as "ceg_admin@example.com"
    When I select "Anna University" from the program selector
    Then I follow "Manage"
    Then I should not see "Mentor Profile Fields"
    And I should not see "Student Profile Fields"
    Then I select "psg" from the program selector
    And I logout

    # Sub program admin
    When I have logged in as "psg@example.com"
    Then I follow "Manage"
    Then I follow "Customize"
    Then I should see the page title "Customize User Profile Fields"
    And I should not see "profile fields of Anna University"
