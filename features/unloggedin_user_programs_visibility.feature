Feature: Unloggedin visit home page
Background: Admin logs in
   Given the current program is "primary":"org_primary"
   Then I should see "Programs"
   And I have logged in as "ram@example.com"

@javascript
Scenario: Unlogged in user should see programs tab if atleast one program is published

  Then I follow "Manage"
  Then I follow "Program Overview"
  Then I should see "Programs" within "li#programs a"
  Then I hover over "my_programs_container"
  Then I select "Albers Mentor Program" from the program selector
  Then I follow "Manage"
  Then I follow "Program Settings"
  And I choose "program_published_false"
  And I hover over "my_profile"
  And I press "Save"
  Then I should see "Your changes have been saved"
  And I hover over "my_profile"
  Then I follow "Sign out"
  Given the current program is "primary":"nomreqpro"
  Then I should see "Primary Organization"
  Given the current program is "primary":"org_primary"
  Then I should see "Programs"
  And I have logged in as "ram@example.com"
  Then I hover over "my_programs_container"
  Then I select "NWEN" from the program selector
  Then I follow "Manage"
  Then I follow "Program Settings"
  And I choose "program_published_false"
  And I press "Save"
  Then I should see "Your changes have been saved"

  Then I hover over "my_programs_container"
  Then I select "Moderated Program" from the program selector
  Then I follow "Manage"
  Then I follow "Program Settings"
  And I choose "program_published_false"
  And I press "Save"
  Then I should see "Your changes have been saved"
  Then I hover over "my_programs_container"
  Then I select "Project Based Engagement" from the program selector
  Then I follow "Manage"
  Then I follow "Program Settings"
  And I choose "program_published_false"
  And I press "Save"
  Then I should see "Your changes have been saved"
  And I hover over "my_profile"
  Then I follow "Sign out"
  Given the current program is "primary":"nomreqpro"
  Then I should see "Primary Organization"
  And I have logged in as "no_mreq_admin@example.com"
  Then I follow "Manage"
  Then I follow "Program Settings"
  And I choose "program_published_false"
  And I press "Save"
  Then I should see "Your changes have been saved"
  And I hover over "my_profile"
  Then I follow "Sign out"
  Given the current program is "primary":"nomreqpro"
  Then I should not see "Primary Organization"
  Given the current program is "primary":"org_primary"
  Then I should not see "Programs" within "#navbar"
  And I have logged in as "ram@example.com"
  Then I hover over "my_programs_container"
  Then I select "Albers Mentor Program" from the program selector
  Then I follow "Manage"
  Then I follow "Program Overview"
  Then I should not see "li#programs"