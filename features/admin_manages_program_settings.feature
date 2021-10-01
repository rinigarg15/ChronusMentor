Feature: revamped Program Settings Tab

Background: Admin logs in
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I should see "General Settings"
  And I should see "Membership"
  And I should see "Matching Settings"
  And I should see "Mentoring Connection Settings"
  And I should see "Permissions"


@javascript
Scenario: Matching Settings
  And I follow "Matching Settings"
  When I hover over "connection_limit_help_text" and should see "Limit includes students with whom they are connected as well as students whose request to connect are pending"
  And I should see "Mentoring Mode"
  And I should see "Select the mentoring modes for your program"
  And I should see "Ongoing Mentoring"
  And I should see "In this mode, participants will be part of a mentoring connection for a period of time and will share a mentoring space"
  And I should see "One-time Mentoring"
  And I should see "In this mode, participants set up single meetings"
  And I should see "Ongoing Mentoring Settings "
  And I should see "How does matching happen?"
  And I should see "Students send mentoring requests to mentors "
  And I should see "Mentors offer mentoring to students"
  And I should see "Administrators assign mentoring connections"
  And I should see "Mentoring Connection Settings "
  And I should see "Maximum pending requests allowable from a student"
  And I should see "Remind the receiver if requests are pending"
  And I should see "Close requests if pending more than"
  And I should see "Leave this blank if you don't want to close requests automatically "
  And I should see "days"
  And I should see "Advanced Options"
  And I should see "Mentoring Connection Limits"
  And I should see "Maximum concurrent students for a mentor"
  And I should see "Allow mentors to increase their mentoring connection limits "
  And I should see "Allow mentors to decrease their mentoring connection limits "
  And I should see "Maximum concurrent mentors for a student"
  Then I open advanced options setting section
  And I should see "Allow students to send requests for mentoring"
  And I should see "Allow students to withdraw request for mentoring"
  And I click ".cjs_matching_ongoing_advanced_setting_toggle"
  And I should not see "Allow mentors and students with 0% match-scores to connect"
  And I should not see "Message when match score is 0%"
  And I should not see "Mentor is students manager"
  And I should not see "Restrict upto"
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  Then I follow "Advanced Options"
  And I should see "Allow mentors and students with 0% match-scores to connect"
  And I should see "Message when match score is 0%"
  And I hover over "not_a_match_help_text" and should see "'Not a Match' will still appear for users with 0% score. Upon hover, your custom message will display."
  And I should see "Mentor is students manager"
  And I should see "Restrict upto"

@javascript
Scenario: Program with mentoring mode as not mentee directly requesting mentor should not see reminder in Matching Settings
  Given the current program is "annauniv":"psg"
  And I have logged in as "psg@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I should see "Mentoring Mode"
  And I should see "Select the mentoring modes for your program"
  And I should see "Ongoing Mentoring"
  And I should not see "Remind the receiver if requests are pending"

@javascript
Scenario: Matching settings for project based program
  Given the current program is "primary":"pbe"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I should see "Mentoring Connection Limits"
  And I select "10 mentoring connections" from "Maximum number of mentoring connections a mentor can join"
  And I select "7 mentoring connections" from "Maximum number of mentoring connections a student can join"
  And I press "Save"
  Then I should see the flash "Your changes have been saved"

@javascript
Scenario: Matching setting should be visible to flash only programs
  And I login as super user
  Then I disable ongoing engagement mode for "primary":"albers"
  And I follow "Manage"
  And I follow "Program Settings"
  Then I follow "Matching Settings"
  And I should see "Allow mentors and students with 0% match-scores to connect"
  Then I should see "Message when match score is 0%"
  And I should not see "Ongoing Mentoring Settings"
  Then I logout

@javascript
Scenario: Enable third role for a program
  And I should not see "Enable third role"
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I should see "Enable third role"
  And I should not see "Click here to customize the term for third role. The current term is 'Teacher'."
  Then I should see the radio button "program_third_role_enabled_false" selected
  Then I click "#program_third_role_enabled_true"
  And I press "Save"
  Then I should see the flash "The third role has been added. Click here to customize the term for third role. Other changes also have been saved."
  Then I should see the radio button "program_third_role_enabled_true" selected
  And I should see "Click here to customize the term for third role."
  And I follow "Click here"
  And I should see "Term for Teacher"

@javascript
Scenario: Disable third role for a program
  Given the current program is "primary":"pbe"
  And I follow "Manage"
  And I follow "Program Settings"
  And I should not see "Enable third role"
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I should see "Enable third role"
  Then I should see the radio button "program_third_role_enabled_true" selected
  And element with id "#program_third_role_enabled_false" should be disabled
  Then I hover over "info-circle" icon
  Then I should see "Role cannot be removed as the role has associated users" within ".tooltip"
  Then I stub "can_be_removed?" for "Role" as "boolean" value "true"
  And I reload the page
  And element with id "#program_third_role_enabled_false" should not be disabled
  Then I click "#program_third_role_enabled_false"
  Then I stub "can_be_removed?" for "Role" as "boolean" value "false"
  And I press "Save"
  And I should see the flash "Failed to remove third role."
  Then I stub "can_be_removed?" for "Role" as "boolean" value "true"
  And I follow "Manage"
  And I follow "Program Settings"
  Then I click "#program_third_role_enabled_false"
  And I press "Save"
  And I should see the flash "The role 'Teacher' has been removed from the program. Other changes also have been saved."
  Then I should see the radio button "program_third_role_enabled_false" selected

@javascript
Scenario: Update banner logo for a program
  Then I set the "banner" for the "Program" with name "Albers Mentor Program" to "pic_2.png"
  Then I set the "logo" for the "Program" with name "Albers Mentor Program" to "test_pic.png"
  And I login as super user
  And I follow "Program Settings"
  And I should see "pic_2.png" within "#banner_dropzone_file_preview_element"
  And I should see "test_pic.png" within "#program_logo_dropzone_file_preview_element"
  And I click ".remove-file-name" within "#banner_dropzone_file_preview_element"
  And I should see "Are you sure you want to remove?"
  And I confirm popup
  And I should see "#banner_dropzone_file_preview_element" hidden
