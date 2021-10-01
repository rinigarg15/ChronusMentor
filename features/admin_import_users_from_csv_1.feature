@not_run_on_bs
Feature: User CSV Import at program level

Background:
  Given the current program is "primary":""
  When I have logged in as "ram@example.com"
  And I enable "user_csv_import" feature as a super user
  Then I set the focus to the main window

@javascript @not_run_on_bs
Scenario: Super user should be able to see user csv import in feature listing
# IE Driver issue with CSV mapping fields using select box
  Given the current program is "primary":"albers"
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Features"
  Then I should see "Import users from CSV"


@javascript @not_run_on_bs
Scenario: Invalid file and invalid role options will show error message at program level
  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from CSV"
  Then I should see "Add users from CSV"
  Then I should see "CSV File"
  Then I should see "Select Role"
  When I hover over "what_is_select_role" and should see "All the users added will be assigned the role selected below."
  Then I should see "Map a column in CSV"
  When I hover over "what_is_map_column_in_csv" and should see "You can map a column in CSV to roles and those roles will be assigned to the users added. Choose this option if your file includes multiple roles."
  Then I press "Continue"
  Then I should see "Please upload a valid csv file."
  Then I choose "Map a column in CSV"
  Then I press "Continue"
  Then I should see "Please upload a valid csv file."
  And I set the attachment field "user_import_csv" to "csv_import.csv"
  Then I choose "Select Role"
  Then I press "Continue"
  Then I should see "Please select a role or map role using csv."
  Then I choose "Select Role"
  Then I check "Mentor"
  Then I press "Continue"
  Then I should see "Please upload a valid csv file."
  And I set the attachment field "user_import_csv" to "pic_2.png"
  Then I choose "Map a column in CSV"
  Then I press "Continue"
  Then I should see "Please upload a valid CSV file. If you are using an Excel file, follow these instructions to convert the file into a CSV file."


@javascript @not_run_on_bs
Scenario: Invalid file will show error message at org level
  And I follow "Manage"
  And I follow "Add Users from CSV"
  Then I should see "Add users from CSV"
  Then I should see "CSV File"
  Then I should not see "Select Role"
  Then I should not see "Map a column in CSV"
  Then I press "Continue"
  Then I should see "Please upload a valid csv file."
  And I set the attachment field "user_import_csv" to "pic_2.png"
  Then I press "Continue"
  Then I should see "Please upload a valid CSV file. If you are using an Excel file, follow these instructions to convert the file into a CSV file."

