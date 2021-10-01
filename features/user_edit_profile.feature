  Feature: Customizes student and mentor profile

@javascript @cross-browser
Scenario: Mentor edits his profile
  Given the current program is "primary":"albers"
  And I have logged in as "robert@example.com"
  And I follow "Edit Profile"
  And I fill the answer "Phone" with "988425370"
  And I fill the answer "Skype ID" with "appy@skype.com"
  And I fill in "member_email" with "appy@gmail.com"
  And I press "Save"
  Then I should see "appy@gmail.com" score in the profile score box
  And I click on the section with header "Mentoring Profile"
  And I fill the answer "About Me" with "I am Appy"
  And I fill the answer "Expertise" with "I know stuff"
  And I save the section "Mentoring Profile"
  Then I should see "appy@gmail.com" score in the profile score box
  And I follow "Actions"
  Then I follow "View your Profile"

  And I should see "988425370"
  And I should see "appy@skype.com"
  And I should see "appy@gmail.com"
  And I should see "I am Appy"
  And I should see "I know stuff"
  And I follow "Actions"
  And I follow "Edit your Profile"

  And I follow "Settings"
  And I click on the section with header "Ongoing Mentoring"
  And I fill in "user_max_connections_limit" with "1"
  And I press "Save"
  Then I should see "Your changes have been saved"
  And I follow "Settings"
  And value of "#user_max_connections_limit" should be "1"
  And I fill in "user_max_connections_limit" with "0"
  And I press "Save" within "#settings_section_ongoing"
  Then I should see "Your mentoring connections limit cannot be less than 1 since you are already mentoring 1 student(s)."

@javascript @cross-browser
Scenario: Mentor edits profile with mentoring mode
  Given the current program is "primary":"albers"
  And I have logged in as "robert@example.com"
  And I follow "Edit Profile"
  And I follow "Settings"
  And I should not see "Both modes of Mentoring"
  And I logout
  And I have logged in as "ram@example.com"
  When I login as super user
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Then I follow "Manage"
  Then I follow "Program Settings"
  Then I follow "Matching Settings"
  Then I check "program_allow_mentoring_mode_change"
  And I press "Save"
  And I logout
  And I have logged in as "robert@example.com"
  And I follow "Edit Profile"
  And I follow "Settings"
  And I should see "Ongoing Mentoring"
  And I should see "One-time Mentoring"
  And I should see "Both modes"
  And I change the mentoring mode setting to "ongoing"
  And I press "Save"
  And I should see "You already have pending meeting request(s), Kindly reply to those first and then you can change the mentoring mode"
  And I follow "Settings"
  And I change the mentoring mode setting to "one_time"
  And I should see "You already have pending mentoring request(s), Kindly reply to those first and then you can change the mentoring mode"
  And I logout
  And I have logged in as "rahim@example.com"
  And I follow "Edit Profile"
  And I follow "Settings"
  And I should not see "One Time Mentoring"
  And I should not see "Both modes of Mentoring"
  And I logout

  When I have logged in as "mentor_3@example.com"
  And I follow "Edit Profile"
  And I follow "Settings"
  And I change the mentoring mode setting to "one_time"
  Then I should see "Your changes have been saved. Please set your availability for the selected mentoring mode(s)."

  When I fill in Frequesny Slots with "0"
  And I press "Save" within "#settings_section_onetime"
  And I change the mentoring mode setting to "both"
  Then I should see "Your changes have been saved. Please set your availability for the selected mentoring mode(s)."

  When I fill in Frequesny Slots with "5"
  And I press "Save" within "#settings_section_onetime"
  And I change the mentoring mode setting to "one_time"
  Then I should see "Your changes have been saved"
  And I should not see "Please set your availability for the selected mentoring mode(s)."

  When I change the mentoring mode setting to "both"
  And I fill in "user_max_connections_limit" with "0"
  And I press "Save" within "#settings_section_ongoing"
  And I change the mentoring mode setting to "ongoing"
  Then I should see "Your changes have been saved. Please set your availability for the selected mentoring mode(s)."

  When I fill in "user_max_connections_limit" with "3"
  And I press "Save" within "#settings_section_ongoing"
  And I change the mentoring mode setting to "both"
  Then I should see "Your changes have been saved"
  And I should not see "Please set your availability for the selected mentoring mode(s)."

