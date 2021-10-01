Feature: Test message for time zone fix
  Background: Set the program to albers
    Given the current program is "primary":"albers"
    
  @javascript @cross-browser
  Scenario: Hide of Time Zone Box should hide the box
    And I have logged in as "ram@example.com"
    And I hover over "my_profile"
    And I click on profile picture and click "Account Settings"
    Then I should not see "Your computer's time zone doesn't match your profile. Stay on top of your meetings and appointments by making them the same. You can also change these settings later through Account Settings."
    Then I follow "Home"
    Then I should see "Your computer's time zone doesn't match your profile. Stay on top of your meetings and appointments by making them the same. You can also change these settings later through Account Settings."
    Then I click ".hide_time_zone_alert_box"
    Then I should see "#cjs_display_time_zone_alert" hidden
    And I logout
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    Then I should see "#cjs_display_time_zone_alert" hidden
    And I clear the time zone cookie
    Then I follow "Home"
    Then I should see "Your computer's time zone doesn't match your profile. Stay on top of your meetings and appointments by making them the same. You can also change these settings later through Account Settings."
    And I logout

  @javascript @cross-browser
  Scenario: User selects a time zone and he doesn't see the time zone popup.
    And I have logged in as "ram@example.com"
    Then I should see "Your computer's time zone doesn't match your profile. Stay on top of your meetings and appointments by making them the same. You can also change these settings later through Account Settings."
    And I press "Use my device's time zone" within ".cjs_display_time_zone"
    Then I should see "#cjs_display_time_zone_alert" hidden 
    And I logout

  @javascript @not_run_on_bs
   Scenario: Member submits a time zone.
   # Time zone issue with remote browser usage
    And I have logged in as "ram@example.com"
    And I hover over "my_profile"
    And I click on profile picture and click "Edit Profile"
    Then I follow "Settings"
    And I press "Save" within "#settings_section_general"
    Then I follow "Home"
    Then I should see "Your computer's time zone doesn't match your profile. Stay on top of your meetings and appointments by making them the same. You can also change these settings later through Account Settings."
    Then I should see ".cjs_display_time_zone" not hidden
    Then I should see "(GMT+00:00) Etc/UTC" within "#profile_time_zone"
    And I press "Use my device's time zone" within ".cjs_display_time_zone"
    And I click on profile picture and click "Account Settings"
    Then I should see "Asia" selected from "#timezone_area"
    Then I should see "(GMT+05:30) Kolkata" selected from "#member_time_zone"
    And I logout