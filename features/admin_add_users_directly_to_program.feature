Feature: Admin Should be able to view Add to program in all members listing page

Background: Admin logs in
    Given the current program is "primary":""
    And I have logged in as "ram@example.com"
    And I enable "organization_profiles" feature as a super user


@javascript @enrollment_scenario
  Scenario: Admin adds one user directly to program
    Given I reset the password for member with email "arun@albers.com"
    When I follow "Manage"
    And I follow "Member Views"
    Then I should see "Freakin Admin"
    Then I should see "ram@example.com"
    Then I should see "Albers Mentor Program" in the row "ct_admin_view_checkbox_40"
    Then I should see "Active"
    And I follow "Actions"
    Then I should see "Invite to Program"
    Then I should see "Add to Program"
    And I follow "Add to Program"
    Then I should see "Please select at least one user"
    Then I should not see "Student, Mentor" in the row "ct_admin_view_checkbox_40"
    Then I check "ct_admin_view_checkbox_40"
    And I follow "Actions"
    And I follow "Add to Program"
    Then I should see "Following member will be added to the program:"
    Then I should see "arun albers"
    And I press "Submit"
    Then I should see "Following member will be added to the program:"
    And I select "Project Based Engagement" from "admin_view_program_id"
    Then I check "Mentor"
    And I press "Submit"
    Then I should not see "Following member will be added to the program:"
    Then I should see "The selected user have been added to the program as Mentor successfully"
    Then I should see "Albers Mentor Program (Student)" in the row "ct_admin_view_checkbox_40"
    Then I should see "Project Based Engagement (Mentor)" in the row "ct_admin_view_checkbox_40"
    Then I logout
    When I open new mail
    Then I should see "You have been invited by Freakin Admin (Administrator) to join Project Based Engagement" in the email text part body
    Then I should see "It is important that you review and complete your profile." in the email text part body
    And I follow "Accept and sign up" in the email
    And I should see "Sign up with Password"

  @javascript @enrollment_scenario @cross_browser
  Scenario: Admin adds multiple user directly to program
    And I follow "Manage"
    And I follow "Member Views"
    Then I should see "Albers Mentor Program" in the row "ct_admin_view_checkbox_40"
    Then I should not see "Student, Mentor" in the row "ct_admin_view_checkbox_40"
    Then I should not see "Albers Mentor Program" in the row "ct_admin_view_checkbox_66"
    Then I check "ct_admin_view_checkbox_40"
    Then I check "ct_admin_view_checkbox_66"
    And I follow "Actions"
    And I follow "Add to Program"
    Then I should see "Following members will be added to the program:"
    Then I should see "arun albers, Assistant User"
    And I select "Project Based Engagement" from "admin_view_program_id"
    Then I check "Mentor"
    Then I check "Student"
    And I press "Submit"
    Then I should see "The selected users have been added to the program as Mentors, Students successfully"
    Then I should see "Mentor, Student" in the row "ct_admin_view_checkbox_40"
    Then I should see "Mentor, Student" in the row "ct_admin_view_checkbox_66"
    Then I should see "Project Based Engagement" in the row "ct_admin_view_checkbox_66"
    Then I logout

@javascript
  Scenario: Admin adds user directly to program from show page
    And I follow "Manage"
    And I follow "Member Views"
    And I follow "Assistant"
    Then I should see "Add User To Program"
    And I follow "Add User To Program"
    Then I should not see "Following member will be added to the program:"
    Then I should see "Assistant User"
    And I press "Submit"
    Then I should not see "Following member will be added to the program:"
    Then I check "Student"
    And I press "Submit"
    Then I should see "Student" within "div#profile_side_bar"
    Then I should see "The selected user have been added to the program as Student successfully"

    And I follow "Add User To Program"
    Then I should not see "Following member will be added to the program:"
    Then I check "Mentor"
    And I press "Submit"
    Then I should see "Student" within "div#profile_side_bar"
    Then I should see "Mentor" within "div#profile_side_bar"
    Then I should see "The selected user have been added to the program as Mentor successfully"

    And I follow "Add User To Program"
    Then I should not see "Following member will be added to the program:"
    Then I check "Mentor"
    Then I check "Student"
    And I press "Submit"
    Then I should see "Student" within "div#profile_side_bar"
    Then I should see "Mentor" within "div#profile_side_bar"
    Then I should see "The selected user have been added to the program as Mentor, Student successfully"
    Then I logout

@javascript @cross_browser
  Scenario: Admin adds user directly to program from show page with both roles
  And I follow "Manage"
  And I follow "Member Views"
  And I follow "Assistant"

  And I follow "Add User To Program"
  Then I should not see "Following member will be added to the program:"
  Then I check "Mentor"
  Then I check "Student"
  And I press "Submit"
  Then I should see "Mentor" within "div#profile_side_bar"
  Then I should see "Student" within "div#profile_side_bar"
  Then I should see "The selected user have been added to the program as Mentor, Student successfully"
  Then I logout