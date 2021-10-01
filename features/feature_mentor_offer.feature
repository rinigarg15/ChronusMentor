Feature: Mentor Offer
  In order to get connected to a mentee
  As an mentor
  I want to offer mentoring or add the mentee directly

@javascript
Scenario: Mentor adds a mentee as his mentee
    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    When I follow "Students"
    And I should not see "Offer Mentoring"
    Then I logout
    #Admin logs in
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    Then I login as super user
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Matching Settings"
    And I follow "Advanced Options"
    And Then I enable "offer_mentoring" feature
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Matching Settings"
    And I follow "Advanced Options"
    Then I should see "Mentor initiated offers need acceptance of students"
    And I should see the radio button "program_mentor_offer_needs_acceptance_true" selected
    Then I logout as super user
    Then I logout
     #Mentor logs in
    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    When I follow "Students"
    Then I offer mentoring for "arun albers" in mentees listing
    Then I should see "arun albers"
    Then I should see "Offer mentoring to arun albers"
    Then I logout

@javascript
Scenario: Mentor offers a mentoring offer and Mentee accepts the offer from mobile footer
    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    When I follow "Students"
    And I should not see "Offer Mentoring"
    Then I logout
    #Admin logs in
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    Then I login as super user
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Matching Settings"
    And I follow "Advanced Options"
    Then I should not see "Mentor initiated offers need acceptance of students"
    Then I login as super user
    And Then I enable "offer_mentoring" feature
    And I follow "Program Settings"
    And I follow "Matching Settings"
    And I follow "Advanced Options"
    Then I should see "Mentor initiated offers need acceptance of students"
    And I choose "program_mentor_offer_needs_acceptance_true" 
    And I press "Save"
    Then I logout as super user
    Then I logout
    #Mentor logs in - check for connection limit
    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    Then I follow "Edit Profile"
    And I follow "Settings"
    And I click on the section with header "Ongoing Mentoring"
    And I fill in "Connections Limit" with "1"
    Then I press "Save" within "#settings_section_ongoing"
    When I follow "Students"
    And I connect from users listing
    Then I should not see "Offer Mentoring"
    Then I go to the homepage
    Then I follow "Albers Mentor Program"
    Then I follow "Edit Profile"
    And I follow "Settings"
    And I click on the section with header "Ongoing Mentoring"
    And I fill in "Connections Limit" with "2"
    Then I press "Save" within "#settings_section_ongoing"

    When I follow "Students"
    Then I send a mentoring offer
    Then I follow "Mentors"
    Then I should see "Good unique name"
    And I should not see "Offer Mentoring"
    And I should not see "Add Good unique as Student"
    Then I follow "Good unique name"
    And I should not see "Offer Mentoring"
    And I should not see "Add Good unique as Student"
    Then I follow "Home"
    And I click ".pending_requests_notification_icon"
    Then I should not see "Mentoring Offers 1" within "#pending_requests_dropdown"
    Then I logout

    #Mentee Logs in
    Given the current program is "primary":"albers"
    When I have logged in as "arun@albers.com"
    Then I change to mobile view
    And I should see "Match"
    And I should see "2" within ".cjs_footer_total_requests"
    Then I click by xpath "//*[@id='page-wrapper']/nav[2]/div/div/div[1]/div[3]"
    And I follow "Mentoring Offers"
    And I should see "Received Mentoring Offers"
    And I should see "Good unique name"
    And I should see "Actions"
    And I follow "Actions"
    And I follow "Accept"
    And I should see "1" within ".cjs_footer_total_requests"
    And I logout