@javascript @cross-browser
Scenario: Mentor edits profile with text-only field
  # Basic profile
  Given the current program is "primary":"main"
  Then I perform missed migrations
  And I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  Then I should see "Preview"
  And I should see "Customize"
  And I follow "Customize"

  And I open section with header "Basic Information"

  #Checking ordered option
  And I click on add new question

  And I fill in "profile_question_text_0" with "New Text Field"
  And I select "Text Entry" from "profile_question_question_type_0"
  And I check "profile_question_text_only_option"
 
  And I press "Save" within "form#edit_profile_question_"
  Then I wait for ajax to complete
  And I follow "Programs"
  Then I check "Mentor"
  And I set default visibility in program "primary"
  And I logout

  Given the current program is "primary":"albers"
  And I have logged in as "robert@example.com"
  And I follow "Edit Profile"
  And I fill the answer "New Text Field" with "test988"
  And I press "Save"
  Then I should see "cannot contain digits"
  And I fill the answer "New Text Field" with "test text type"
  And I press "Save"
  And I follow "Actions"
  And I follow "View your Profile"
  And I should see "test text type"
  And I logout

  # New section
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And I login as super user
  Given the current program is "primary":""
  And I follow "Manage"
  And I follow "Customize"

  And I click on add new section

  And I fill in "new_section_title_add_new_section_form" with "New Section"
  And I press "Save" within "form#add_new_section_form"

  And I click on the last section

  #Checking other option
  And I click on add new question

  And I fill in "profile_question_text_0" with "New Text Field"
  And I select "Text Entry" from "profile_question_question_type_0"
  And I should not see "allow_multiple"
  And I check "profile_question_text_only_option"

  And I press "Save" within "form#edit_profile_question_"
  Then I wait for ajax to complete
  And I configured question for "mentor" role in the program "primary" and set default visibility
  And I logout

  Given the current program is "primary":"albers"
  And I have logged in as "robert@example.com"
  And I follow "Edit Profile"
  And I click on the section with header "New Section"
  Then I should see "New Text Field"
  And I fill the answer "New Text Field" with "test988"
  And I save the section "New Section"
  Then I should see "cannot contain digits"
  And I fill the answer "New Text Field" with "test text type"
  And I save the section "New Section"
  And I follow "Actions"
  And I follow "View your Profile"
  And I should see "test text type"

  @javascript @cross-browser
  Scenario: Student answers a file type question
  Given the current program is "primary":"main"
  Then I perform missed migrations  
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Customize"
  And I open section with header "Basic Information"
  And I click on add new question

  And I fill in "profile_question_text_0" with "New File Type"
  And I select "Upload File" from "profile_question_question_type_0"
  And I press "Save" within "form#edit_profile_question_"
  Then I wait for ajax to complete
  And I follow "Programs"
  Then I check "Student"
  And I set default visibility in program "primary"
  And I logout

  Given the current program is "primary":"albers"
  Then I have logged in as "rahim@example.com"
  And I follow "Edit Profile"
  Then I make the question "New File Type" mandatory in "primary":"albers"
  Then I reload the page
  Then I should see "New mandatory fields have been added to the Basic Information section of the profile. Please fill them out to complete your profile."
  Then I should see submit button "Save & Proceed"
  And I press "Save & Proceed"
  And I should see the flash "Please fill the highlighted fields with appropriate values to proceed"
  Then I upload the file "some_file.txt" for the file type question "New File Type"
  Then I uncheck "some_file.txt"
  Then I should see ".ajax-file-uploader" not hidden
  And I press "Save & Proceed"
  And I should see the flash "Please fill the highlighted fields with appropriate values to proceed"
  Then I check "some_file.txt"
  And I press "Save & Proceed"
  And I click on the section with header "Basic Information"
  And the "some_file.txt" checkbox should be checked
  Then I uncheck "some_file.txt"
  Then I should see ".ajax-file-uploader" not hidden
  And I press "Save"
  And I should see the flash "Please fill the highlighted fields with appropriate values to proceed"
  Then I upload the file "handbook_test.txt" for the file type question "New File Type"
  Then I uncheck "handbook_test.txt"
  Then I should see ".ajax-file-uploader" not hidden
  And I press "Save"
  And I should see the flash "Please fill the highlighted fields with appropriate values to proceed"
  Then I check "handbook_test.txt"
  Then I should see ".ajax-file-uploader" hidden
  And I press "Save"
  Then I should see "Your changes have been saved"
  And I click on the section with header "Basic Information"
  And the "handbook_test.txt" checkbox should be checked

  @javascript @cross-browser
  Scenario: Student edits his basic profile
  Given the current program is "primary":"albers"
  And I have logged in as "rahim@example.com"
  And I follow "Edit Profile"
  Then I should see "rahim@example.com" score in the profile score box
  And I fill the answer "Phone" with "988425370"
  And I fill the answer "Skype ID" with "appy@skype.com"
  And I fill in "member_email" with "appy@gmail.com"
  And I press "Save"
  Then I should see "appy@gmail.com" score in the profile score box
  And I click on the section with header "Mentoring Profile"
  And I fill the answer "About Me" with "I am Appy"
  And I save the section "Mentoring Profile"

  Then I should see "appy@gmail.com" score in the profile score box
  And I click on the section with header "More Information Students"
  And I fill the answer "What is your hobby" with "Travelling, Chatting"

  And I save the section "More Information Students"
  Then I should see "appy@gmail.com" score in the profile score box
  And I follow "Actions"
  And I follow "View your Profile"
  And I should see "988425370"
  And I should see "appy@skype.com"
  And I should see "appy@gmail.com"
  And I should see "I am Appy"
  And I should see "Travelling, Chatting"

  @javascript @cross-browser
  Scenario: Mentor-Student edits his basic profile
  Given the current program is "primary":"albers"
  And I have logged in as "mentrostud@example.com"
  And I follow "Edit Profile"
  And I fill the answer "Phone" with "988425370"
  And I fill the answer "Skype ID" with "appy@skype.com"
  And I fill in "member_email" with "appy@gmail.com"
  And I press "Save"
  Then I should see "appy@gmail.com" score in the profile score box
  And I click on the section with header "Mentoring Profile"
  Then I should see "Please specify the areas in which you want to mentor"
  And I fill the answer "About Me" with "I am Appy"
  And I fill the answer "Expertise" with "I know stuff"
  And I save the section "Mentoring Profile"

  And I click on the section with header "More Information Students"
  And I fill the answer "What is your hobby" with "Travelling, Chatting"
  And I save the section "More Information Students"
  Then I should see "appy@gmail.com" score in the profile score box
  And I follow "Actions"
  And I follow "View your Profile"
  And I should see "988425370"
  And I should see "appy@skype.com"
  And I should see "appy@gmail.com"
  And I should see "I am Appy"
  And I should see "Travelling, Chatting"
  And I should see "I know stuff"
  And I follow "Actions"
  And I follow "Edit your Profile"

  And I follow "Settings"
  And I click on the section with header "Ongoing Mentoring"
  And I fill in "user_max_connections_limit" with "1"
  And I press "Save" within "#settings_section_ongoing"
  And I follow "Settings"
  And value of "#user_max_connections_limit" should be "1"

  @javascript @cross-browser
  Scenario: Mentee should be able to change password
    Given the current program is "primary":"albers"
    And I have logged in as "rahim@example.com"
    And I click on profile picture and click "Account Settings"
    And I fill in "member[current_password]" with "monkey"
    And I fill in "member[password]" with "NewPassword"
    And I fill in "member[password_confirmation]" with "NewPassword"
    And I follow "Change"
    Then I should see the flash "Your password has been successfully changed"

    And I logout
    And I follow "Login"
    And I fill in "email" with "rahim@example.com"
    And I fill in "password" with "NewPassword"
    And I press "Login"
    And I logout

  @javascript @cross-browser
  Scenario: Mentee should be able to change the notification settings from All to Aggregate
    Given the current program is "primary":"albers"
    And the notifications setting of "rahim@example.com" is "all"
    And I have logged in as "rahim@example.com"
    And I follow "Edit Profile"
    And I follow "Notifications" within "div#mentor_profile"
    And I change the notification setting to "aggregate"
    Then creating a new "mentee" announcement should not trigger a mail to "rahim@example.com"

  @javascript
  Scenario: Mentees logs out
    Given the current program is "primary":"albers"
    And I have logged in as "rahim@example.com"
    Then I logout
    Then I should see "Primary Organization"

  @javascript
  Scenario: Mentor should be able to change password
    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    And I click on profile picture and click "Account Settings"
    And I fill in "member[current_password]" with "monkey"
    And I fill in "member[password]" with "NewPassword"
    And I fill in "member[password_confirmation]" with "NewPassword"
    And I follow "Change"
    Then I should see the flash "Your password has been successfully changed"

    When I follow "Sign out"
    And I follow "Login"
    And I fill in "email" with "robert@example.com"
    And I fill in "password" with "NewPassword"
    And I press "Login"
    Then I should see "Sign out"

  @javascript
  Scenario: Mentor should be able to change the notification settings from All to Aggregate from "Edit Profile"
    Given the current program is "primary":"albers"
    And the notifications setting of "robert@example.com" is "all"
    And I have logged in as "robert@example.com"
    And I follow "Edit Profile"
    And I follow "Notifications" within "div#mentor_profile"
    And I change the notification setting to "aggregate"
    Then creating a new "mentor" announcement should not trigger a mail to "robert@example.com"

  @javascript
  Scenario: Mentor should be able to change the notification settings from All to Aggregate from "Account Settings" within a program
    Given the current program is "primary":"albers"
    And the notifications setting of "robert@example.com" is "all"
    And I have logged in as "robert@example.com"
    And I click on profile picture and click "Account Settings"
    And I should see "Settings: Primary Organization"
    And I should see "Settings: Albers Mentor Program"
    And I should not see "Settings: NWEN"
    And I edit the notification setting to "aggregate"
    Then creating a new "mentor" announcement should not trigger a mail to "robert@example.com"

  @javascript
  Scenario: Mentor should be able to change the notification settings from All to Aggregate from "Account Settings" from organization level
    Given the current program is "primary":""
    And the notifications setting of "robert@example.com" is "all"
    And I have logged in as "robert@example.com"
    And I click on profile picture and click "Account Settings"
    And I should see "Settings: Primary Organization"
    And I should see "Settings: Albers Mentor Program"
    And I should see "Settings: NWEN"
    And I click on the section with header "Settings: Albers Mentor Program"

    And I edit the notification setting to "aggregate"
    Then creating a new "mentor" announcement should not trigger a mail to "robert@example.com"

  @javascript @cross-browser
  Scenario: Uncheck weekly update checkbox
    Given the current program is "primary":"albers"
    And I have logged in as "rahim@example.com"
    And I click on profile picture and click "Account Settings"
    Then I should see "Activities related to my mentoring connections"
    And I should see "Program updates and activities"
    And I should see "Communication related to messages, meetings, requests, events and other updates will be sent each time there is activity"
    And I press "Save Settings" within ".program_settings"
    And I click on profile picture and click "Account Settings"
    And I should see "Get a notification each time there is activity"
    And I should see "Get a notification as part of the daily digest"
    And I should see "Get a notification as part of the weekly digest"

  @javascript
  Scenario: Mentor logs out
    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    Then I logout
    Then I should see "Primary Organization"

  @javascript @cross-browser
  Scenario: User fills in Other option for a question
    Given the current program is "primary":"main"
    Then I perform missed migrations
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    Then I should see "Preview"
    And I should see "Customize"
    And I follow "Customize"

    And I click on add new section

    And I fill in "new_section_title_add_new_section_form" with "New Section"
    And I press "Save" within "form#add_new_section_form"

    And I click on the last section

    #Checking other option
    And I click on add new question

    And I fill in "profile_question_text_0" with "New Other Field"
    And I select "Pick one answer" from "profile_question_question_type_0"
    And I should not see "allow_multiple"
    And I add choices "vatican,pope,rome"
    Then I check "profile_question_allow_other_option"
    When I scroll the div ".cjs-side-panel-slim-scroll"

    And I press "Save" within "form#edit_profile_question_"
    Then I wait for ajax to complete
    And I configured question for "mentor" role in the program "primary" and set default visibility
    And I logout

    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    And I follow "Edit Profile"


    And I click on the section with header "New Section"
    Then I should see "New Other Field"

    And I fill in other option with "italy"

    And I save the section "New Section"

    And I follow "Actions"
    Then I follow "View your Profile"
    Then I should see "New Other Field"
    And I should see "italy"

