@reindex
Feature: Admin user management

Background: Admin logs in
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And clear mail deliveries
  And I enable "member_tagging" feature as a super user
  #And I reindex model "user"
  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Albers Mentor Program"

@javascript @p2
Scenario: Admin adds a new view with existing name and delete a view
  Then I follow "Manage"
  And I follow "User Views"
  And I click "#clicked-title-admin-view"
  And I should see "Create a new view"
  Then I follow "Create a new view"
  Then I should see "New View"
  And I fill in "admin_view_title" with "A New ,View"
  Then I follow "Next »"
  Then I click view
  Then I follow "Next »"
  Then I click view
  And I press "Create View"
  Then I should see "The View - A New ,View has been created successfully"
  And I click "#clicked-title-admin-view"
  And I should see "Create a new view"
  Then I follow "Create a new view"
  And I fill in "admin_view_title" with "A New ,View"
  Then I follow "Next »"
  Then I click view
  Then I follow "Next »"
  Then I click view
  And I press "Create View"
  Then I should see "You already have a view with this title"
  Then I close the flash
  Then I follow the back link
  Then I delete the view with title "A New ,View"
  And I logout

@javascript
Scenario: Admin adds a new view and does location filtering at program level
  Then I follow "Manage"
  And I follow "User Views"
  And I click "#clicked-title-admin-view"
  And I should see "Create a new view"
  Then I follow "Create a new view"
  Then I should see "New View"
  And I fill in "admin_view_title" with "Program Location View"
  Then I follow "Next »"
  Then I click view
  Then I should see "Profile Questions"
  Then I select "Location" from "admin_view_profile_questions_questions_1_question"
  Then I select "Not Contains Any Of" from "admin_view_profile_questions_questions_1_operator"
  Then I select "Contains Any Of" from "admin_view_profile_questions_questions_1_operator"
  Then I select "Country" from "admin_view_profile_questions_questions_1_scope"
  Then I click "#s2id_autogen5"
  Then I click on select2 result "India"
  Then I follow "Next »"
  Then I click view
  And I press "Create View"
  Then I should see "userrobert@example.com"
  Then I follow "Update View"
  Then I follow "Add one more"
  Then I select "Phone" from "admin_view_profile_questions_questions_2_question"
  Then I select "Not Contains" from "admin_view_profile_questions_questions_2_operator"
  Then I select "Contains" from "admin_view_profile_questions_questions_2_operator"
  Then I fill in "admin_view_profile_questions_questions_2_value" with "345"
  Then I select "About Me" from "admin_view_profile_questions_questions_1_question"
  Then I should not see "India"
  Then I follow "Add one more"
  Then I select "Location" from "admin_view_profile_questions_questions_3_question"
  Then I select "Contains Any Of" from "admin_view_profile_questions_questions_3_operator"
  Then I select "State" from "admin_view_profile_questions_questions_3_scope"
  Then I click "#s2id_autogen6"
  Then I click on select2 result "Tamil Nadu, India"
  Then I click ".fa.fa-trash"
  Then I click ".fa.fa-trash"
  Then I select "Location" from "admin_view_profile_questions_questions_1_question"
  Then I select "Contains Any Of" from "admin_view_profile_questions_questions_1_operator"
  Then I select "City" from "admin_view_profile_questions_questions_1_scope"
  Then I click "#s2id_autogen7"
  Then I click on select2 result "Chennai, Tamil Nadu, India"
  And I press "Update View"
  Then I should not see "userrobert@example.com"