@javascript @not_run_on_bs
Scenario: Upload file and map csv columns at prog level
  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Add Users"
  And I follow "Add users from CSV"
  Then I should see "Add users from CSV"
  And I set the attachment field "user_import_csv" to "csv_import.csv"
  Then I choose "Map a column in CSV"
  Then I press "Continue"
  Then I should see "Instructions"
  Then I should see "Map the columns from CSV to the fields in your program. Here are some tips:"
  Then I should see "Please note the program fields which are marked * must be present in the CSV."
  Then I should see "First Name *"
  Then I should see "Last Name *"
  Then I should see "Email *"
  Then I should see "Roles *"
  Then I should see ".cjs_optional_import_options" hidden
  Then I should see "First Name" within "#_csv_dropdown_0"
  Then I should see "Last Name" within "#_csv_dropdown_0"
  Then I should see "Email" within "#_csv_dropdown_0"
  Then I should see "Roles" within "#_csv_dropdown_0"
  Then I should see "Location" within "#_csv_dropdown_0"
  Then I should see "language" within "#_csv_dropdown_0"
  Then I should see "Select an imported field"
  Then I should see "First Name" within "#_csv_dropdown_1"
  Then I set the focus to the main window

  #Selecting Columns
  Then I select "First Name" from "[csv_dropdown][0]" 
  Then I wait for ajax to complete
  Then I should see "eg: Alan, Michael" within "div.example_text_for_dropdown_0"
  Then I should not see "First Name" within "#_csv_dropdown_1"
  Then I select "Select an imported field" from "[csv_dropdown][0]"
  Then I wait for ajax to complete
  Then I should see ".example_text_for_dropdown_0" hidden
  Then I should see "First Name" within "#_csv_dropdown_1"
  Then I select "First Name" from "[csv_dropdown][0]"
  Then I wait for ajax to complete
  Then I select "Last Name" from "[csv_dropdown][1]"
  Then I wait for ajax to complete
  Then I select "Email" from "[csv_dropdown][2]"
  Then I wait for ajax to complete
  Then I select "Roles" from "[csv_dropdown][3]"
  Then I wait for ajax to complete
  Then I should see ".cjs_optional_import_options" not hidden
  Then I select "Select an imported field" from "[csv_dropdown][0]"
  Then I wait for ajax to complete
  And element with id "#submit_columns_mapping_button" should be disabled
  Then I wait for ajax to complete
  Then I select "First Name" from "[csv_dropdown][0]"
  Then I wait for ajax to complete
  And element with id "#submit_columns_mapping_button" should not be disabled
  Then I should see "Language" within "#_profile_dropdown_4"
  Then I select "Language" from "[profile_dropdown][5]"
  Then I wait for ajax to complete
  Then I should not see "Language" within "#_profile_dropdown_4"
  Then I press "Continue"

  #Move Backwards
  Then I follow "Map Data"
  Then I should see "First Name" within "#_csv_dropdown_0"
  Then I should see "Last Name" within "#_csv_dropdown_1"
  Then I should see "Email" within "#_csv_dropdown_2"
  Then I should see "Roles" within "#_csv_dropdown_3"
  Then I should see "Location" within "#_csv_dropdown_4"
  Then I should see "language" within "#_csv_dropdown_5"
  Then I follow "Cancel"
  Then I should see "CSV File"

@javascript @not_run_on_bs
Scenario: Upload file and map csv columns at org level
  And I follow "Manage"
  And I follow "Add Users from CSV"
  Then I should see "Add users from CSV"
  And I set the attachment field "user_import_csv" to "csv_import.csv"
  Then I press "Continue"
  Then I should see "Instructions"
  Then I should see "Map the columns from CSV to the fields in your program. Here are some tips:"
  Then I should see "Please note the program fields which are marked * must be present in the CSV."
  Then I should see "First Name *"
  Then I should see "Last Name *"
  Then I should see "Email *"
  Then I should see ".cjs_optional_import_options" hidden
  Then I should see "First Name" within "#_csv_dropdown_0"
  Then I should see "Last Name" within "#_csv_dropdown_0"
  Then I should see "Email" within "#_csv_dropdown_0"
  Then I should see "Roles" within "#_csv_dropdown_0"
  Then I should see "Location" within "#_csv_dropdown_0"
  Then I should see "language" within "#_csv_dropdown_0"
  Then I should see "Select an imported field"
  Then I should see "First Name" within "#_csv_dropdown_1"

  #Selecting Columns
  Then I set the focus to the main window
  Then I select "First Name" from "[csv_dropdown][0]"
  Then I wait for ajax to complete
  Then I should see "eg: Alan, Michael" within "div.example_text_for_dropdown_0"
  Then I should not see "First Name" within "#_csv_dropdown_1"
  Then I select "Select an imported field" from "[csv_dropdown][0]"
  Then I wait for ajax to complete
  Then I should see ".example_text_for_dropdown_0" hidden
  Then I should see "First Name" within "#_csv_dropdown_1"
  Then I select "First Name" from "[csv_dropdown][0]"
  Then I wait for ajax to complete
  Then I select "Last Name" from "[csv_dropdown][1]"
  Then I wait for ajax to complete
  Then I select "Email" from "[csv_dropdown][2]"
  Then I wait for ajax to complete
  Then I should see ".cjs_optional_import_options" not hidden
  Then I select "Select an imported field" from "[csv_dropdown][0]"
  Then I wait for ajax to complete
  Then I should see ".cjs_optional_import_options" not hidden
  And element with id "#submit_columns_mapping_button" should be disabled
  Then I wait for ajax to complete
  Then I select "First Name" from "[csv_dropdown][0]"
  Then I wait for ajax to complete
  And element with id "#submit_columns_mapping_button" should not be disabled
  Then I should see "Language" within "#_profile_dropdown_4"
  Then I select "Language" from "[profile_dropdown][5]"
  Then I wait for ajax to complete
  Then I should not see "Language" within "#_profile_dropdown_4"
  Then I press "Continue"

  #Move Backwards
  Then I follow "Map Data"
  Then I should see "First Name" within "#_csv_dropdown_0"
  Then I should see "Last Name" within "#_csv_dropdown_1"
  Then I should see "Email" within "#_csv_dropdown_2"
  Then I should see "Roles" within "#_csv_dropdown_3"
  Then I should see "Location" within "#_csv_dropdown_4"
  Then I should see "language" within "#_csv_dropdown_5"
  Then I follow "Import Data"
  Then I should see "CSV File"