@javascript @cross-browser
  Scenario: Admin creates single choice type question and User fills in answers
    Given the current program is "primary":"main"
    Then I perform missed migrations
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    Then I should see "Preview"
    And I should see "Customize"
    And I follow "Customize"
     
    And I click on add new section
     
    And I fill in "new_section_title_add_new_section_form" with "New Section"
    And I press "Save" within "form#add_new_section_form"
     
    And I click on the last section
     
    #Checking single choice option
    And I click on add new question
     
    And I fill in "profile_question_text_0" with "New Single Choice"
    And I select "Pick one answer" from "profile_question_question_type_0"
    And I should not see "allow_multiple"
    And I add choices "male,female"
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save" within "form#edit_profile_question_"
    Then I wait for ajax to complete
    And I configured question for "mentor" role in the program "primary" and set default visibility
    And I logout

    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    And I follow "Edit Profile"
     
    And I click on the section with header "New Section"
    Then I should see "New Single Choice"
   
    And I select "male" from "New Single Choice"
       
    And I save the section "New Section"

@javascript @cross-browser
  Scenario: Admin creates ordered options type question and User fills in answers
    Given the current program is "primary":"main"
    Then I perform missed migrations
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    Then I should see "Preview"
    And I should see "Customize"
    And I follow "Customize"

    And I click on add new section

    And I fill in "new_section_title_add_new_section_form" with "New Section"
    And I press "Save" within "form#add_new_section_form"

    And I click on the last section

    #Checking ordered option
    And I click on add new question

    And I fill in "profile_question_text_0" with "New Other Field"
    And I select "Ordered Options" from "profile_question_question_type_0"
    And I add choices "vatican,pope,rome"
    Then I check "profile_question_allow_other_option"
    Then I set the focus to the main window
    And I select "2" options from "#profile_question_options_count_0"
    Then I wait for ajax to complete
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save" within "form#edit_profile_question_"
    Then I wait for ajax to complete
    And I follow "Definition"
    Then I should see "2" options selected for question "New Other Field"
    And I configured question for "mentor" role in the program "primary" and set default visibility

    Then I follow "Preview"
    And I follow "User Profile Form"
    And I check "Mentor"
    And I follow "Preview"
    Then I should see "New Other Field"
    And I select ordered options "pope" and "rome"

    And I logout

    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    And I follow "Edit Profile"


    And I click on the section with header "New Section"
    Then I should see "New Other Field"
    Then I select ordered options "Other..." and "vatican"

    And I save the section "New Section"
    Then I should see the flash "Please fill the highlighted fields with appropriate values to proceed"
    And I fill other field of index "0" with "davinci"
    And I save the section "New Section"

    And I follow "Actions"
    Then I follow "View your Profile"
    Then I should see "New Other Field"
    And I should see "vatican"
    And I should see "davinci"
    And I should not see "pope"
    And I follow "Actions"
    And I follow "Edit your Profile"

    And I click on the section with header "New Section"
    Then I should see "New Other Field"
    Then I select ordered options "pope" and "vatican"
    Then I select ordered options "Other..." and "vatican"
    Then I should not see "davinci"
    And I fill other field of index "0" with "davinci"
    And I save the section "New Section"

