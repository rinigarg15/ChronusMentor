@not_run_on_bs


Feature: User CSV Import at Org Level and UUID check

Background:
  Given the current program is "primary":""
  Then I perform missed migrations
  When I have logged in as "ram@example.com"
  And I enable "user_csv_import" feature as a super user
  Then I set the focus to the main window

@javascript @not_run_on_bs
Scenario: Validation and import at org level including suspended users
  #First Time import
  # IE Driver issue with CSV mapping fields using select box
  And I follow "Manage"
  And I follow "Add Users from CSV"
  And I set the attachment field "user_import_csv" to "csv_import.csv"
  Then I press "Continue"

  Then I set the focus to the main window
  Then I should see "First Name" within "#_csv_dropdown_0"
  Then I select "First Name" from "[csv_dropdown][0]"
  Then I wait for ajax to complete
  Then I select "Last Name" from "[csv_dropdown][1]"
  Then I wait for ajax to complete
  Then I select "Email" from "[csv_dropdown][2]"
  Then I wait for ajax to complete
  Then I select "Language" from "[profile_dropdown][5]"
  Then I wait for ajax to complete
  Then I press "Continue"
  And I should see "Complete"
  And I should see "Cancel"
  Then I should see "3 new members will be imported to Primary Organization "
  Then I follow "3"
  Then I wait for ajax to complete
  Then I should see "Records"
  Then I should see "michael@gmail.com"
  Then I should see "alan@gmail.com"
  And I should see "steve@gmail.com"
  Then I close the qtip popup
  Then I should see "We are almost done"
  Then I follow "Complete"
  # Then I should see "We're processing the data, please wait"
  Then I should see "The import has been successfully completed."

  #On reimport profile has to be updated
  And I follow "Manage"
  And I follow "Add Users from CSV"
  And I set the attachment field "user_import_csv" to "csv_import.csv"
  Then I press "Continue"

  Then I set the focus to the main window
  Then I should see "First Name" within "#_csv_dropdown_0"
  Then I select "First Name" from "[csv_dropdown][0]"
  Then I wait for ajax to complete
  Then I select "Last Name" from "[csv_dropdown][1]"
  Then I wait for ajax to complete
  Then I select "Email" from "[csv_dropdown][2]"
  Then I wait for ajax to complete
  Then I select "Language" from "[profile_dropdown][5]"
  Then I wait for ajax to complete
  Then I press "Continue"
  Then I should see "Profile information for 3 members who are already part of Primary Organization will be updated"
  Then I follow "3"
  Then I should see "michael@gmail.com"
  Then I close the qtip popup
  Then I should see "We are almost done"
  Then I follow "Complete"
  Then I should see "The import has been successfully completed."

  #The member has to be in dormant state
  Then the state of "steve@gmail.com" should be dormant

  #On suspending shouldnt be able to add the user to any program

  And I suspend member with email "steve@gmail.com"
  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from CSV"
  And I set the attachment field "user_import_csv" to "csv_import.csv"
  Then I choose "Select Role"
  Then I check "Mentor"
  Then I press "Continue"

  Then I set the focus to the main window
  Then I should see "First Name" within "#_csv_dropdown_0"
  Then I select "First Name" from "[csv_dropdown][0]"
  Then I wait for ajax to complete
  Then I select "Last Name" from "[csv_dropdown][1]"
  Then I wait for ajax to complete
  Then I select "Email" from "[csv_dropdown][2]"
  Then I wait for ajax to complete
  Then I select "Roles" from "[csv_dropdown][3]"
  Then I wait for ajax to complete
  Then I press "Continue"
  Then I should see "1 user will not be imported as they are suspended from Primary Organization"
  Then I follow "1"
  Then I wait for ajax to complete
  Then I should see "steve@gmail.com"
  Then I logout

@javascript @not_run_on_bs
Scenario: Email Domain Restriction
  Given the current program is "primary":""
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  Then I follow "Security"
  And I fill in "organization_security_setting_attributes_email_domain" with "chronus.com"
  Then I press "Save"
  And I follow "Manage"
  And I follow "Add Users from CSV"
  And I set the attachment field "user_import_csv" to "csv_import.csv"
  Then I press "Continue"

  Then I set the focus to the main window
  Then I should see "First Name" within "#_csv_dropdown_0"
  Then I select "First Name" from "[csv_dropdown][0]"
  Then I wait for ajax to complete
  Then I select "Last Name" from "[csv_dropdown][1]"
  Then I wait for ajax to complete
  Then I select "Email" from "[csv_dropdown][2]"
  Then I wait for ajax to complete
  Then I select "Language" from "[profile_dropdown][5]"
  Then I wait for ajax to complete
  Then I press "Continue"
  Then I should see "There are errors in 3 rows. They will be ignored and not imported."
  When I follow "errors in 3 rows"
  Then I hover over "2_0" and should see "should be of chronus.com"
  Then I logout