@javascript @not_run_on_bs
Scenario: Validation and import at program level
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
  Then I select "Language" from "[profile_dropdown][5]"
  Then I wait for ajax to complete
  Then I press "Continue"

  #Validation Information
  Then I should see "1 new user in Active state will be imported to your program"
  Then I should see "There are errors in 2 rows. They will be ignored and not imported."
  And I should see "Complete"
  And I should see "Cancel"

  #Viewing Errors
  Then I follow "errors in 2 rows"
  Then I should see "Records" within "div#remoteModal"
  Then I should see "michael@gmail.com"
  And I should see "steve@gmail.com"
  Then I hover over "3_0" and should see "is invalid"
  Then I close the qtip popup
  Then I should not see "Records"

  #View To be imported user data
  Then I follow "1"
  Then I should see "Records" within "div#remoteModal"
  Then I should see "alan@gmail.com"
  Then I should see "Download"
  Then I close the qtip popup
  Then I should not see "Records"
  Then I follow "Complete"
  # Then I should see "We're processing the data, please wait"
  Then I should see "The import has been successfully completed."
  Then mail should go to "alan@gmail.com" having "You have been invited by Freakin Admin \(Administrator\) to join Albers Mentor Program as a mentor"

  #Deactivate imported User and reimport profile should not throw any error
  Then I navigate to "alan@gmail.com" profile in "albers"
  Then I follow "Deactivate Membership"
  Then I should see "Reason *"
  Then I fill in "state_change_reason" with "Some Reason"
  Then I press "Deactivate"
  Then I should see "deactivated"

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
  Then I should see "Profile information for 1 user who is already part of this program will be updated"
  Then I should see "There are errors in 2 rows. They will be ignored and not imported."

  #Deactivated User
  Then I follow "1"
  Then I should see "Records" within "div#remoteModal"
  Then I should see "alan@gmail.com"
  Then I close the qtip popup
  Then I should not see "Records"

  #CSV Download
  Then I clear the downloads folder
  Then I follow "errors in 2 rows"
  Then I follow "Download"
  Then I wait for download to complete
  Then the csv must contain "michael@gmail.com" under "Email"
  Then the csv must contain "steve@gmail.com" under "Email"
  Then the csv must contain "Russia" under "Location"
  Then the csv must contain "Roles is invalid" under "Errors"

  #Existing Member Import as Org Admin should behave same irrespective of profile view permissions
  Given the current program is "primary":"nwen"
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
  Then I press "Continue"
  Then I should see "3 new users in Active state will be imported to your program"
  Then I logout

  #Existing Member Import as Track Admin with Profile view permissions set to No and Yes
  When I have logged in as "bdespota@example.com"
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
  Then I press "Continue"
  Then I should see "1 user who is part of the Primary Organization and not a part of this program will be invited"
  Then I follow "1"
  Then I should see "Records" within "div#remoteModal"
  Then I should see "alan@gmail.com"

  #Setting profile view permission to Yes
  And I give permission to admins in program "primary":"nwen"
  Then I reload the page
  Then I should see "3 new users in Active state will be imported to your program"
  Then I logout