@admin_manage_draft_connections
Feature: Admin visits connections page, crate draft connections, publish, filter, edit and discard them
  In order to perform the above steps
  As an admin
  I want to login and enter the appropriate as required

  Background: Admin logs in
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"

  @javascript
  Scenario: Admin enables drafted connections and creates, discards, filters and edits connections
    When I select "Primary Organization" from the program selector
    And I select "Albers Mentor Program" from the program selector
    And I follow "Manage"
    And I follow "Connections"
    And I should see "Ongoing" within "li.ct_active"
    And I follow "Create New Mentoring Connection"
    And I fill in "group_name" with "drafted_group_1"
    And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>" within "#new_group"
    And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>" within "#new_group" 
    And I press "save_as_draft"
    And I should see "Create New Mentoring Connection" 
    And I should see "Drafted" within "li.ct_active"
    And I should see "drafted_group_1"
    And I follow "Publish Mentoring Connection"
    And I fill in "group_message" with "Test Message"
    And I press "Publish"
    And I should see "The mentoring connection has been published"
    And I should see "Drafted" within "li.ct_active"
    #select all
    Then I click "#cjs_groups_primary_checkbox"
    Then I follow "Actions"
    Then I follow "Discard Mentoring Connection"
    Then I should see "Are you sure you want to discard 3 mentoring connections? All information related to these mentoring connections will be removed."
    And I press "Discard"
    Then I should see "No Mentoring Connections found matching your criteria. You can try the following." in the xpath "//div[@id='group_elements' and @class='col-md-8 p-l-0']"
    Then I logout

  @javascript
  Scenario: Student in drafted connection looks for the drafted mentor in listing page
    #Admin enables 'Offer Mentoring' Feature
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Connection Settings"
    Then I should not see "Mentor Initiated offers need acceptance of students"
    Then I login as super user
    And Then I enable "offer_mentoring" feature
    And I logout
    #Student visiting his mentor according to drafted connection should not be able to see "Request Ongoing Mentoring/Your Mentoring Connection" links for his mentor in Drafted Connection
    And I have logged in as "student_1@example.com"
    When I navigate to "userrobert@example.com" profile in "albers"
    Then I should not see "Request Mentoring Connection"
    And I should not see "Your Mentoring Connection"
    And I follow "Mentors"
    Then I follow "Connect" in the users listing
    And I should see "Request Mentoring Connection"
    Then I fill in "sf_quick_search" with "Robert"
    And I press "Go"
    Then I remove the status filter
    Then I follow "Connect" in the users listing
    And I should not see "Request Mentoring Connection"
    And I should not see "Go to Mentoring Connection"
    And I logout
    And I have logged in as "userrobert@example.com"
    When I navigate to "student_1@example.com" profile in "albers"
    And I follow "Actions"
    Then I should not see "Offer Mentoring"
    And I should not see "Your Mentoring Connection"
    And I follow "Students"
    Then I follow "Connect" in the users listing
    And I should see "Offer Mentoring"
    Then I fill in "sf_quick_search" with "student_b"
    And I press "Go"
    Then I follow "Connect" in the users listing
    And I should see "Send Message"
    And I should not see "Offer Mentoring"
    And I should not see "Go to Mentoring Connection"
    And I logout

  @javascript @cross_browser
  Scenario: Admin enables drafted connections and creates, discards, filters and edits connections
    And I select "Primary Organization" from the program selector
    When I select "Albers Mentor Program" from the program selector
    And I follow "Manage"
    And I follow "Connections"
    And I should see "Ongoing" within "li.ct_active"
    And I follow "Drafted"
    And I should see "Drafted" within "li.ct_active"
    Then I follow "Publish Mentoring Connection" in the bulk actions
    Then I should see "Please select at least one mentoring connection"
    And I click "#cjs_groups_primary_checkbox"
    And I uncheck the group "drafted_group_1" in the listing
    Then I follow "Publish Mentoring Connection" in the bulk actions
    And I press "Publish"
    Then I should see "Mentoring Connections published successfully"
    And I click "#cjs_groups_primary_checkbox"
    Then I follow "Discard Mentoring Connection" in the bulk actions
    Then I should see "Are you sure you want to discard 1 mentoring connection"
    And I press "Discard"
    Then I should see "Mentoring Connections discarded successfully"
    Then I logout

   @javascript @p2
   Scenario: Admin views the drafted connection from the user profile
     When I select "Primary Organization" from the program selector
     When I select "Albers Mentor Program" from the program selector
     When I visit the profile of "userrobert@example.com"
     And I follow "Mentoring Connections (1)"
     Then I should see "Drafted (1)" within "div.inner_tabs"
     And I follow "Drafted (1)"
     Then I should see "user & example"
     Then I logout