@javascript @not_run_on_bs
Scenario: Education Experience Publication Upload File and Manager fields should not be mapped
  Given the current program is "primary":""
  Then I follow "Manage"
  And I follow "Customize"
  And I open section with header "Basic Information"
  And I click on add new question
  And I fill in "profile_question_text_0" with "Resume"
  And I select "Upload File" from "profile_question_question_type_0"
  And I press "Save" within "form#edit_profile_question_"
  Then I wait for ajax to complete
  And I check "Mentor"
  Given the current program is "primary":"albers"
  When I follow "Mentors"
  And I follow "Add Mentors Directly" for the group "action_1"
  And I fill in "user_email" with "NewMentor@iit.com"
  And I click "#cjs_add_user_next"
  Then I should see "Resume"
  And I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from CSV"
  Then I should see "Add users from CSV"
  And I set the attachment field "user_import_csv" to "csv_import.csv"
  Then I choose "Select Role"
  Then I check "Mentor"
  Then I press "Continue"
  Then I should see "Instructions"
  Then I should see "First Name" within "#_csv_dropdown_1"
  Then I set the focus to the main window
  Then I select "First Name" from "[csv_dropdown][0]"
  Then I wait for ajax to complete
  Then I select "Last Name" from "[csv_dropdown][1]"
  Then I wait for ajax to complete
  Then I select "Email" from "[csv_dropdown][2]"
  Then I wait for ajax to complete
  Then I should see ".cjs_optional_import_options" not hidden
  And I should not see "UUID" within "#_profile_dropdown_3"
  Then I should not see "Education" within "#_profile_dropdown_3"
  Then I should not see "Current Experience" within "#_profile_dropdown_3"
  Then I should not see "Current Publication" within "#_profile_dropdown_3"
  Then I should not see "Current Manager" within "#_profile_dropdown_3"
  Then I should not see "Work" within "#_profile_dropdown_3"
  Then I should not see "Upload File" within "#_profile_dropdown_3"
  Then I logout

@javascript @not_run_on_bs
Scenario: UUID has to be unique
  Given the current program is "primary":"albers"
  And I login as super user
  And I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from CSV"
  And I set the attachment field "user_import_csv" to "csv_import.csv"
  Then I choose "Map a column in CSV"
  Then I press "Continue"

  Then I set the focus to the main window
  Then I should see "First Name" within "#_csv_dropdown_0"
  Then I select "First Name" from "[csv_dropdown][0]"
  Then I wait for ajax to complete
  Then I select "Last Name" from "[csv_dropdown][1]"
  Then I wait for ajax to complete
  Then I select "Email" from "[csv_dropdown][2]"
  Then I wait for ajax to complete
  Then I select "Roles" from "[csv_dropdown][3]"
  Then I wait for ajax to complete
  Then I select "UUID" from "[profile_dropdown][6]"
  Then I wait for ajax to complete
  Then I press "Continue"
  Then I should see "We are almost done"
  Then I should see "1 new user in Active state will be imported to your program"
  Then I should see "There are errors in 2 rows. They will be ignored and not imported."
  Then I follow "errors in 2 rows"
  Then I should see "Records" within "div#remoteModal"
  Then I hover over "6_0" and should see "has to be unique."
  Then I hover over "6_1" and should see "has to be unique."
  Then I close the qtip popup
  Then I should not see "Records"
  Then I follow "1"
  Then I should see "Records" within "div#remoteModal"
  Then I should see "alan@gmail.com"
  Then I should see "Download"
  Then I close the qtip popup
  Then I should see "We are almost done"
  Then I follow "Complete"
  # Then I should see "We're processing the data, please wait"
  Then I should see "The import has been successfully completed."
  Then mail should go to "alan@gmail.com" having "You have been invited by Freakin Admin \(Administrator\) to join Albers Mentor Program as a mentor"
  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from CSV"
  And I set the attachment field "user_import_csv" to "csv_import.csv"
  Then I choose "Map a column in CSV"
  Then I press "Continue"

  Then I set the focus to the main window
  Then I should see "First Name" within "#_csv_dropdown_0"
  Then I select "First Name" from "[csv_dropdown][0]"
  Then I wait for ajax to complete
  Then I select "Last Name" from "[csv_dropdown][1]"
  Then I wait for ajax to complete
  Then I select "Email" from "[csv_dropdown][2]"
  Then I wait for ajax to complete
  Then I select "Roles" from "[csv_dropdown][3]"
  Then I wait for ajax to complete
  Then I select "UUID" from "[profile_dropdown][6]"
  Then I wait for ajax to complete
  Then I press "Continue"
  Then I should see "We are almost done"
  #Then I should see "Profile information for 1 user who is already part of this program will be updated"
  Then I should see "There are errors in 2 rows. They will be ignored and not imported."
  Then I follow "errors in 2 rows"
  Then I should see "Showing" within "div#remoteModal"
  Then I hover over "6_0" and should see "has to be unique."
  Then I hover over "6_1" and should see "has to be unique."
  Then I close the qtip popup
  Then I logout

@javascript @not_run_on_bs
Scenario: Mandatory Fields if not filled the user should be imported to Unpublished state
  Given the current program is "primary":""
  Given there are some mandatory multiple experience fields
  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from CSV"
  And I set the attachment field "user_import_csv" to "csv_import.csv"
  Then I choose "Map a column in CSV"
  Then I press "Continue"

  Then I set the focus to the main window
  Then I should see "First Name" within "#_csv_dropdown_0"
  Then I select "First Name" from "[csv_dropdown][0]"
  Then I wait for ajax to complete
  Then I select "Last Name" from "[csv_dropdown][1]"
  Then I wait for ajax to complete
  Then I select "Email" from "[csv_dropdown][2]"
  Then I wait for ajax to complete
  Then I select "Roles" from "[csv_dropdown][3]"
  Then I wait for ajax to complete
  Then I press "Continue"
  Then I should see "1 new user in Unpublished state"
  When I hover over "unpublished_help_text" and should see "These users will be in Unpublished state as mandatory profile fields are missing"
  Then I logout
