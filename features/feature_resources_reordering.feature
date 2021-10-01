Feature: Resources feature

Background: Admin logs in
  Given the current program is "primary":""

  @javascript @cross-browser
  Scenario: Create/Edit/Delete Resources

    And I have logged in as "ram@example.com"
    And I follow "Manage"
    Then I should see "Resources"
    And I follow "Resources"

    # Make a Resource QuickLink
    And I follow "Working with the Mentoring Connection Plan"
    And I follow "Edit resource"
    And I check "Moderated Program"
    And I check "Mentor"
    And I check "Albers Mentor Program"
    And I press "Save"

    # Create
    And I follow "Add new resource"
    And I fill in "Title" with "body"
    And I fill in CKEditor "resource_content" with "This is the first message"
    And I press "Publish"
    Then I should see "The resource has been successfully published"

    #Edit
    Then I follow "body"
    Then I should see "Edit resource"
    And I follow "Edit resource"
    And I fill in CKEditor "resource_content" with "This is the edited message"
    Then I press "Save"
    Then I should see "The resource has been successfully updated."

    #Delete
    And I follow "Add new resource"
    And I fill in "Title" with "dummy"
    And I fill in CKEditor "resource_content" with "This is the dummy message"
    And I press "Publish"
    Then I should see "The resource has been successfully published"
    Then I follow "dummy"
    And I click "#action_1 .dropdown-toggle"
    Then I should see "Delete resource"
    And I follow "Delete resource"
    Then I should see "Are you sure you want to delete this resource?"
    And I confirm popup
    Then I should see "The resource has been successfully removed"

    # track level resource
    And I follow "Home"
    Then I follow "Albers Mentor Program"
    Then I should see "Resources"
    And I follow "Resources"
    Then I should see "Global resource"
    Then I should see "Working with the Mentoring Connection Plan"
    Then I should see "0 Views"
    And I follow "Working with the Mentoring Connection Plan"
    And I follow "Edit resource"
    And I check "Mentor"
    And I press "Save"

    #Add track level resource
    And I click "#action_1 .dropdown-toggle"
    And I follow "Add new resource"
    And I fill in "Title" with "Track Res"
    And I fill in CKEditor "resource_content" with "This is the track level resource"
    And I press "Publish"
    Then I should see "The resource has been successfully published"
    And I logout

    # end user
    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    Then I follow "Resources" tab
    Then I should see "Working with the Mentoring Connection Plan"
    Then I should see "Track Res"
    When I follow "Track Res"
    Then I should see "This is the track level resource"
    Then I should see "Was this resource helpful?"
    And I follow "No"
    Then I should see "Sorry about that!"
    Then I fill in "resource_rating" with "Start working right away"
    And I press "Submit"
    Then a mail should go to "userram@example.com" having "Start working right away"
    And I should see "Was this resource helpful?"
    And I should see "No"
    Then I reload the page
    Then I should see "Was this resource helpful?"
    And I follow "Yes"
    Then I should see "Thank You!"
    And I should see "Have a question?"
    When I follow "Have a question?"
    Then I fill in "resource_question" with "resource not helpful"
    And I press "Submit"
    Then a mail should go to "userram@example.com" having "resource not helpful"
    When I follow back link
    Then I should see "Working with the Mentoring Connection Plan"
    Then I should see "Track Res"
    And I should not see "dummy"
    And I follow "body"
    Then I should see ".actions_1" hidden
    And I should see "This is the edited message"
    And I should not see "Add new resources"
    And I should not see "Reorder resources"
    And I logout

    # admin sees incremented view
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    Then I should see "Resources" within "ul#side-menu"
    And I follow "Resources"
    And I should see "Track Res" within "ul#side-menu"
    And I follow "View All"
    Then I should see "Track Res"
    Then I should see "1 View"
    Then I should see "1 marked helpful"
    And I logout

  @javascript
  Scenario: Create Resources at program level validations
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I follow "Resources"
    And I follow "Actions"
    And I follow "Add new resource"
    And I uncheck "Mentor"
    And I uncheck "Student"
    And I uncheck "User"
    And I fill in "Title" with "Resource for none"
    Then I choose radio button with label "None"
    And I fill in CKEditor "resource_content" with "This is the first message"
    And I press "Publish"
    And I should see "Please fill all the required fields. Fields marked * are required"
    And I check "User"
    And I press "Publish"
    And I should not see "Please fill all the required fields. Fields marked * are required"
    Then I should see "Resource for none"
    And I follow "Resources"
    And I follow "Actions"
    And I follow "Add new resource"
    And I uncheck "Mentor"
    And I uncheck "Student"
    And I uncheck "User"
    And I check "User"
    And I fill in "Title" with "Resource for pin to view"
    And I fill in CKEditor "resource_content" with "This is the first message"
    When I select "All Mentors" view as user set for resource
    Then I should see "23"
    And I should see "Mentor"
    And I should see "View Users"
    And I should see "Edit View"
    Then I scroll to bottom of page
    Then I click on input by value "Publish"
    #Then I click "#cjs_submit_resources"
    And I should not see "Please fill all the required fields. Fields marked * are required"
    Then I should see "successfully published"
    Then I scroll to bottom of page
    Then I should see "Resource for pin to view"
    And I follow "Resources"
    And I follow "Actions"
    And I follow "Add new resource"
    And I uncheck "Mentor"
    And I uncheck "Student"
    And I check "User"
    And I fill in "Title" with "Resource for admin view"
    And I fill in CKEditor "resource_content" with "This is the first message"
    And I choose radio button with label "None"
    And I press "Publish"
    And I should not see "Please fill all the required fields. Fields marked * are required"
    Then I should see "Resource for admin view"
    And I logout

  @javascript
  Scenario: Member redirected to external URL when clicking on have a question?
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I login as super user
    And I follow "Manage"
    And I follow "Customize Contact Administrator Settings"
    Then I should see "Contact Administrator Settings"
    And I choose "contact_external_link"
    And I press "Save"
    Then I should not see "Settings have been saved successfully"
    And I fill in "contact_admin_setting_contact_url" with "http://www.google.com"
    And I press "Save"
    Then I should see "Settings have been saved successfully"
    And I follow "Manage"
    Then I should see "Resources"
    And I follow "Resources"
    And I click "#action_1 .dropdown-toggle"
    And I follow "Add new resource"
    And I fill in "Title" with "Track Res"
    And I fill in CKEditor "resource_content" with "This is the track level resource"
    And I press "Publish"
    Then I should see "The resource has been successfully published"
    And I logout
    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    Then I follow "Resources" tab
    Then I should see "Track Res"
    When I follow "Track Res"
    Then I should see "This is the track level resource"
    And I should see "Have a question?"
    When I follow "Have a question?"
    Then I should not see "Ask a Question"