@javascript @cross-browser
  Scenario: Admin does not allow mentor to update max connection limit
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Matching Settings"
    And I uncheck "program_can_increase_connection_limit"
    And I uncheck "program_can_decrease_connection_limit"
    And I press "Save"
    And I logout
    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    And I click on profile picture and click "Account Settings"
    Then I should not see "Connections Limit"

@javascript
  Scenario: Users should be able to go back to previous url from profile page
    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    Then I should see "Students"
    When I follow "Students"
    Then I should see "arun albers"
    And I should see "Drafted User"
    When I follow "arun albers"
    Then I should see "arun albers's Profile"
    When I follow back link
    Then I should see "arun albers"
    And I should see "Drafted User"

  @javascript
  Scenario: Users should be able to go back to previous url from profile edit page
    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    And I follow "Edit Profile"
    Then I should see "Your Profile"
    When I follow back link
    Then I should see "My Activity"
    And I should see "All Activity"

@javascript
Scenario: Mentor should be able to set availability settings in settings page
  Given the current program is "primary":"albers"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I have logged in as "ram@example.com"
  And I allow mentors in the program to configure availability slots
  And I logout
  And I have logged in as "robert@example.com"
  And I remove all the existing mentoring slots for "robert@example.com"
  And I follow "Edit Profile"
  And I follow "Settings"
  And I click on the section with header "One-time Mentoring"
  Then the "member_will_set_availability_slots_false" checkbox_id should be checked
  Then member with email "robert@example.com" should not see no available timeslot message
  And I should not see "Add Timeslot"
  And I change meeting availability preference to configuring calendar slots
  Then I should see "Set Availability From Meetings Calendar"
  And I should see "I would like to set specific dates and times I am available"
  Then member with email "robert@example.com" should see no available timeslot message
  And I should see "Add Timeslot"
  When I press "Save"
  Then I should see "Your changes have been saved"