@javascript
Scenario: Admin adds a new view and does location filtering at organization level
  Given the current program is "primary":""
  Then I follow "Manage"
  And I follow "Member Views"
  And I click "#clicked-title-admin-view"
  And I should see "Create a new view"
  Then I follow "Create a new view"
  Then I should see "New View"
  And I fill in "admin_view_title" with "Organization Location View"
  Then I follow "Next »"
  Then I click view
  Then I should see "Profile Questions"
  Then I select "Location" from "admin_view_profile_questions_questions_1_question"
  Then I select "Not Contains Any Of" from "admin_view_profile_questions_questions_1_operator"
  Then I select "Contains Any Of" from "admin_view_profile_questions_questions_1_operator"
  Then I select "Country" from "admin_view_profile_questions_questions_1_scope"
  Then I click "#s2id_autogen4"
  Then I click on select2 result "India"
  Then I follow "Next »"
  Then I click view
  And I press "Create View"
  Then I should see "robert@example.com"
  Then I should see "userrobert@example.com"
  Then I should see "no_mreq_mentor@example.com"
  Then I should see "no_mreq_student@example.com"
  Then I follow "Update View"
  Then I follow "Add one more"
  Then I select "Phone" from "admin_view_profile_questions_questions_2_question"
  Then I select "Not Contains" from "admin_view_profile_questions_questions_2_operator"
  Then I select "Contains" from "admin_view_profile_questions_questions_2_operator"
  Then I fill in "admin_view_profile_questions_questions_2_value" with "345"
  Then I select "About Me" from "admin_view_profile_questions_questions_1_question"
  Then I should not see "India"
  Then I follow "Add one more"
  Then I select "Location" from "admin_view_profile_questions_questions_3_question"
  Then I select "Contains Any Of" from "admin_view_profile_questions_questions_3_operator"
  Then I select "State" from "admin_view_profile_questions_questions_3_scope"
  Then I click "#s2id_autogen5"
  Then I click on select2 result "Tamil Nadu, India"
  Then I click ".fa.fa-trash"
  Then I click ".fa.fa-trash"
  Then I select "Location" from "admin_view_profile_questions_questions_1_question"
  Then I select "Contains Any Of" from "admin_view_profile_questions_questions_1_operator"
  Then I select "City" from "admin_view_profile_questions_questions_1_scope"
  Then I click "#s2id_autogen6"
  Then I click on select2 result "Chennai, Tamil Nadu, India"
  And I press "Update View"
  Then I should see "robert@example.com"
  Then I should see "no_mreq_mentor@example.com"
  Then I should not see "userrobert@example.com"
  Then I should not see "no_mreq_student@example.com"


@javascript
Scenario: Admin adds a new view with existing name and delete a view on organization level
  Given the current program is "primary":""
  Then I follow "Manage"
  And I follow "Member Views"
  And I click "#clicked-title-admin-view"
  And I should see "Create a new view"
  Then I follow "Create a new view"
  Then I should see "New View"
  And I fill in "admin_view_title" with "A New View"
  Then I follow "Next »"
  Then I click view
  Then I follow "Next »"
  Then I click view
  And I press "Create View"
  Then I should see "The View - A New View has been created successfully"
  And I click "#clicked-title-admin-view"
  And I should see "Create a new view"
  Then I follow "Create a new view"
  And I fill in "admin_view_title" with "A New View"
  Then I follow "Next »"
  Then I click view
  Then I follow "Next »"
  Then I click view
  And I press "Create View"
  Then I should see "You already have a view with this title"
  Then I close the flash
  And I follow the back link
  Then I delete the view with title "A New View"
  And I logout

@javascript @cross_browser
Scenario: Admin filtering in the view
  Then I follow "Manage"
  And I follow "User Views"
  Then I filter table by "email" with "nonexistingterm"
  Then I should see blank table
  Then I clear table filter for "email"

  And I should see "arun"
  And I should see "mentor_m"
  Then I filter table by "first_name" with "mentor_m"
  Then I should see "mentor_m"
  And I should not see "arun"
  Then I clear table filter for "first_name"

  Then I sort table by "email"
  And I should see "mentor_12@example.com"
  Then I check "ct_admin_view_checkbox_40"
  Then I check "ct_admin_view_checkbox_37"
  And I follow "Go to the next page"

  Then I check "ct_admin_view_checkbox_7"
  Then I click ".dropdown-toggle"
  Then I scroll down by "-10000"
  Then I set the focus to the main window
  Then I filter table by "first_name" with "mentor"
  And I should see "mentrostud@example.com"
  Then I clear table filter for "first_name"

  And I filter table by "last_name" with "mentor"
  And I should see "non_request@example.com"
  And I should see "request@example.com"
  Then I clear table filter for "last_name"

  And I should see "mentor_12@example.com"
  And I click on "cjs_send_message" in Actions

  Then I should see "rahim user, mentor_m chronus, arun albers"
  Then I cancel modal
  Then I logout

@javascript
Scenario: Ogranization admin views in Standalone Program
  When I logout
  Given the current program is "foster":""
  And I have logged in as "fosteradmin@example.com"
  And clear mail deliveries
  And I enable "organization_profiles" feature as a super user
  And I follow "Manage"
  Then I should see "Member Views"
  And I should see "User Views"
  Then I follow "Member Views"
  Then I should see "Anderson"
  And I should see "Eric"
  And I follow "Manage"
  Then I follow "User Views"
  Then I should see "Anderson"
  And I should see "Eric"
  And I follow "Manage"
  Then I follow "Member Views"
  Then I should see "All Members"
  Then I logout