@javascript
Scenario: Mentor offers a mentoring offer and Mentee accepts the offer
    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    When I follow "Students"
    And I should not see "Offer Mentoring"
    Then I logout
    #Admin logs in
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    Then I login as super user
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Matching Settings"
    And I follow "Advanced Options"
    Then I should not see "Mentor initiated offers need acceptance of students"
    Then I login as super user
    And Then I enable "offer_mentoring" feature
    And I follow "Program Settings"
    And I follow "Matching Settings"
    And I follow "Advanced Options"
    Then I should see "Mentor initiated offers need acceptance of students"
    And I choose "program_mentor_offer_needs_acceptance_true" 
    And I press "Save"
    Then I logout as super user
    Then I logout
    #Mentor logs in - check for connection limit
    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    Then I follow "Edit Profile"
    And I follow "Settings"
    And I click on the section with header "Ongoing Mentoring"
    And I fill in "Connections Limit" with "1"
    Then I press "Save" within "#settings_section_ongoing"
    When I follow "Students"
    And I connect from users listing
    Then I should not see "Offer Mentoring"
    Then I go to the homepage
    Then I follow "Albers Mentor Program"
    Then I follow "Edit Profile"
    And I follow "Settings"
    And I click on the section with header "Ongoing Mentoring"
    And I fill in "Connections Limit" with "2"
    Then I press "Save" within "#settings_section_ongoing"

    When I follow "Students"
    Then I send a mentoring offer
    Then I follow "Mentors"
    Then I should see "Good unique name"
    And I should not see "Offer Mentoring"
    And I should not see "Add Good unique as Student"
    Then I follow "Good unique name"
    And I should not see "Offer Mentoring"
    And I should not see "Add Good unique as Student"
    Then I logout

    #Mentee Logs in
    Given the current program is "primary":"albers"
    When I have logged in as "arun@albers.com"
    And I accept the mentoring offer
    And I logout

@javascript
Scenario: Offer Mentoring should not be visible in ongoing mentoring disabled program in mentee lsiting
    Given the current program is "primary":"albers"
    And I enable "offer_mentoring" feature that was removed from UI as super user of "primary":"albers"
    When I have logged in as "robert@example.com"
    And I follow "Students"
    And I connect from users listing
    Then I should see "Offer Mentoring"
    And I change engagement type of program "primary":"albers" to "career based"
    And I follow "Students"
    And I connect from users listing
    Then I should not see "Offer Mentoring"

@javascript
Scenario: Offer Mentoring should not be visible in ongoing mentoring disabled program in mentee profile
    Given the current program is "primary":"albers"
    And I enable "offer_mentoring" feature that was removed from UI as super user of "primary":"albers"
    When I have logged in as "robert@example.com"
    And I follow "Students"
    And I follow "arun albers"
    And I open Actions from profile
    Then I should see "Offer Mentoring"
    And I change engagement type of program "primary":"albers" to "career based"
    And I follow "Students"
    And I follow "arun albers"
    And I open Actions from profile
    Then I should not see "Offer Mentoring"

@javascript
Scenario: Mentor with onetime mentoring mode cannot offer mentoring from Mentee listing and profile
    Given the current program is "primary":"albers"
    And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
    And I enable "offer_mentoring" feature that was removed from UI as super user of "primary":"albers"
    When I have logged in as "ram@example.com"
    When I login as super user
    And I follow "Manage"
    Then I follow "Program Settings"
    Then I follow "Matching Settings"
    Then I check "program_allow_mentoring_mode_change"
    And I press "Save"
    Then I logout as super user
    Then I logout
    When I have logged in as "robert@example.com"
    And I follow "Students"
    And I connect from users listing
    Then I should see "Offer Mentoring"
    And I change mentoring mode of mentor with email "robert@example.com" in program "primary":"albers" to "one time"
    And I follow "Students"
    And I connect from users listing
    Then I should not see "Offer Mentoring"
    And I change mentoring mode of mentor with email "robert@example.com" in program "primary":"albers" to "ongoing"
    And I follow "arun albers"
    And I open Actions from profile
    Then I should see "Offer Mentoring"
    And I change mentoring mode of mentor with email "robert@example.com" in program "primary":"albers" to "one time"
    And I follow "Students"
    And I follow "arun albers"
    And I open Actions from profile
    Then I should not see "Offer Mentoring"