@javascript
Scenario: Mentor should be able to view and add and delete slots from settings page
  Given the current program is "primary":"albers"
  And I change meeting availability preference of member with email "robert@example.com" to configure availability slots
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I have logged in as "ram@example.com"
  And I allow mentors in the program to configure availability slots
  And I logout
  And I have logged in as "robert@example.com"
  And I remove all the existing mentoring slots for "robert@example.com"
  And I follow "Edit Profile"
  And I follow "Settings"
  And I click on the section with header "One-time Mentoring"
  Then the "member_will_set_availability_slots_true" checkbox_id should be checked
  Then I should see "Set Availability From Meetings Calendar"
  And I should see "I would like to set specific dates and times I am available"
  Then member with email "robert@example.com" should see no available timeslot message
  And I should see "Add Timeslot"
  When I follow "Add Timeslot"
  Then I should see "Availability Slot"
  When I press "Save" within "#availability_slot_form_container"
  Then I should see the flash "The availability slot has been created succesfully"
  And I should see "Not specified" within ".cjs_availability_slot_list"
  When I click ".delete_icon"
  Then I should see "Are you sure you want to delete the availability slot?"
  Then I press "OK"
  Then I should see the flash "The availability slot has been deleted succesfully"
  Then member with email "robert@example.com" should see no available timeslot message
  When I follow "Add Timeslot"
  And I select "Daily" from "mentoring_slot_repeats_every_option"
  And I fill in "mentoring_slot_end_datepicker" with a date "February 28, 2050"
  When I press "Save" within "#availability_slot_form_container"
  Then I should see the flash "The availability slot has been created succesfully"
  And I should see "Repeats daily until Feb 28, 2050" within ".cjs_availability_slot_list"
  When I click ".delete_icon"
  Then I should see "This is a recurrent availability slot. Deleting will delete all the occurences. Are you sure you want to continue?"
  Then I press "OK"
  Then I should see the flash "The availability slot has been deleted succesfully"
  Then member with email "robert@example.com" should see no available timeslot message
  When I follow "Add Timeslot"
  And I select "Weekly" from "mentoring_slot_repeats_every_option"
  And I check "S"
  And I check "M"
  And I fill in "mentoring_slot_location" with "I am available on skype"
  And I fill in "mentoring_slot_end_datepicker" with a date "February 28, 2050"
  Then I press "Save" within "#availability_slot_form_container"
  Then I check the content in mentoring slot list to be repeats "Su, Mo" until "Feb 28, 2050"
  And I should see "I am available on skype" within ".cjs_availability_slot_list"
  And I remove all the existing mentoring slots for "robert@example.com"
  When I follow "Add Timeslot"
  And I select "Monthly" from "mentoring_slot_repeats_every_option"
  And I fill in "mentoring_slot_location" with "I am available on phone"
  And I fill in "mentoring_slot_end_datepicker" with a date "February 28, 2060"
  Then I press "Save" within "#availability_slot_form_container"
  Then I should see "Repeats every month" within ".cjs_availability_slot_list"
  And I should see "I am available on phone" within ".cjs_availability_slot_list"