@javascript @cross_browser
Scenario: Admin Bulk Actions
  #Bulk Deactivate
  Then I follow "Manage"
  And I follow "User Views"

  Then I should see "All Users"
  Then I should see "Actions"
  Then I add "arun@albers.com" from selection
  Then I add "userram@example.com" from selection
  Then I add "ram@example.com" from selection
  Then I add "robert@example.com" from selection

  Then I follow "Actions" within ".cjs-admin-views-actions"
  Then I follow "Deactivate Membership"
  Then I should see "The membership of the following users will be deactivated from the program"
  Then I fill in "admin_view_reason" with "You are deactivated"
  Then I click on input by value "Submit"
  #Org admin cannot be deactivated
  Then I in "60" seconds should see "The selected users membership have been deactivated from the program."
  Then I logout

  #Bulk Reactivate - delta indexing issue
  #Then I add "arun@albers.com" from selection
  #Then I add "userram@example.com" from selection
  #Then I add "ram@example.com" from selection
  #Then I add "robert@example.com" from selection

  #Then I follow "Actions" within ".cjs-admin-views-actions"
  #Then I follow "Reactivate Membership"
  #Then I should see " The membership of the following users will be reactivated in #the program"
  #Then I press "Submit"
  #Then I should see "The selected users membership have been reactivated"
  #Then I wait for ajax to complete
  #Then I reindex model "user"

 @javascript
 Scenario: Admin does bulk deactivate from remove user popup

  Then I follow "Manage"
  And I follow "User Views"
  Then I wait for ajax to complete
  Then I add "arun@albers.com" from selection
  Then I add "userram@example.com" from selection
  Then I add "robert@example.com" from selection

  Then I follow "Actions" within ".cjs-admin-views-actions"
  Then I follow "Remove User"
  Then I should see "You are about to remove 3 users"
  Then I should see "Removal of users is an irreversible action and will lead to loss of data. All their contributions in any mentoring connections, any activity in articles, forums and profile data including reporting information will be removed from the program permanently."
  Then I press "Deactivate Users"
  Then I wait for ajax to complete
  # Required since there is an animation delay
  Then I should see "The membership of the following users will be deactivated from the program"
  Then I fill in "admin_view_reason" with "You are deactivated"
  Then I press "Submit"
  #Org admin cannot be deactivated
  Then I should see "The selected users membership have been deactivated from the program."
  Then I logout

@javascript
Scenario: Admin does bulk removal of users

  Then I follow "Manage"
  And I follow "User Views"
  Then I wait for ajax to complete
  #Bulk Remove
  Then I add "arun@albers.com" from selection
  Then I add "userram@example.com" from selection
  Then I add "ram@example.com" from selection
  Then I add "robert@example.com" from selection

  Then I follow "Actions" within ".cjs-admin-views-actions"
  Then I follow "Remove User"
  Then I should see "You are about to remove 4 users"
  Then I should see "Removal of users is an irreversible action and will lead to loss of data. All their contributions in any mentoring connections, any activity in articles, forums and profile data including reporting information will be removed from the program permanently."
  Then I press "Remove Users"
  #Org admin cannot be removed
  Then I should see "Freakin Admin has not been removed"
  Then I wait for ajax to complete
  Then I add "mentor_0@example.com" from selection
  Then I add "mentor_1@example.com" from selection
  Then I add "mentor_2@example.com" from selection

  Then I follow "Actions" within ".cjs-admin-views-actions"
  Then I follow "Remove User"
  Then I should see "Removal of users is an irreversible action and will lead to loss of data. All their contributions in any mentoring connections, any activity in articles, forums and profile data including reporting information will be removed from the program permanently."
  Then I press "Remove Users"
  Then I should see "The selected users have been removed"
  Then I logout

@javascript @cross_browser
Scenario: Administrator send bulk admin message from org level admin view
  Given the current program is "primary":""
  And I follow "Manage"
  And I should see "Member Views"
  And I follow "Member Views"

  #Send Message
  Then I check "ct_admin_view_checkbox_3"
  And I click on "cjs_send_message" in Actions
  And I fill in "admin_message_subject" with "An admin view subject"
  And I fill in CKEditor "admin_message_content" with "An admin view message"
  And I press "Send"
  Then I should see "Your message has been sent"
  And I logout
  When I have logged in as "robert@example.com"
  Given "1" last "message" exist
  And I follow "Messages"
  Then I should see "Freakin Admin (Administrator)"
  Then I should see "An admin view subject - An admin view message"
  And I logout