@javascript
Scenario: Mentor should be able to see only availability slots when general availability is disabled by admin
  Given the current program is "primary":"albers"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Given mentors in "primary":"albers" are allowed to configure only availability slots
  When I have logged in as "robert@example.com"
  And I follow "Edit Profile"
  And I follow "Settings"
  And I click on the section with header "One-time Mentoring"
  Then I should see "Add Timeslot"
  And I should not see "Set General Availability Guidelines"
  And I should not see "Set Availability From Meetings Calendar"
  When I follow "Add Timeslot"
  And I select "Daily" from "mentoring_slot_repeats_every_option"
  And I fill in "mentoring_slot_end_datepicker" with a date "February 28, 2050"
  When I press "Save" within "#availability_slot_form_container"
  Then I should see the flash "The availability slot has been created succesfully"
  And I should see "Repeats daily until Feb 28, 2050" within ".cjs_availability_slot_list"

@javascript
Scenario: Admin shouldn't be able to add timeslots in mentors profile page with out impersonation
  Given the current program is "primary":"albers"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Given mentors in "primary":"albers" are allowed to configure only availability slots
  When I have logged in as "ram@example.com"
  And I follow "Mentors"
  Then I should see "Good unique name"
  When I follow "Good unique name"
  Then I should see "Edit Good unique name's profile"
  When I follow "Edit Good unique name's profile"
  And I follow "Settings"
  Then I should not see "Add Timeslot"

@javascript
Scenario: Should not see the settings and notifications settings
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I login as super user
  And I click on profile picture and click "Edit Profile"
  Then I should see "Basic Information"
  Then I should not see "Time Zone"
  Then I should not see "Get a notification as part of the daily digest"
  And I follow "Settings"
  Then I should see "Time Zone"
  Then I should not see "Get a notification as part of the daily digest"
  Then I should not see "Basic Information"
  And I follow "Notifications" within "div#mentor_profile"
  Then I should see "Get a notification as part of the daily digest"
  Then I should not see "Time Zone"
  Then I should not see "Basic Information"
  And I logout

@javascript
Scenario: Should see the notification settings are saved
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I login as super user
  And I click on profile picture and click "Edit Profile"
  And I follow "Notifications" within "div#mentor_profile"
  And I click ".onoffswitch-label" within "#end_user_communication_switch"
  Then I reload the page
  And I follow "Notifications" within "div#mentor_profile"
  And I click on the section with header "Admin Notification Setting"
  Then I should see the toggle button "end_user_communication_switch .onoffswitch-checkbox" not selected
  Then I should see the toggle button "program_management_switch .onoffswitch-checkbox" selected
  Then I should see the toggle button "digest_and_alerts_switch .onoffswitch-checkbox" selected
  And I logout

@javascript
Scenario: Should not get email if notification setting is disabled
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I login as super user
  And I click on profile picture and click "Edit Profile"
  And I follow "Notifications" within "div#mentor_profile"
  And I click on the section with header "Administrator Notification Settings"
  And I click ".onoffswitch-label" within "#end_user_communication_switch"
  And I click ".onoffswitch-label" within "#program_management_switch"
  And I click ".onoffswitch-label" within "#digest_and_alerts_switch"
  And I logout
  Given the current program is "primary":"albers"
  And I have logged in as "rahim@example.com"
  And I follow "Contact Admin"
  And I fill in "admin_message_subject" with "Hello Admin"
  And I fill in "admin_message_content" with "Hoe are you?"
  And I press "Send Message"
  Then individual mails should go to "userram@example.com" having "Hoe are you"
  And I logout
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I login as super user
  And I click on profile picture and click "Edit Profile"
  And I follow "Notifications" within "div#mentor_profile"
  And I click on the section with header "Administrator Notification Settings"
  And I logout


@javascript
Scenario: Should get email if notification setting is not disabled
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I login as super user
  And I click on profile picture and click "Edit Profile"
  And I follow "Notifications" within "div#mentor_profile"
  And I click on the section with header "Administrator Notification Settings"
  And I logout
  Given the current program is "primary":"albers"
  And I have logged in as "rahim@example.com"
  And I follow "Contact Admin"
  And I fill in "admin_message_subject" with "Hello Admin"
  And I fill in "admin_message_content" with "Hoe are you?"
  And I press "Send Message"
  Then individual mails should go to "userram@example.com,ram@example.com" having "Hoe are you"
  And I logout
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I login as super user
  And I click on profile picture and click "Edit Profile"
  And I follow "Notifications" within "div#mentor_profile"
  And I click on the section with header "Admininistrator Notification Settings"
  And I logout
